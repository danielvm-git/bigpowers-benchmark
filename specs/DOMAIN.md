# Domain Model — BigPowers-Benchmark

Last updated: 2026-05-23. Built by `model-domain` interview.

---

## Bounded Context

Single context. One macOS app, one user, one local machine.

---

## Entities & Value Objects

### Run (aggregate root) ✓

**A Run is the atomic unit of benchmarking: one Task × one Model × one bigpowers ref → one scored result.**

The user always runs one at a time. There is no batch, queue, or parallel execution — a deliberate constraint driven by available compute.

Maps 1:1 to `BenchRow` on disk.

```
Run
├── id: UUID
├── timestamp: Date
├── bigpowersRef: String       ← git ref identifying the task suite version
├── model: ModelID
├── task: TaskID
├── codePass: Int              ← 0 or 1 (did the code compile and pass tests?)
├── artifactScore: Int         ← 0–2 (quality of the produced artifact)
├── conventionScore: Int       ← 0–2 (adherence to project conventions)
├── overallScore: Double       ← (codePass×2 + artifactScore + conventionScore) / 4
├── duration: TimeInterval     ← wall-clock seconds
├── cost: Double               ← USD cost of the LLM call(s)
└── workspace: String          ← path opencode used as working directory
```

**Score formula:** `overallScore = (codePass × 2 + artifactScore + conventionScore) / 4`

**Persistence:** one JSON shard per Run at `~/runs/data/run_<ISO8601>_<taskId>.json`

**ADR note:** no RunBatch entity — user explicitly runs one-by-one due to compute constraints.

---

## Entities & Value Objects (continued)

### Sandbox ✓ (partial)

A Daytona sandbox with a specific version of the bigpowers skillset pre-installed. opencode runs **inside** the sandbox — never on the host machine. This guarantees that a Run's `bigpowersRef` reflects the actual skillset version used; there is no way to run against the wrong version because the sandbox is the isolation boundary.

```
Sandbox
├── sandboxId: String          ← Daytona sandbox ID
├── bigpowersRef: String       ← git ref / version tag of the skillset installed inside
└── label: String              ← human-readable name (e.g. "bigpowers-v1.2.0")
```

**Lifecycle:** long-lived. Sandboxes are pre-created and managed by the user outside the app (one per bigpowers version under test). The app discovers them via Daytona's `GET /sandboxes` API and never provisions or destroys them.

**Workspace reset strategy:** fresh clone per Run. Before each Run, the app deletes the task workspace directory inside the sandbox and re-clones the task repo at the pinned `bigpowersRef`. Guarantees opencode always starts from an identical state. `git reset` was rejected because prior-run artifacts (committed files, stray outputs) could contaminate results. The bigpowers skillset and opencode installation are preserved. Previous Run results are unaffected because each Run's `BenchRow` is already persisted as a separate JSON shard before the reset occurs.

**Re-run semantics:** running the same Task × Model combination on the same Sandbox a second time produces a second `BenchRow` shard with a new UUID and timestamp. Both coexist in `~/runs/data/`. Neither overwrites the other.

**ADR candidate:** opencode-inside-sandbox is a hard architectural constraint, not a preference. Reversing it would invalidate the integrity guarantee of every recorded `bigpowersRef`.

### Run (updated)

`bigpowersRef` on `BenchRow` is read from the `Sandbox` used for the run — it is not user-entered. The app sets it automatically at run time to prevent transcription error.

---

### TaskSuite ✓

A named, ordered collection of Tasks used to group runs for browsing and selection. Suites are defined in the task repo. A Run always executes exactly one Task — a Suite is a filter/lens, not a unit of execution.

```
TaskSuite
├── suiteId: String      ← e.g. "canonical"
├── name: String         ← e.g. "Canonical"
└── taskIds: [TaskID]    ← ordered list of tasks in this suite
```

When launching a Run from Mission Control, the user selects a Suite, then picks one Task from within it. The selected Suite can be changed per-run — it is not locked to the sandbox or model.

### Task ✓ (partial)

A benchmark task: a scaffold codebase with pre-existing bugs, features, or refactoring challenges that opencode is asked to solve. Tasks live in a separate task repo (URL configured in Settings). The task repo structure:

```
tasks-repo/
├── suites.json              ← defines suites and their task lists
├── T01_bug_investigation/
│   ├── task.json            ← metadata (name, description, difficulty, category, grading, expectedRuntime)
│   ├── README.md
│   └── src/ tests/ ...
├── T02_feature_slice/ ...
└── (A–J tasks to be ported from sdd-comparison-test/SANDBOX/)
```

Metadata lives in `task.json` (machine-readable, Swift `Codable`). Human description lives in `README.md`. A top-level `suites.json` defines suite membership.

---

### Provider ✓

A configured LLM provider. Defined in `providers.json` (stored in `~/Library/Application Support/BigPowersBenchmark/`). Each provider has a base URL, API key (Keychain), models endpoint, and transport type.

Confirmed providers: OpenRouter, Anthropic, Nous Research, Google, Cursor.

### Model ✓

