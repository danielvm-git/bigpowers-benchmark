#!/usr/bin/env python3
# story: e58s01 e58s02 e58s03 e58s05 e58s06 e58s07 e58s08 e58s09
"""A/B eval: run the same tasks with and without bigpowers and grade only the outcome.

Each run gets a fresh temp git workdir (outside the repo) copied from the task fixture.
The arm setup runs, the agent runs through an adapter command, then hidden tests are
copied in and the task's grade command decides pass/fail. Advisory: exit 0 after a
completed run, 2 on configuration errors.
"""
from __future__ import annotations

import argparse
import gzip
import json
import os
import shutil
import subprocess
import sys
import tempfile
import time
from datetime import datetime, timezone
from difflib import SequenceMatcher
from pathlib import Path

import yaml

sys.path.insert(0, str(Path(__file__).resolve().parent))
from ab_metrics import parse_metrics, tap_score, tap_failures, tap_failed_names  # type: ignore[import]  # noqa: E402
from ab_vsm import vsm_from  # type: ignore[import]  # noqa: E402
from ab_waste import waste_for  # type: ignore[import]  # noqa: E402
from ab_report import (  # type: ignore[import]  # noqa: E402
    BOOTSTRAP_RESAMPLES, BOOTSTRAP_SEED, aggregate, bigpowers_sha, print_summary, runner_sha, write_reports,
)
from ab_provenance import (  # type: ignore[import]  # noqa: E402
    DEFAULT_IMAGE, collect_inputs, diff_inputs, input_digest,
)
from ab_preflight import preflight_all  # type: ignore[import]  # noqa: E402
from ab_process import run as run_process  # type: ignore[import]  # noqa: E402
from ab_decision import decide, policy_with_defaults, preregistration_sha  # type: ignore[import]  # noqa: E402
import ab_calibration as calibration  # type: ignore[import]  # noqa: E402

RUNNER_ROOT = Path(os.environ.get("AB_RUNNER_ROOT", Path(__file__).resolve().parents[2])).resolve()
REPO_ROOT = RUNNER_ROOT  # backwards-compatible name for the runner checkout
BENCH_DIR = RUNNER_ROOT / "benchmarks"
AB_DIR = BENCH_DIR / "ab"
DEFAULT_CONFIG = AB_DIR / "config.yaml"
DEFAULT_TASKS_DIR = AB_DIR / "tasks"
DEFAULT_OUT = BENCH_DIR / "reports"
DEFAULT_ARMS = "vanilla,bigpowers"
GIT_ID = ["-c", "user.name=ab-eval", "-c", "user.email=ab-eval@localhost", "-c", "commit.gpgsign=false"]


class ConfigError(Exception):
    pass


# ── loading ──────────────────────────────────────────────────────────────────

def load_yaml(path: Path) -> dict:
    if not path.is_file():
        raise ConfigError(f"missing file: {path}")
    return yaml.safe_load(path.read_text()) or {}


def load_tasks(tasks_dir: Path, wanted: list[str] | None) -> list[dict]:
    tasks = {}
    for task_yaml in sorted(tasks_dir.glob("*/task.yaml")):
        task = load_yaml(task_yaml)
        task["dir"] = task_yaml.parent
        tasks[task["id"]] = task
    if not wanted:
        return list(tasks.values())
    unknown = [t for t in wanted if t not in tasks]
    if unknown:
        raise ConfigError(f"unknown task(s) {unknown}; valid: {sorted(tasks)}")
    return [tasks[t] for t in wanted]


def pick(section: dict, names: list[str], kind: str) -> dict:
    unknown = [n for n in names if n not in section]
    if unknown:
        raise ConfigError(f"unknown {kind}(s) {unknown}; valid: {sorted(section)}")
    return {n: section[n] for n in names}


def resolve_adapter(config: dict, name: str, custom_cmd: str | None, parser: str | None) -> dict:
    if custom_cmd:
        return {"name": "custom", "command": custom_cmd, "parser": parser or "none"}
    adapter = dict(pick(config.get("adapters", {}), [name], "adapter")[name])
    adapter["name"] = name
    if parser:
        adapter["parser"] = parser
    return adapter


# ── one run ──────────────────────────────────────────────────────────────────

def sh(cmd: str, cwd: Path, env: dict | None = None, timeout: float | None = None):
    # stdin closed: `opencode run` otherwise waits on an open stdin forever (e58s02).
    # Process-group kill on timeout keeps grandchildren from poisoning later tests (e58s01).
    return run_process(cmd, cwd, env=env, timeout=timeout)


