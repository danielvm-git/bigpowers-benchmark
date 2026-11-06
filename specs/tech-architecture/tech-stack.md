# Tech Stack & Architecture

## Stack
- **Platform**: macOS 14.0+
- **Application Language**: Swift 6 (Strict Concurrency enabled)
- **UI Framework**: SwiftUI (`NavigationSplitView`, Swift Charts, `Table`, `Canvas+Path`)
- **Terminal Rendering**: `SwiftTerm` via `NSViewRepresentable`
- **Runner Subsystem**: Python 3.11+ / Docker (`pi-docker` adapter) / Bash
- **Persistence**: JSON shards in `~/runs/data/` (`BenchRow`), YAML/JSONL reports in `benchmarks/reports/`
- **Secrets Management**: macOS Keychain (`SecItemAdd`, `SecItemCopyMatching`) — never disk or env files

## Modules
1. **BigPowersBenchmarkKit**:
   - `Models/`: Data structures (`BenchRow`, `ABRunRecord`, `TaskItem`, `Screen`)
   - `Store/`: `BenchmarkStore` file watcher and shard persistence
   - `Runner/`: `HostRunExecutor`, `ShellCommandRunner`, `AsyncStream` process bridges
   - `Views/`: SwiftUI split-view cockpit, mission control, charts, and terminal views
2. **Benchmark Harness**:
   - `scripts/run-ab-eval.sh`: Runner entry point
   - `scripts/lib/ab-eval.py`: Evaluation orchestration and adapter dispatch
   - `scripts/lib/ab_metrics.py`: Statistical calculation, bootstrap CIs, and lean value stream metrics

## Gray Areas & Standards
- **Error Handling**: Throwing typed errors in SwiftKit, exit code status protocols in harness scripts.
- **Process Boundaries**: All external processes spawned with strict timeout handlers and output streaming.
- **API Shape**: Decoupled async event streams (`AsyncStream<RunEvent>`) between execution and UI layers.
