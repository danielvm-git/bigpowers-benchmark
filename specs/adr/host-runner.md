# ADR: Dual Execution Mode — Host vs Daytona

## Status

Accepted — 2026-05-24

## Context

Solo developers need to run benchmarks locally without Docker or a self-hosted Daytona stack. The legacy Tauri app used git worktrees on the host with `opencode` invoked via `Process`. The Swift app initially only supported Daytona REST API execution inside remote sandboxes.

Cross-version regression (`bigpowersRef` v1.1 vs v1.2) requires trustworthy isolation of skills and toolchain. Host mode relaxes full sandbox guarantees for development velocity.

## Decision

Introduce **dual execution modes**:

| Mode | Default | Use case |
|------|---------|----------|
| **Host** | Yes | Local dev, smoke tests, one ref at a time |
| **Daytona** | No | Official regression across bigpowers versions |

Both modes emit `AsyncStream<RunEvent>` and persist `BenchRow` via `BenchmarkStore`.

### Host mode guarantees

- Fresh task worktree per run under `worktreeRoot`
- Skills injected from **pinned `bigpowersRef`** via `git archive` (not live working tree copy)
- `BenchRow.bigpowersRef` stamped from configured ref
- Serial runs only (one at a time)

### Host mode does NOT guarantee

- opencode / Node toolchain version isolation
- Parallel cross-version runs
- Agent isolation from host filesystem

### Daytona mode

Unchanged — `DaytonaRunExecutor` uses `DaytonaClient` API. Required before publishing regression comparisons across bigpowers versions.

## Fixes legacy bug

Old `reset_sandbox.sh` copied `$BIGPOWERS_PATH/CLAUDE.md` from disk regardless of `BIGPOWERS_REF`. Host mode uses `git -C <repo> archive <ref>` for `CLAUDE.md`, `.claude`, and `skills/`.

## When to switch to Daytona Cloud

Use **Host** mode when:

- Iterating on a single `bigpowersRef` on your Mac
- Smoke-testing Mission Control without API keys
- Developing runner/UI changes locally

Switch to **Daytona** mode when:

- Comparing results across `bigpowersRef` versions (e.g. v1.1 vs v1.2) for publication
- You need opencode/Node toolchain isolation per sandbox
- Running parallel benchmarks against different refs

Host mode one-time setup:

```bash
npm i -g @opencode-ai/opencode
export OPENROUTER_API_KEY="..."   # provider key, not Daytona
mkdir -p ~/runs/data && cd ~/runs/data && git init && git commit --allow-empty -m "init"
```

Settings → Execution: **Host (local)** with Bigpowers repo, SANDBOX path, worktree root `/tmp/bp_bench_runs`, and desired `bigpowersRef`.

## Consequences

- Relaxes DOMAIN.md constraint #2 ("opencode inside sandbox") for host mode only
- Settings gains execution mode toggle and host path fields
- Mission Control hides sandbox picker in host mode
