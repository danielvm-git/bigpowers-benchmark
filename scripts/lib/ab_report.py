#!/usr/bin/env python3
# story: e58s01 e58s03 e58s04 e58s10
"""A/B eval aggregation and reports — pure functions over run records (no agent, no subprocess
except reading the bigpowers git SHA). Split from ab-eval.py to keep both under the 300-line cap."""
from __future__ import annotations

import json
import math
import os
import random
import subprocess
import sys
from datetime import date
from pathlib import Path

import yaml

sys.path.insert(0, str(Path(__file__).resolve().parent))
from atomic_write import atomic_write_text  # noqa: E402

RUNNER_ROOT = Path(os.environ.get("AB_RUNNER_ROOT", Path(__file__).resolve().parents[2])).resolve()
REPO_ROOT = RUNNER_ROOT  # backwards-compatible name for the runner checkout
BOOTSTRAP_RESAMPLES = 1000
BOOTSTRAP_SEED = 58


# ── aggregation ──────────────────────────────────────────────────────────────

def mean(values: list) -> float | None:
    vals = [v for v in values if v is not None]
    return round(sum(vals) / len(vals), 4) if vals else None


def percentile(values: list, p: float) -> float | None:
    """Nearest-rank percentile; None values are ignored, as are empty inputs."""
    vals = sorted(v for v in values if v is not None)
    if not vals:
        return None
    index = max(0, math.ceil((p / 100) * len(vals)) - 1)
    return round(vals[min(index, len(vals) - 1)], 4)


def median(values: list) -> float | None:
    vals = sorted(v for v in values if v is not None)
    if not vals:
        return None
    middle = len(vals) // 2
    if len(vals) % 2:
        return round(vals[middle], 4)
    return round((vals[middle - 1] + vals[middle]) / 2, 4)


def bootstrap_delta_ci(treatment: list[float], control: list[float]) -> list[float]:
    """Seeded 95% CI of mean(treatment) - mean(control); bools or scores in [0, 1]."""
    rng = random.Random(BOOTSTRAP_SEED)
    deltas = []
    for _ in range(BOOTSTRAP_RESAMPLES):
        t = [rng.choice(treatment) for _ in treatment]
        c = [rng.choice(control) for _ in control]
        deltas.append(sum(t) / len(t) - sum(c) / len(c))
    deltas.sort()
    lo = deltas[int(0.025 * BOOTSTRAP_RESAMPLES)]
    hi = deltas[int(0.975 * BOOTSTRAP_RESAMPLES) - 1]
    return [round(lo, 4), round(hi, 4)]


def arm_summary(runs: list[dict]) -> dict:
    return {
        "runs": len(runs),
        "pass_rate": mean([float(r["pass"]) for r in runs]),
        "mean_score": mean([r.get("score") for r in runs]),
        "mean_bugs_opened": mean([r.get("bugs_opened", 0) for r in runs]),
        "tamper_rate": mean([float(r["tampered"]) for r in runs]),
        "agent_error_rate": mean([float(r["agent_error"]) for r in runs]),
        "mean_cost_usd": mean([r["cost_usd"] for r in runs]),
        "mean_input_tokens": mean([r["input_tokens"] for r in runs]),
        "mean_output_tokens": mean([r["output_tokens"] for r in runs]),
        "mean_turns": mean([r["turns"] for r in runs]),
        "mean_duration_s": mean([r["duration_s"] for r in runs]),
        "mean_diff_lines": mean([r["diff_lines"] for r in runs]),
        "median_duration_s": median([r["duration_s"] for r in runs]),
        "p90_duration_s": percentile([r["duration_s"] for r in runs], 90),
        "median_cost_usd": median([r["cost_usd"] for r in runs]),
        "p90_cost_usd": percentile([r["cost_usd"] for r in runs], 90),
        "median_input_tokens": median([r["input_tokens"] for r in runs]),
        "p90_input_tokens": percentile([r["input_tokens"] for r in runs], 90),
        "median_diff_lines": median([r["diff_lines"] for r in runs]),
        "p90_diff_lines": percentile([r["diff_lines"] for r in runs], 90),
    }


def aggregate(records: list[dict], arms: list[str], tasks: list[str]) -> dict:
    by_arm = {a: [r for r in records if r["arm"] == a] for a in arms}
    summary = {a: arm_summary(runs) for a, runs in by_arm.items()}
    per_task = {t: {a: mean([float(r["pass"]) for r in by_arm[a] if r["task"] == t]) for a in arms}
                for t in tasks}
    per_task_score = {t: {a: mean([r.get("score") for r in by_arm[a] if r["task"] == t]) for a in arms}
                      for t in tasks}
    deltas = {a: arm_delta(by_arm, summary, a) for a in arms if a != "vanilla"} if "vanilla" in arms else {}
    from ab_lean import lean_summary  # type: ignore[import]  # lazy: ab_lean imports this module
    return {"arms_summary": summary, "per_task": per_task, "per_task_score": per_task_score,
            "delta": deltas.get("bigpowers"), "deltas_vs_vanilla": deltas,
            "lean": lean_summary(records, arms)}