def git(workdir: Path, *args: str) -> str:
    res = subprocess.run(["git", *GIT_ID, *args], cwd=workdir, capture_output=True, text=True, check=True)
    return res.stdout.strip()


def snapshot(workdir: Path, message: str) -> str:
    git(workdir, "add", "-A")
    git(workdir, "commit", "-q", "--allow-empty", "--no-verify", "-m", message)
    return git(workdir, "rev-parse", "HEAD")


def file_lines(workdir: Path, paths: list[str]) -> dict:
    return {rel: (workdir / rel).read_text().splitlines() if (workdir / rel).is_file() else None
            for rel in paths}


def protected_changes(workdir: Path, before: dict) -> tuple[bool, int]:
    """Tampered = an original line removed or changed. Added lines are counted, not flagged:
    a TDD arm adds tests to the visible files, and hidden tests decide the grade (e58s02)."""
    tampered, added = False, 0
    for rel, now in file_lines(workdir, list(before)).items():
        if before[rel] is None or now is None:
            tampered = tampered or before[rel] is not None
            continue
        for op, _, _, j1, j2 in SequenceMatcher(None, before[rel], now, autojunk=False).get_opcodes():
            added += j2 - j1 if op == "insert" else 0
            tampered = tampered or op not in ("equal", "insert")
    return tampered, added


def changed_lines(workdir: Path, base: str) -> int:
    git(workdir, "add", "-A")
    total = 0
    for line in git(workdir, "diff", "--cached", "--numstat", base).splitlines():
        added, deleted, _ = line.split("\t", 2)
        total += (int(added) if added.isdigit() else 0) + (int(deleted) if deleted.isdigit() else 0)
    return total


def save_trace(path: Path, stdout: str) -> None:
    """Agent transcript for later process analysis (e58s05)."""
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_bytes(gzip.compress(stdout.encode()))


def env_for(prompt: str, model: str | None, workdir: Path, home: Path,
            subject_root: Path, timeout_s: int = 900) -> dict:
    """$AB_HOME is a fresh empty dir per run: adapters point HOME at it to hide global skills.
    $AB_BP_ROOT is the bigpowers checkout under test; $AB_RUNNER_ROOT is this repo.
    $AB_TIMEOUT leaves 30 s for an in-container `timeout` to stop the agent first (e58s07)."""
    env = dict(os.environ)
    env.update({"AB_PROMPT": prompt, "AB_MODEL": model or "", "AB_WORKDIR": str(workdir),
                "AB_HOME": str(home), "AB_BP_ROOT": str(subject_root),
                "AB_RUNNER_ROOT": str(RUNNER_ROOT),
                "AB_TIMEOUT": str(max(10, timeout_s - 30))})
    return env


def grade_cmd(adapter: dict, cmd: str, env: dict) -> tuple[str, dict]:
    """Runs grade/score through the adapter's grade_wrapper (e.g. a no-network container)."""
    if not adapter.get("grade_wrapper"):
        return cmd, env
    return adapter["grade_wrapper"], {**env, "AB_CMD": cmd}


