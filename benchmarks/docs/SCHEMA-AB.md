# A/B Benchmark Schema

This repository owns the **outcome A/B benchmark**. The per-skill micro-benchmark
(`specs/benchmarks/<skill>.yaml` and the `run-benchmark` skill) stays in the bigpowers
repository; its schema is summarized below only so the two are not confused.

## Skill micro-benchmark schema (owned by bigpowers)

`pass@k = sum(weight × pass_rate per scenario) / sum(all weights)`; see the bigpowers
`specs/benchmarks/SCHEMA.md` for the full v2 schema.

## Full schema (v2)

```yaml
skill: <skill-name>
version: "2"                 # v2 adds split, runs, with/without delta
runs: 3                      # runs per scenario for statistical significance (default 3)
scenarios:
  - id: s01
    name: "short description"
    split: train | validation # train = iteration guidance; validation = authoritative
    prompt: |
      "..."
    grader:
      type: code | rubric
      command: "bash -c '...'"   # code grader: exit 0 = PASS
      criteria:                  # rubric grader: ≥ 80% yes = PASS
        - "The output contains X"
    weight: 1.0              # contribution to pass@k (default 1.0)
```

## pass@k calculation

`pass@k = sum(weight × pass_rate per scenario) / sum(all weights)` where `pass_rate = passes / runs`.

Calculated separately for train/validation splits and with/without-skill modes.
Delta `Δ = pass@k_with − pass@k_without` isolates the skill's contribution. Negative delta = regression.

`run-benchmark.sh` runs no agent, so it cannot measure the without-skill arm. Since e58s01 it
reports that arm as `null` and prints `UNMEASURED` (it used to force it to 0, which made every
delta look positive). Real with/without numbers come from the A/B runner below.

## A/B outcome eval (e58s01)

`bash scripts/run-ab-eval.sh` runs the same tasks with and without bigpowers through a real
agent CLI and grades only the outcome. It is advisory: exit 0 after a run, 2 on config errors.

## Reproducibility inputs

Every report carries an `inputs` block and a top-level `input_digest`:

```yaml
inputs:
  schema: 1
  subject: {path, sha, ref, dirty, dirty_diff_sha}
  runner:  {root, sha}
  config:  {path, sha256}
  image:   {name, id}
  tasks:
    ab-11: {task_yaml, fixture, hidden, audit, solution}
```

- A dirty subject aborts with exit 2 unless `--allow-dirty` is passed. The dirty state and a
  hash of the diff are still recorded.
- A clean subject is snapshotted with `git worktree add --detach HEAD`; the report records the
  stable `subject.path` plus the temporary `subject.worktree_path`.
- `--allow-dirty` copies the working tree (including `.git`) instead of using HEAD, so provenance
  still sees the dirty state.
- `--runner-worktree` snapshots this repository's `benchmarks/` and `scripts/` the same way; a
  dirty runner is copied and recorded, never silently used in place.
- `--verify-inputs <report.yaml|json>` recomputes the block and exits 2 on any difference.
  Worktree paths are ignored because they change every run; SHA and tree hashes are not.
- `--json-out <path>` writes the same report plus the raw records as JSON for the app.

## Tail statistics

`arms_summary` carries all three views for `duration_s`, `cost_usd`, `input_tokens` and
`diff_lines`:

- `mean_*` — keeps the old table compatible;
- `median_*` — the typical run;
- `p90_*` — the tail a single timeout or rework-heavy run creates.

Percentiles are nearest-rank; `None` values are ignored, never coerced to zero. `print_summary`
prints a second table with the tail columns so a slow outlier cannot hide behind a mean.

## Task calibration

A task can only show an arm delta when vanilla sometimes fails it. Calibration runs vanilla only
(no bigpowers arm) and classifies each task:

| Vanilla pass rate | Band | Meaning |
|---|---|---|
| `> 0.80` | `too_easy` | saturated; revise or retire |
| `0.20 – 0.80` | `discriminating` | usable |
| `< 0.20` | `too_hard` | unusable as written |
| no runs | `unknown` | not calibrated |

