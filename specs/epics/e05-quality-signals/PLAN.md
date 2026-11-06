# e05 — Quality signals a green suite cannot hide

The normal grade is necessary but not sufficient. `ab-20` proved it: both arms passed `grade`, but
the separate `audit` found the same brand-handling defect in every run. This epic makes that
visible and gating.

## e05s01 — Audit defects become a scored quality signal (5 BCP, P0)

**Steps**

1. Make `audit` mandatory for every task, or `audit: null` with a `reason` field → verify: `python3 Tests/test_ab_audit.py`.
2. Record `audit_total`, `audit_failed`, `audit_clean = audit_failed == 0` and `audit_rate` per run → verify: `python3 Tests/test_ab_audit.py`.
3. Add `quality.quality_pass = pass and audit_clean and not tampered` → verify: `python3 Tests/test_ab_audit.py`.
4. Add `quality.quality_score` with pre-registered weights in `config.yaml` (`pass 0.5`, `score 0.25`, `audit_clean 0.15`, `not tampered 0.10`); report components → verify: `rg -n 'quality_score' benchmarks/docs/SCHEMA-AB.md`.
5. Report `quality_rate` per arm and per task; add `min_quality_gain` to the decision policy → verify: `python3 Tests/test_ab_audit.py`.

**Acceptance:** a green-grade/red-audit run is `quality_pass: false` and cannot `ship`.

## e05s02 — Protected-test edits as a separate failure signal (5 BCP, P0)

**Steps**

1. Split `tampered` into `protected_removed_lines`, `protected_changed_lines` and `protected_added_lines` → verify: `python3 Tests/test_ab_tamper.py`.
2. Keep `tampered = removed > 0 or changed > 0`; added lines are allowed and counted → verify: `python3 Tests/test_ab_tamper.py`.
3. Add `test_tamper` (protected file under `test/` or `*test*`) and `test_tamper_rate` → verify: `python3 Tests/test_ab_tamper.py`.
4. Make `tampered` a hard `reject` reason in the decision policy → verify: `python3 Tests/test_ab_decision.py`.
5. Add tests: delete a test, weaken an assertion, append a test, touch a non-test protected file → verify: `python3 Tests/test_ab_tamper.py`.

**Acceptance:** weakening or deleting a visible test is never a quality pass, even when hidden tests pass.

## e05s03 — One quality table (3 BCP, P1)

**Steps**

1. Add a `quality` block per arm and per task: `pass_rate`, `mean_score`, `audit_clean_rate`, `test_tamper_rate`, `quality_pass_rate` → verify: `rg -n 'quality_pass_rate' benchmarks/docs/SCHEMA-AB.md`.
2. Print one table with those five columns, not separate sections → verify: `python3 Tests/test_ab_quality_report.py`.
3. Add a regression test where pass is 1.0 but quality is 0.0 → verify: `python3 Tests/test_ab_quality_report.py`.

**Acceptance:** no report can show 100% pass while hiding an audit or tamper failure.