def run_once(task: dict, arm: str, setup: str, adapter: dict, model: str | None,
             run_idx: int, keep: bool, subject_root: Path,
             trace_dir: Path | None = None) -> dict:
    workdir = Path(tempfile.mkdtemp(prefix=f"bp-ab-{task['id']}-{arm}-"))
    home = Path(tempfile.mkdtemp(prefix="bp-ab-home-"))
    try:
        shutil.copytree(task["dir"] / "fixture", workdir, dirs_exist_ok=True)
        git(workdir, "init", "-q")
        snapshot(workdir, "fixture")
        env = env_for(task["prompt"], model, workdir, home, subject_root, task.get("timeout_s", 900))
        if sh(setup, workdir, env).returncode != 0:
            raise ConfigError(f"arm '{arm}' setup failed in {workdir}")
        base = snapshot(workdir, f"arm {arm}")
        protected = task.get("protected", [])
        before = file_lines(workdir, protected)

        started = time.monotonic()
        timed_out = False
        try:
            agent = sh(adapter["command"], workdir, env, timeout=task.get("timeout_s", 900))
            exit_code, stdout = agent.returncode, agent.stdout
        except subprocess.TimeoutExpired as exc:
            timed_out, exit_code = True, None
            stdout = exc.stdout.decode() if isinstance(exc.stdout, bytes) else (exc.stdout or "")
        duration = round(time.monotonic() - started, 1)
        if trace_dir is not None:
            save_trace(trace_dir / f"{task['id']}-{arm}-{run_idx}.jsonl.gz", stdout)

        tampered, protected_added = protected_changes(workdir, before)
        diff = changed_lines(workdir, base)
        waste = waste_for(workdir, base, stdout, adapter.get("parser", "none"), task["dir"],
                          trace_dir / f"{task['id']}-{arm}-{run_idx}.patch.gz" if trace_dir else None)
        shutil.copytree(task["dir"] / "hidden", workdir, dirs_exist_ok=True)
        cmd, genv = grade_cmd(adapter, task["grade"], env)
        passed = sh(cmd, workdir, genv, timeout=300).returncode == 0
        score = None
        if task.get("score"):
            cmd, genv = grade_cmd(adapter, task["score"], env)
            score = tap_score(sh(cmd, workdir, genv, timeout=300).stdout)
        bugs_opened = 0
        bug_details = []
        if task.get("audit"):
            if (task["dir"] / "audit").is_dir():
                shutil.copytree(task["dir"] / "audit", workdir, dirs_exist_ok=True)
            cmd, genv = grade_cmd(adapter, task["audit"], env)
            out = sh(cmd, workdir, genv, timeout=300).stdout
            bugs_opened = tap_failures(out)
            bug_details = tap_failed_names(out)
        metrics = parse_metrics(adapter.get("parser", "none"), stdout)
        return {
            "task": task["id"], "arm": arm, "run": run_idx, "pass": passed, "score": score,
            "bugs_opened": bugs_opened, "bug_details": bug_details, "tampered": tampered,
            "protected_lines_added": protected_added, "diff_lines": diff, "duration_s": duration, "agent_exit": exit_code,
            "agent_error": timed_out or exit_code != 0 or bool(metrics.pop("agent_reported_error")),
            "timed_out": timed_out, "vsm": vsm_from(adapter.get("parser", "none"), stdout), "waste": waste, **metrics,
        }
    finally:
        shutil.rmtree(home, ignore_errors=True)
        if keep:
            print(f"  kept workdir: {workdir}")
        else:
            shutil.rmtree(workdir, ignore_errors=True)


# ── CLI ──────────────────────────────────────────────────────────────────────

def parse_args(argv: list[str] | None) -> argparse.Namespace:
    p = argparse.ArgumentParser(description="A/B eval: vanilla agent vs bigpowers, outcome-graded")
    p.add_argument("--config", type=Path, default=DEFAULT_CONFIG)
    p.add_argument("--tasks-dir", type=Path, default=DEFAULT_TASKS_DIR)
    p.add_argument("--tasks", help="comma-separated task ids (default: all)")
    p.add_argument("--arms", default=DEFAULT_ARMS)
    p.add_argument("--k", type=int, help="runs per task per arm (default: config k)")
    p.add_argument("--adapter", help="adapter name (default: config default_adapter, else claude)")
    p.add_argument("--adapter-cmd", help="custom adapter command; prompt is in $AB_PROMPT")
    p.add_argument("--parser", help="output parser: claude-json | none")
    p.add_argument("--model", help="exported as $AB_MODEL for the adapter")
    p.add_argument("--bigpowers-root",
                   help="path to the bigpowers checkout under test (default: $AB_BP_ROOT)")
    p.add_argument("--out", type=Path, default=DEFAULT_OUT)
    p.add_argument("--json-out", type=Path,
                   help="also write the full report plus records as JSON (for the app)")
    p.add_argument("--allow-dirty", action="store_true",
                   help="run against a dirty bigpowers checkout (recorded, not recommended)")
    p.add_argument("--verify-inputs", type=Path,
                   help="recompute the inputs of a report and exit 2 on any mismatch")
    p.add_argument("--fail-on-decision", action="store_true",
                   help="exit 1 when the pre-registered policy says reject")
    p.add_argument("--calibrate", action="store_true",
                   help="run vanilla only, k=10 by default, and classify task difficulty")
    p.add_argument("--calibration-cache", type=Path, default=AB_DIR / "calibration-cache.json")
    p.add_argument("--no-calibration-cache", action="store_true",
                   help="ignore cached calibration results")
    p.add_argument("--preflight-only", action="store_true",
                   help="prove the fixtures are valid, then exit without running an agent")
    p.add_argument("--skip-preflight", action="store_true",
                   help="debug only: skip the pristine-fixture checks")
    p.add_argument("--preflight-cache", type=Path, default=AB_DIR / "preflight-cache.json")
    p.add_argument("--keep", action="store_true", help="keep workdirs for inspection")
    p.add_argument("--dry-run", action="store_true", help="print the run matrix; run nothing")
    return p.parse_args(argv)


