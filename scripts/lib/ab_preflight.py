#!/usr/bin/env python3
"""Pristine-fixture preflight: prove every selected task is a valid experiment before an agent runs.

For each task: arm setup exits 0, the visible tests match their declared expectation,
fixture + hidden fails grade, and solution + hidden passes grade (score 1.0 when present).
Results are cached by content digest so a repeated run pays nothing.
"""
from __future__ import annotations

import hashlib
import json
import os
import shutil
import subprocess
import tempfile
import time
from pathlib import Path

from ab_metrics import tap_score  # type: ignore[import]
from ab_provenance import docker_image_id, task_hashes  # type: ignore[import]
from ab_process import run as run_process  # type: ignore[import]

GIT_ID = ["-c", "user.name=ab-preflight", "-c", "user.email=ab@local", "-c", "commit.gpgsign=false"]


def run(command: str, cwd: Path, env: dict, adapter: dict | None = None,
        timeout: float = 300) -> dict:
    actual = command
    actual_env = env
    if adapter and adapter.get("grade_wrapper"):
        actual = adapter["grade_wrapper"]
        actual_env = {**env, "AB_CMD": command}
    started = time.monotonic()
    try:
        result = run_process(actual, cwd, env=actual_env, timeout=timeout)
        return {"command": command, "exit": result.returncode,
                "stdout": result.stdout[-4000:], "stderr": result.stderr[-4000:],
                "duration_s": round(time.monotonic() - started, 2)}
    except subprocess.TimeoutExpired as exc:
        return {"command": command, "exit": None, "timeout": True,
                "stdout": (exc.stdout or "")[-4000:], "stderr": "timed out",
                "duration_s": round(time.monotonic() - started, 2)}


def env_for(task: dict, subject_root: Path, runner_root: Path, workdir: Path, home: Path,
            model: str | None, timeout_s: int) -> dict:
    env = dict(os.environ)
    env.update({
        "AB_PROMPT": task["prompt"], "AB_MODEL": model or "",
        "AB_WORKDIR": str(workdir), "AB_HOME": str(home),
        "AB_BP_ROOT": str(subject_root), "AB_RUNNER_ROOT": str(runner_root),
        "AB_TIMEOUT": str(max(10, timeout_s - 30)),
    })
    return env


def git(workdir: Path, *args: str) -> None:
    subprocess.run(["git", *GIT_ID, *args], cwd=workdir, check=True, capture_output=True)


def visible_command(task: dict) -> tuple[str | None, bool]:
    """(command, expected_pass); a red-suite task declares visible_tests: fail."""
    preflight = task.get("preflight") or {}
    expected_pass = preflight.get("visible_tests", "pass") == "pass"
    command = preflight.get("command")
    if command is None and (task["dir"] / "fixture" / "package.json").is_file():
        command = "npm test"
    return command, expected_pass


def cache_key(task: dict, arms: dict, adapter: dict, image: str | None) -> str:
    payload = {
        "task": task_hashes(task["dir"]),
        "setup": {name: spec["setup"] for name, spec in arms.items()},
        "grade": task.get("grade"), "score": task.get("score"),
        "preflight": task.get("preflight"),
        "image": image or docker_image_id(None),
        "adapter": adapter.get("name"), "wrapper": adapter.get("grade_wrapper"),
    }
    return hashlib.sha256(json.dumps(payload, sort_keys=True).encode()).hexdigest()


def preflight_task(task: dict, arms: dict, adapter: dict, subject_root: Path,
                   runner_root: Path, model: str | None,
                   cache: dict | None = None, image: str | None = None) -> dict:
    key = cache_key(task, arms, adapter, image)
    if cache is not None and cache.get(key, {}).get("ok"):
        return {**cache[key], "cached": True}

    checks = []
    fixture = Path(tempfile.mkdtemp(prefix=f"bp-pre-{task['id']}-"))
    solution = Path(tempfile.mkdtemp(prefix=f"bp-pre-sol-{task['id']}-"))
    home = Path(tempfile.mkdtemp(prefix="bp-pre-home-"))
    try:
        for workdir in (fixture, solution):
            shutil.copytree(task["dir"] / "fixture", workdir, dirs_exist_ok=True)
            git(workdir, "init", "-q")
            git(workdir, "add", "-A")
            git(workdir, "commit", "-q", "--allow-empty", "-m", "fixture")

        env = env_for(task, subject_root, runner_root, fixture, home, model,
                      int(task.get("timeout_s", 900)))

        for name, spec in arms.items():
            result = run(spec["setup"], fixture, env, timeout=120)
            checks.append({"check": f"setup:{name}", "ok": result["exit"] == 0, **result})

        command, expected_pass = visible_command(task)
        if command:
            result = run(command, fixture, env, adapter)
            ok = (result["exit"] == 0) if expected_pass else (result["exit"] not in (0, None))
            checks.append({"check": "visible_tests", "expected": "pass" if expected_pass else "fail",
                           "ok": ok, **result})

        hidden = task["dir"] / "hidden"
        shutil.copytree(hidden, fixture, dirs_exist_ok=True)
        result = run(task["grade"], fixture, env, adapter)
        checks.append({"check": "fixture_fails_grade", "ok": result["exit"] not in (0, None), **result})

        shutil.copytree(task["dir"] / "solution", solution, dirs_exist_ok=True)
        shutil.copytree(hidden, solution, dirs_exist_ok=True)
        # The grade_wrapper mounts $AB_WORKDIR, not the subprocess cwd.
        solution_env = {**env, "AB_WORKDIR": str(solution)}
        result = run(task["grade"], solution, solution_env, adapter)
        checks.append({"check": "solution_passes_grade", "ok": result["exit"] == 0, **result})

        if task.get("score"):
            result = run(task["score"], solution, solution_env, adapter)
            score = tap_score(result.get("stdout", ""))
            checks.append({"check": "solution_score", "score": score,
                           "ok": result["exit"] == 0 and score == 1.0, **result})

        record = {"task": task["id"], "ok": all(c["ok"] for c in checks),
                  "cache_key": key, "checks": checks, "cached": False}
        if cache is not None and record["ok"]:
            cache[key] = record
        return record
    finally:
        for path in (fixture, solution, home):
            shutil.rmtree(path, ignore_errors=True)


def load_cache(path: Path) -> dict:
    if not path.is_file():
        return {}
    try:
        return json.loads(path.read_text())
    except (OSError, json.JSONDecodeError):
        return {}


def save_cache(path: Path, cache: dict) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    temp = path.with_suffix(path.suffix + ".tmp")
    temp.write_text(json.dumps(cache, indent=2, sort_keys=True))
    temp.replace(path)


def preflight_all(tasks: list[dict], arms: dict, adapter: dict, subject_root: Path,
                  runner_root: Path, model: str | None, cache_path: Path,
                  use_cache: bool = True, image: str | None = None) -> list[dict]:
    cache = load_cache(cache_path) if use_cache else {}
    results = []
    for task in tasks:
        result = preflight_task(task, arms, adapter, subject_root, runner_root, model,
                                cache if use_cache else None, image=image)
        results.append(result)
        print(f"[preflight] {task['id']:<8} {'PASS' if result['ok'] else 'FAIL'}"
              f"{' (cached)' if result.get('cached') else ''}", flush=True)
        if not result["ok"]:
            for check in result["checks"]:
                if not check["ok"]:
                    print(f"  - {check['check']} failed: exit={check.get('exit')}", flush=True)
    if use_cache:
        save_cache(cache_path, cache)
    return results
