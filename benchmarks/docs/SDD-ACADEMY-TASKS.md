# SDD Academy projects → benchmark tasks

Source: <https://sdd-academy.vercel.app/projects> (10 practice projects).
The site provides a description, a table-level schema and getting-started steps. It does **not**
provide fixtures, hidden tests or reference solutions, and its content is not licensed for
copying. Everything below is a task **design**; the specs, fixtures and tests are ours.

## All ten project pages, mapped to a core slice

| # | Project | Level | Core slice for our harness | Likely band |
|---|---|---|---|---|
| 1 | Element Explorer API | beginner | element filters, sorting, pagination, unknown category | too_easy risk |
| 2 | Todo API | beginner | auth-lite, task CRUD, sharing, idempotent complete | too_easy risk |
| 3 | Digital Music Store | intermediate | playlists, reviews, purchase entitlement, duplicate purchase | mid |
| 4 | Flight Booking System | advanced | seat inventory, double-book prevention, payment, cancel/refund | **hard** |
| 5 | Social Network Platform | advanced | follow graph, feed pagination, visibility, unread messages | mid/hard |
| 6 | HR Management Portal | advanced | payroll tax brackets, leave proration, duplicate period | **hard** |
| 7 | Banking System | advanced | double-entry ledger, transfer atomicity, idempotency, currency | **hard** |
| 8 | Recommendation Engine | intermediate | interaction log, co-occurrence, cold start, A/B buckets | mid |
| 9 | Real-Time Chat | intermediate | message ordering, delivery states, presence, reconnect | mid/hard |
| 10 | Project Management Tool | advanced | task dependencies, cycle detection, assignment, progress roll-up | mid/hard |

## Batch 1 — implemented here

### ab-27 Banking ledger

- Source: Banking System.
- Core: `createAccount`, `transfer`, `ledger`, `balance`, `reset`.
- Hard parts: double-entry invariants, idempotency keys, currency mismatch, insufficient funds,
  concurrent transfers, no partial writes.
- Hidden tests: success + two ledger entries summing to zero; insufficient funds/no mutation;
  unknown account; non-positive amount; duplicate idempotency key; same-account transfer;
  currency mismatch; 10 concurrent transfers preserve total and never overdraw; duplicate account.

### ab-28 Flight booking

- Source: Flight Booking System.
- Core: `createFlight`, `book`, `cancel`, `availableSeats`, `booking`, `reset`.
- Hard parts: deterministic seat assignment, no double booking, idempotent booking, cancellation
  refunds exactly once, sold-out state.
- Hidden tests: lowest free seat; sold out; unknown flight; idempotent retry; concurrent last-seat
  race; cancel/refund once; cancel twice; seat released after cancel; invalid seats/price.

### ab-29 HR payroll

- Source: HR Management Portal.
- Core: `runPayroll`, `payrollReport`, `reset`.
- Hard parts: progressive tax brackets, pension, proration, rounding, duplicate period, inactive
  employees, totals.
- Hidden tests: bracket boundaries (200000/200001/400000/400001), pension 5%, inactive exclusion,
  duplicate period, invalid period, rounding, empty payroll, totals equal sum of lines.

## Batch 2 — planned

| Task | Source | Core slice |
|---|---|---|
| ab-30 Digital music store | Digital Music Store | playlist ownership, review uniqueness, purchase entitlement |
| ab-31 Social feed | Social Network | follow graph, feed ordering/pagination, private accounts |
| ab-32 Recommendation engine | Recommendation Engine | co-occurrence scoring, cold start, deterministic A/B buckets |
| ab-33 Chat delivery | Real-Time Chat | message ordering, delivered/read states, presence timeout |
| ab-34 Project dependencies | Project Management | DAG validation, cycle detection, critical path, progress roll-up |
| ab-35 Element explorer | Element Explorer | filters, sorting, pagination, stable ordering |
| ab-36 Todo collaboration | Todo API | sharing, ownership, idempotent complete, list ordering |

## Why this ordering

The last calibration showed that CRUD and endpoint count are not the hard part. Batch 1 focuses on
**invariants, atomicity, idempotency and money/seat state** — the parts that can fail even when
every endpoint returns 200.

## Batch 1 calibration (2026-11-05)

| Task | k | Pass rate | Band | Note |
|---|---:|---:|---|---|
| ab-27 banking ledger | 5 | 0.80 | **discriminating** | first new task in the 20–80% band |
| ab-28 flight booking | 5 | 0.00 | too_hard | 7/8 hidden tests pass; unknown booking must throw |
| ab-29 HR payroll | 5 | 1.00 | too_easy | after `invalid_salary` was specified |

ab-27 is the first task after ab-09 to land in the band. ab-28 is a genuine hard task, not a spec
ambiguity: the model did not make `cancel` / `booking` reject an unknown id.

Batch 2 should prioritise tasks that combine **state transitions with invariants** like ab-27,
not more CRUD endpoints.

## Batch 2 calibration (2026-11-05)

| Task | k | Pass rate | Mean score | Band | Note |
|---|---:|---:|---:|---|---|
| ab-30 project DAG | 5 | 0.60 | 0.771 | **discriminating** | 2 agent errors |
| ab-31 chat ordering | 5 | 0.20 | 0.900 | **discriminating** | lower boundary |
| ab-32 social feed | 5 | 0.60 | 0.756 | **discriminating** | 2 agent errors |

