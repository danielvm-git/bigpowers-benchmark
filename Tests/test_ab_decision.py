#!/usr/bin/env python3
"""tests/test_ab_decision.py — the pre-registered decision policy.

Run: python3 Tests/test_ab_decision.py
"""
import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from test_ab_eval import load_module  # noqa: E402

dec = load_module("ab_decision", "ab_decision.py")


def summary(cost=0.01, tamper=0.0, error=0.0):
    return {"mean_cost_usd": cost, "tamper_rate": tamper, "agent_error_rate": error}


def delta(pass_gain, ci=None, score=None, score_ci=None, cost=0.0):
    return {"pass_rate": pass_gain, "ci95": ci, "score": score,
            "score_ci95": score_ci, "cost_usd": cost}


class TestDecide(unittest.TestCase):
    def test_clear_gain_ships(self):
        result = dec.decide("bigpowers", summary(), delta(0.10, [0.06, 0.20], 0.05, [0.03, 0.08]),
                            None, 17, 1.0, 1.0)
        self.assertEqual(result["verdict"], "ship")
        self.assertTrue(result["reasons"])

    def test_tamper_rejects_before_any_analysis(self):
        result = dec.decide("bigpowers", summary(tamper=0.05),
                            delta(0.50, [0.40, 0.60]), None, 17)
        self.assertEqual(result["verdict"], "reject")
        self.assertTrue(any("tamper" in reason for reason in result["reasons"]))

    def test_cost_without_gain_rejects(self):
        result = dec.decide("bigpowers", summary(cost=0.02),
                            delta(0.0, [-0.05, 0.05], 0.0, [-0.01, 0.01]), None, 17, 2.0, 1.0)
        self.assertEqual(result["verdict"], "reject")
        self.assertTrue(any("cost" in reason for reason in result["reasons"]))

    def test_high_cost_with_clear_gain_ships_with_a_warning(self):
        result = dec.decide("bigpowers", summary(cost=0.02),
                            delta(0.10, [0.06, 0.20]), None, 17, 2.0, 1.0)
        self.assertEqual(result["verdict"], "ship")
        self.assertTrue(result["warnings"])

    def test_wide_ci_is_inconclusive(self):
        result = dec.decide("bigpowers", summary(),
                            delta(0.02, [-0.02, 0.06], 0.01, [-0.01, 0.03]), None, 17, 1.1, 1.1)
        self.assertEqual(result["verdict"], "inconclusive")

    def test_regression_rejects(self):
        result = dec.decide("bigpowers", summary(), delta(-0.10, [-0.20, -0.02]), None, 17)
        self.assertEqual(result["verdict"], "reject")
        self.assertTrue(any("regression" in reason for reason in result["reasons"]))

    def test_missing_ci_is_not_a_ship(self):
        result = dec.decide("bigpowers", summary(), delta(0.10), None, 17)
        self.assertEqual(result["verdict"], "inconclusive")

    def test_low_audit_clean_rate_rejects(self):
        result = dec.decide("bigpowers", summary(), delta(0.10, [0.06, 0.20]), None, 17,
                            quality={"audit_clean_rate": 0.5})
        self.assertEqual(result["verdict"], "reject")
        self.assertTrue(any("audit" in reason for reason in result["reasons"]))

    def test_too_few_tasks_is_inconclusive(self):
        result = dec.decide("bigpowers", summary(), delta(0.10, [0.06, 0.20]),
                            {"min_discriminating_tasks": 10}, 3)
        self.assertEqual(result["verdict"], "inconclusive")


class TestPreregistration(unittest.TestCase):
    def test_hash_is_stable_and_sensitive(self):
        a = dec.preregistration_sha({}, ["vanilla"], ["ab-01"], 10, "pi-docker", "m")
        b = dec.preregistration_sha({}, ["vanilla"], ["ab-01"], 10, "pi-docker", "m")
        c = dec.preregistration_sha({"max_cost_multiplier": 2.0}, ["vanilla"], ["ab-01"], 10,
                                    "pi-docker", "m")
        self.assertEqual(a, b)
        self.assertNotEqual(a, c)


if __name__ == "__main__":
    unittest.main(verbosity=2)
