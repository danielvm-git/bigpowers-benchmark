# e04s03 — long-horizon and external task calibration

Date: 2026-11-04
Adapter: `pi-docker`
Model: `opencode-go/deepseek-v4.1-flash`
Subject: `/Users/danielvm/Developer/bigpowers` @ `52842a2f`
Runner: `bigpowers-benchmark` @ `1d4978f` (dirty; recorded)

## Tasks added

| Task | Shape | Source |
|---|---|---|
| `ab-21` | changing issue thread, old-data migration | ours |
| `ab-22` | multi-file HTTP API, routing/validation/error shape | ours |
| `ab-23` | resume a migration from saved state | ours |
| `ab-24` | URL shortener with aliases, expiry, click counts | adapted from intent-bench (Apache-2.0) |

## Calibration results

| Task | k | Pass rate | Band | Notes |
|---|---:|---:|---|---|
| ab-21 | 3 | 1.00 | too_easy | after `invalid due date` and completed-overdue clarifications |
| ab-22 | 3 | 1.00 | too_easy | PATCH API solved every run |
| ab-23 | 3 | 1.00 | too_easy | resume/state solved every run |
| ab-24 | 5 | 1.00 | too_easy | URL shortener solved every run |

For context, the earlier hard tasks after their ambiguity fixes were also `too_easy`
(ab-17 5/5, ab-19 10/10, ab-20 5/5), and ab-09 was 8/10 at the 0.80 upper boundary.

## What this means

The model saturates small and mid, fully specified tasks. Adding requirements, files and state
was not enough: the agent reads the spec, implements it, and passes. The suite currently has
**no task in the 20–80% band except ab-09 at the boundary**. e04s04's calibration gate cannot
pass with this suite.

The failures during calibration were mostly **spec ambiguities**, not difficulty:

- ab-21: `invalid due` vs `invalid due date`; completed todos in `--overdue`.
- ab-23: summary key `totalCents` vs `revenueCents`; return shape not relied on after fixing.
- ab-24: visible test expected lowercase codes while the spec allowed mixed case.

Those fixes are correct, but they move tasks from `too_hard` to `too_easy`, not into the band.

## Options for the next iteration

1. **Mid-size, stateful tasks** — planning poker backend with 25-way concurrent votes and the
   no-op-vote rule (proto-specs, MIT); SpecBench `json_parser` / `package_resolver` at 500–1500
   LOC.
2. **Concurrency and invariants** — tasks where the hard part is lost updates, idempotency,
   ordering or rollback, not more endpoints.
3. **Accept the null result** — publish that this model saturates the current suite and stop
   adding tasks that only increase length.

The next story, e04s04, should remain blocked until at least 7 tasks are in the band (re-scoped from 10 after batch 8).

## ab-25 / ab-26 retest (k=3, post-fix)

| Task | Pass rate | Band | Notes |
|---|---:|---|---|
| ab-25 | 1.00 | too_easy | checkpoint/resume solved every run |
| ab-26 | 1.00 | too_easy | 1 agent error, but the run still passed |

Reports: `benchmarks/reports/calibration-ab25-ab26-retry/CALIBRATION-2026-11-04.yaml`.

Conclusion unchanged: state, atomic writes and a small TCP protocol were still solved by vanilla.

## SDD Academy batch 1 (ab-27/28/29)

| Task | k | Pass rate | Mean score | Band | Note |
|---|---:|---:|---:|---|---|
| ab-27 banking ledger | 5 | 0.80 | 0.956 | **discriminating** | first new task in the band |
| ab-28 flight booking | 5 | 0.00 | 0.875 | too_hard | one hidden test missed: unknown booking must throw |
| ab-29 HR payroll | 5 | 1.00 | 1.000 | too_easy | after specifying `invalid_salary` |

Reports:

- `benchmarks/reports/calibration-sdd-batch1/CALIBRATION-2026-11-05.yaml`
- `benchmarks/reports/calibration-sdd-batch1-retest/CALIBRATION-2026-11-05.yaml`

ab-28 is close: 7 of 8 hidden tests pass; the failure is a real spec requirement (cancel/booking an
unknown id must throw `booking_not_found`). It is a genuine `too_hard`, not an ambiguity.

## SDD Academy batch 2 (ab-30/31/32)

