# e03s01 — Report median and p90 for duration, cost, tokens and diff lines
<!-- story: e03s01 -->

**type:** feat
**risk:** P1
**context:** infra
**BCPs:** 3

## Context

A single timed-out or rework-heavy run can move the mean more than the effect under test. The
report currently publishes means only. Add median and p90 for `duration_s`, `cost_usd`,
`input_tokens` and `diff_lines`, per arm. Keep means for compatibility.

## Steps

1. Add `percentile(values, p)` (nearest-rank, ignores `None`) and `median` in `ab_report.py` → verify: `python3 Tests/test_ab_report.py`.
2. Add `median_*` and `p90_*` keys to `arm_summary` for the four metrics → verify: `python3 Tests/test_ab_report.py`.
3. Print median/p90 in `print_summary` without breaking the existing table → verify: `python3 -c "import sys; sys.path.insert(0,'scripts/lib'); import ab_report; print(ab_report.percentile([1,2,3,4,10], 90))"`.
4. Add the keys to `benchmarks/docs/SCHEMA-AB.md` → verify: `rg -n 'median_duration_s|p90_duration_s' benchmarks/docs/SCHEMA-AB.md`.
5. Update the Lean summary to use medians for cost-per-pass? No: keep `cost_per_pass` as total cost / passes, and add `median_cost_usd` only → verify: `rg -n 'median_cost_usd' benchmarks/docs/SCHEMA-AB.md`.

## Verification Script (Step-by-Step)

1. Run a fake matrix with one extreme duration.
2. Confirm mean moves much more than median.
3. Confirm p90 is between median and max.

## Out of scope

- Changing the bootstrap CI (it stays on the mean; add a median CI later only if needed).
- Recomputing old reports; the next run uses the new keys.

## Risks

- Percentile definition differences: document nearest-rank in SCHEMA.
- `None` values from adapters without parsers must not become 0.

## Acceptance Criteria

- [ ] Four metrics carry mean, median and p90.
- [ ] `None` is ignored, not coerced.
- [ ] Existing keys are unchanged.
