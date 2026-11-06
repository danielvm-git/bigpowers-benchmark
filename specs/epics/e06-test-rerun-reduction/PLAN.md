# e06 — Measure and reduce avoidable test reruns

The Lean view already shows overprocessing: bigpowers runs 2.3× more tests and 2.8× more re-edits
for the same first-time-through. This epic makes the waste precise and tests a safe reduction.

## e06s01 — Hash test inputs and label repeated green runs (3 BCP, P1)

**Steps**

1. In `ab_waste.py`, compute `test_input_hash` at each test command: hash of changed source files, test files, `package.json`, lockfile and any task-declared inputs → verify: `python3 Tests/test_ab_waste.py`.
2. Record per run `test_runs_with_input_change`, `test_runs_same_input`, `green_runs_same_input` → verify: `rg -n 'green_runs_same_input' benchmarks/docs/SCHEMA-AB.md`.
3. Define `redundant_green_run = exit 0 and hash unchanged since the previous green run`; keep the existing `redundant_test_runs` name for compatibility → verify: `python3 Tests/test_ab_waste.py`.
4. Add a test where a green run repeats with no edits and is labelled redundant, and one where a source edit makes it non-redundant → verify: `python3 Tests/test_ab_waste.py`.

**Acceptance:** a repeated green run with unchanged inputs is measured, not guessed.

## e06s02 — Opt-in test guard plus ablation (5 BCP, P1)

**Steps**

1. Add `scripts/lib/test-guard.sh`: `check <hash>` exits 0 if the last run for that hash was green, 1 otherwise; `record <hash> <exit>` stores the result under `.bp-test-guard/` → verify: `bash tests/test_test_guard.sh`.
2. Require both conditions to skip: hash match **and** last result green; never skip after a red run → verify: `bash tests/test_test_guard.sh`.
3. Add a `bp-testguard` arm: `bp-core` setup plus an `AGENTS.md` rule to use the guard before rerunning tests → verify: `rg -n 'bp-testguard' benchmarks/ab/config.yaml`.
4. Record `guard_checks`, `guard_skips`, `guard_false_skips` (a skip followed by a failure when the test is next run) → verify: `rg -n 'guard_false_skips' benchmarks/docs/SCHEMA-AB.md`.
5. Run a paired ablation on tasks with high `redundant_test_runs`; require ≥50% reduction (CI excludes zero) and no quality loss → verify: `python3 Tests/test_ab_guard_decision.py`.
6. If the guard regresses quality, do not adopt it; record the negative result as an ADR → verify: `test -f specs/adr/0006-test-guard.md`.

**Acceptance:** the guard is adopted only with measured benefit and no quality regression.
