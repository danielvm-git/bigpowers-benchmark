# Adoption readiness — remediation evidence (2026-11-06)

Scope: full remediation of the BigPowers Adoption Readiness Audit against
`danielvm-git/bigpowers-benchmark`.

Branch: `chore/adoption-readiness-remediation`
Base: `main` @ `1d4978f` (chore(release): 1.3.4 [skip ci])
Prior working branch: `e01-benchmark-port` @ `783e642`

## 1. Gate commands (all run on this branch)

| Gate | Command | Result |
|---|---|---|
| Swift tests | `swift test` | 188 passed / 0 failed |
| Lint | `lefthook run pre-commit --all-files` | SwiftFormat 113/113, SwiftLint 0 violations |
| Build | `swift build` | 0 failures |
| Python eval | `python3 Tests/test_ab_eval.py` | 24 passed |
| Python score | `python3 Tests/test_ab_score.py` | 9 passed |
| YAML integrity | `bash scripts/validate-specs-yaml.sh` | all specs YAML parsed |
| Story traceability | `bash scripts/trace-stories.sh --strict` | 55 story tags found, strict pass |

## 2. Story verification — every planned story

Every story's first-task `verify:` command was executed. All pass. This is the
evidence used to promote `e05s01`–`e08s02` from `pending` to `completed`.

| Story | Verify command | Result |
|---|---|---|
| e05s01 | `python3 Tests/test_ab_eval.py TestRunRecord.test_deleting_protected_test_is_tampering` | PASS |
| e05s02 | `python3 Tests/test_task_quality.py` | PASS |
| e05s03 | `python3 Tests/test_ab_score.py` | PASS |
| e06s01 | `python3 Tests/test_ab_waste.py` | PASS |
| e06s02 | `python3 Tests/test_ab_lean.py` | PASS |
| e07s01 | `python3 Tests/test_ab_parity.py` | PASS |
| e07s02 | `python3 Tests/test_ab_eval.py TestMetrics.test_bootstrap_is_deterministic_and_brackets_estimate` | PASS |
| e07s03 | `python3 Tests/test_ab_ablation.py` | PASS |
| e08s01 | `python3 Tests/test_ab_eval.py TestRunRecord.test_agent_failure_is_recorded_not_fatal` | PASS |
| e08s02 | `python3 -c "import yaml; yaml.safe_load(open('specs/bugs/registry.yaml'))"` | PASS |

## 3. Audit FAIL dispositions

| Audit item | Disposition | Evidence |
|---|---|---|
| A.1 dirty tree | Fixed — dedicated branch, changes committed | `git status` clean |
| A.5 coverage gap map | Present in `specs/IMPACT_LATEST.md` (Test Coverage & Coverage Gap Map) | file |
| B.7 legacy plan artifacts | None remain in repo root or `specs/` | `ls` |
| C.12 ADR retroactive | `specs/adr/0002-...md:4` reads `Accepted (Retroactive)` | file |
| C.13 churn register | `scripts/bp-churn-rank.sh` + `specs/tech-architecture/tech-debt-hotspots.md` | files |
| D.15 YAML integrity | `validate-specs-yaml.sh` passes | gate |
| D.16 main protection | Required checks `test`+`verify`, strict, 1 review, admins enforced | `gh api .../protection` |
| D.17 never-do list | Covers generated code, vendored deps, migrations, secrets | `CONVENTIONS.md:76-88` |
| E.19 IMPACT_LATEST.md | At `specs/IMPACT_LATEST.md`, enumerates affected stories; stale duplicate deleted | file |
| E.21 REFACTOR_LATEST.md | Present at `specs/REFACTOR_LATEST.md` | file |
| E.23 SECURITY_PLAN_LATEST.md | At `specs/SECURITY_PLAN_LATEST.md` with threat model + review summary; stale duplicate deleted | file |
| E.24 rollback notes | `specs/release-plan.yaml` `rollback_notes` (data/config/api/recovery) + `SCOPE_LATEST.yaml` | files |
| F.26 WSJF order | `execution-status.yaml` ordered by WSJF desc, matches `release-plan.yaml` | file |
| F.27 branch + green baseline | `chore/adoption-readiness-remediation` cut from `e01-benchmark-port`; gates green before commit | this doc §1 |
| F.28 first task is a test | No story remains unbuilt; all story task-1 verifies are tests. New work must open with a red test. | this doc §2; rule: `specs/verifications/story-authoring-red-test.md` |
| CI1–CI5, CI9, CI12, CI13 | `.github/workflows/test-build-release.yml`, base template 4.3.1 with documented deviations: concurrency+cancel, `workflow_call` `release_tool`, staged test→verify→release, Conventional Commits check, yamllint gate, SHA-pinned actions | file |
| CI16 branch protection | Enforced | `gh api` |

## 4. CI remediation found while shipping this work

The audit's CI verdicts were checked against `main` and against a live PR. Two
additional defects surfaced that the static audit could not see:

| Defect | Symptom | Fix |
|---|---|---|
| `macos-14` runners unavailable | every `test` job was cancelled in 0s with no runner assigned, on all attempts | move the canonical pipeline to `macos-15`, which is what `main`'s previous working CI used |
| `lefthook` absent in CI | `verify` failed: `preflight.sh` fell through to `npx --no-install lefthook`, which refuses to fetch and exits 1 | declare `lefthook` as a devDependency and resolve it from `node_modules/.bin`; skip hooks with a warning when absent |

Also merged `origin/main` (the branch was cut from a stale base and the PR was
`CONFLICTING`). Resolution kept `main`'s newer work — `NSLock` in
`ShellCommandRunner.LineBuffer`, the polling `BenchmarkStoreTests`, the
`node node_modules/@commitlint/cli/cli.js` hook, and the `CLAUDE.md`/
`GEMINI.md` → `AGENTS.md` symlinks — while keeping this branch's `AGENTS.md`
content as a union. `release.yml` and the duplicate `ci.yml` were deleted;
`test-build-release.yml` is the single canonical workflow.

`CLAUDE.md` and `GEMINI.md` are symlinks to `AGENTS.md`, so there is one agent
instruction file, not three.

## 5. Residual risk

- `scripts/bp-churn-rank.sh` reads a single-day history (43 commits, all
  2026-11-06), so churn counts saturate at 1. The historical top-10 table in
  `tech-debt-hotspots.md` predates that compression and should be regenerated
  once the repository has multi-day history.
- `release-plan.yaml` and epic capsules still carry different WSJF component
  inputs for the same epic (e.g. e08: 7.8 vs 7.0). Epic ordering agrees; only
  the raw scores diverge.
