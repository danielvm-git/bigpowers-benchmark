# e01s04 — Remove the A/B assets from bigpowers with a pointer and changelog
<!-- story: e01s04 -->

**type:** feat
**risk:** P1
**context:** infra
**BCPs:** 3

## Context

Once this repo proves parity, bigpowers must stop shipping the A/B harness. The split is:

| Stays in bigpowers | Moves here |
|---|---|
| `skills/run-benchmark` and `specs/benchmarks/*.yaml` (skill micro-benchmark) | `specs/benchmarks/ab/**` |
| `skills/evolve-skill` | `scripts/run-ab-eval.sh`, `scripts/ab-sandbox.sh` |
| `specs/benchmarks/golden/**` and the golden suite | `scripts/lib/ab-*.py`, `scripts/lib/ab-arm-bigpowers.sh` |
| `specs/benchmarks/SCHEMA.md` skill section | A/B section → `benchmarks/docs/SCHEMA-AB.md` |
| — | `TASK-REVIEW`, `HARDER-TASKS`, `LEAN-VSM`, `AB-*` reports |

A one-release redirect shim keeps direct CLI users from a silent break: `scripts/run-ab-eval.sh`
prints the new command and exits 2. Remove the shim at the next major.

## Steps

1. Replace `scripts/run-ab-eval.sh` with a shim that prints the new repo and command, exits 2 → verify: `bash scripts/run-ab-eval.sh; test $? -eq 2`.
2. Delete `scripts/ab-sandbox.sh`, `scripts/lib/ab-*.py`, `scripts/lib/ab-arm-bigpowers.sh`, `tests/test_ab_eval.py`, `tests/test_ab_score.py` → verify: `test ! -e scripts/lib/ab-eval.py && test ! -e tests/test_ab_eval.py`.
3. Delete `specs/benchmarks/ab/**`, `specs/benchmarks/reports/AB-*`, `specs/benchmarks/reports/ab-runs-*`, and the three benchmark docs → verify: `test ! -d specs/benchmarks/ab && test -z "$(find specs/benchmarks/reports -name 'AB-*' -o -name 'ab-runs-*')"`.
4. Update `specs/benchmarks/SCHEMA.md`: keep the skill schema, replace the A/B sections with a pointer → verify: `rg -n 'bigpowers-benchmark' specs/benchmarks/SCHEMA.md`.
5. Update `run-benchmark/SKILL.md` and `evolve-skill/SKILL.md` to say outcome A/B numbers come from this repo → verify: `rg -n 'bigpowers-benchmark' skills/run-benchmark/SKILL.md skills/evolve-skill/SKILL.md`.
6. Rewrite e58 story verify directives that call the deleted runner; mark the e58 epic as moved → verify: `rg -n 'tests/test_ab_eval.py|run-ab-eval.sh --dry-run' specs/epics specs/execution-status.yaml || true`.
7. Add `specs/benchmarks/README.md` pointer and a `README.md` section; commit with `feat(benchmark)!:` + `BREAKING CHANGE:` footer → verify: `git log -1 --format=%B | rg 'BREAKING CHANGE'`.
8. Run the bigpowers gates → verify: `npm run compliance && bash scripts/run-benchmark-tests.sh`.

## Verification Script (Step-by-Step)

1. On a clean bigpowers branch, `rg -n 'ab-eval|ab-sandbox|ab_metrics|ab_vsm|ab_waste'` finds only the shim, docs and changelog.
2. `npm run compliance` passes.
3. `bash scripts/run-benchmark-tests.sh` passes.
4. The shim names this repo and the new command.

## Out of scope

- Removing the skill micro-benchmark, `run-benchmark` or `evolve-skill`.
- Removing the golden suite.

## Risks

- e58 story verify commands will fail if not rewritten; the story is not done until the suite is green.
- `scripts/lib/atomic_write.py` and `python-env.sh` may be used by other bigpowers scripts: grep before deleting.
- A hard removal without a shim breaks CI in downstream repos; keep the shim for one release.

## Acceptance Criteria

- [ ] bigpowers has no A/B runner, task suite or A/B reports.
- [ ] bigpowers README, SCHEMA and skills point here.
- [ ] bigpowers compliance and verification gates pass.
- [ ] The shim is the only executable A/B path left, and it exits 2.
