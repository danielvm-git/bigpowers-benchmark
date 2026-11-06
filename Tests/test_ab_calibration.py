#!/usr/bin/env python3
"""tests/test_ab_calibration.py — vanilla-only task difficulty calibration.

Run: python3 Tests/test_ab_calibration.py
"""
import io
import sys
import tempfile
import unittest
from contextlib import redirect_stdout
from pathlib import Path

import yaml

sys.path.insert(0, str(Path(__file__).resolve().parent))
from test_ab_eval import load_module  # noqa: E402

cal = load_module("ab_calibration", "ab_calibration.py")
ab = load_module("ab_eval", "ab-eval.py")


def record(passed, score=None, timed_out=False, error=False):
    return {"task": "t-01", "arm": "vanilla", "pass": passed, "score": score,
            "timed_out": timed_out, "agent_error": error}


class TestClassify(unittest.TestCase):
    def test_band_boundaries(self):
        self.assertEqual(cal.classify(0.0), "too_hard")
        self.assertEqual(cal.classify(0.19), "too_hard")
        self.assertEqual(cal.classify(0.2), "discriminating")
        self.assertEqual(cal.classify(0.5), "discriminating")
        self.assertEqual(cal.classify(0.8), "discriminating")
        self.assertEqual(cal.classify(0.81), "too_easy")
        self.assertEqual(cal.classify(1.0), "too_easy")
        self.assertEqual(cal.classify(None), "unknown")


class TestSummarize(unittest.TestCase):
    def test_pass_rate_score_and_band(self):
        records = [record(True, 1.0), record(False, 0.5), record(False), record(True, 1.0)]
        results = cal.summarize(records, [{"id": "t-01"}])
        self.assertEqual(results[0]["runs"], 4)
        self.assertEqual(results[0]["passes"], 2)
        self.assertEqual(results[0]["pass_rate"], 0.5)
        self.assertEqual(results[0]["mean_score"], 0.8333)
        self.assertEqual(results[0]["band"], "discriminating")

    def test_counts(self):
        results = [{"band": "too_easy"}, {"band": "discriminating"},
                   {"band": "too_hard"}, {"band": "unknown"}]
        self.assertEqual(cal.counts(results),
                         {"too_easy": 1, "discriminating": 1, "too_hard": 1, "unknown": 1})


class TestCalibrationCache(unittest.TestCase):
    def test_cache_key_is_stable_and_input_sensitive(self):
        tmp = Path(tempfile.mkdtemp(prefix="ab-cal-cache-"))
        task_dir = tmp / "task"
        (task_dir / "fixture").mkdir(parents=True)
        (task_dir / "fixture" / "file").write_text("x")
        (task_dir / "task.yaml").write_text(yaml.safe_dump({"id": "t-01", "prompt": "x",
                                                             "grade": "true", "timeout_s": 30}))
        task = {"id": "t-01", "dir": task_dir}
        a = cal.cache_key(task, "pi-docker", "m", 10, "true")
        b = cal.cache_key(task, "pi-docker", "m", 10, "true")
        c = cal.cache_key(task, "pi-docker", "m", 5, "true")
        self.assertEqual(a, b)
        self.assertNotEqual(a, c)
        path = tmp / "cache.json"
        cal.save_cache(path, {a: {"pass_rate": 0.5}})
        self.assertEqual(cal.load_cache(path)[a]["pass_rate"], 0.5)


class TestCalibrationRun(unittest.TestCase):
    def test_cli_writes_a_report_and_band(self):
        tmp = Path(tempfile.mkdtemp(prefix="ab-cal-"))
        task = tmp / "task"
        (task / "fixture").mkdir(parents=True)
        (task / "hidden").mkdir()
        (task / "hidden" / "check.sh").write_text("test -f ok.txt\n")
        (task / "solution").mkdir()
        (task / "solution" / "ok.txt").write_text("ok\n")
        (task / "task.yaml").write_text(yaml.safe_dump({
            "id": "t-01", "prompt": "make ok.txt", "grade": "sh check.sh",
            "timeout_s": 120,
        }))
        subject = tmp / "subject"
        subject.mkdir()
        config = tmp / "config.yaml"
        config.write_text(yaml.safe_dump({
            "k": 4, "arms": {"vanilla": {"setup": "true"}},
            "adapters": {"claude": {"command": "false"}},
        }))
        counter = tmp / "counter"
        adapter = (
            f'n=$(cat {counter} 2>/dev/null || echo 0); n=$((n+1)); echo $n > {counter}; '
            f'if [ "$n" -le 2 ]; then cp -R {task}/solution/. .; fi'
        )
        out = tmp / "out"
        argv = ["--calibrate", "--config", str(config), "--tasks-dir", str(tmp),
                "--bigpowers-root", str(subject), "--adapter-cmd", adapter,
                "--k", "4", "--skip-preflight", "--no-calibration-cache", "--out", str(out)]
        with redirect_stdout(io.StringIO()):
            self.assertEqual(ab.main(argv), 0)
        report = yaml.safe_load(next(out.glob("CALIBRATION-*.yaml")).read_text())
        self.assertEqual(report["kind"], "calibration")
        result = report["results"][0]
        self.assertEqual(result["pass_rate"], 0.5)
        self.assertEqual(result["band"], "discriminating")
        self.assertEqual(report["summary"]["discriminating"], 1)


if __name__ == "__main__":
    unittest.main(verbosity=2)