```bash
bash scripts/ab-calibrate.sh --bigpowers-root /path/to/bigpowers --k 10
```

The report is `benchmarks/reports/CALIBRATION-<date>.yaml`: per task pass rate, mean hidden score,
timeouts, agent errors and band, plus band counts. Results are cached by task content, adapter,
model, k and arm setup in `benchmarks/ab/calibration-cache.json` (gitignored). `--no-calibration-cache`
forces a fresh run.

## Decision policy

The policy is data in `benchmarks/ab/config.yaml`. It is hashed together with the arms, tasks,
k, adapter and model into `preregistration_sha` **before round 1**, and the hash is stored in the
report and in `inputs.decision`. A post-hoc policy edit is therefore an inputs mismatch.

```yaml
decision_policy:
  confidence: 0.95
  min_pass_gain: 0.05
  min_score_gain: 0.02
  max_cost_multiplier: 1.50
  max_lead_time_multiplier: 1.50
  max_tamper_rate: 0.00
  min_audit_clean_rate: 1.00
  min_quality_gain: 0.05
  max_agent_error_rate: 0.05
  min_discriminating_tasks: 0   # e04 raises this to 7
```

Verdict order:

1. **reject** — tamper, audit or reliability safety threshold fails.
2. **reject** — pass-rate regression with the CI upper bound at or below zero.
3. **inconclusive** — fewer tasks than the calibration policy requires.
4. **reject** — cost or lead time exceeds its multiplier without the minimum pass/score gain.
5. **ship** — the lower 95% CI bound clears `min_pass_gain` or `min_score_gain`; warnings note a
   high cost or lead time that was accepted for a real gain.
6. **inconclusive** — the CI is too wide, missing, or does not clear the minimum.

`--fail-on-decision` exits 1 only on `reject`; `inconclusive` stays advisory.

## Task authoring

Hard tasks declare their spec style and map every behaviour to a hidden test:

```yaml
spec_style: behavioural
requirements:
  - id: expiry-boundary
    behaviour: "at exactly 15 minutes the hold is expired"
    hidden: "a hold expires exactly at 15 minutes"
```

- `spec_style: behavioural` — the prompt and fixture spec describe observable behaviour, error
  messages and public API shapes; no formulas, helper calls or internal wiring.
- `requirements` — each item names the hidden test that proves it. A requirement without a
  matching hidden test fails `Tests/test_task_quality.py`.
- Every hard task has boundary, null/missing-input and regression coverage in
  `hidden/test-hidden/`.

## Pristine-fixture preflight

Before round 1, every selected task is proven inside the adapter's `grade_wrapper` (or on the
host when no wrapper exists):

1. every arm setup exits 0;
2. the visible tests match the task's declared expectation;
3. `fixture + hidden` fails `grade`;
4. `solution + hidden` passes `grade`, and `score` is 1.0 when present.

```yaml
preflight:
  visible_tests: pass   # pass | fail (red-suite tasks declare fail)
  command: npm test     # default: npm test when fixture/package.json exists
```

- `--preflight-only` runs the checks and exits without an agent.
- Preflight is on by default; `--skip-preflight` is a debug escape hatch.
- Results are cached by task content, setup, grade, adapter and image; the cache lives at
  `benchmarks/ab/preflight-cache.json` and is gitignored.

```bash
bash scripts/run-ab-eval.sh --dry-run                       # print the matrix, spend nothing
bash scripts/run-ab-eval.sh --tasks ab-01 --k 1             # one task, both arms, default adapter (pi)
bash scripts/run-ab-eval.sh --adapter opencode              # opencode CLI, default opencode-go/deepseek-v4-pro
bash scripts/run-ab-eval.sh --adapter claude --model <m>    # Claude Code
bash scripts/run-ab-eval.sh --adapter gemini --model <m>    # another harness
```

