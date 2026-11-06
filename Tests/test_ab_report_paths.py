#!/usr/bin/env python3
"""tests/test_ab_report_paths.py — one report directory, the canonical one.

Run: python3 Tests/test_ab_report_paths.py
"""
import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from test_ab_eval import REPO_ROOT, load_module  # noqa: E402

ab = load_module("ab_eval", "ab-eval.py")


class TestReportPaths(unittest.TestCase):
    def test_the_duplicate_path_is_gone(self):
        self.assertFalse((REPO_ROOT / "benchmarks" / "ab" / "reports").exists())

    def test_the_canonical_path_is_used(self):
        self.assertEqual(ab.DEFAULT_OUT, REPO_ROOT / "benchmarks" / "reports")
        self.assertTrue(ab.DEFAULT_OUT.is_dir())


if __name__ == "__main__":
    unittest.main(verbosity=2)
