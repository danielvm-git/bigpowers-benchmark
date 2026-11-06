#!/usr/bin/env python3
"""Content provenance for an A/B run: subject SHA + dirty state, task trees, config and image.

Every report carries an `inputs` block so a run can be reproduced or rejected. Hashing is
deterministic: relative paths are sorted, and vendor/build directories are excluded.
"""
from __future__ import annotations

import hashlib
import json
import os
import subprocess
from pathlib import Path

EXCLUDED_PARTS = {".git", "node_modules", "vendor", "__pycache__", ".build", ".DS_Store"}
DEFAULT_IMAGE = "bp-ab-agent:pi-1.5.0"


def sha256_file(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def sha256_tree(root: Path) -> str:
    """Hash relative path + null + content + null for every file, in sorted order."""
    digest = hashlib.sha256()
    for path in sorted(root.rglob("*")):
        relative = path.relative_to(root)
        if any(part in EXCLUDED_PARTS for part in relative.parts):
            continue
        if not path.is_file():
            continue
        digest.update(relative.as_posix().encode())
        digest.update(b"\0")
        digest.update(path.read_bytes())
        digest.update(b"\0")
    return digest.hexdigest()


def git(root: Path, *args: str) -> str:
    result = subprocess.run(["git", *args], cwd=root, capture_output=True, text=True)
    return result.stdout.strip()


def git_state(root: Path) -> dict:
    sha = git(root, "rev-parse", "HEAD") or "unknown"
    status = git(root, "status", "--porcelain")
    dirty = bool(status)
    dirty_diff_sha = None
    if dirty:
        diff = subprocess.run(["git", "diff", "--binary", "HEAD"], cwd=root,
                              capture_output=True).stdout
        dirty_diff_sha = hashlib.sha256(diff + status.encode()).hexdigest()
    return {"sha": sha, "ref": "HEAD", "dirty": dirty, "dirty_diff_sha": dirty_diff_sha}


def docker_image_id(image: str | None) -> str | None:
    if not image:
        return None
    try:
        result = subprocess.run(
            ["docker", "image", "inspect", "--format", "{{.Id}}", image],
            capture_output=True, text=True, timeout=15,
        )
    except (OSError, subprocess.TimeoutExpired):
        return None
    return result.stdout.strip() or None


def task_hashes(task_dir: Path) -> dict[str, str | None]:
    hashes: dict[str, str | None] = {"task_yaml": sha256_file(task_dir / "task.yaml")}
    for name in ("fixture", "hidden", "audit", "solution"):
        directory = task_dir / name
        hashes[name] = sha256_tree(directory) if directory.is_dir() else None
    return hashes


def collect_inputs(subject_root: Path, runner_root: Path, config_path: Path,
                   tasks: list[dict], image: str | None = None) -> dict:
    subject_root = subject_root.resolve()
    runner_root = runner_root.resolve()
    config_path = config_path.resolve()
    subject_source = Path(os.environ.get("AB_BP_SOURCE_ROOT", subject_root)).resolve()
    runner_source = Path(os.environ.get("AB_RUNNER_SOURCE_ROOT", runner_root)).resolve()
    subject = {"path": str(subject_source), **git_state(subject_root)}
    runner = {"root": str(runner_source), **git_state(runner_root)}
    if subject_source != subject_root:
        subject["worktree_path"] = str(subject_root)
    if runner_source != runner_root:
        runner["worktree_path"] = str(runner_root)
    return {
        "schema": 1,
        "subject": subject,
        "runner": runner,
        "config": {"path": str(config_path), "sha256": sha256_file(config_path)},
        "image": {"name": image, "id": docker_image_id(image)},
        "tasks": {task["id"]: task_hashes(task["dir"]) for task in tasks},
    }


def input_digest(inputs: dict) -> str:
    return hashlib.sha256(json.dumps(inputs, sort_keys=True).encode()).hexdigest()


def diff_inputs(expected: dict, actual: dict, path: str = "inputs") -> list[str]:
    """Return human-readable differences; empty means the inputs match."""
    if isinstance(expected, dict) and isinstance(actual, dict):
        problems = []
        for key in sorted(set(expected) | set(actual)):
            # A new run gets a fresh temp worktree path; identity is the SHA and tree hashes.
            if key == "worktree_path":
                continue
            if key not in expected:
                problems.append(f"{path}.{key}: unexpected")
            elif key not in actual:
                problems.append(f"{path}.{key}: missing")
            else:
                problems.extend(diff_inputs(expected[key], actual[key], f"{path}.{key}"))
        return problems
    if expected != actual:
        return [f"{path}: {expected!r} != {actual!r}"]
    return []
