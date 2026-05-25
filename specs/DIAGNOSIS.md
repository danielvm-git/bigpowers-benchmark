# Diagnosis: Benchmark Runs Fail with `opencode exited with code 1`

## Problem

When starting a benchmark run from Mission Control in **Host** execution mode, every attempt fails within ~1–2 seconds during the `runningOpencode` phase.

**Actual behavior:**
- User selects a task (e.g. T01) and a model from the bench-candidate list
- Clicks Start Run
- Workspace reset completes (phase advances to `runningOpencode`)
- Run fails immediately with `opencodeNonZeroExit(code: 1)`
- UI shows: `opencode exited with code 1`
- A `BenchFailureRow` shard is written to `~/runs/data/fail_*.json` with `"phase": "runningOpencode"`

**Expected behavior:**
- Host runner resets the task worktree, invokes opencode with the selected model, grades the result, and persists a `BenchRow` in `~/runs/data/`

**How to reproduce:**
1. Launch app (`swift run BigPowersBenchmark`)
2. Settings → Execution: **Host (local)**
3. Mission Control → select T01 and any bench candidate (e.g. OpenCode Zen or Claude CLI model)
4. Start Run
5. Observe failure in ~2s with `opencode exited with code 1`

**Earlier variant (may still occur if SANDBOX path is misconfigured):**
- Failure in `resettingWorkspace` with `SANDBOX task T01 not found`
- Occurs when the configured SANDBOX path does not contain `T01/baseline/src/`
- Real task files live at `~/Developer/bigpowers-benchmark-old/SANDBOX/` on this machine

---

## Root Cause Analysis

### Verified root cause: catalog model ID passed to opencode instead of provider/model slug

The host runner invokes opencode with the **internal catalog ID** stored in Mission Control's model picker (e.g. `opencode:opencode/deepseek-v4-flash-free`, `claudecli:claude-haiku-4-5`). Opencode's `--model` flag requires the **`provider/model`** format (documented in `opencode run --help`).

The model registry already exposes the correct external slug via `ModelInfo.apiModelId` (`resolvedModelId` when present). Model Health pings use `apiModelId`; the host runner does not.

**Evidence:**
- Latest failure shard: `"modelId": "opencode:opencode/deepseek-v4-flash-free"`, `"phase": "runningOpencode"`, `"duration": 1.69`
- Debug log: `"error": "opencodeNonZeroExit(code: 1)"` after `"phase": "runningOpencode"` (not workspace reset)
- Opencode parses `--model` by splitting on `/` only — a catalog ID like `opencode:opencode/foo` yields provider `opencode:opencode` (invalid); `claudecli:claude-haiku-4-5` yields empty model slug
- Integration tests mock opencode with `model: "test/model"` (correct format), masking the production bug
- Catalog tests assert `apiModelId != id` for CLI/OpenCode entries and `apiModelId.hasPrefix("opencode/")` for Zen models

**Why it fails fast (~1–2s):** Opencode rejects the malformed provider/model tuple before completing an agent session, returning exit code 1.

### Secondary issue: non-opencode transports selected in host mode

Even after resolving to `apiModelId`, **Claude CLI** and **Gemini CLI** models (`claude-haiku-4-5`, `gemini-2.5-flash`, etc.) are not valid opencode provider/model pairs. Model Health correctly pings these via their native CLIs; host mode has no equivalent CLI runner path. Per the host-runner ADR, host mode is designed around opencode + OpenRouter-style models.

Selecting a Claude CLI bench candidate in host mode will continue to fail until either:
- host mode filters the model picker to opencode-compatible transports, or
- a separate Claude/Gemini CLI executor path is added

### Resolved / latent: SANDBOX path mismatch

An earlier failure mode (`sandboxTaskMissing`) occurred when UserDefaults or defaults pointed at `~/Developer/bigpowers-benchmark/SANDBOX` (missing) instead of `~/Developer/bigpowers-benchmark-old/SANDBOX` (present). `HostRunConfig` now auto-detects both locations and clears invalid stored paths. If the old error persists, set SANDBOX path explicitly in Settings or clear `bigpowers.host.sandboxPath` from UserDefaults.

Symlink breakage in git archive extraction remains a latent risk but is **not** the cause of current ~2s opencode failures (workspace reset completes successfully).

### Contributing factors

1. **No model ID resolution at run boundary** — catalog ID flows unchanged from UI to Process arguments
2. **No transport guard in host mode** — CLI subscription models appear alongside opencode models in the picker
3. **stderr not logged on opencode failure** — debug log only records exit code, hiding opencode's actual error text
4. **Misleading prior diagnosis** — focused on SANDBOX/symlinks; current logs show reset succeeds and opencode fails

### Risk level

**Medium** — fix is localized (model resolution + host-mode filter), but host mode cannot run Claude/Gemini CLI models without additional executor work.

---

## TDD Fix Plan

### 1. Resolve catalog ID to opencode model slug at run start

**RED:** Write a test that given a catalog entry `id: "opencode:opencode/big-pickle"` with `apiModelId: "opencode/big-pickle"`, the host executor receives `opencode/big-pickle` as the `--model` argument (assert via mock shell capturing arguments).

**GREEN:** In Mission Control (or a small resolver used by both Mission Control and HostRunExecutor), look up `ModelInfo` by selected catalog ID and pass `apiModelId` to `executor.run(task:model:)`. Preserve catalog ID in `BenchRow.modelId` / failure records for traceability.

**verify:** `swift test --filter HostRunExecutor`

### 2. Reject non-opencode transports in host mode

**RED:** Write a test that starting a host run with a `pingTransport` of `.claudeCLI` returns a clear error (e.g. `RunnerError.unsupportedTransport`) before invoking opencode, with a message like "Host mode requires an OpenCode or OpenRouter model."

**GREEN:** Add transport check in `startRun()` when `isHostMode` is true; filter bench-candidate picker to `.openCode` and `.openRouter` transports only (or mark CLI models disabled with tooltip).

**verify:** `swift test --filter MissionControl`

### 3. Log opencode stderr on non-zero exit

**RED:** Write a test that when the mock shell returns exit code 1 with stderr `"unknown provider"`, the failure is logged to the runner component with stderr content sanitized.

**GREEN:** In HostRunExecutor, on non-zero opencode exit, log stderr (and the resolved model slug + worktree path) via `AppLogger.runner.error` before throwing `opencodeNonZeroExit`.

**verify:** `swift test --filter HostRunExecutor`

### 4. End-to-end host run with OpenCode Zen model

**RED:** Integration test using real SANDBOX fixture and mock opencode that asserts a run with catalog ID `opencode:opencode/test` invokes `--model opencode/test` and completes grading.

**GREEN:** No additional code beyond fixes 1–3.

**verify:** `swift test --filter HostRunExecutor`

### REFACTOR

- Extract `HostRunModelResolver` (catalog ID → opencode slug + transport validation) for reuse by Mission Control and executor
- Surface opencode stderr in Mission Control log panel on failure (already yielded as `.logLine` — ensure UI shows err lines)

---

## Acceptance Criteria

- [ ] Host run with OpenCode Zen model resolves catalog ID to `opencode/<slug>` and opencode receives valid `--model`
- [ ] Host run with Claude/Gemini CLI model is blocked with actionable error before opencode is invoked
- [ ] Opencode stderr appears in debug log on failure
- [ ] At least one end-to-end host run test passes with mock opencode
- [ ] All existing tests still pass
- [ ] Manual smoke: Start Run with `opencode:opencode/deepseek-v4-flash-free` completes or fails with provider error (not instant malformed-model exit)

## Resolution

<!-- filled in by validate-fix -->