An LLM available for benchmarking. Identified by a `provider/model-id` string (e.g. `openrouter/anthropic/claude-sonnet-4.6`). Model metadata (capabilities, context window, cost, tier) is sourced from `models.dev/api.json` + per-provider `/models` endpoints, cached to `models-cache.json` with a 1h TTL. The Registry screen is populated from this cache.

This replicates the old app's settled solution — static model files were rejected because they drift immediately.

---

### LogLine ✓

A single line emitted by opencode during a Run. Captured via Daytona's log-streaming API and displayed in the terminal panel.

```
LogLine
├── t:    String   ← ISO8601 timestamp
├── kind: String   ← "info" | "ok" | "warn" | "err" | "cmd"
└── text: String   ← the log message
```

Maps 1:1 to the terminal panel CSS classes in the design system (`terminal-type-info`, `terminal-type-ok`, etc.).

### Grading ✓

Fully automated. After opencode exits, `score_run.sh` runs inside the Daytona sandbox via Daytona's process API and emits a JSON object:

```json
{ "code_pass": 0|1, "artifact_score": 0|1|2, "convention_score": 0|1|2, "token_cost": 0.0 }
```

**Scoring rules (derived from old app `score_run.sh`):**
- `code_pass`: run `test.js` — exit 0 = 1, else = 0
- `artifact_score`: count `.md` files in `specs/` — 0 = 0, 1–2 = 1, 3+ = 2
- `convention_score`: check git log — no commits = 0, commits without CC format = 1, ≥1 Conventional Commit = 2
- `overallScore = (codePass × 2 + artifactScore + conventionScore) / 4`

The Swift app reads the JSON output, populates the `BenchRow`, and writes the JSON shard.

---

### BenchmarkStore ✓

Manages all persisted `BenchRow` JSON shards on disk.

```
BenchmarkStore
├── runsURL: URL               ← ~/runs/data/
├── autoCommit: Bool           ← user pref (Settings)
└── autoPush: Bool             ← user pref (Settings)
```

**Responsibilities:**
- `saveBenchRow(_:)` — write `run_<ISO8601>_<taskId>.json`
- `loadAllRuns()` — decode all JSON shards from `runsURL`
- **Directory watcher** — `DispatchSource.makeFileSystemObjectSource` watches `runsURL` for `.write` events; on event, debounces and calls `reloadRuns()`. Keeps the UI live when external processes (git pull, scripts) drop new shards.
- **Auto-commit** — if `autoCommit` is true, shells out to `git commit -m "chore(bench): add run <id>"` after each save
- **Auto-push** — if `autoPush` is true, shells out to `git push` after a successful commit

`~/runs/data/` must be a git repo. The app does not init it — user is responsible for the initial `git init` and remote setup.

### BenchmarkRunner ✓

Orchestrates a full Run against a Daytona sandbox. Implemented as a Swift `actor`.

**Full lifecycle per Run:**
1. **Select sandbox** — user picks a pre-existing Daytona sandbox (by `sandboxId`)
2. **Reset workspace** — call Daytona process API to delete the task directory inside the sandbox, then `git clone <taskRepoURL> --branch <bigpowersRef> -- <taskDir>` inside the sandbox
3. **Run opencode** — call Daytona PTY/process API: `opencode run --model <modelId> --dangerously-skip-permissions --dir <taskDir> "<taskPrompt>"`; stream stdout/stderr as `LogLine` via `AsyncStream<LogLine>`
4. **Score** — after opencode exits, call Daytona process API to run `score_run.sh <taskDir>`; parse JSON output
5. **Persist** — build `BenchRow`, call `BenchmarkStore.saveBenchRow(_:)` (which handles auto-commit/push)
6. **Yield result** — return completed `BenchRow` to caller

**Daytona auth** — API key stored in Keychain under `bigpowers.benchmark.daytona`. URL configured in Settings.

---

## Full Entity Summary

| Entity | Type | Key facts |
|--------|------|-----------|
| `Run` (`BenchRow`) | Aggregate root | 1 task × 1 model × 1 sandbox → 1 JSON shard |
| `Sandbox` | Entity | Long-lived Daytona sandbox; pre-created by user; 1 bigpowers version |
| `Task` | Value object | From task repo; `task.json` metadata; fresh-cloned per Run |
| `TaskSuite` | Value object | Named group of tasks; defined in `suites.json`; filter only |
| `Provider` | Value object | Config in `providers.json`; API key in Keychain |
| `Model` | Value object | `provider/model-id` string; sourced from `models.dev` + provider APIs |
| `LogLine` | Value object | `{t, kind, text}`; streamed from Daytona during Run |
| `BenchmarkStore` | Service | Persistence, directory watcher, git commit/push |
| `BenchmarkRunner` | Actor | Daytona orchestration — reset → run → score → persist |

## Key Constraints (never relax without an ADR)

1. **One Run at a time** — compute constraint; no queue, no parallelism
2. **opencode inside sandbox** — version isolation guarantee; can't run on host
3. **Fresh clone per Run** — clean-state guarantee; `git reset` was rejected
4. **Scores are computed, never entered** — `score_run.sh` is the only source of truth for `codePass`, `artifactScore`, `conventionScore`
5. **API keys in Keychain only** — never in files, logs, or environment variables in committed code