def main(argv: list[str] | None = None) -> int:
    args = parse_args(argv)
    try:
        config = load_yaml(args.config)
        arm_names = ["vanilla"] if args.calibrate else [
            a.strip() for a in args.arms.split(",") if a.strip()]
        arms = pick(config.get("arms", {}), arm_names, "arm")
        adapter_name = args.adapter or config.get("default_adapter", "claude")
        adapter = resolve_adapter(config, adapter_name, args.adapter_cmd, args.parser)
        tasks = load_tasks(args.tasks_dir, args.tasks.split(",") if args.tasks else None)
        if not tasks:
            raise ConfigError(f"no tasks found in {args.tasks_dir}")
        subject_arg = args.bigpowers_root or os.environ.get("AB_BP_ROOT")
        if not subject_arg:
            raise ConfigError("set --bigpowers-root or AB_BP_ROOT to the bigpowers checkout under test")
        subject_root = Path(subject_arg).expanduser().resolve()
        if not subject_root.is_dir():
            raise ConfigError(f"bigpowers root is not a directory: {subject_root}")
    except ConfigError as exc:
        print(f"ERROR: {exc}")
        return 2
    k = args.k or int(config.get("k", 3))
    model = args.model or adapter.get("default_model")

    if args.calibrate:
        if "vanilla" not in config.get("arms", {}):
            print("ERROR: calibration needs a vanilla arm")
            return 2
        arms = {"vanilla": config["arms"]["vanilla"]}
        k = args.k or 10
    run_tasks = tasks

    image = os.environ.get("AB_IMAGE", DEFAULT_IMAGE) if adapter["name"] == "pi-docker" else None
    expected = None
    if args.verify_inputs:
        report = (
            json.loads(args.verify_inputs.read_text())
            if args.verify_inputs.suffix == ".json"
            else yaml.safe_load(args.verify_inputs.read_text())
        )
        expected = report.get("inputs")
        wanted = set(report.get("tasks") or [])
        if wanted:
            tasks = [task for task in tasks if task["id"] in wanted]
        if expected:
            image = (expected.get("image") or {}).get("name")
    policy = policy_with_defaults(config.get("decision_policy"))
    prereg = preregistration_sha(policy, list(arms), [t["id"] for t in tasks], k,
                                 adapter["name"], model)
    inputs = collect_inputs(subject_root, RUNNER_ROOT, args.config, tasks, image=image)
    inputs["decision"] = {"policy": policy, "preregistration_sha": prereg}
    digest = input_digest(inputs)

    if args.verify_inputs:
        if expected is None:
            print("INPUTS MISMATCH: report has no inputs block")
            return 2
        problems = diff_inputs(expected, inputs)
        if problems:
            print("INPUTS MISMATCH:")
            for problem in problems:
                print(f"  - {problem}")
            return 2
        print("INPUTS OK")
        return 0

    if inputs["subject"]["dirty"] and not args.allow_dirty:
        print("ERROR: bigpowers checkout is dirty; commit/stash or pass --allow-dirty")
        return 2

    if args.preflight_only:
        results = preflight_all(tasks, arms, adapter, subject_root, RUNNER_ROOT, model,
                                args.preflight_cache, image=image)
        return 0 if all(result["ok"] for result in results) else 2

    print(f"A/B eval: {len(tasks)} task(s) x {len(arms)} arm(s) x k={k} via adapter '{adapter['name']}'"
          f"{f' model {model}' if model else ''}")
    if args.dry_run:
        for task in tasks:
            for arm, spec in arms.items():
                print(f"  {task['id']:<8} {arm:<10} setup: {spec['setup']}")
        print(f"  adapter command: {adapter['command']}")
        return 0

    cached_calibration: dict[str, dict] = {}
    if args.calibrate and not args.no_calibration_cache:
        cache = calibration.load_cache(args.calibration_cache)
        for task in tasks:
            key = calibration.cache_key(task, adapter["name"], model, k, arms["vanilla"]["setup"])
            if key in cache:
                cached_calibration[task["id"]] = {**cache[key], "cached": True}
        run_tasks = [task for task in tasks if task["id"] not in cached_calibration]
        if cached_calibration:
            print(f"calibration: {len(cached_calibration)} task(s) from cache")

    if not args.skip_preflight:
        results = preflight_all(run_tasks, arms, adapter, subject_root, RUNNER_ROOT, model,
                                args.preflight_cache, image=image)
        if not all(result["ok"] for result in results):
            print("ERROR: preflight failed; no agent was run")
            return 2

    # Round-robin (e58s05): any prefix of the run covers every arm, and slow provider periods hit
    # all arms alike. Each record is appended to ab-live.jsonl as soon as its run finishes.
    records = []
    sha = bigpowers_sha(subject_root)
    args.out.mkdir(parents=True, exist_ok=True)
    live = args.out / "ab-live.jsonl"
    try:
        for i in range(1, k + 1):
            for task in run_tasks:
                for arm, spec in arms.items():
                    rec = run_once(task, arm, spec["setup"], adapter, model, i, args.keep,
                                   subject_root, args.out / "traces")
                    records.append(rec)
                    with live.open("a") as f:
                        f.write(json.dumps({**rec, "bigpowers_sha": sha, "model": model,
                                            "input_digest": digest}) + "\n")
                    print(f"  {task['id']:<8} {arm:<10} run {i}: {'PASS' if rec['pass'] else 'FAIL'}"
                          f"{' TAMPERED' if rec['tampered'] else ''}{' AGENT-ERROR' if rec['agent_error'] else ''}", flush=True)
    except ConfigError as exc:
        print(f"ERROR: {exc}")
        return 2

    if args.calibrate:
        new_results = calibration.summarize(records, run_tasks, set(cached_calibration))
        new_by_id = {result["id"]: result for result in new_results}
        results = [cached_calibration.get(task["id"]) or new_by_id[task["id"]] for task in tasks]
        if not args.no_calibration_cache:
            cache = calibration.load_cache(args.calibration_cache)
            for task in run_tasks:
                key = calibration.cache_key(task, adapter["name"], model, k,
                                            arms["vanilla"]["setup"])
                cache[key] = new_by_id[task["id"]]
            calibration.save_cache(args.calibration_cache, cache)
        cal_meta = {
            "kind": "calibration",
            "generated_at": datetime.now(timezone.utc).isoformat(timespec="seconds"),
            "bigpowers_sha": sha, "runner_sha": runner_sha(),
            "adapter": adapter["name"], "model": model, "k": k,
            "tasks": [t["id"] for t in tasks],
            "inputs": inputs, "input_digest": digest,
        }
        path = calibration.write_report(args.out, results, cal_meta)
        calibration.print_table(results)
        print(f"Wrote {path}")
        return 0

    result = aggregate(records, list(arms), [t["id"] for t in tasks])
    decisions: dict[str, dict] = {}
    vanilla_summary = result["arms_summary"].get("vanilla")
    lean_arms = (result.get("lean") or {}).get("arms", {})
    vanilla_lead = (lean_arms.get("vanilla") or {}).get("lead_time_s")
    for arm in arms:
        if arm == "vanilla":
            continue
        summary = result["arms_summary"][arm]
        delta = result.get("deltas_vs_vanilla", {}).get(arm, {})
        cost_mult = None
        if vanilla_summary and vanilla_summary.get("mean_cost_usd") and summary.get("mean_cost_usd"):
            cost_mult = summary["mean_cost_usd"] / vanilla_summary["mean_cost_usd"]
        lead_mult = None
        arm_lead = (lean_arms.get(arm) or {}).get("lead_time_s")
        if vanilla_lead and arm_lead:
            lead_mult = arm_lead / vanilla_lead
        decisions[arm] = decide(
            arm, summary, delta, policy, len(tasks), cost_mult, lead_mult,
            quality=None,
            reliability={"agent_error_rate": summary.get("agent_error_rate")},
        )
    result["decisions"] = decisions
    result["decision"] = decisions.get("bigpowers") or next(iter(decisions.values()), None)

    meta = {
        "generated_at": datetime.now(timezone.utc).isoformat(timespec="seconds"),
        "bigpowers_sha": sha, "runner_sha": runner_sha(), "adapter": adapter["name"], "model": model,
        "k": k, "tasks": [t["id"] for t in tasks], "arms": list(arms),
        "arm_setup": {a: s["setup"] for a, s in arms.items()},
        "inputs": inputs, "input_digest": digest,
        "decision_policy": policy, "preregistration_sha": prereg,
        "ci_method": f"bootstrap over runs, {BOOTSTRAP_RESAMPLES} resamples, seed {BOOTSTRAP_SEED}",
    }
    report = write_reports(args.out, meta, result, records, args.json_out)
    print_summary(result)
    for arm, decision in decisions.items():
        print(f"DECISION {arm}: {decision['verdict']} — {'; '.join(decision['reasons']) or 'no reasons'}")
    print(f"Wrote {report}")
    if args.fail_on_decision and any(d["verdict"] == "reject" for d in decisions.values()):
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
