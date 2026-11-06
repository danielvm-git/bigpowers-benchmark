# e08 — Benchmark reliability tracked separately

A benchmark that fails for infrastructure reasons is not a benchmark. This epic keeps reliability
visible and stops bug-record drift.

## e08s01 — Reconcile the e58 flake and #183/#185/#167 (5 BCP, P1)

**Steps**

1. Port `specs/bugs/registry.yaml` and the benchmark-related BUG files into this repo → verify: `test -f specs/bugs/registry.yaml && test -f specs/bugs/BUG-2026-11-03-story-verify-e58-eval-flake.md`.
2. Reconcile statuses and links for the e58 flake and #183, #185, #167: one entry per bug, one file per entry, links to the issue and the fixing commit → verify: `bash scripts/check-bug-registry.sh`.
3. Add `scripts/check-bug-registry.sh`: duplicate IDs, missing files, file without entry, status mismatch, open bug with no owner → verify: `bash tests/test_check_bug_registry.sh`.
4. Run it in preflight and in the verification gate → verify: `rg -n 'check-bug-registry' scripts/run-benchmark-tests.sh`.
5. For the e58 flake, require the e02s04 stress evidence before marking fixed; otherwise keep it open with the named test and the new diagnostics → verify: `rg -n 'status: (fixed|open)' specs/bugs/BUG-2026-11-03-story-verify-e58-eval-flake.md`.

**Acceptance:** a bug cannot be "fixed" in code while its record says open, or vice versa.

## e08s02 — Reliability block in every report (3 BCP, P1)

**Steps**

1. Add `reliability` per arm: `agent_error_rate`, `timeout_rate`, `preflight_failures`,
   `infra_errors`, `runs_discarded`, `flake_rate` → verify: `rg -n 'reliability:' benchmarks/docs/SCHEMA-AB.md`.
2. Count only infrastructure causes (Docker, timeout, provider 5xx, preflight) — never a failed task → verify: `python3 Tests/test_ab_reliability.py`.
3. Keep reliability out of `quality_score`; the decision policy may `reject` on reliability thresholds
   but must name them separately → verify: `python3 Tests/test_ab_decision.py`.
4. Print the reliability table next to quality → verify: `python3 Tests/test_ab_reliability.py`.

**Acceptance:** a run with 20% infrastructure failures cannot masquerade as a quality drop or a clean run.
