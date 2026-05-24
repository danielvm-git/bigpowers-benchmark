# PLAN — SwiftTerm & Rest of Features Integration (Validated via opensrc)

This document outlines the technical design and execution plan to complete the BigPowers-Benchmark SwiftUI application, integrating the `SwiftTerm` local process terminal connection type from `big-terminal` and finishing all missing features across the project.

---

## 1. Goal Description

Implement all remaining features of the BigPowers-Benchmark macOS app (macOS 14+ Sonoma, SwiftUI native) while replacing the simple `NSTextView` logs panel with a high-fidelity `SwiftTerm` terminal panel that supports two connection types:
1. **Log Stream (Read-only)**: Renders output from Daytona's command execution stream. We validated Daytona's log-streaming mechanism in the `daytonaio/daytona` TypeScript SDK (which uses `wss://.../process/session/{sessionId}/command/{commandId}/logs?follow=true`). We will parse these JSON logs into ANSI escape codes dynamically and feed them to `SwiftTerm.TerminalView` via `feed(text:)`.
2. **Local Terminal (Interactive)**: Integrates the interactive shell terminal from the `big-terminal` project (`LocalProcessTerminalView`), allowing the user to run local shell commands directly within the app workspace.

Additionally, this plan addresses the current Swift 6.0 strict concurrency errors in `BenchmarkRunner` and implements the remaining views: Dashboard, Mission Control (full cockpit UI), Run Explorer (compare/export), Task Library, Model Health, Skill Insights (radar chart using Canvas), Analytics, and MenuBarExtra progress tracking.

---

## 2. Proposed Changes

### Component 1: Build Configuration & Concurrency Fixes

#### [MODIFY] [Package.swift](file:///Users/danielvm/Developer/bigpowers-benchmark/Package.swift)
- Add the `SwiftTerm` package dependency: `.package(url: "https://github.com/migueldeicaza/SwiftTerm.git", from: "1.13.0")`.
- Link `"SwiftTerm"` as a dependency of the `"BigPowersBenchmarkKit"` target.

#### [MODIFY] [Sandbox.swift](file:///Users/danielvm/Developer/bigpowers-benchmark/Sources/BigPowersBenchmarkKit/Daytona/Sandbox.swift)
- Mark `Sandbox` and `SandboxState` as conforming to `Sendable` to fix Swift 6.0 data race compilation errors when crossing task boundaries inside `BenchmarkRunner`.

---

### Component 2: Core Theme & Client Services

#### [MODIFY] [Theme.swift](file:///Users/danielvm/Developer/bigpowers-benchmark/Sources/BigPowersBenchmarkKit/Theme/Theme.swift)
- Implement `ThemeTokens` containing all 18 color tokens specified in `THEME_SYSTEM.md` (`bg`, `bg1`, `surface`, `surface2`, `border`, `border2`, `fg`, `fg2`, `fg3`, `fg4`, `accent`, `accentD`, `accentF`, `good`, `bad`, `warn`, `grid`, `grid2`, `shadow`).
- Implement the static token definitions for all 13 themes (Auto, Light, Dark, Mono, Ocean, Forest, Ember, Violet, Midnight, Crimson, Slate, Amber, Rose) matching the prototype values exactly.

#### [MODIFY] [DaytonaClient.swift](file:///Users/danielvm/Developer/bigpowers-benchmark/Sources/BigPowersBenchmarkKit/Daytona/DaytonaClient.swift)
- Implement `streamLogs` using `URLSessionWebSocketTask` connecting to `wss://<host>/toolbox/{sandboxId}/toolbox/process/session/{sessionId}/command/{commandId}/logs?follow=true`.
- Ensure headers (including API key) are stripped from any thrown errors to prevent exposing secrets in logs.
- Add ping testing integration.

#### [MODIFY] [BenchmarkRunner.swift](file:///Users/danielvm/Developer/bigpowers-benchmark/Sources/BigPowersBenchmarkKit/Runner/BenchmarkRunner.swift)
- Fix the strict concurrency compiler warning/error.
- Fully implement Phase 2: running `opencode` with JSON log stream.
- Fully implement Phase 3 (Grading): executing `score_run.sh` inside sandbox, decoding the 4-key output, deleting the temp prompt file.
- Fully implement Phase 4+5 (Persist + Events): building `BenchRow`, calling `saveBenchRow(_:)`, yielding completion.
- Add 60-second timeouts per phase using `withThrowingTaskGroup` to race execution against a timer.

---

### Component 3: Terminal Panels (SwiftTerm Integration)

#### [NEW] [TerminalView.swift](file:///Users/danielvm/Developer/bigpowers-benchmark/Sources/BigPowersBenchmarkKit/Views/Terminal/TerminalView.swift)
- Wraps `SwiftTerm.TerminalView` (base view) inside `NSViewRepresentable` to function as a high-performance log console.
- Translates JSON log lines into color-coded ANSI escape sequences (e.g., `\u{001B}[32m` for ok, `\u{001B}[31m` for err) and feeds them to the terminal.
- Dynamically applies font size and theme colors (background, foreground, caret, selection) from the active theme.

#### [NEW] [LocalTerminalView.swift](file:///Users/danielvm/Developer/bigpowers-benchmark/Sources/BigPowersBenchmarkKit/Views/Terminal/LocalTerminalView.swift)
- Port the local process interactive terminal view from `/Users/danielvm/Developer/big-terminal/Sources/TerminalView.swift`.
- Inherits from `LocalProcessTerminalView` and spawns a login shell session using the settings in settings view (defaulting to `/bin/zsh`).

---

### Component 4: App Views & Screens