| Task | k | Pass rate | Mean score | Band | Notes |
|---|---:|---:|---:|---|---|
| ab-30 project DAG | 5 | 0.60 | 0.771 | discriminating | 2 agent errors |
| ab-31 chat ordering | 5 | 0.20 | 0.900 | discriminating | lower boundary |
| ab-32 social feed | 5 | 0.60 | 0.756 | discriminating | 2 agent errors |

After spec clarifications for `invalid_estimate`, `invalid_participants` and the chat/presence
errors, all three landed in the 20–80% band. Combined with ab-09 and ab-27, the suite now has five
discriminating tasks.

## SDD Academy batch 3 (ab-33..ab-37)

| Task | k | Pass rate | Mean score | Band |
|---|---:|---:|---:|---|
| ab-33 music store | 3 | 0.00 | 0.555 | too_hard |
| ab-34 recommender | 3 | 1.00 | 1.000 | too_easy |
| ab-35 todo collaboration | 3 | 1.00 | 1.000 | too_easy |
| ab-36 project timeline | 3 | 0.00 | 0.809 | too_hard |
| ab-37 loans | 3 | 0.67 | 0.944 | discriminating |

Total discriminating tasks: ab-09, ab-27, ab-30, ab-31, ab-32, ab-37 = **6**.

## Batch 3 retest (ab-33/36)

| Task | k | Pass rate | Mean score | Band |
|---|---:|---:|---:|---|
| ab-33 music store | 5 | 1.00 | 1.000 | too_easy |
| ab-36 project timeline | 5 | 0.40 | 0.857 | discriminating |

Seven discriminating tasks now: ab-09, ab-27, ab-30, ab-31, ab-32, ab-36, ab-37.

## Batch 4 (ab-38/39/40)

| Task | k | Pass rate | Mean score | Band |
|---|---:|---:|---:|---|
| ab-38 timeline replan | 3 | 1.00 | 1.000 | too_easy |
| ab-39 social messaging | 3 | 1.00 | 1.000 | too_easy |
| ab-40 ledger holds | 3 | 1.00 | 1.000 | too_easy |

After message-normalisation, all three are too easy. Seven discriminating tasks remain.

## Batch 5 (ab-41/42/43)

| Task | k | Pass rate | Mean score | Band |
|---|---:|---:|---:|---|
| ab-41 JSON parser | 3 | 1.00 | 1.000 | too_easy |
| ab-42 binary protocol | 3 | 1.00 | 1.000 | too_easy |
| ab-43 package resolver | 3 | 1.00 | 1.000 | too_easy |

ab-43 first calibrated at 0.833 (too_hard) because the spec omitted the invalid-version rule; after
making it explicit it passed 3/3. Seven discriminating tasks remain. Evidence:
`benchmarks/reports/calibration-sdd-batch5/` and `benchmarks/reports/calibration-sdd-batch5b/`.

## Batch 6 (ab-44/45/46)

| Task | k | Pass rate | Mean score | Band |
|---|---:|---:|---:|---|
| ab-44 fair scheduler | 3 | 1.00 | 1.000 | too_easy |
| ab-45 FX settlement | 3 | 0.00 | 0.833 | too_hard |
| ab-46 policy engine | 3 | 1.00 | 1.000 | too_easy |

## Batch 7 (ab-47/48/49)

| Task | k | Pass rate | Mean score | Band |
|---|---:|---:|---:|---|
| ab-47 inventory reservations | 3 | 1.00 | 1.000 | too_easy |
| ab-48 feed cursor | 3 | 1.00 | 1.000 | too_easy |
| ab-49 order workflow | 3 | 0.00 | 0.857 | too_hard |

Both too_hard results were single underspecified edges (unused-currency rate validation and
refund-history entries). The model solves clean specs. Seven discriminating tasks remain:
ab-09, ab-27, ab-30, ab-31, ab-32, ab-36, ab-37.

## Batch 8 (ab-50/51/52, larger multi-module)

| Task | k | Pass rate | Mean score | Band |
|---|---:|---:|---:|---|
| ab-50 warehouse fulfillment | 3 | 0.00 | 0.800 | too_hard |
| ab-51 proxy auction | 3 | 0.00 | 0.875 | too_hard |
| ab-52 receivables reconciliation | 3 | 1.00 | 1.000 | too_easy |

ab-50 failed atomicity and fulfill-availability on all runs; ab-51 failed one proxy/tie edge on
all runs; ab-52 passed 3/3. The hard tasks fail deterministically, so they cannot enter the band
without changing the model or timeout. Seven discriminating tasks remain.
