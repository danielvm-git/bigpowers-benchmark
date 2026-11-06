#!/usr/bin/env python3
"""Vanilla-only calibration: can this task tell two arms apart?

A task is useful only when vanilla passes it sometimes. Saturated tasks (always pass) and
impossible tasks (never pass) cannot produce a delta. Results are cached by input digest.
"""
from __future__ import annotations

import hashlib
import json
from datetime import date
from pathlib import Path

import yaml

from ab_provenance import task_hashes  # type: ignore[import]
from atomic_write import atomic_write_text  # type: ignore[import]

TOO_EASY_ABOVE = 0.8
TOO_HARD_BELOW = 0.2


def classify(pass_rate: float | None) -> str:
    if pass_rate is None:
        return "unknown"
    if pass_rate < TOO_HARD_BELOW:
        return "too_hard"
    if pass_rate > TOO_EASY_ABOVE:
        return "too_easy"
    return "discriminating"


def summarize(records: list[dict], tasks: list[dict], cached: set[str] | None = None) -> list[dict]:
    cached = cached or set()
    results = []
    for task in tasks:
        runs = [record for record in records if record["task"] == task["id"]]
        passes = sum(1 for record in runs if record["pass"])
        pass_rate = round(passes / len(runs), 4) if runs else None
        scores = [float(record["score"]) for record in runs
                  if record.get("score") is not None]
        results.append({
            "id": task["id"],
            "runs": len(runs),
            "passes": passes,
            "pass_rate": pass_rate,
            "mean_score": round(sum(scores) / len(scores), 4) if scores else None,
            "timed_out": sum(1 for record in runs if record.get("timed_out")),
            "agent_error": sum(1 for record in runs if record.get("agent_error")),
            "band": classify(pass_rate),
            "cached": task["id"] in cached,
        })
    return results


def counts(results: list[dict]) -> dict:
    out = {"too_easy": 0, "discriminating": 0, "too_hard": 0, "unknown": 0}
    for result in results:
        out[result["band"]] = out.get(result["band"], 0) + 1
    return out


def cache_key(task: dict, adapter: str | None, model: str | None, k: int, setup: str) -> str:
    payload = {
        "task": task_hashes(task["dir"]),
        "adapter": adapter,
        "model": model,
        "k": k,
        "setup": setup,
    }
    return hashlib.sha256(json.dumps(payload, sort_keys=True).encode()).hexdigest()


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


def write_report(out: Path, results: list[dict], meta: dict) -> Path:
    out.mkdir(parents=True, exist_ok=True)
    path = out / f"CALIBRATION-{date.today().isoformat()}.yaml"
    document = {**meta, "results": results, "summary": counts(results)}
    atomic_write_text(path, yaml.safe_dump(document, sort_keys=False))
    return path


def print_table(results: list[dict]) -> None:
    print(f"{'task':<8} {'pass':>6} {'score':>7} {'band':<14} {'timeout':>7} {'err':>4}")
    for result in results:
        pass_rate = "-" if result["pass_rate"] is None else f"{result['pass_rate']:.2f}"
        score = "-" if result["mean_score"] is None else f"{result['mean_score']:.3f}"
        cached = " (cached)" if result.get("cached") else ""
        print(f"{result['id']:<8} {pass_rate:>6} {score:>7} {result['band']:<14} "
              f"{result['timed_out']:>7} {result['agent_error']:>4}{cached}")
    summary = counts(results)
    print(f"bands: too_easy {summary['too_easy']}  discriminating {summary['discriminating']}  "
          f"too_hard {summary['too_hard']}  unknown {summary['unknown']}")
