# e03s02 — Pre-register acceptance thresholds and emit a decision verdict
<!-- story: e03s02 -->

**type:** feat
**risk:** P1
**context:** infra
**BCPs:** 5

## Context

Choosing thresholds after seeing the numbers is how benchmarks become marketing. This story puts
the policy in `config.yaml`, hashes it before the run, and makes the report say
`ship | reject | inconclusive` with reasons.

Default policy (tune before e07, then freeze):

```yaml
decision_policy:
  confidence: 0.95
  min_pass_gain: 0.05
  min_score_gain: 0.02
  max_cost_multiplier: 1.50
  max_lead_time_multiplier: 1.50
  max_tamper_rate: 0.00
  min_audit_clean_rate: 1.00
  min_quality_gain: 0.05
  min_discriminating_tasks: 10
```

Rules:

- `reject` if any safety threshold fails (tamper, audit, preflight).
- `reject` if cost or lead time exceeds its multiplier while pass/score gains are below minimums.
- `inconclusive` if the CI for pass or score includes zero and no harm is shown.
- `ship` only if the lower CI bound clears the minimum gain and cost/time stay inside bounds.

## Steps

1. Add `decision_policy` to `config.yaml` with comments and a `preregistration` block → verify: `python3 -c "import yaml; c=yaml.safe_load(open('benchmarks/ab/config.yaml')); print(c['decision_policy']['min_pass_gain'])"`.
2. Add `decision.py` with a pure `decide(arm, summary, delta, policy, task_count)` → verify: `python3 Tests/test_ab_decision.py`.
3. Hash the policy + arms + tasks + k into `preregistration_sha` and write it to report meta before round 1 → verify: `python3 Tests/test_ab_decision.py`.
4. Add the `decision` block to the report: `{verdict, reasons[], policy, preregistration_sha}` → verify: `rg -n 'verdict|preregistration_sha' benchmarks/docs/SCHEMA-AB.md`.
5. Add `--fail-on-decision` so CI can fail on `reject` → verify: `python3 Tests/test_ab_decision.py`.
6. Print a one-line verdict at the end of a run → verify: `python3 Tests/test_ab_decision.py`.
7. Test the four cases: ship, reject-safety, reject-cost, inconclusive → verify: `python3 Tests/test_ab_decision.py`.

## Verification Script (Step-by-Step)

1. Run a fake matrix with a clear gain and no cost increase; verdict is `ship`.
2. Add a tamper; verdict is `reject` with the tamper reason.
3. Double the cost; verdict is `reject` or `inconclusive` per the rules, with the multiplier named.
4. Change the policy after the run; `--verify-inputs` reports the hash mismatch.

## Out of scope

- Automatic task-count gating (e04s04 owns the calibration gate).
- Multiple-comparison correction across arms; add later if the arm count grows.

## Risks

- A policy that is too strict makes every run inconclusive; start with the values above and record
  why they were chosen.
- A policy that is too loose turns a null result into a ship; the lower CI bound is the guard.
- `preregistration_sha` must be computed before the first agent run, not at report time.

## Acceptance Criteria

- [ ] The policy lives in config and is hashed before the run.
- [ ] The report contains a verdict and reasons.
- [ ] `--fail-on-decision` exits 1 on reject.
- [ ] All four verdict paths have tests.
