# e02s02 — Pristine-fixture preflight before any agent run
<!-- story: e02s02 -->

**type:** feat
**risk:** P0
**context:** infra
**BCPs:** 8

## Context

The 2026-11-03 run wasted agent tokens because `ab-11`, `ab-13` and `ab-20` shipped a broken
`npm test` script: agents spent effort repairing `package.json` instead of solving the task. This
story proves, before round 1, that every selected task is a valid experiment.

For every selected task, inside the adapter's `grade_wrapper` container:

1. Arm setup exits 0.
2. The visible test command runs and matches the task's declared expectation.
3. `fixture + hidden` fails `grade`.
4. `solution + hidden` passes `grade`, and `score` is 1.0 when present.

Any failure aborts with exit 2 before an agent is launched. Results are cached by
`(task_digest, solution_digest, image_id, grade_cmd, setup_cmd)` so repeated runs do not pay twice.

## Steps

1. Extend `task.yaml` with optional `preflight: {visible_tests: pass|fail, command: "npm test"}`; default `pass` and `npm test` when `package.json` exists → verify: `rg -n 'preflight' benchmarks/docs/SCHEMA-AB.md`.
2. Mark `ab-03` as `visible_tests: fail` because it is a red-suite task → verify: `rg -n 'visible_tests: fail' benchmarks/ab/tasks/ab-03-red-suite-slugify/task.yaml`.
3. Add `scripts/lib/ab_preflight.py` with `check_task(task, arms, adapter, runner_root)` returning a structured result → verify: `python3 -m py_compile scripts/lib/ab_preflight.py`.
4. Run visible tests; for `pass` expect 0, for `fail` expect non-zero; print the last 20 lines on mismatch → verify: `python3 Tests/test_ab_preflight.py`.
5. Copy `hidden/` into a pristine fixture and assert `grade` is non-zero → verify: `python3 Tests/test_ab_preflight.py`.
6. Copy `solution/` over the fixture, copy `hidden/`, assert `grade` is 0 and `score` is 1.0 when present → verify: `python3 Tests/test_ab_preflight.py`.
7. Run the preflight through `grade_wrapper` when defined; never on the host → verify: `python3 Tests/test_ab_preflight.py`.
8. Add `--preflight-only`, `--skip-preflight` (debug), and a content-addressed cache → verify: `bash scripts/run-ab-eval.sh --preflight-only --tasks ab-11 --bigpowers-root /tmp/bp-subject`.
9. Make the default path run preflight before round 1 and abort exit 2 → verify: `python3 Tests/test_ab_preflight.py`.
10. Add a deliberately broken fixture test: missing `package.json` script must abort, not spend → verify: `python3 Tests/test_ab_preflight.py`.

## Verification Script (Step-by-Step)

1. Run `--preflight-only` on all tasks; every line is PASS.
2. Break `ab-11`'s `npm test`; re-run; expect FAIL and exit 2 before any agent run.
3. Restore; re-run; PASS from cache.
4. Confirm the cache key changes when a hidden test changes.

## Out of scope

- Proving that hidden tests are requirement-complete (e04s02).
- Proving the fixture is in the 20-80% band (e04s01).

## Risks

- Preflight doubles setup cost; the cache is mandatory, not optional.
- A red-suite task must not be forced to green; `visible_tests: fail` keeps it honest.
- Running the visible test on the host would execute fixture code; always use `grade_wrapper`.

## Acceptance Criteria

- [ ] A broken fixture aborts before any token is spent.
- [ ] A red-suite task is expected to fail visible tests.
- [ ] `solution + hidden` passes for every task.
- [ ] Preflight results are cached by input digest.
