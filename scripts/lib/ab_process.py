#!/usr/bin/env python3
"""Subprocess helper that kills the whole process group on timeout.

A timed-out `bash -c` can leave node/python grandchildren running; under CI contention they
poison later tests. start_new_session + killpg makes timeout cleanup deterministic.
"""
from __future__ import annotations

import os
import signal
import subprocess
from pathlib import Path


def run(command: str, cwd: Path, env: dict | None = None, timeout: float | None = None,
        stdin: int | None = subprocess.DEVNULL) -> subprocess.CompletedProcess:
    process = subprocess.Popen(
        ["bash", "-c", command], cwd=cwd, env=env, stdin=stdin,
        stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True,
        start_new_session=True,
    )
    try:
        stdout, stderr = process.communicate(timeout=timeout)
    except subprocess.TimeoutExpired:
        try:
            os.killpg(os.getpgid(process.pid), signal.SIGKILL)
        except (ProcessLookupError, PermissionError):
            pass
        stdout, stderr = process.communicate()
        raise subprocess.TimeoutExpired(
            process.args, timeout or 0, output=stdout, stderr=stderr)
    return subprocess.CompletedProcess(process.args, process.returncode, stdout, stderr)
