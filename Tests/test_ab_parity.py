#!/usr/bin/env python3
"""tests/test_ab_parity.py — prove the moved harness still matches the source.

Three checks:
  1. every task file matches benchmarks/ab/TASKS.sha256
  2. every key in the pinned source report exists in a report built here
  3. the dry-run matrix lists the same tasks and arms

Run: python3 Tests/test_ab_parity.py
"""
import hashlib
import io
import json
import sys
import tempfile
import unittest
from contextlib import redirect_stdout
from pathlib import Path

import yaml

sys.path.insert(0, str(Path(__file__).resolve().parent))
from test_ab_eval import REPO_ROOT, load_module  # noqa: E402

ab = load_module("ab_eval", "ab-eval.py")
rep = load_module("ab_report", "ab_report.py")

OLD_REPORT = REPO_ROOT / "Tests" / "fixtures" / "ab-report-2026-11-03.yaml"
MANIFEST = REPO_ROOT / "benchmarks" / "ab" / "TASKS.sha256"


def keys_subset(old, new, path="report"):
    """Assert every key in old exists in new. Values are compared by key only."""
    if isinstance(old, dict):
        if not isinstance(new, dict):
            raise AssertionError(f"{path}: expected a dict, got {type(new).__name__}")
        missing = sorted(set(old) - set(new))
        if missing:
            raise AssertionError(f"{path}: missing keys {missing}")
        for key in old:
            keys_subset(old[key], new[key], f"{path}.{key}")
    elif isinstance(old, list) and old and isinstance(old[0], dict):
        if not isinstance(new, list) or not new:
            raise AssertionError(f"{path}: expected a non-empty list of dicts")
        keys_subset(old[0], new[0], f"{path}[0]")


class TestTaskTree(unittest.TestCase):
    def test_every_task_file_matches_the_manifest(self):
        lines = [line for line in MANIFEST.read_text().splitlines() if line.strip()]
        self.assertGreater(len(lines), 100)
        for line in lines:
            digest, rel = line.split("  ", 1)
            path = REPO_ROOT / rel
            self.assertTrue(path.is_file(), rel)
            self.assertEqual(hashlib.sha256(path.read_bytes()).hexdigest(), digest, rel)


class TestReportKeys(unittest.TestCase):
    def record(self, task, arm, passed):
        return {
            "task": task, "arm": arm, "pass": passed, "score": 1.0, "bugs_opened": 0,
            "tampered": False, "agent_error": False, "cost_usd": 0.01,
            "input_tokens": 100, "output_tokens": 20, "turns": 1, "duration_s": 1.0,
            "diff_lines": 2,
            "vsm": {"lead_time_s": 1.0, "time_to_first_build_s": 0.1, "switches": 1,
                    "stages": {"plan": {"s": 0.1}, "design": {"s": 0.2},
                               "build": {"s": 0.3}, "test": {"s": 0.4},
                               "deploy": {"s": 0.0}, "maintain": {"s": 0.0}}},
            "waste": {"test_runs": 1, "redundant_test_runs": 0, "rework_loops": 0,
                      "reedits": 0, "rereads": 0, "repeated_commands": 0,
                      "review_load": 1, "diff_ratio": 1.0, "ftt": True, "pce": 0.5,
                      "leftovers": [], "extra_files": []},
        }

    def test_source_report_keys_survive(self):
        old = yaml.safe_load(OLD_REPORT.read_text())
        tasks, arms = old["tasks"], old["arms"]
        records = [self.record(t, a, i % 2 == 0) for t in tasks for a in arms for i in range(2)]
        result = rep.aggregate(records, arms, tasks)
        meta = {k: old[k] for k in (
            "generated_at", "bigpowers_sha", "runner_sha", "adapter", "model", "k",
            "tasks", "arms", "arm_setup", "ci_method", "notes") if k in old}
        keys_subset(old, {**meta, **result})


class TestDryRunMatrix(unittest.TestCase):
    def test_matrix_covers_every_task_and_arm(self):
        tmp = Path(tempfile.mkdtemp(prefix="ab-parity-"))
        (tmp / "subject" / "skills" / "x").mkdir(parents=True)
        (tmp / "subject" / "scripts").mkdir()
        buf = io.StringIO()
        with redirect_stdout(buf):
            code = ab.main(["--dry-run", "--bigpowers-root", str(tmp / "subject"),
                            "--out", str(tmp / "out")])
        self.assertEqual(code, 0)
        lines = [line for line in buf.getvalue().splitlines() if line.startswith("  ab-")]
        tasks = list((REPO_ROOT / "benchmarks" / "ab" / "tasks").glob("*/task.yaml"))
        arms = [a for a in ab.DEFAULT_ARMS.split(",") if a]
        self.assertEqual(len(lines), len(tasks) * len(arms))
        self.assertTrue(any("ab-11" in line and "bigpowers" in line for line in lines))


if __name__ == "__main__":
    unittest.main(verbosity=2)
