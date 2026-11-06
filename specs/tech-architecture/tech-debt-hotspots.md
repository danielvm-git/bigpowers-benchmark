# Technical Debt & Architecture Hotspots

Last updated: 2026-11-06.

## How to regenerate

```bash
bash scripts/bp-churn-rank.sh --since "900 days ago" --limit 12
```

Window: repository history `2026-05-23` → `2026-11-06` (46 commits). The script
defaults to a 90-day window, which on this repository yields a flat "1 commit
per file" list and cannot rank anything — pass an explicit `--since` wide
enough to cover the whole history. Re-rank with the default window once commits
span more than 90 days of activity.

Rank 1 (`CHANGELOG.md`) is release tooling, not application code; exclude it
when reasoning about friction.

## Churn Hotspots (all-time top 12, 2026-11-06)

| Rank | Commits | Path | Friction Area |
|:---:|:---:|---|---|
| 1 | 10 | `CHANGELOG.md` | Release tooling writes here; not app code |
| 2 | 8 | `Sources/BigPowersBenchmarkKit/Views/ContentView.swift` | Split-view navigation root and tab routing |
| 3 | 8 | `Sources/BigPowersBenchmark/BigPowersBenchmarkApp.swift` | App root lifecycle & dependency injection coordination |
| 4 | 6 | `Sources/BigPowersBenchmarkKit/Store/BenchmarkStore.swift` | File watcher debounce, shard parsing, and persistence |
| 5 | 6 | `.swiftlint.yml` | Lint rule churn while converging on strict |
| 6 | 5 | `Tests/BigPowersBenchmarkTests/ModelHealthSubscriptionProviderTests.swift` | Ping-scope subscription permutations |
| 7 | 5 | `Tests/BigPowersBenchmarkTests/BenchmarkStoreTests.swift` | Async store and git-repo status timing |
| 8 | 5 | `Sources/BigPowersBenchmarkKit/Views/RunExplorerView.swift` | Shard filtering, sorting, and comparison state |
| 9 | 5 | `Sources/BigPowersBenchmarkKit/Views/MissionControlView.swift` | Real-time terminal streaming and run dispatch |
| 10 | 5 | `Sources/BigPowersBenchmarkKit/Services/GitService.swift` | Git process spawning and worktree cleanup |
| 11 | 4 | `Sources/BigPowersBenchmarkKit/Views/SettingsView.swift` | Keychain credential editing and validation |
| 12 | 4 | `Sources/BigPowersBenchmarkKit/Views/ModelHealth/ModelHealthViewModel.swift` | Ping scheduling and row state |

## Known Technical Debt
1. **Runner / Subprocess Isolation**:
   - `ShellCommandRunner` and `ab_process.py` manage process groups separately in Swift and Python.
   - Long-term opportunity: Unify process timeout and signal handling semantics across language boundaries.
2. **Catalog Metadata Caching**:
   - `StaticCatalogCache` and `ModelRegistry` use local file cache with manual invalidation; could benefit from etag-based HTTP polling.
3. **Task Definition Normalization**:
   - Some legacy task definitions in `benchmarks/ab/tasks` have varying fixture formats; ongoing normalization in Epic e04.