Batch 2 moved three more tasks into the band. Together with ab-09 and ab-27, the benchmark now
has **five discriminating tasks**; the e04s04 gate then needed ten (re-scoped to seven after batch 8).

## Batch 3 calibration (2026-11-06, k=3)

| Task | Pass rate | Mean score | Band | Note |
|---|---:|---:|---|---|
| ab-33 music store | 0.00 | 0.555 | too_hard | 1 agent error |
| ab-34 recommender | 1.00 | 1.000 | too_easy | |
| ab-35 todo collaboration | 1.00 | 1.000 | too_easy | |
| ab-36 project timeline | 0.00 | 0.809 | too_hard | close; one hidden test failing |
| ab-37 loans | 0.67 | 0.944 | **discriminating** | |

Six tasks are now in the band: ab-09, ab-27, ab-30, ab-31, ab-32, ab-37. Four more are needed
for the e04s04 gate.

## Batch 3 retest (2026-11-06)

| Task | k | Pass rate | Mean score | Band |
|---|---:|---:|---:|---|
| ab-33 music store | 5 | 1.00 | 1.000 | too_easy |
| ab-36 project timeline | 5 | 0.40 | 0.857 | **discriminating** |

After specifying `purchase_not_found: <id>` and `invalid_delay`, ab-33 became too easy and ab-36
moved into the band. Total discriminating: **7** — ab-09, ab-27, ab-30, ab-31, ab-32, ab-36, ab-37.

## Batch 4 calibration (2026-11-06, k=3)

| Task | Pass rate | Mean score | Band |
|---|---:|---:|---|
| ab-38 timeline replan | 1.00 | 1.000 | too_easy |
| ab-39 social messaging | 1.00 | 1.000 | too_easy |
| ab-40 ledger holds | 1.00 | 1.000 | too_easy |

ab-40 was `too_hard` with strict error-message assertions and `too_easy` once the message variants
were accepted. The message was noise; the behaviour was solved.

## Batch 5 calibration (2026-11-06, k=3)

| Task | Pass rate | Mean score | Band |
|---|---:|---:|---|
| ab-41 JSON parser | 1.00 | 1.000 | too_easy |
| ab-42 binary protocol | 1.00 | 1.000 | too_easy |
| ab-43 package resolver | 1.00 | 1.000 | too_easy |

ab-43 was `too_hard` at 0.833 only because the spec did not say invalid registry versions are
rejected; after adding that rule it passed 3/3. The model solves parsers, wire protocols and
semver resolution. Total discriminating remains **7**: ab-09, ab-27, ab-30, ab-31, ab-32, ab-36,
ab-37. The next tasks target money rounding, scheduling ties and policy precedence, the areas where
earlier tasks discriminated.

## Batch 6 calibration (2026-11-06, k=3)

| Task | Pass rate | Mean score | Band |
|---|---:|---:|---|
| ab-44 fair scheduler | 1.00 | 1.000 | too_easy |
| ab-45 FX settlement | 0.00 | 0.833 | too_hard |
| ab-46 policy engine | 1.00 | 1.000 | too_easy |

ab-45 failed only the unused-currency rate validation case; the core rounding and netting
passed. Seven discriminating tasks remain.

## Batch 7 calibration (2026-11-06, k=3)

| Task | Pass rate | Mean score | Band |
|---|---:|---:|---|
| ab-47 inventory reservations | 1.00 | 1.000 | too_easy |
| ab-48 feed cursor | 1.00 | 1.000 | too_easy |
| ab-49 order workflow | 0.00 | 0.857 | too_hard |

ab-49 failed only the refund-history entry, which the spec did not enumerate. The model solves
clean state-machine, pagination, reservation and policy specs. Seven discriminating tasks remain:

**ab-09, ab-27, ab-30, ab-31, ab-32, ab-36, ab-37.**

The pattern across batches 4-7: clean single-module specs are too easy; ambiguity produces
too_hard, not discrimination. Reaching ten needs larger multi-module tasks or a re-scoped gate.

## Batch 8 calibration (2026-11-06, k=3, larger multi-module tasks)

| Task | Pass rate | Mean score | Band |
|---|---:|---:|---|
| ab-50 warehouse fulfillment | 0.00 | 0.800 | too_hard |
| ab-51 proxy auction | 0.00 | 0.875 | too_hard |
| ab-52 receivables reconciliation | 1.00 | 1.000 | too_easy |

These tasks were deliberately larger (3–4 interacting rules, 8–10 hidden tests). ab-50 failed
atomicity and fulfillment invariants on every run; ab-51 failed one proxy-price/tie edge on every
run. Both failures are genuine spec edges, not ambiguity. ab-52 was solved 3/3.

**Conclusion:** clean specs are solved; the remaining failures are genuine hard edges that fail
consistently, so they land in `too_hard`, not the 20–80% band. Seven discriminating tasks remain:
ab-09, ab-27, ab-30, ab-31, ab-32, ab-36, ab-37. Reaching ten needs either a weaker calibration
model, a lower task timeout, or a re-scoped gate; adding more clean tasks has not worked.
