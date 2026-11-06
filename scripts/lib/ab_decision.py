#!/usr/bin/env python3
"""Pre-registered decision policy for an A/B report.

The policy lives in config.yaml and is hashed before the first run. This module only applies
it: safety first, then regression, then cost/time, then the lower confidence bound.
"""
from __future__ import annotations

import hashlib
import json

DEFAULTS = {
    "confidence": 0.95,
    "min_pass_gain": 0.05,
    "min_score_gain": 0.02,
    "max_cost_multiplier": 1.50,
    "max_lead_time_multiplier": 1.50,
    "max_tamper_rate": 0.00,
    "min_audit_clean_rate": 1.00,
    "min_quality_gain": 0.05,
    "max_agent_error_rate": 0.05,
    "min_discriminating_tasks": 0,
}


def policy_with_defaults(policy: dict | None) -> dict:
    return {**DEFAULTS, **(policy or {})}


def preregistration_sha(policy: dict | None, arms: list[str], tasks: list[str], k: int,
                        adapter: str | None, model: str | None) -> str:
    payload = {
        "policy": policy_with_defaults(policy),
        "arms": sorted(arms),
        "tasks": sorted(tasks),
        "k": k,
        "adapter": adapter,
        "model": model,
    }
    return hashlib.sha256(json.dumps(payload, sort_keys=True).encode()).hexdigest()


def _lower(ci: list | None) -> float | None:
    return ci[0] if ci and len(ci) == 2 else None


def _upper(ci: list | None) -> float | None:
    return ci[1] if ci and len(ci) == 2 else None


def decide(arm: str, summary: dict, delta: dict, policy: dict | None, task_count: int,
           cost_multiplier: float | None = None, lead_time_multiplier: float | None = None,
           quality: dict | None = None, reliability: dict | None = None) -> dict:
    rules = policy_with_defaults(policy)
    reasons: list[str] = []
    warnings: list[str] = []

    tamper = summary.get("tamper_rate") or 0.0
    if tamper > rules["max_tamper_rate"]:
        reasons.append(f"tamper rate {tamper:.2f} > {rules['max_tamper_rate']:.2f}")

    audit_clean = (quality or {}).get("audit_clean_rate")
    if audit_clean is not None and audit_clean < rules["min_audit_clean_rate"]:
        reasons.append(f"audit clean rate {audit_clean:.2f} < {rules['min_audit_clean_rate']:.2f}")

    agent_error = (reliability or {}).get("agent_error_rate")
    if agent_error is not None and agent_error > rules["max_agent_error_rate"]:
        reasons.append(f"agent error rate {agent_error:.2f} > {rules['max_agent_error_rate']:.2f}")

    if reasons:
        return _verdict(arm, "reject", reasons, warnings, rules)

    pass_gain = delta.get("pass_rate") or 0.0
    pass_low = _lower(delta.get("ci95"))
    pass_high = _upper(delta.get("ci95"))
    score_gain = delta.get("score")
    score_low = _lower(delta.get("score_ci95"))
    if pass_gain < 0 and pass_high is not None and pass_high <= 0:
        reasons.append(f"pass rate regression {pass_gain:+.2f} (CI upper {pass_high:+.2f})")
        return _verdict(arm, "reject", reasons, warnings, rules)

    if task_count < rules["min_discriminating_tasks"]:
        reasons.append(f"{task_count} tasks < {rules['min_discriminating_tasks']} required")
        return _verdict(arm, "inconclusive", reasons, warnings, rules)

    cost_mult = cost_multiplier if cost_multiplier is not None else 1.0
    lead_mult = lead_time_multiplier if lead_time_multiplier is not None else 1.0
    gains_below = pass_gain < rules["min_pass_gain"] and (
        score_gain is None or score_gain < rules["min_score_gain"])
    if (cost_mult > rules["max_cost_multiplier"]
            or lead_mult > rules["max_lead_time_multiplier"]) and gains_below:
        reasons.append(
            f"cost x{cost_mult:.2f} / lead x{lead_mult:.2f} exceed policy without a worthwhile gain")
        return _verdict(arm, "reject", reasons, warnings, rules)

    pass_ship = pass_low is not None and pass_low >= rules["min_pass_gain"]
    score_ship = score_low is not None and score_low >= rules["min_score_gain"]
    if pass_ship or score_ship:
        if cost_mult > rules["max_cost_multiplier"]:
            warnings.append(f"cost x{cost_mult:.2f} is above the preferred maximum")
        if lead_mult > rules["max_lead_time_multiplier"]:
            warnings.append(f"lead time x{lead_mult:.2f} is above the preferred maximum")
        if pass_ship:
            reasons.append(f"pass lower CI {pass_low:+.2f} >= {rules['min_pass_gain']:+.2f}")
        if score_ship:
            reasons.append(f"score lower CI {score_low:+.2f} >= {rules['min_score_gain']:+.2f}")
        return _verdict(arm, "ship", reasons, warnings, rules)

    if pass_low is None and score_low is None:
        reasons.append("no confidence interval (need more than one run)")
    else:
        reasons.append(
            f"pass CI [{pass_low if pass_low is not None else '?'}, "
            f"{pass_high if pass_high is not None else '?'}] does not clear the minimum gain")
    return _verdict(arm, "inconclusive", reasons, warnings, rules)


def _verdict(arm: str, verdict: str, reasons: list[str], warnings: list[str], rules: dict) -> dict:
    return {
        "arm": arm,
        "verdict": verdict,
        "reasons": reasons,
        "warnings": warnings,
        "policy": rules,
    }
