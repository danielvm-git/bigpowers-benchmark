# e04s01 — Calibration framework and difficulty bands
<!-- story: e04s01 -->

**type:** feature
**risk:** P0
**context:** harness
**BCPs:** 5

## Problem
A benchmark suite with saturated tasks (all pass or all fail) cannot measure difference between agent configurations.

## Requirements
- Define criteria for `too_easy` (pass rate > 0.8), `discriminating` (0.2 ≤ pass rate ≤ 0.8), and `too_hard` (pass rate < 0.2).
- Add `--calibrate` option to `scripts/run-ab-eval.sh` and output band summary YAML.

## Verification
- `python3 Tests/test_ab_calibration.py` runs and passes.