- **Config:** `benchmarks/ab/config.yaml` — `arms` (setup commands) and `adapters`
  (command templates; the prompt is in `$AB_PROMPT`). The `claude` adapter runs with
  `--setting-sources project --strict-mcp-config`, so user-level skills (including a global
  bigpowers install), CLAUDE.md, hooks, plugins and MCP servers do not leak into either arm.
- **Tasks:** `benchmarks/ab/tasks/<id>/` with `task.yaml` (`id`, `prompt`, `protected`,
  `grade`, `timeout_s`, optional `score`), `fixture/` (what the agent sees), `hidden/` (copied in only after the
  agent exits) and `solution/` (reference; the unit tests check fixture fails, solution passes).
  Prompts never name bigpowers. A `grade` command must name test **files/globs**
  (`node --test test/*.test.js`): on node 24 a bare `node --test test/` resolves the directory as a
  module path and exits 1, which silently pins that task's pass rate at 0.
- **Default adapter (e58s07):** `pi-docker` — pi inside a fresh `bp-ab-agent` container per run.
  Start the sandbox once with `bash scripts/ab-sandbox.sh up` (`down`, `status`); it builds two
  images pinned by digest (`bp-ab-agent:pi-1.5.0`, `bp-ab-proxy:tinyproxy-1`), creates the
  internal network `bp-ab-internal` (no route to the internet) and starts the proxy, which allows
  `opencode.ai` and nothing else. The container mounts only the run's workdir and `$AB_HOME` (it
  gets a copy of your pi `auth.json`), runs as uid 1000 with `--cpus`/`--memory`/`--pids-limit`
  limits, and an in-container `timeout "$AB_TIMEOUT"` stops the agent before the runner's own
  timeout. `AB_TIMEOUT` is the task's `timeout_s` minus 30 s. The host `pi` adapter remains for
  quick local checks: it can read this repo and reach any website, so its numbers are not comparable.
- **grade_wrapper (e58s07):** an adapter may declare `grade_wrapper`, a command template with
  `$AB_CMD`. The runner then runs the task's `grade` and `score` through it, so agent-written code
  never executes on the host. `pi-docker` grades in a container with `--network none`.
- **Default adapter (e58s06):** `pi` (host) with model `opencode-go/deepseek-v4.1-flash` and parser
  `pi-json` (sums assistant `message_end` usage; a `stopReason` of `error`/`aborted` or an aborted
  run marks an agent error). Isolation: `HOME` and `PI_CODING_AGENT_DIR` point inside `$AB_HOME`,
  which gets only a copy of the user's pi `auth.json`; user settings and packages (which may load
  bigpowers globally) never load. `--approve` lets the bigpowers arms' `.agents/skills` load.
- **Isolation on the host:** each run gets a fresh empty `$AB_HOME`; the `opencode` adapter points
  `HOME` and `XDG_CONFIG_HOME` at it (global skills, AGENTS.md and plugins never load) and keeps
  `XDG_DATA_HOME` for credentials. Adapter stdin is always closed. An adapter may set
  `default_model`, used when `--model` is absent and recorded in the report.
- **Per run:** `pass`, `tampered` (an original line of a `protected` file was removed or changed,
  or the file was deleted), `protected_lines_added` (lines added to protected files, e.g. new
  tests from a TDD arm: counted, not flagged, since hidden tests decide `pass`), `diff_lines`, `duration_s`,
  `agent_error`, plus `cost_usd`, `input_tokens`, `output_tokens`, `turns` from the adapter's
  parser (`scripts/lib/ab_metrics.py`): `claude-json` (one result object) or `opencode-jsonl`
  (sums `step_finish` events; an `error` event marks an agent error).
- **Partial credit (e58s03):** a task's optional `score` command runs **hidden tests only**
  (`node --test --test-reporter=tap test-hidden/*.test.js`; piped output is not TAP without the
  flag). `score` = passed / (passed + failed + cancelled) over every `# pass` / `# fail` summary,
  or `null`. Tests an agent adds to visible files cannot raise it.
