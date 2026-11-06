# e01s03 — Add the app bridge: launch a harness run and ingest JSON reports
<!-- story: e01s03 -->

**type:** feat
**risk:** P0
**context:** app
**BCPs:** 8

## Context

The macOS app currently launches `opencode` directly (`HostRunExecutor`, `DaytonaRunExecutor`) and
grades with `score_run.sh`. The A/B harness is a different execution model: a matrix run that
produces `ab-live.jsonl` while it runs and `AB-<date>.yaml` at the end. This story makes the app a
cockpit over that harness without changing `BenchRow` or the legacy runner.

Minimum vertical slice:

1. The harness emits a JSON sidecar (`AB-<date>.json`) next to the YAML so Swift needs no YAML parser.
2. Swift builds the command, streams stdout as `RunEvent.logLine`, cancels by killing the process group.
3. Swift decodes `ab-live.jsonl` into `ABRunRecord` and the sidecar into `ABReport`.
4. A small view launches one task × one arm × k=1 and shows the log plus the decoded record.

## Steps

1. Add `--json-out <path>` to `ab-eval.py`; `write_reports` writes the full `{meta, result, records}` JSON atomically → verify: `python3 Tests/test_ab_eval.py && rg -n 'json_out' scripts/lib/ab-eval.py`.
2. Add `ABRunRecord.swift` with snake_case `CodingKeys` matching a JSONL line; make missing optional fields decode as `nil` → verify: `swift test --filter ABRunRecordCoding`.
3. Add `ABReport.swift` for the sidecar: `arms_summary`, `per_task`, `per_task_score`, `delta`, `deltas_vs_vanilla`, `lean`, `inputs`, `decision` → verify: `swift test --filter ABReportCoding`.
4. Add `HarnessCommand.swift`: pure builder for the CLI args; no shell string interpolation → verify: `swift test --filter HarnessCommand`.
5. Add `HarnessRunner.swift` (actor): `Process`, `Pipe`, `AsyncStream<RunEvent>`, configurable timeout, `terminate()` on cancel, tail the live JSONL → verify: `swift test --filter HarnessRunner`.
6. Add `HarnessReportStore.swift`: read `AB-*.json` and `ab-runs-*.jsonl` from a reports dir; never write → verify: `swift test --filter HarnessReportStore`.
7. Add `HarnessRunView` + `HarnessRunViewModel` under `Views/Harness/`: task, arm, adapter, k, Run/Cancel, log panel, record table; wire into Mission Control → verify: `swift build`.
8. Add Settings fields: bigpowers checkout path, harness repo path, reports dir, default adapter → verify: `swift test --filter Settings` or `swift build`.

## Verification Script (Step-by-Step)

1. Set the bigpowers checkout path in Settings.
2. Pick `ab-11`, arm `bigpowers`, adapter `pi-docker`, k=1; press Run.
3. Confirm log lines stream; confirm a record appears when the run finishes.
4. Confirm `benchmarks/reports/AB-<date>.json` exists and the app shows the same pass/cost.
5. Cancel a second run mid-flight; confirm the child process is gone (`pgrep -f ab-eval.py` empty).

## Out of scope

- A full matrix dashboard, charts and leaderboard (later).
- Writing A/B records to `~/runs/data/` (the report dir is the source of truth).
- A YAML parser dependency.

## Risks

- `Process` deadlock if stdout/stderr are not drained concurrently: drain both, as `ShellCommandRunner` already learned.
- Killing only the parent leaves Docker children: launch with a process group and kill the group.
- The live JSONL is appended while read: tolerate partial last lines.
- The app must not import `BenchRow` semantics into `ABRunRecord`; keep both models.

## Acceptance Criteria

- [ ] The app starts a harness run and streams logs.
- [ ] The app decodes the report without YAML.
- [ ] Cancel kills the whole process tree.
- [ ] `BenchRow` and `~/runs/data/` behavior are unchanged.
