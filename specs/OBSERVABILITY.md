# Observability — Solo-Dev Debug

Cross-cutting story: structured NDJSON logging for AI-assisted debugging.

## Goal

When the app misbehaves (Settings Test Connection, benchmark runs, persistence), a solo developer can:

1. Reproduce the issue
2. Copy or tail `~/Library/Logs/BigPowersBenchmark/debug.ndjson`
3. Paste into Cursor/Claude to fix

## Log file

| Property | Value |
|----------|-------|
| Path | `~/Library/Logs/BigPowersBenchmark/debug.ndjson` |
| Format | NDJSON — one JSON object per line |
| Rotation | None in v1 (append-only) |

## Schema

Required fields on every line:

```json
{
  "level": "info",
  "timestamp": "2026-05-23T12:00:00.000Z",
  "message": "App launched",
  "component": "app"
}
```

Optional context: `error`, `statusCode`, `path`, `method`, `runId`, `taskId`, `phase`, `sandboxId`.

## Sanitization

Never log:

- API keys or Keychain values
- `Authorization` headers or `Bearer` tokens

All error strings pass through `LogSanitizer` before log or UI display.

## Instrumentation boundaries

| Component | Events |
|-----------|--------|
| App launch | Version, log path, Daytona base URL (not key) |
| `DaytonaClient` | HTTP method + path; status on failure; ping result |
| `BenchmarkRunner` | Phase transitions; timeouts; opencode exit; grading; persist |
| `BenchmarkStore` | Save/load failures |
| `GitService` | Non-zero exit; timeout |
| Settings | Test Connection click + outcome |

## Solo-dev verify loop

```bash
# Reproduce → inspect
tail -100 ~/Library/Logs/BigPowersBenchmark/debug.ndjson

# Or in app: Help → Copy Debug Log
```

## Out of scope

- Model Health ping / `ModelRegistry` (Story 7.1)
- Provider API key entry UI
- Pulse / OpenTelemetry
- `orchestrator.log` second file

## Acceptance criteria

- [x] App launch creates `debug.ndjson` with boot line
- [x] Test Connection with empty key shows "Missing API key" in UI and log
- [x] Help → Copy Debug Log copies last 100 NDJSON lines
- [x] No `Bearer` or `Authorization` in log output
- [x] `bash scripts/setup.sh` idempotent (run twice, no errors)
- [x] `swift test` green

## Verify commands

```bash
swift test
bash scripts/setup.sh
bash scripts/setup.sh
tail -5 ~/Library/Logs/BigPowersBenchmark/debug.ndjson
grep -E 'Bearer|Authorization' ~/Library/Logs/BigPowersBenchmark/debug.ndjson && exit 1 || echo "OK: no secrets"
```