- **Suite:** `ab-01`–`ab-03` (written for e58s01) and `ab-04`–`ab-08`, ported from the legacy
  bigpowers-benchmark T01–T05 with neutral prompts, protected visible tests and hidden tests.
  Hard tasks with `score` (e58s03): `ab-11` (ledger rounding bug from a user report, two
  trap fixes; fixture 11/18) and `ab-13` (split a 240-line module, oracle on ~420 seeded orders
  plus structure checks; fixture 15/18). Candidates: `HARDER-TASKS_LATEST.md`.
- **Ablation arms (e58s04):** `ab-arm-bigpowers.sh` takes `AB_BP_SKILLS` (`all` | `none` | comma
  list) and `AB_BP_SEED` (seed path or `none`). Config arms: `bp-core` (seed + 6 named skills),
  `bp-seed` (seed only), `bp-skills` (all skills, no seed), `tdd-line` (3-line TDD rule, no skills).
- **Live progress (e58s05):** runs go round-robin (run 1 of every task and arm, then run 2, …).
  Each record is appended to `<out>/ab-live.jsonl` as it finishes, and each agent transcript is
  saved to `<out>/traces/<task>-<arm>-<run>.jsonl.gz`. Watch one or many shards with
  `python3 scripts/lib/ab_progress.py <out-dir>... [--watch 600]`: runs, pass, score, cost and
  errors per task and arm, deltas against vanilla with CIs, and their evolution by run index.
- **Value stream map (e58s08):** every record has a `vsm` block for pi transcripts (`null` for
  other parsers): `lead_time_s`, `time_to_first_build_s`, `switches`, `sequence` and
  `stages.<plan|design|build|test|deploy|maintain|wrap-up>` = `{s, cost_usd, output_tokens, turns}`.
  Each model turn, from its start to the next turn's start, goes to the stage of the action it takes.
  The rules are in `benchmarks/ab/vsm.yaml`. Map saved transcripts with
  `python3 scripts/lib/ab_vsm.py <traces>/*.jsonl.gz`. Rationale: `LEAN-VSM_LATEST.md`.
- **Waste metrics (e58s09):** each run's final patch is saved as `<out>/traces/<id>.patch.gz` and the
  record gets a `waste` block (`scripts/lib/ab_waste.py`). Patch metrics, any adapter:
  `product/test/doc/plan_lines`, `solution_lines`, `diff_ratio` (product ÷ reference solution),
  `extra_files`, `leftovers` (regex in `vsm.yaml`), `review_load` (changed lines + files + Markdown
  words). Transcript metrics, pi only (else `null`): `rereads`, `repeated_commands`, `test_runs`,
  `rework_loops` (failing test runs after the first build edit, from `exit_code` or a `fail N`
  summary), `reedits`, `ftt`, `pce` = (build + test time) ÷ lead time.
- **Lean views (e58s10):** the report has `lean` (`scripts/lib/ab_lean.py`): per arm, mean lead
  time, first build, switches, stage seconds and shares, waste means, `ftt_rate`, `leftover_rate`,
  `cost_per_pass`; `lean.deltas.<arm>.<metric>` = `{delta, ci95}` against vanilla. `print_summary` and
  `ab_progress.py` print a VSM bar per arm (length = mean lead time) and the waste table.
  `waste.redundant_test_runs` counts green test runs with no edit since the previous green run.
- **Reports:** `benchmarks/reports/AB-<date>.yaml` (per-arm and per-task rates and
  `mean_score`, `per_task_score`, delta `bigpowers − vanilla` for pass rate and score, each with a
  seeded bootstrap 95% CI; `deltas_vs_vanilla` gives the same for every non-vanilla arm) and
  `ab-runs-<date>.jsonl` (raw runs).

## Reports

- **YAML:** `benchmarks/reports/BENCHMARK-<skill>-<YYYY-MM-DD>.yaml`
- **JSON:** `benchmarks/reports/benchmark-<skill>.json` — `with_skill` / `without_skill` mean columns + delta

Reports are gitignored except when pinned as baselines.
