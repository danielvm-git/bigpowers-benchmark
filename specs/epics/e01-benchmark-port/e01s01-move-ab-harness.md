# e01s01 — Move A/B harness, tasks and reports into benchmarks/
<!-- story: e01s01 -->

**type:** refactor
**risk:** P0
**context:** infra
**BCPs:** 8

## Context

The A/B harness currently lives in bigpowers under `specs/benchmarks/ab/`, `scripts/run-ab-eval.sh`,
`scripts/ab-sandbox.sh` and `scripts/lib/ab-*.py`. This story moves it into this repository without
changing behavior. The move is deliberately path-stable in behavior: the same CLI, the same report
keys, the same task files. Only the repository that hosts the runner changes.

Target layout:

```
benchmarks/
  README.md
  ab/config.yaml
  ab/vsm.yaml
  ab/tasks/**
  ab/arms/**
  docs/SCHEMA-AB.md
  docs/TASK-REVIEW.md
  docs/HARDER-TASKS.md
  docs/LEAN-VSM.md
  reports/                 # canonical, pinned reports only
scripts/
  run-ab-eval.sh
  ab-sandbox.sh
  lib/ab-eval.py
  lib/ab_report.py
  lib/ab_metrics.py
  lib/ab_vsm.py
  lib/ab_waste.py
  lib/ab_lean.py
  lib/ab_progress.py
  lib/ab-arm-bigpowers.sh
  lib/python-env.sh
  lib/atomic_write.py
tests/
  test_ab_eval.py
  test_ab_score.py
```

## Steps

1. Create `benchmarks/ab/` and copy `specs/benchmarks/ab/{config.yaml,vsm.yaml,tasks,arms}` verbatim → verify: `diff -rq <bigpowers>/specs/benchmarks/ab benchmarks/ab --exclude reports` prints nothing.
2. Create `benchmarks/docs/` and move the A/B-only docs: `SCHEMA.md` A/B sections, `TASK-REVIEW_LATEST.md`, `HARDER-TASKS_LATEST.md`, `LEAN-VSM_LATEST.md` → verify: `test -f benchmarks/docs/SCHEMA-AB.md && test -f benchmarks/docs/TASK-REVIEW.md && test -f benchmarks/docs/LEAN-VSM.md`.
3. Copy the runner: `scripts/run-ab-eval.sh`, `scripts/ab-sandbox.sh`, `scripts/lib/ab-*.py`, `scripts/lib/ab-arm-bigpowers.sh`, `scripts/lib/python-env.sh`, `scripts/lib/atomic_write.py`, `scripts/ab-sandbox/` → verify: `bash -n scripts/run-ab-eval.sh && python3 -m py_compile scripts/lib/ab-*.py`.
4. Copy the eval tests: `tests/test_ab_eval.py`, `tests/test_ab_score.py` → verify: `python3 Tests/test_ab_eval.py`.
5. Change `ab-eval.py` constants: `BENCH_DIR = REPO_ROOT / "benchmarks"`, `REPORTS_DIR = BENCH_DIR / "reports"`, `DEFAULT_CONFIG = BENCH_DIR / "ab" / "config.yaml"`, `DEFAULT_TASKS_DIR = BENCH_DIR / "ab" / "tasks"`; keep `REPO_ROOT` as the runner repo → verify: `python3 Tests/test_ab_eval.py` still green.
6. Update `AGENTS.md`, `README.md`, `CONVENTIONS.md` commands to the new path and add prerequisites (python3, docker, node, git) → verify: `rg -n "run-ab-eval|benchmarks/reports" README.md AGENTS.md CONVENTIONS.md`.
7. Add `benchmarks/reports/.gitignore` for `ab-live.jsonl`, `traces/`, raw `ab-runs-*.jsonl`; pin only curated `AB-*.yaml` + `.json` → verify: `git check-ignore benchmarks/reports/ab-live.jsonl`.

## Verification Script (Step-by-Step)

1. `bash scripts/run-ab-eval.sh --dry-run --bigpowers-root /path/to/bigpowers` prints a task × arm matrix.
2. `python3 Tests/test_ab_eval.py` exits 0.
3. `git status --short` shows only intended moves.

## Out of scope

- Changing task prompts, graders or hidden tests.
- Rewriting any Python module.
- No app code in this story.

## Risks

- Import order: `ab_lean` imports `ab_report` lazily; moving files can create circular imports. The test suite catches it.
- `atomic_write.py` and `python-env.sh` may be shared with bigpowers-only scripts; copy, don't move, until e01s04 proves no other caller.

## Acceptance Criteria

- [ ] The task suite is byte-identical to the source.
- [ ] The runner starts from `benchmarks/`.
- [ ] The eval suite passes from the new location.
- [ ] No behavior change is visible in `--dry-run` output.
