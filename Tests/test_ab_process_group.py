#!/usr/bin/env python3
"""tests/test_ab_process_group.py — a timed-out adapter must not leave a grandchild alive.

Run: python3 Tests/test_ab_process_group.py
"""
import os
import subprocess
import sys
import tempfile
import time
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from test_ab_eval import load_module  # noqa: E402

runner = load_module("ab_process", "ab_process.py")


class TestProcessGroup(unittest.TestCase):
    def test_success_returns_stdout_and_exit(self):
        tmp = Path(tempfile.mkdtemp(prefix="ab-proc-ok-"))
        result = runner.run("printf hello", tmp, timeout=5)
        self.assertEqual(result.stdout, "hello")
        self.assertEqual(result.returncode, 0)

    def test_timeout_kills_the_whole_group(self):
        tmp = Path(tempfile.mkdtemp(prefix="ab-proc-timeout-"))
        marker = tmp / "child.pid"
        command = f"sleep 300 & echo $! > {marker}; wait"
        with self.assertRaises(subprocess.TimeoutExpired):
            runner.run(command, tmp, timeout=1)
        pid = int(marker.read_text().strip())
        time.sleep(0.2)
        with self.assertRaises(ProcessLookupError):
            os.kill(pid, 0)


if __name__ == "__main__":
    unittest.main(verbosity=2)
