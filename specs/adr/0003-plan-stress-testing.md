# ADR: Plan Stress-Testing & Assumptions Validation (Grill-Me)

## Status
Accepted — 2026-11-06

## Context
Before transitioning from discover/plan to build execution, core assumptions of the port, A/B evaluation harness, and runner isolation were stress-tested using the `grill-me` protocol.

## Grilling Challenges & Resolved Decisions

1. **Challenge**: Why keep the harness in Python/Docker instead of rewriting it in pure Swift?
   - **Resolution**: Rewriting the harness in Swift would invalidate the comparative historical baseline across models and delay verification. Python/Docker provides mature sandbox isolation and statistical libraries (SciPy bootstrap). The Swift app serves as cockpit and runner orchestrator.

2. **Challenge**: How to prevent benchmark runs on dirty git worktrees from corrupting scores?
   - **Resolution**: Strict pristine preflight is enforced. Any uncommitted change or dirty state triggers immediate exit code 2 unless `--allow-dirty` is explicitly provided.

3. **Challenge**: How to ensure cross-runner compatibility between the legacy Tauri shards and Swift app?
   - **Resolution**: The `BenchRow` JSON schema is frozen and strictly validated in tests (`ABReportCodingTests` and `ABRunRecordCodingTests`).
