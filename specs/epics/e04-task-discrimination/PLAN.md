# e04 — Tasks that can tell arms apart

The suite is saturated: `TASK-REVIEW_LATEST.md` found 0/14 tasks in the 20-80% vanilla-pass band,
and the three "harder" tasks also passed 15/15. More repetitions cannot fix this. The work is task
design, calibrated before it is used.

## e04s01 — Vanilla-only calibration (5 BCP, P0)

**Steps**

1. Add `--calibrate`: run vanilla only, k=10, no bigpowers arm → verify: `bash scripts/ab-calibrate.sh --tasks ab-11 --k 10 --bigpowers-root <checkout>`.
2. Report per task: `pass_rate`, `mean_hidden_score`, `runs`, `timed_out`, `agent_error` → verify: `rg -n 'pass_rate|mean_hidden_score' benchmarks/reports/CALIBRATION-*.yaml`.
3. Classify `too_easy` (>0.8), `discriminating` ([0.2, 0.8]), `too_hard` (<0.2) → verify: `python3 Tests/test_ab_calibration.py`.
4. Cache by input digest; never recalibrate an unchanged task → verify: `python3 Tests/test_ab_calibration.py`.

**Acceptance:** every task has a calibration record with a band label and a date.

## e04s02 — De-prescribe specs and complete hidden tests (8 BCP, P1)

**Steps**

1. Add a `spec_style: behavioural` field to `task.yaml`; reject `prescriptive` on shipped tasks → verify: `rg -n 'spec_style' benchmarks/docs/SCHEMA-AB.md`.
2. Rewrite prompts to state observable behaviour only: no formulas, helper names, internal field maps or exact code → verify: `python3 Tests/test_task_quality.py`.
3. Add a requirement checklist per task: each stated requirement, its boundary, null/missing input and a regression case → verify: `python3 Tests/test_task_quality.py`.
4. Add the missing hidden tests, including the boundaries the review named (2999 vs 3000 cents, the 6th alias, an expired hold at exactly `expiresAt`) → verify: `python3 Tests/test_task_quality.py`.
5. Re-calibrate after every edit; a task that leaves the band is revised again → verify: `python3 Tests/test_ab_calibration.py`.

**Acceptance:** the prompt describes what a caller observes; hidden tests cover every requirement and its edges.

## e04s03 — Long-horizon and multi-step tasks (8 BCP, P1)

**Steps**

1. Add `ab-21`: requirements split across a three-comment issue thread; a later comment changes the
   format; old data files must keep loading → verify: `test -f benchmarks/ab/tasks/ab-21-*/task.yaml`.
2. Add `ab-22`: a 600-1500 LOC multi-file app where the change touches routing, validation and error shape → verify: `test -f benchmarks/ab/tasks/ab-22-*/task.yaml`.
3. Add `ab-23`: a two-session task; the fixture includes a `STATE.md` the agent must resume from → verify: `test -f benchmarks/ab/tasks/ab-23-*/task.yaml`.
4. Each task: fixture fails, solution passes, hidden tests cover regressions → verify: `bash scripts/run-ab-eval.sh --preflight-only --tasks ab-21,ab-22,ab-23 --bigpowers-root <checkout>`.

**Acceptance:** three long-horizon tasks exist and preflight cleanly.

## e04s04 — Calibration gate (3 BCP, P0)

**Steps**

1. Add `scripts/check-calibration.sh`: at least 7 tasks in the band and the armed suite has no
   `too_easy` task older than the last revision → verify: `bash scripts/check-calibration.sh benchmarks/reports/CALIBRATION-<date>.yaml`.
2. Wire it into the release gate; e07 cannot start until it passes → verify: `rg -n 'check-calibration' scripts/run-benchmark-tests.sh`.
3. Record saturated tasks as retired with a reason, not silently dropped → verify: `rg -n 'retired|saturated' benchmarks/docs/TASK-REVIEW.md`.

**Acceptance:** the benchmark refuses to run a suite that cannot discriminate.
