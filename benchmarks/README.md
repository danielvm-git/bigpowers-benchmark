# Outcome A/B benchmark

This directory owns the outcome benchmark that compares a **vanilla** coding agent with
**bigpowers** (and its ablation arms) on hidden-test tasks. It moved here from the bigpowers
repository so bigpowers can stay a skills catalog and this repository can be the scorecard.

## What lives here

```
benchmarks/
  ab/config.yaml          arms, adapters, decision policy
  ab/vsm.yaml             value-stream stage rules
  ab/tasks/<id>/          task.yaml + fixture/ + hidden/ + solution/
  ab/arms/                seed instructions for the arms
  docs/                   schema, task review, harder-task design, Lean VSM
  reports/                curated reports (AB-*.yaml); raw shards are ignored
```

The runner lives in `scripts/`:

```
scripts/run-ab-eval.sh
scripts/ab-sandbox.sh
scripts/lib/ab-*.py
scripts/lib/ab-arm-bigpowers.sh
scripts/lib/ab-sandbox/
```

## Prerequisites

- macOS 14+ or Linux
- `python3` with `PyYAML` (`python3 -m pip install -r requirements.txt`)
- `git`
- `node` 20+ (the tasks use `node:test`)
- Docker, for the `pi-docker` adapter and the no-network grade container
- A pi auth file at `~/.pi/agent/auth.json` (or set `AB_PI_AUTH`)

Start the sandbox once:

```bash
bash scripts/ab-sandbox.sh up
bash scripts/ab-sandbox.sh status
```

## Run

The subject is an **external bigpowers checkout**, not this repository:

```bash
export BIGPOWERS_ROOT=/path/to/bigpowers

# Print the matrix and spend nothing
bash scripts/run-ab-eval.sh --dry-run --bigpowers-root "$BIGPOWERS_ROOT"

# Prove the fixtures are valid without spending agent tokens
bash scripts/run-ab-eval.sh --tasks ab-11 --preflight-only --bigpowers-root "$BIGPOWERS_ROOT"

# One task, both arms, one run (preflight runs first by default)
bash scripts/run-ab-eval.sh --tasks ab-11 --k 1 --bigpowers-root "$BIGPOWERS_ROOT"

# Calibrate task difficulty with vanilla only (k=10 by default)
bash scripts/ab-calibrate.sh --bigpowers-root "$BIGPOWERS_ROOT" --k 10

# Full paired run (subject and runner snapshotted from HEAD)
bash scripts/run-ab-eval.sh --tasks ab-09,ab-11,ab-13 --arms vanilla,bigpowers,bp-core \
  --k 10 --bigpowers-root "$BIGPOWERS_ROOT" --runner-worktree
```

Reports are written to `benchmarks/reports/`:

- `AB-<date>.yaml` — arm summaries, per-task results, delta vs vanilla, Lean views
- `ab-runs-<date>.jsonl` — one record per run (ignored unless pinned)
- `ab-live.jsonl` — live append while a run is in progress (ignored)
- `traces/<task>-<arm>-<run>.jsonl.gz` — agent transcripts (ignored)

## Tests

```bash
python3 Tests/test_ab_eval.py
python3 Tests/test_ab_ablation.py
python3 Tests/test_ab_score.py
python3 Tests/test_ab_tasks.py
python3 Tests/test_ab_vsm.py
python3 Tests/test_ab_waste.py
python3 Tests/test_ab_lean.py
python3 Tests/test_ab_progress.py
python3 Tests/test_ab_sandbox.py
```

## Boundaries

- **Runner root** (`AB_RUNNER_ROOT`) is this repository: it owns tasks, arms, rules and reports.
- **Subject root** (`AB_BP_ROOT`) is the bigpowers checkout under test: it owns `skills/`,
  `scripts/` and `CLAUDE.md`.
- The per-skill micro-benchmark (`run-benchmark`, `specs/benchmarks/<skill>.yaml`) stays in
  bigpowers. It is a regression harness, not an outcome benchmark.
