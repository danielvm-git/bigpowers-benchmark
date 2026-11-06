# e01s02 — Point the runner at an external bigpowers checkout
<!-- story: e01s02 -->

**type:** refactor
**risk:** P0
**context:** infra
**BCPs:** 5

## Context

In bigpowers, `REPO_ROOT` was both the runner and the subject: `AB_BP_ROOT` pointed at the repo
that held `scripts/lib/ab-eval.py`. After the move, the runner lives here and the subject is an
external bigpowers checkout. Keeping the two concepts fused would silently benchmark this app's
own repo. This story separates them.

New contract:

| Variable | Meaning |
|---|---|
| `AB_RUNNER_ROOT` | this repo; holds `benchmarks/` and `scripts/` |
| `AB_BP_ROOT` | the bigpowers checkout under test; holds `skills/`, `scripts/`, `CLAUDE.md` |
| `--bigpowers-root` | CLI flag that sets `AB_BP_ROOT` |
| `--runner-root` | optional override; defaults to the repo containing the script |

## Steps

1. Add `--bigpowers-root` and `--runner-root` to `ab-eval.py`; require the former unless `--dry-run` is used with an explicit env value → verify: `python3 scripts/lib/ab-eval.py --help | rg -- '--bigpowers-root|--runner-root'`.
2. Replace `REPO_ROOT` uses in `ab_report.py` and `ab_lean.py` with `runner_root()`; `bigpowers_sha()` reads `AB_BP_ROOT` → verify: `python3 Tests/test_ab_eval.py`.
3. Make `run-ab-eval.sh` resolve `AB_BP_ROOT` from the flag/env and export it before exec → verify: `bash scripts/run-ab-eval.sh --dry-run --bigpowers-root /tmp/bp-subject` prints the subject path.
4. Make `ab-arm-bigpowers.sh` fail with exit 2 when `AB_BP_ROOT/skills` is missing → verify: `AB_BP_ROOT=/tmp/empty bash scripts/lib/ab-arm-bigpowers.sh; test $? -eq 2`.
5. Read `vsm.yaml` and the arm seed from `AB_RUNNER_ROOT`, never from the subject → verify: `rg -n 'AB_RUNNER_ROOT|vsm.yaml' scripts/lib/ab-eval.py scripts/lib/ab_vsm.py`.
6. Record both SHAs in report meta: `bigpowers_sha` (subject) and `runner_sha` (this repo) → verify: `python3 Tests/test_ab_eval.py` and a smoke report contains both keys.

## Verification Script (Step-by-Step)

1. Clone bigpowers to `/tmp/bp-subject`.
2. `bash scripts/run-ab-eval.sh --dry-run --bigpowers-root /tmp/bp-subject` and confirm the banner names that path.
3. Set `AB_BP_ROOT=/tmp/empty` and run `ab-arm-bigpowers.sh`; expect a clear exit 2.
4. Confirm a smoke report has `bigpowers_sha` != `runner_sha` when the repos differ.

## Out of scope

- Dirty-tree enforcement (e02s01).
- Immutable worktrees (e02s03).

## Risks

- Hidden uses of `REPO_ROOT` in `ab_vsm.py` / `ab_waste.py` may read the wrong tree. Grep all `REPO_ROOT` before editing.
- `ab-arm-bigpowers.sh` copies `$AB_BP_ROOT/scripts` into the workdir; that is intentional and must keep working.

## Acceptance Criteria

- [ ] A dry run names the external subject.
- [ ] A missing subject skills directory is a hard config error.
- [ ] Reports carry both SHAs.
- [ ] The task suite and arm seed resolve from the runner repo.