def arm_delta(by_arm: dict, summary: dict, arm: str) -> dict:
    """arm - vanilla: pass rate and score with seeded bootstrap CIs, tamper rate and cost (e58s04)."""
    tr, va = summary[arm], summary["vanilla"]
    cost = None
    if tr["mean_cost_usd"] is not None and va["mean_cost_usd"] is not None:
        cost = round(tr["mean_cost_usd"] - va["mean_cost_usd"], 4)
    delta = {
        "pass_rate": round(tr["pass_rate"] - va["pass_rate"], 4),
        "ci95": bootstrap_delta_ci([r["pass"] for r in by_arm[arm]], [r["pass"] for r in by_arm["vanilla"]]),
        "tamper_rate": round(tr["tamper_rate"] - va["tamper_rate"], 4),
        "cost_usd": cost,
    }
    scores = {a: [r["score"] for r in by_arm[a] if r.get("score") is not None] for a in (arm, "vanilla")}
    if scores[arm] and scores["vanilla"]:
        delta["score"] = round(tr["mean_score"] - va["mean_score"], 4)
        delta["score_ci95"] = bootstrap_delta_ci(scores[arm], scores["vanilla"])
    if tr.get("mean_bugs_opened") is not None and va.get("mean_bugs_opened") is not None:
        delta["bugs_opened"] = round(tr["mean_bugs_opened"] - va["mean_bugs_opened"], 4)
    return delta


# ── reporting ────────────────────────────────────────────────────────────────

def git_sha(root: Path) -> str:
    res = subprocess.run(["git", "rev-parse", "--short", "HEAD"], cwd=root, capture_output=True, text=True)
    return res.stdout.strip() or "unknown"


def bigpowers_sha(root: Path | None = None) -> str:
    """SHA of the bigpowers checkout under test, never of the runner repo."""
    subject = root or Path(os.environ.get("AB_BP_ROOT", "."))
    return git_sha(subject)


def runner_sha() -> str:
    return git_sha(RUNNER_ROOT)


def write_reports(out: Path, meta: dict, result: dict, records: list[dict],
                  json_out: Path | None = None) -> Path:
    out.mkdir(parents=True, exist_ok=True)
    today = date.today().isoformat()
    report = out / f"AB-{today}.yaml"
    # Atomic (#181): the dashboard reads these while a run is still appending.
    atomic_write_text(report, yaml.safe_dump({**meta, **result}, sort_keys=False))
    records_path = out / f"ab-runs-{today}.jsonl"
    atomic_write_text(
        records_path,
        "".join(json.dumps({**rec, "bigpowers_sha": meta["bigpowers_sha"]}) + "\n" for rec in records),
    )
    if json_out is not None:
        json_out.parent.mkdir(parents=True, exist_ok=True)
        atomic_write_text(json_out, json.dumps(
            {**meta, **result, "records": records}, indent=2, sort_keys=False) + "\n")
    return report


def print_summary(result: dict) -> None:
    def fmt(v, p=2):
        return "-" if v is None else f"{v:.{p}f}"

    print(f"{'arm':<10} {'pass':>6} {'score':>6} {'bugs':>6} {'tamper':>7} {'cost$':>8} {'turns':>6} {'secs':>7}")
    for arm, s in result["arms_summary"].items():
        b_str = "-" if s.get("mean_bugs_opened") is None else f"{s['mean_bugs_opened']:.1f}"
        print(f"{arm:<10} {fmt(s['pass_rate']):>6} {fmt(s['mean_score']):>6} {b_str:>6} {fmt(s['tamper_rate']):>7} "
              f"{fmt(s['mean_cost_usd'], 3):>8} {fmt(s['mean_turns'], 1):>6} {fmt(s['mean_duration_s'], 0):>7}")
    print(f"\n{'arm':<10} {'med$':>9} {'p90$':>9} {'med_s':>9} {'p90_s':>9} "
          f"{'med_tok':>10} {'p90_tok':>10} {'med_diff':>9} {'p90_diff':>9}")
    for arm, s in result["arms_summary"].items():
        print(f"{arm:<10} {fmt(s.get('median_cost_usd'), 4):>9} {fmt(s.get('p90_cost_usd'), 4):>9} "
              f"{fmt(s.get('median_duration_s'), 1):>9} {fmt(s.get('p90_duration_s'), 1):>9} "
              f"{fmt(s.get('median_input_tokens'), 0):>10} {fmt(s.get('p90_input_tokens'), 0):>10} "
              f"{fmt(s.get('median_diff_lines'), 1):>9} {fmt(s.get('p90_diff_lines'), 1):>9}")
    for arm, d in result.get("deltas_vs_vanilla", {}).items():
        line = f"delta {arm:<10} - vanilla: pass {d['pass_rate']:+.2f} CI {d['ci95']}"
        if "score" in d:
            line += f"  score {d['score']:+.2f} CI {d['score_ci95']}"
        if "bugs_opened" in d:
            line += f"  bugs {d['bugs_opened']:+.1f}"
        print(line)
    from ab_lean import lean_lines  # type: ignore[import]
    for line in lean_lines(result.get("lean")):
        print(line)
