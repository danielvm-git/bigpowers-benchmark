# e01s05 — Cutover parity test: same report keys, same task files, same verdict
<!-- story: e01s05 -->

**type:** test
**risk:** P0
**context:** infra
**BCPs:** 3

## Context

A move is only safe if the new runner produces the same observable result as the old one. This
story pins a parity fixture from the bigpowers runner before e01s04 deletes it, then asserts the
new runner matches on three axes:

1. **Task tree** — every `task.yaml`, `fixture/`, `hidden/`, `solution/` and `audit/` byte-identical.
2. **Report schema** — every key in the old `AB-*.yaml` exists in the new report; new keys are additive.
3. **Dry-run matrix** — same tasks × arms lines, order-insensitive.

## Steps

1. Add `benchmarks/ab/TASKS.sha256`: sorted `sha256sum` of every task file from the source commit → verify: `sha256sum -c benchmarks/ab/TASKS.sha256`.
2. Add `Tests/fixtures/ab-report-2026-11-03.yaml` and `ab-runs-2026-11-03.jsonl` pinned from the source → verify: `test -f Tests/fixtures/ab-report-2026-11-03.yaml`.
3. Add `tests/test_ab_parity.py` with `assert_keys_subset(old, new)` recursive on dicts → verify: `python3 Tests/test_ab_parity.py`.
4. Add a dry-run matrix comparison: normalize each line to `task arm setup`, sort, diff → verify: `python3 Tests/test_ab_parity.py`.
5. Add a JSON/YAML equivalence test: for a fake run, `yaml.safe_load(AB-*.yaml) == json.load(AB-*.json)` → verify: `python3 Tests/test_ab_parity.py`.
6. Wire the parity test into `scripts/run-benchmark-tests.sh` → verify: `rg -n 'test_ab_parity' scripts/run-benchmark-tests.sh`.

## Verification Script (Step-by-Step)

1. `sha256sum -c benchmarks/ab/TASKS.sha256` is clean.
2. `python3 Tests/test_ab_parity.py` exits 0.
3. Deliberately rename a key in a copy of the new report; the parity test fails.
4. Deliberately edit a task fixture; the hash check fails.

## Out of scope

- Comparing live agent outcomes (that is e07).
- Re-running the old harness after e01s04 deletes it.

## Risks

- Exporters reorder YAML keys: compare dicts, not text.
- The old report contains `&id001` anchors; load with a real YAML parser.
- Fixture paths in the report are absolute temp paths; normalize before comparing.

## Acceptance Criteria

- [ ] The task tree hash matches the source.
- [ ] Every old report key exists in the new report.
- [ ] Dry-run matrices are identical.
- [ ] The parity test runs in the verification gate.
