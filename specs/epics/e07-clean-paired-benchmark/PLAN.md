# e07 — Clean paired benchmark and publication

This is the payoff epic: one clean, pre-registered run that answers the question the benchmark
exists for, with the honesty the Lean work already established.

## e07s01 — Pre-register matrix, sample size and thresholds (3 BCP, P0)

**Steps**

1. Freeze `benchmarks/ab/config.yaml`: arms `vanilla,bigpowers,bp-core` (+ `bp-testguard` only if
   e06 proved it), `k=10`, tasks = the e04 discriminating set, adapter `pi-docker`, model pinned → verify: `python3 Tests/test_preregistration.py`.
2. Write `benchmarks/reports/PREREGISTRATION-<date>.yaml`: tasks, arms, k, image digest, policy hash,
   decision rules and the reason for each threshold → verify: `test -f benchmarks/reports/PREREGISTRATION-*.yaml`.
3. Commit it before the first agent run; the runner records the same hash in the report → verify: `python3 Tests/test_preregistration.py`.
4. State the null hypothesis and the smallest effect worth shipping → verify: `rg -n 'null hypothesis|minimum worthwhile' benchmarks/reports/PREREGISTRATION-*.yaml`.

**Acceptance:** changing the policy after the run is detectable and invalidates the run.

## e07s02 — Run the paired benchmark and ablation (8 BCP, P0)

**Steps**

1. Check out a clean subject at a tagged SHA; run `--preflight-only`; all tasks pass → verify: the preflight table is all PASS.
2. Run `bash scripts/run-ab-eval.sh --tasks <discriminating> --arms vanilla,bigpowers,bp-core --k 10 --adapter pi-docker --bigpowers-root <clean> --json-out ...` → verify: `ab-live.jsonl` grows and `AB-<date>.yaml` is written.
3. Verify `inputs` matches the preregistration (subject SHA, task hashes, config hash, image digest) → verify: `python3 scripts/lib/ab-eval.py --verify-inputs benchmarks/reports/AB-<date>.json`.
4. Report correctness, score, audit, tamper, tokens, cost, lead time, first build, redundant tests and diff size, with mean/median/p90 and bootstrap CIs → verify: `rg -n 'median_|p90_|audit_clean|redundant_test_runs' benchmarks/reports/AB-<date>.yaml`.
5. Emit the decision verdict; if `reject` or `inconclusive`, record it and do not spin the result → verify: `rg -n 'verdict:' benchmarks/reports/AB-<date>.yaml`.

**Acceptance:** a complete report exists for the pre-registered matrix; no run is discarded after the fact.

## e07s03 — Publish the report, human summary and receipts (3 BCP, P1)

**Steps**

1. Write `benchmarks/reports/LATEST.md`: question, matrix, result table, verdict, threats to validity
   and the exact commands to reproduce → verify: `test -f benchmarks/reports/LATEST.md`.
2. Add a `benchmark` block to `specs/receipts.json`: run date, subject SHA, image digest, k, verdict,
   pass/quality deltas with CIs → verify: `python3 Tests/test_receipts.py`.
3. Link the report from `README.md` and `benchmarks/README.md` → verify: `rg -n 'LATEST.md' README.md benchmarks/README.md`.
4. Publish the null result if that is what the data says; no "best of" selection → verify: `rg -ni 'null result|inconclusive' benchmarks/reports/LATEST.md`.

**Acceptance:** a reader can reproduce the run and see the verdict without reading Python.
