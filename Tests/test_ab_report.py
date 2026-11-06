#!/usr/bin/env python3
"""tests/test_ab_report.py — tail statistics for the A/B report.

Run: python3 Tests/test_ab_report.py
"""
import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from test_ab_eval import load_module  # noqa: E402

rep = load_module("ab_report", "ab_report.py")


def record(duration=1.0, cost: float | None = 0.1, tokens: int | None = 10,
           diff: int | None = 1, passed=True):
    return {
        "task": "t", "arm": "vanilla", "pass": passed, "score": 1.0,
        "bugs_opened": 0, "tampered": False, "agent_error": False,
        "cost_usd": cost, "input_tokens": tokens, "output_tokens": 1,
        "turns": 1, "duration_s": duration, "diff_lines": diff,
    }


class TestPercentile(unittest.TestCase):
    def test_nearest_rank(self):
        self.assertEqual(rep.percentile([1, 2, 3, 4, 10], 90), 10)
        self.assertEqual(rep.percentile([1, 2, 3, 4], 50), 2)
        self.assertEqual(rep.percentile([1], 90), 1)

    def test_ignores_none_and_empty(self):
        self.assertEqual(rep.percentile([None, 1, None, 3], 50), 1)
        self.assertIsNone(rep.percentile([None, None], 90))
        self.assertIsNone(rep.percentile([], 90))

    def test_median_averages_the_middle_for_even_counts(self):
        self.assertEqual(rep.median([1, 2, 3, 4]), 2.5)
        self.assertEqual(rep.median([1, 2, 3]), 2)
        self.assertIsNone(rep.median([None]))


class TestTailStatistics(unittest.TestCase):
    def test_arm_summary_carries_median_and_p90(self):
        records = [
            record(duration=1, cost=0.1, tokens=10, diff=1),
            record(duration=2, cost=0.2, tokens=20, diff=2),
            record(duration=3, cost=0.3, tokens=30, diff=3),
            record(duration=4, cost=0.4, tokens=40, diff=4),
            record(duration=100, cost=10, tokens=1000, diff=50),
        ]
        summary = rep.arm_summary(records)
        self.assertEqual(summary["median_duration_s"], 3)
        self.assertEqual(summary["p90_duration_s"], 100)
        self.assertEqual(summary["median_cost_usd"], 0.3)
        self.assertEqual(summary["p90_cost_usd"], 10)
        self.assertEqual(summary["median_input_tokens"], 30)
        self.assertEqual(summary["p90_input_tokens"], 1000)
        self.assertEqual(summary["median_diff_lines"], 3)
        self.assertEqual(summary["p90_diff_lines"], 50)

    def test_mean_moves_more_than_median_on_an_outlier(self):
        records = [record(duration=1), record(duration=1), record(duration=1), record(duration=100)]
        summary = rep.arm_summary(records)
        self.assertEqual(summary["median_duration_s"], 1)
        self.assertGreater(summary["mean_duration_s"], summary["median_duration_s"])

    def test_missing_values_stay_none(self):
        records = [record(cost=None, tokens=None, diff=None)]
        summary = rep.arm_summary(records)
        self.assertIsNone(summary["median_cost_usd"])
        self.assertIsNone(summary["p90_cost_usd"])
        self.assertIsNone(summary["median_input_tokens"])
        self.assertIsNone(summary["p90_input_tokens"])
        self.assertIsNone(summary["median_diff_lines"])
        self.assertIsNone(summary["p90_diff_lines"])


if __name__ == "__main__":
    unittest.main(verbosity=2)
