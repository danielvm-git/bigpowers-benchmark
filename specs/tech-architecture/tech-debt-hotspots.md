# Technical Debt & Architecture Hotspots

Last updated: 2026-11-06. Generated via `bp-churn-rank.sh` and codebase audit.

## Churn Hotspots (Historical Top 10)
| Rank | Commits | Path | Friction Area |
|:---:|:---:|---|---|
| 1 | 8 | `Sources/BigPowersBenchmark/BigPowersBenchmarkApp.swift` | App root lifecycle & dependency injection coordination |
| 2 | 7 | `Sources/BigPowersBenchmarkKit/Views/ContentView.swift` | Split-view navigation root and tab routing |
| 3 | 5 | `Sources/BigPowersBenchmarkKit/Views/RunExplorerView.swift` | Shard filtering, sorting, and comparison state |
| 4 | 5 | `Sources/BigPowersBenchmarkKit/Views/MissionControlView.swift` | Real-time terminal streaming and run dispatch |
| 5 | 5 | `Sources/BigPowersBenchmarkKit/Store/BenchmarkStore.swift` | File watcher debounce, shard parsing, and persistence |
| 6 | 5 | `Sources/BigPowersBenchmarkKit/Services/GitService.swift` | Git process spawning and worktree cleanup |
| 7 | 4 | `Sources/BigPowersBenchmarkKit/Views/SettingsView.swift` | Keychain credential editing and validation |
| 8 | 4 | `Sources/BigPowersBenchmarkKit/Models/ModelInfo.swift` | Catalog model representation and pricing metadata |
| 9 | 3 | `Sources/BigPowersBenchmarkKit/Runner/ShellCommandRunner.swift` | AsyncStream line piping and process group reaping |
| 10 | 3 | `scripts/lib/ab_process.py` | Subprocess timeout handling and orphan process cleanup |

## Known Technical Debt
1. **Runner / Subprocess Isolation**:
   - `ShellCommandRunner` and `ab_process.py` manage process groups separately in Swift and Python.
   - Long-term opportunity: Unify process timeout and signal handling semantics across language boundaries.
2. **Catalog Metadata Caching**:
   - `StaticCatalogCache` and `ModelRegistry` use local file cache with manual invalidation; could benefit from etag-based HTTP polling.
3. **Task Definition Normalization**:
   - Some legacy task definitions in `benchmarks/ab/tasks` have varying fixture formats; ongoing normalization in Epic e04.
