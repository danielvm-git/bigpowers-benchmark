#!/usr/bin/env python3
"""tests/test_ab_provenance.py — deterministic content hashes and dirty-subject guards.

Run: python3 Tests/test_ab_provenance.py
"""
import io
import json
import subprocess
import sys
import tempfile
import unittest
from contextlib import redirect_stdout
from pathlib import Path

import yaml

sys.path.insert(0, str(Path(__file__).resolve().parent))
from test_ab_eval import load_module  # noqa: E402

prov = load_module("ab_provenance", "ab_provenance.py")
ab = load_module("ab_eval", "ab-eval.py")
dec = load_module("ab_decision", "ab_decision.py")


def git(root, *args):
    subprocess.run(["git", "-c", "user.name=t", "-c", "user.email=t@t", *args],
                   cwd=root, check=True, capture_output=True)


class ProvenanceFixture(unittest.TestCase):
    def setUp(self):
        self.tmp = Path(tempfile.mkdtemp(prefix="ab-prov-"))
        self.subject = self.tmp / "subject"
        (self.subject / "skills" / "skill-a").mkdir(parents=True)
        (self.subject / "skills" / "skill-a" / "SKILL.md").write_text("a\n")
        (self.subject / "scripts").mkdir()
        (self.subject / "scripts" / "x.sh").write_text("echo x\n")
        git(self.subject, "init", "-q")
        git(self.subject, "add", "-A")
        git(self.subject, "commit", "-q", "-m", "init")

        self.runner = self.tmp / "runner"
        (self.runner / "benchmarks" / "ab" / "tasks").mkdir(parents=True)
        (self.runner / "README.md").write_text("runner\n")
        git(self.runner, "init", "-q")
        git(self.runner, "add", "-A")
        git(self.runner, "commit", "-q", "-m", "init")

        self.config = self.tmp / "config.yaml"
        self.config.write_text(yaml.safe_dump({"k": 1, "arms": {"vanilla": {"setup": "true"}},
                                               "adapters": {"claude": {"command": "false"}}}))

        self.task = self.tmp / "task"
        for name in ("fixture", "hidden", "solution"):
            (self.task / name).mkdir(parents=True)
            (self.task / name / "file.txt").write_text(name + "\n")
        (self.task / "task.yaml").write_text(yaml.safe_dump({
            "id": "t-01", "prompt": "x", "grade": "true", "timeout_s": 30}))
        self.tasks = [{"id": "t-01", "dir": self.task}]

    def test_tree_hash_is_deterministic_and_excludes_vendor_dirs(self):
        first = prov.sha256_tree(self.subject)
        (self.subject / "node_modules" / "pkg").mkdir(parents=True)
        (self.subject / "node_modules" / "pkg" / "x").write_text("noise")
        self.assertEqual(prov.sha256_tree(self.subject), first)

    def test_dirty_subject_records_a_diff_hash(self):
        clean = prov.git_state(self.subject)
        self.assertFalse(clean["dirty"])
        (self.subject / "new.txt").write_text("changed")
        dirty = prov.git_state(self.subject)
        self.assertTrue(dirty["dirty"])
        self.assertIsNotNone(dirty["dirty_diff_sha"])

    def test_collect_inputs_has_the_required_blocks(self):
        inputs = prov.collect_inputs(self.subject, self.runner, self.config, self.tasks)
        self.assertEqual(inputs["schema"], 1)
        self.assertFalse(inputs["subject"]["dirty"])
        self.assertEqual(inputs["tasks"]["t-01"]["task_yaml"],
                         prov.sha256_file(self.task / "task.yaml"))
        self.assertEqual(inputs["tasks"]["t-01"]["fixture"],
                         prov.sha256_tree(self.task / "fixture"))
        self.assertEqual(inputs["config"]["sha256"], prov.sha256_file(self.config))
        self.assertIsNone(inputs["image"]["id"])

    def test_digest_is_stable_and_diff_detects_changes(self):
        inputs = prov.collect_inputs(self.subject, self.runner, self.config, self.tasks)
        self.assertEqual(prov.input_digest(inputs), prov.input_digest(inputs))
        changed = json.loads(json.dumps(inputs))
        changed["subject"]["dirty"] = True
        self.assertTrue(prov.diff_inputs(inputs, changed))
        self.assertEqual(prov.diff_inputs(inputs, inputs), [])

    def test_dirty_subject_aborts_unless_allowed(self):
        (self.subject / "new.txt").write_text("changed")
        argv = ["--config", str(self.config), "--tasks-dir", str(self.tmp),
                "--bigpowers-root", str(self.subject), "--out", str(self.tmp / "out"),
                "--arms", "vanilla", "--dry-run"]
        self.assertEqual(ab.main(argv), 2)
        with redirect_stdout(io.StringIO()):
            self.assertEqual(ab.main(argv + ["--allow-dirty"]), 0)

    def test_verify_inputs_cli(self):
        inputs = prov.collect_inputs(self.subject, ab.RUNNER_ROOT, self.config, self.tasks)
        policy = dec.policy_with_defaults({})
        inputs["decision"] = {
            "policy": policy,
            "preregistration_sha": dec.preregistration_sha(
                policy, ["vanilla"], ["t-01"], 1, "claude", None),
        }
        report = self.tmp / "report.json"
        report.write_text(json.dumps({"inputs": inputs}))
        argv = ["--config", str(self.config), "--tasks-dir", str(self.tmp),
                "--bigpowers-root", str(self.subject), "--arms", "vanilla",
                "--verify-inputs", str(report)]
        with redirect_stdout(io.StringIO()):
            self.assertEqual(ab.main(argv), 0)
        (self.subject / "new.txt").write_text("changed")
        with redirect_stdout(io.StringIO()):
            self.assertEqual(ab.main(argv), 2)


if __name__ == "__main__":
    unittest.main(verbosity=2)
