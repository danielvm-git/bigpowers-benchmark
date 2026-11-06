#!/usr/bin/env python3
"""tests/test_ab_preflight.py — prove a fixture is a valid experiment before any agent runs.

Run: python3 Tests/test_ab_preflight.py
"""
import io
import json
import shutil
import subprocess
import sys
import tempfile
import unittest
from contextlib import redirect_stdout
from pathlib import Path

import yaml

sys.path.insert(0, str(Path(__file__).resolve().parent))
from test_ab_eval import load_module  # noqa: E402

pre = load_module("ab_preflight", "ab_preflight.py")
ab = load_module("ab_eval", "ab-eval.py")
prov = load_module("ab_provenance", "ab_provenance.py")


def git(root, *args):
    subprocess.run(["git", "-c", "user.name=t", "-c", "user.email=t@t", *args],
                   cwd=root, check=True, capture_output=True)


class PreflightFixture(unittest.TestCase):
    def setUp(self):
        self.tmp = Path(tempfile.mkdtemp(prefix="ab-pre-"))
        self.subject = self.tmp / "subject"
        (self.subject / "skills" / "s").mkdir(parents=True)
        (self.subject / "skills" / "s" / "SKILL.md").write_text("s\n")
        (self.subject / "scripts").mkdir()
        (self.subject / "scripts" / "x").write_text("x\n")
        git(self.subject, "init", "-q")
        git(self.subject, "add", "-A")
        git(self.subject, "commit", "-qm", "init")

        self.task_dir = self.tmp / "task"
        (self.task_dir / "fixture").mkdir(parents=True)
        (self.task_dir / "fixture" / "keep.txt").write_text("fixture\n")
        (self.task_dir / "hidden").mkdir()
        (self.task_dir / "hidden" / "check.sh").write_text("test -f ok.txt\n")
        (self.task_dir / "solution").mkdir()
        (self.task_dir / "solution" / "ok.txt").write_text("ok\n")
        (self.task_dir / "task.yaml").write_text(yaml.safe_dump({
            "id": "t-01", "prompt": "make ok.txt", "protected": [],
            "grade": "sh check.sh", "score": "printf '# pass 1\\n# fail 0\\n'",
            "timeout_s": 30,
            "preflight": {"visible_tests": "fail", "command": "test -f ok.txt"},
        }))
        self.tasks = [{"id": "t-01", "dir": self.task_dir,
                       **yaml.safe_load((self.task_dir / "task.yaml").read_text())}]
        self.arms = {"vanilla": {"setup": "true"}}
        self.adapter = {"name": "claude", "command": "false", "parser": "claude-json"}

    def test_valid_fixture_passes_all_checks(self):
        result = pre.preflight_task(self.tasks[0], self.arms, self.adapter,
                                    self.subject, ab.RUNNER_ROOT, None, cache=None)
        self.assertTrue(result["ok"])
        names = {check["check"] for check in result["checks"]}
        self.assertIn("setup:vanilla", names)
        self.assertIn("visible_tests", names)
        self.assertIn("fixture_fails_grade", names)
        self.assertIn("solution_passes_grade", names)
        self.assertIn("solution_score", names)

    def test_broken_visible_test_fails(self):
        task = dict(self.tasks[0])
        task["preflight"] = {"visible_tests": "pass", "command": "false"}
        result = pre.preflight_task(task, self.arms, self.adapter,
                                    self.subject, ab.RUNNER_ROOT, None, cache=None)
        self.assertFalse(result["ok"])
        self.assertTrue(any(c["check"] == "visible_tests" and not c["ok"] for c in result["checks"]))

    def test_solution_that_fails_grade_is_rejected(self):
        (self.task_dir / "solution" / "ok.txt").unlink()
        result = pre.preflight_task(self.tasks[0], self.arms, self.adapter,
                                    self.subject, ab.RUNNER_ROOT, None, cache=None)
        self.assertFalse(result["ok"])
        self.assertTrue(any(c["check"] == "solution_passes_grade" and not c["ok"]
                            for c in result["checks"]))

    def test_cache_hit_skips_the_checks(self):
        cache = {}
        first = pre.preflight_task(self.tasks[0], self.arms, self.adapter,
                                   self.subject, ab.RUNNER_ROOT, None, cache=cache)
        second = pre.preflight_task(self.tasks[0], self.arms, self.adapter,
                                    self.subject, ab.RUNNER_ROOT, None, cache=cache)
        self.assertTrue(first["ok"])
        self.assertTrue(second["cached"])

    def test_preflight_only_cli_runs_before_an_agent(self):
        config = self.tmp / "config.yaml"
        config.write_text(yaml.safe_dump({
            "k": 1, "arms": {"vanilla": {"setup": "true"}},
            "adapters": {"claude": {"command": "false", "parser": "claude-json"}},
        }))
        marker = self.tmp / "ran.txt"
        argv = ["--config", str(config), "--tasks-dir", str(self.tmp),
                "--bigpowers-root", str(self.subject), "--arms", "vanilla",
                "--adapter-cmd", f"touch {marker}", "--preflight-only",
                "--preflight-cache", str(self.tmp / "cache.json")]
        with redirect_stdout(io.StringIO()):
            self.assertEqual(ab.main(argv), 0)
        self.assertFalse(marker.exists())

    def test_preflight_failure_aborts_before_an_agent(self):
        config = self.tmp / "config.yaml"
        config.write_text(yaml.safe_dump({
            "k": 1, "arms": {"vanilla": {"setup": "true"}},
            "adapters": {"claude": {"command": "false", "parser": "claude-json"}},
        }))
        (self.task_dir / "solution" / "ok.txt").unlink()
        marker = self.tmp / "ran.txt"
        argv = ["--config", str(config), "--tasks-dir", str(self.tmp),
                "--bigpowers-root", str(self.subject), "--arms", "vanilla",
                "--adapter-cmd", f"touch {marker}",
                "--preflight-cache", str(self.tmp / "cache.json"), "--k", "1"]
        with redirect_stdout(io.StringIO()):
            self.assertEqual(ab.main(argv), 2)
        self.assertFalse(marker.exists())

    def test_grade_wrapper_runs_against_the_solution_workdir(self):
        adapter = {**self.adapter,
                   "grade_wrapper": 'cd "$AB_WORKDIR" && bash -c "$AB_CMD"'}
        result = pre.preflight_task(self.tasks[0], self.arms, adapter,
                                    self.subject, ab.RUNNER_ROOT, None, cache=None)
        self.assertTrue(result["ok"])

    def test_ab_03_declares_a_red_visible_suite(self):
        task = yaml.safe_load((Path(ab.AB_DIR) / "tasks" / "ab-03-red-suite-slugify" / "task.yaml").read_text())
        self.assertEqual(task["preflight"]["visible_tests"], "fail")


if __name__ == "__main__":
    unittest.main(verbosity=2)