#### [MODIFY] [ContentView.swift](file:///Users/danielvm/Developer/bigpowers-benchmark/Sources/BigPowersBenchmarkKit/Views/ContentView.swift)
- Replace screen title text placeholders in `NavigationSplitView`'s detail column with actual View mountings:
  - `.dashboard` -> `DashboardView()`
  - `.missionControl` -> `MissionControlView()`
  - `.runExplorer` -> `RunExplorerView()`
  - `.taskLibrary` -> `TaskLibraryView()`
  - `.modelHealth` -> `ModelHealthView()`
  - `.skillInsights` -> `SkillInsightsView()`
  - `.settings` -> `SettingsView()`
  - `.analytics` -> `AnalyticsView()`

#### [MODIFY] [SettingsView.swift](file:///Users/danielvm/Developer/bigpowers-benchmark/Sources/BigPowersBenchmarkKit/Views/SettingsView.swift)
- Implement Daytona connection tester button linked to `DaytonaClient.ping()`.
- Add a new "Terminal Configuration" section allowing configuring:
  - Default Shell Path
  - Option key behavior (as Meta)
  - Font Size
  - High-intensity ANSI colors toggle

#### [MODIFY] [MissionControlView.swift](file:///Users/danielvm/Developer/bigpowers-benchmark/Sources/BigPowersBenchmarkKit/Views/MissionControlView.swift)
- Implement the split cockpit layout (55% controls, 45% terminal panel).
- Cockpit:
  - Pickers for Suite, Task, Model, and Daytona Sandbox.
  - Run/Stop toggle.
  - Task progress stepper (T01 - T05 or dynamic task list).
  - KPI Cards (Overall, Code Pass, Artifact, Convention) with sparkline charts.
- Terminal Panel:
  - Tab control to toggle between "Log Stream" (`TerminalView`) and "Interactive Shell" (`LocalTerminalView`).
  - Clear and Copy to Clipboard buttons.

#### [NEW] [DashboardView.swift](file:///Users/danielvm/Developer/bigpowers-benchmark/Sources/BigPowersBenchmarkKit/Views/Dashboard/DashboardView.swift)
- Aggregates overall performance metrics:
  - Hero metric cards: Best Model, Fastest Model, Lowest Cost, Most Improved (delta or nil).
  - Multi-model score evolution Line Chart (Last 5/10/All picker).
  - Model x Task heatmap using `RectangleMark`.
  - Recent regressions List with DeltaBadges.
  - Recent runs table.

#### [NEW] [RunExplorerView.swift](file:///Users/danielvm/Developer/bigpowers-benchmark/Sources/BigPowersBenchmarkKit/Views/RunExplorer/RunExplorerView.swift)
- Virtualized, sortable `Table` listing all runs from `BenchmarkStore`.
- Search field and filter pickers (Model, Ref, Task).
- Slider drawer / inspector details for selected run showing scores, checklists, and capability chips.
- Compare Mode: Activated when exactly 2 runs are selected, showing delta metrics and score diffs.
- Export Menu: CSV (RFC 4180 compliant) and JSON exports.

#### [NEW] [TaskLibraryView.swift](file:///Users/danielvm/Developer/bigpowers-benchmark/Sources/BigPowersBenchmarkKit/Views/TaskLibrary/TaskLibraryView.swift)
- Sidebar suite list + main grid of Task Cards.
- Details sheet with descriptions, artifact checklists, and historical score trend.
- "Run This Task Only" button opening Mission Control pre-populated with the task ID.

#### [NEW] [ModelHealthView.swift](file:///Users/danielvm/Developer/bigpowers-benchmark/Sources/BigPowersBenchmarkKit/Views/ModelHealth/ModelHealthView.swift)
- Grid showing all LLM providers, their config status, and response latency.
- Leaderboard table ranked by overall capability scores.

#### [NEW] [SkillInsightsView.swift](file:///Users/danielvm/Developer/bigpowers-benchmark/Sources/BigPowersBenchmarkKit/Views/SkillInsights/SkillInsightsView.swift)
- Custom polar Canvas drawing a Skill Radar Chart (Coding, Specs, Conventional Commits, Architecture, Speed).
- Detailed skill breakdown bars.

#### [NEW] [AnalyticsView.swift](file:///Users/danielvm/Developer/bigpowers-benchmark/Sources/BigPowersBenchmarkKit/Views/Analytics/AnalyticsView.swift)
- Detailed regression warnings, scatter plots, and cost-efficiency graphs.

#### [MODIFY] [MenuBarContent.swift](file:///Users/danielvm/Developer/bigpowers-benchmark/Sources/BigPowersBenchmarkKit/Views/MenuBarContent.swift)
- Renders live run progress if a benchmark is active, showing the active task and elapsed time.
- Clicking items opens the main window and focuses the run.

---

## 3. Verification Plan

### Automated Tests
- Run strict unit tests verifying the run lifecycle using `MockDaytonaClient` and `MockGitService`:
  ```bash
  swift test
  ```
- Specifically verify all test suites pass (DaytonaClientTests, BenchmarkRunnerTests, BenchRowCodingTests, ThemeManagerTests, KeychainServiceTests).

### Manual Verification
1. Run the app in development:
   - Check sidebar navigation.
   - Verify Settings allow modifying terminal preferences and successfully pinging Daytona.
2. Trigger a benchmark run in Mission Control:
   - Verify the task stepper advances.
   - Verify the Log Stream terminal prints colored JSON logs.
   - Switch to Local Terminal tab and verify interactive shell commands (like `ls` or `git status`) execute and display output.
3. Check Dashboard & Run Explorer:
   - Verify charts populate with real run data.
   - Test CSV/JSON export and check correct formatting.
