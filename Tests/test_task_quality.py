#!/usr/bin/env python3
"""tests/test_task_quality.py — a task spec must describe behaviour, not an implementation.

Run: python3 Tests/test_task_quality.py
"""
import sys
import unittest
from pathlib import Path

import yaml

sys.path.insert(0, str(Path(__file__).resolve().parent))
from test_ab_eval import REPO_ROOT  # noqa: E402

TASKS = [
    "ab-09-inventory-reservations",
    "ab-17-payment-alias",
    "ab-19-catalog-segregation",
    "ab-20-brand-discount",
    "ab-21-todo-due-dates",
    "ab-22-items-api",
    "ab-23-resume-migration",
    "ab-24-url-shortener",
    "ab-25-resumable-worker",
    "ab-26-mini-redis",
    "ab-27-banking-ledger",
    "ab-28-flight-booking",
    "ab-29-hr-payroll",
    "ab-30-project-dag",
    "ab-31-chat-ordering",
    "ab-32-social-feed",
    "ab-33-music-store",
    "ab-34-recommender",
    "ab-35-todo-collab",
    "ab-36-project-timeline",
    "ab-37-loans",
    "ab-38-timeline-replan",
    "ab-39-social-messaging",
    "ab-40-ledger-holds",
    "ab-41-json-parser",
    "ab-42-binary-protocol",
    "ab-43-package-resolver",
    "ab-44-fair-scheduler",
    "ab-45-fx-settlement",
    "ab-46-policy-engine",
    "ab-47-inventory-reservations",
    "ab-48-feed-cursor",
    "ab-49-order-workflow",
    "ab-50-warehouse-fulfillment",
    "ab-51-auction-engine",
    "ab-52-receivables-reconciliation",
]
MIN_HIDDEN = {
    "ab-09-inventory-reservations": 8,
    "ab-17-payment-alias": 8,
    "ab-19-catalog-segregation": 8,
    "ab-20-brand-discount": 8,
    "ab-21-todo-due-dates": 8,
    "ab-22-items-api": 8,
    "ab-23-resume-migration": 6,
    "ab-24-url-shortener": 9,
    "ab-25-resumable-worker": 7,
    "ab-26-mini-redis": 10,
    "ab-27-banking-ledger": 9,
    "ab-28-flight-booking": 8,
    "ab-29-hr-payroll": 9,
    "ab-30-project-dag": 7,
    "ab-31-chat-ordering": 8,
    "ab-32-social-feed": 9,
    "ab-33-music-store": 6,
    "ab-34-recommender": 7,
    "ab-35-todo-collab": 6,
    "ab-36-project-timeline": 7,
    "ab-37-loans": 6,
    "ab-38-timeline-replan": 6,
    "ab-39-social-messaging": 6,
    "ab-40-ledger-holds": 9,
    "ab-41-json-parser": 3,
    "ab-42-binary-protocol": 7,
    "ab-43-package-resolver": 6,
    "ab-44-fair-scheduler": 6,
    "ab-45-fx-settlement": 6,
    "ab-46-policy-engine": 7,
    "ab-47-inventory-reservations": 8,
    "ab-48-feed-cursor": 7,
    "ab-49-order-workflow": 7,
    "ab-50-warehouse-fulfillment": 10,
    "ab-51-auction-engine": 8,
    "ab-52-receivables-reconciliation": 10,
}
IMPLEMENTATION_MARKERS = [
    "Math.",
    "clock.now() +",
    "getActiveHolds",
    "updateStock(",
    "allocate(",
    "toLine(",
    "formatMoney(",
    "```js\n",
    "```javascript\n",
]


class TestTaskQuality(unittest.TestCase):
    def task_dir(self, name):
        return REPO_ROOT / "benchmarks" / "ab" / "tasks" / name

    def test_hard_tasks_declare_behavioural_specs(self):
        for name in TASKS:
            task = yaml.safe_load((self.task_dir(name) / "task.yaml").read_text())
            self.assertEqual(task.get("spec_style"), "behavioural", name)
            self.assertNotIn("```", task["prompt"], name)

    def test_hard_specs_do_not_contain_implementation_recipes(self):
        for name in TASKS:
            fixture = self.task_dir(name) / "fixture"
            specs = list((fixture / "docs").glob("*.md"))
            specs += [candidate for candidate in (fixture / "ISSUE.md", fixture / "STATE.md")
                      if candidate.is_file()]
            self.assertTrue(specs, name)
            text = "\n".join(spec.read_text() for spec in specs)
            for marker in IMPLEMENTATION_MARKERS:
                self.assertNotIn(marker, text, f"{name}: {marker}")

    def test_each_requirement_names_a_hidden_test(self):
        for name in TASKS:
            task = yaml.safe_load((self.task_dir(name) / "task.yaml").read_text())
            requirements = task.get("requirements") or []
            self.assertGreaterEqual(len(requirements), 5, name)
            hidden = "\n".join(
                test.read_text()
                for test in (self.task_dir(name) / "hidden" / "test-hidden").glob("*.test.js")
            )
            for requirement in requirements:
                self.assertIn(requirement["hidden"], hidden,
                              f"{name}/{requirement['id']} has no matching hidden test")

    def test_hard_tasks_have_multiple_hidden_tests(self):
        for name in TASKS:
            tests = list((self.task_dir(name) / "hidden" / "test-hidden").glob("*.test.js"))
            self.assertTrue(tests, name)
            count = sum(test.read_text().count("test(") for test in tests)
            self.assertGreaterEqual(count, MIN_HIDDEN[name],
                                    f"{name}: only {count} hidden tests")


if __name__ == "__main__":
    unittest.main(verbosity=2)
