# BigPowers-Benchmark SwiftUI Architecture & Handoff Notes

## Target Platform
- **macOS 14+ (Sonoma)** — primary target
- **Apple Silicon-first** — optimized for M1/M2/M3
- **SwiftUI-native** — AppKit interop only where SwiftUI falls short

---

## App Shell

### Main App Structure
```swift
@main
struct BigPowersBenchmarkApp: App {
    @State private var benchmarkStore = BenchmarkStore()
    
    var body: some Scene {
        WindowGroup("BigPowers-Benchmark") {
            ContentView()
                .environment(benchmarkStore)
        }
        
        WindowGroup(id: "mission-control") {
            MissionControlView()
                .environment(benchmarkStore)
        }
        
        WindowGroup(id: "run-explorer") {
            RunExplorerView()
                .environment(benchmarkStore)
        }
        
        MenuBarExtra("BigPowers", systemImage: "gauge.with.dots.needle.bottom.50percent") {
            MenuBarContent()
        }
    }
}
```

**Primitives**: `App`, `Scene`, `WindowGroup`, `MenuBarExtra`

---

## Navigation & Sidebar

### Three-Column NavigationSplitView
```swift
NavigationSplitView {
    // Sidebar
    List(selection: $selection) {
        Label("Dashboard", systemImage: "gauge.with.dots.needle.bottom.50percent")
            .tag(Screen.dashboard)
        Label("Mission Control", systemImage: "play.circle.fill")
            .tag(Screen.missionControl)
        Label("Run Explorer", systemImage: "square.stack.3d.up")
            .tag(Screen.runExplorer)
        // ... etc
    }
    .navigationSplitViewColumnWidth(min: 60, ideal: 240)
} content: {
    // Content area
    ContentForSelection(selection)
} detail: {
    // Detail inspector (for Registry model detail, etc)
    DetailView()
}
```

**Primitives**: `NavigationSplitView`, `List`, `Label`, `@SceneStorage` for persistent selection

**Collapsible sidebar**: User can collapse via toolbar button; SwiftUI handles the 60px collapsed width automatically when labels are hidden.

---

## Toolbar & Title Bar

### Toolbar with custom title and status
```swift
.toolbar {
    ToolbarItemGroup(placement: .principal) {
        HStack {
            Circle()
                .fill(statusColor)
                .frame(width: 8, height: 8)
            Text("last run · 14:32:08 UTC")
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(.secondary)
        }
    }
    
    ToolbarItemGroup(placement: .primaryAction) {
        Button { toggleTheme() } label: {
            Image(systemName: "sun.max")
        }
        Button { openSettings() } label: {
            Image(systemName: "gearshape")
        }
    }
}
```

**Primitives**: `.toolbar(content:)`, `ToolbarItemGroup`, `placement: .principal / .primaryAction`

---

## Data Tables

### Virtualized, sortable tables
```swift
Table(runs, selection: $selectedRuns, sortOrder: $sortOrder) {
    TableColumn("Timestamp") { run in
        Text(run.timestamp.formatted())
            .font(.system(size: 11, design: .monospaced))
    }
    TableColumn("Model", value: \.modelName)
    TableColumn("Overall", value: \.overallScore) { run in
        Text(run.overallScore, format: .number.precision(.fractionLength(2)))
            .foregroundStyle(run.overallScore > 1.0 ? .accent : .secondary)
    }
    .width(min: 80)
}
.onChange(of: sortOrder) { updateSort($1) }
```

**Primitives**: `Table`, `TableColumn`, `TableRow` selection for compare-mode multi-select

**Run Explorer, Mission Control tasks table, Model Health leaderboard** all use `Table`.

---

## Charts

### Swift Charts for score evolution, sparklines, heatmaps
```swift
Chart {
    ForEach(dataPoints) { point in
        LineMark(
            x: .value("Ref", point.ref),
            y: .value("Score", point.score)
        )
        .foregroundStyle(Color.accent)
        .lineStyle(StrokeStyle(lineWidth: 2.5))
        
        PointMark(
            x: .value("Ref", point.ref),
            y: .value("Score", point.score)
        )
        .foregroundStyle(Color.accent)
    }
}
.chartXAxis {
    AxisMarks(values: .automatic) { value in
        AxisValueLabel()
            .font(.system(size: 9, design: .monospaced))
    }
}
.chartYAxis {
    AxisMarks { value in
        AxisGridLine()
            .foregroundStyle(Color.grid)
    }
}
```

**Primitives**: `Chart`, `LineMark`, `AreaMark`, `RuleMark`, `PointMark`, `BarMark`

**Heatmap**: Use `RectangleMark` with x/y for row/column and foregroundStyle mapped to score intensity.

**Skill radar**: Swift Charts doesn't natively support radar/spider. Options:
1. **Canvas + Path** with polar coordinate helper
2. **NSViewRepresentable** wrapping Core Graphics
3. Third-party library (not recommended for v1)

Document choice: **Canvas + Path** for full control.

```swift
Canvas { context, size in
    let center = CGPoint(x: size.width / 2, y: size.height / 2)
    let radius = min(size.width, size.height) / 2 - 20
    
    // Draw polygon
    var path = Path()
    for (index, value) in skillValues.enumerated() {
        let angle = (2 * .pi / CGFloat(skillValues.count)) * CGFloat(index) - .pi / 2
        let x = center.x + cos(angle) * radius * value
        let y = center.y + sin(angle) * radius * value
        if index == 0 {
            path.move(to: CGPoint(x: x, y: y))
        } else {
            path.addLine(to: CGPoint(x: x, y: y))
        }
    }
    path.closeSubpath()
    
    context.stroke(path, with: .color(.accent), lineWidth: 2)
    context.fill(path, with: .color(.accent.opacity(0.1)))
}
```

---

## Forms & Settings

### Form-based settings rail
```swift
Form {
    Section("Providers") {
        ForEach(providers) { provider in
            LabeledContent {
                Toggle(isOn: $provider.enabled) { }
            } label: {
                VStack(alignment: .leading) {
                    Text(provider.name)
                    Text(provider.apiKeyStatus)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
    
    Section("General") {
        Picker("Appearance", selection: $appearance) {
            Text("Auto").tag(Appearance.auto)
            Text("Light").tag(Appearance.light)
            Text("Dark").tag(Appearance.dark)
        }
        
        Toggle("Launch at Login", isOn: $launchAtLogin)
    }
}
```

**Primitives**: `Form`, `Section`, `LabeledContent`, `Toggle`, `Picker(.menu)`, `SecureField`

**Settings master-detail**: Use `.inspector(isPresented:)` placement (macOS 14+) for slide-in Registry model inspector panel.

---

## Sheets & Inspectors

### Modal sheets
```swift
.sheet(isPresented: $showingAddProvider) {
    AddProviderSheet(onDismiss: { showingAddProvider = false })
}
```

### Inspector panel (Registry detail)
```swift
.inspector(isPresented: $showingModelDetail) {
    if let model = selectedModel {
        VStack(alignment: .leading) {
            Text(model.name)
                .font(.headline)
            Text("Context: \(model.contextWindow)")
            // ... metadata
        }
        .padding()
    }
}
```

**Primitives**: `.sheet(isPresented:)`, `.inspector(isPresented:)`, `.confirmationDialog` for destructive actions

---

## Terminal Panel

**SwiftUI cannot stream ANSI efficiently.** Use NSViewRepresentable wrapping NSTextView.

```swift
struct TerminalView: NSViewRepresentable {
    @Binding var logLines: [LogLine]
    
    func makeNSView(context: Context) -> NSScrollView {
        let textView = NSTextView()
        textView.isEditable = false
        textView.font = NSFont.monospacedSystemFont(ofSize: 11, weight: .regular)
        textView.backgroundColor = NSColor(hex: "#0a0c10")
        textView.textColor = NSColor(hex: "#c9d1d9")
        
        let scrollView = NSScrollView()
        scrollView.documentView = textView
        scrollView.hasVerticalScroller = true
        return scrollView
    }
    
    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        guard let textView = scrollView.documentView as? NSTextView else { return }
        
        let attrString = NSMutableAttributedString()
        for line in logLines {
            let lineStr = NSAttributedString(
                string: "\(line.timestamp) \(line.message)\n",
                attributes: [
                    .foregroundColor: colorForType(line.type),
                    .font: NSFont.monospacedSystemFont(ofSize: 11, weight: .regular)
                ]
            )
            attrString.append(lineStr)
        }
        
        textView.textStorage?.setAttributedString(attrString)
        
        // Autoscroll if at bottom
        if context.coordinator.shouldAutoscroll {
            textView.scrollToEndOfDocument(nil)
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator()
    }
    
    class Coordinator {
        var shouldAutoscroll = true
    }
}
```

**Blinking caret**: Add via Timer + custom layer; honor `@Environment(\.accessibilityReduceMotion)`.

**ANSI parser**: Use SwiftTerm library or hand-rolled regex to map ANSI codes to NSAttributedString attributes.

---

## Run Streaming

### OpenCode stdout/stderr via Process + Pipe + AsyncStream

```swift
actor BenchmarkRunner {
    func runBenchmark(model: Model, ref: String) -> AsyncStream<LogLine> {
        AsyncStream { continuation in
            Task {
                let process = Process()
                process.executableURL = URL(fileURLWithPath: "/usr/local/bin/opencode")
                process.arguments = ["run", "--model", model.id, "--ref", ref]
                
                let pipe = Pipe()
                process.standardOutput = pipe
                process.standardError = pipe
                
                let handle = pipe.fileHandleForReading
                handle.readabilityHandler = { fileHandle in
                    let data = fileHandle.availableData
                    if data.isEmpty {
                        continuation.finish()
                        return
                    }
                    if let line = String(data: data, encoding: .utf8) {
                        let logLine = parseLogLine(line)
                        continuation.yield(logLine)
                    }
                }
                
                try? process.run()
                process.waitUntilExit()
                continuation.finish()
            }
        }
    }
}
```

**View model**: `@Observable` (modern macro) or `ObservableObject` + `@Published`

```swift
@Observable
class MissionControlViewModel {
    var logLines: [LogLine] = []
    var currentTask: Task?
    
    func startRun(runner: BenchmarkRunner, model: Model, ref: String) {
        currentTask = Task {
            for await line in runner.runBenchmark(model: model, ref: ref) {
                logLines.append(line)
            }
        }
    }
}
```

**Tauri event names** (bench:progress, bench:result) map directly to the AsyncStream above — same concept, different transport.

---

## Persistence

### File-backed runs/data/ (GitOps)
```swift
struct BenchmarkStore {
    let resultsURL = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent("runs/data")
    
    func saveBenchRow(_ row: BenchRow) throws {
        let filename = "run_\(row.timestamp.ISO8601Format())_\(row.taskId).json"
        let url = resultsURL.appendingPathComponent(filename)
        let data = try JSONEncoder().encode(row)
        try data.write(to: url)
    }
    
    func loadAllRuns() throws -> [BenchRow] {
        let urls = try FileManager.default.contentsOfDirectory(
            at: resultsURL,
            includingPropertiesForKeys: nil
        )
        return try urls.compactMap { url in
            guard url.pathExtension == "json" else { return nil }
            let data = try Data(contentsOf: url)
            return try JSONDecoder().decode(BenchRow.self, from: data)
        }
    }
}
```

**Watch directory for external git pulls**:
```swift
let source = DispatchSource.makeFileSystemObjectSource(
    fileDescriptor: open(resultsURL.path, O_EVTONLY),
    eventMask: .write,
    queue: .main
)
source.setEventHandler {
    Task { await reloadRuns() }
}
source.resume()
```

**Debounced writer**: Use DispatchQueue + asyncAfter to batch commits.

---

## Git Operations

### Shell-out to system git
```swift
func commitResults(message: String) throws {
    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/usr/bin/git")
    process.arguments = ["commit", "-m", message]
    process.currentDirectoryURL = resultsURL
    try process.run()
    process.waitUntilExit()
    guard process.terminationStatus == 0 else {
        throw GitError.commitFailed
    }
}
```

**Auto-commit toggle**: Check user pref before calling.
**Auto-push toggle**: Separate pref; run `git push` after commit if enabled.

---

## Keychain

### API keys via Security framework
```swift
func saveAPIKey(provider: String, key: String) throws {
    let query: [String: Any] = [
        kSecClass as String: kSecClassGenericPassword,
        kSecAttrAccount as String: "bigpowers.benchmark.\(provider)",
        kSecValueData as String: key.data(using: .utf8)!
    ]
    SecItemDelete(query as CFDictionary) // Remove old
    let status = SecItemAdd(query as CFDictionary, nil)
    guard status == errSecSuccess else {
        throw KeychainError.saveFailed
    }
}

func loadAPIKey(provider: String) -> String? {
    let query: [String: Any] = [
        kSecClass as String: kSecClassGenericPassword,
        kSecAttrAccount as String: "bigpowers.benchmark.\(provider)",
        kSecReturnData as String: true
    ]
    var result: AnyObject?
    let status = SecItemCopyMatching(query as CFDictionary, &result)
    guard status == errSecSuccess, let data = result as? Data else {
        return nil
    }
    return String(data: data, encoding: .utf8)
}
```

**Never write keys to providers.json**. Always check env first, then Keychain.

---

## Notifications

### UserNotifications for run complete/failed/regression
```swift
import UserNotifications

func requestNotificationPermission() {
    UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { granted, _ in
        // Store pref
    }
}

func sendRunCompleteNotification(run: BenchRow) {
    let content = UNMutableNotificationContent()
    content.title = "Run Complete"
    content.body = "\(run.modelName) · \(run.taskId) · Overall: \(run.overallScore)"
    content.sound = .default
    content.categoryIdentifier = "RUN_COMPLETE"
    
    let request = UNNotificationRequest(
        identifier: UUID().uuidString,
        content: content,
        trigger: nil
    )
    UNUserNotificationCenter.current().add(request)
}
```

**Actionable buttons**: Use `UNNotificationAction` with identifiers like "OPEN_RUN" / "DISMISS".

---

## Command Palette (⌘K)

### Custom Window + .searchable
```swift
Window("Command Palette", id: "command-palette") {
    CommandPaletteView()
}
.windowStyle(.hiddenTitleBar)
.defaultSize(width: 600, height: 400)
.keyboardShortcut("k", modifiers: .command)
```

**Global hotkey**: Use `NSEvent.addGlobalMonitorForEvents` or HotKey SPM package to register ⌘K system-wide (requires Accessibility permission).

```swift
NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { event in
    if event.modifierFlags.contains(.command) && event.charactersIgnoringModifiers == "k" {
        openCommandPalette()
    }
}
```

---

## Multi-Window

### Each WindowGroup gets @SceneStorage view model
```swift
struct MissionControlView: View {
    @Environment(BenchmarkStore.self) private var store // Shared
    @SceneStorage("missionControl.selectedModel") private var selectedModel: String?
    
    var body: some View {
        // ...
    }
}
```

**Shared data**: Pass app-level `@Observable BenchmarkStore` via `.environment`.

**Per-window state**: Use `@SceneStorage` for UI state like selected model, scroll position, filter state.

---

## Sleep Prevention

### IOPMAssertion during runs
```swift
import IOKit.pwr_mgt

var assertionID: IOPMAssertionID = 0

func preventSleep() {
    IOPMAssertionCreateWithName(
        kIOPMAssertionTypePreventUserIdleSystemSleep as CFString,
        IOPMAssertionLevel(kIOPMAssertionLevelOn),
        "BigPowers benchmark running" as CFString,
        &assertionID
    )
}

func allowSleep() {
    IOPMAssertionRelease(assertionID)
}
```

Call `preventSleep()` when run starts, `allowSleep()` on completion/cancel.

---

## Light / Dark Mode

### Color extensions with init(light:dark:)
```swift
extension Color {
    static let bg = Color(light: Color(hex: "#ffffff"), dark: Color(hex: "#0f1117"))
    static let fg = Color(light: Color(hex: "#1a1d23"), dark: Color(hex: "#e6e8ee"))
    static let accent = Color(light: Color(hex: "#14b8a6"), dark: Color(hex: "#2dd4bf"))
    // ... etc
    
    init(light: Color, dark: Color) {
        self.init(nsColor: NSColor(name: nil) { appearance in
            appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua ? NSColor(dark) : NSColor(light)
        }!)
    }
}
```

**Default**: `.colorScheme(.dark)` (canonical experience).
**User override**: `.preferredColorScheme(userPreference)` follows Settings picker.

---

## Accessibility

### Reduce Motion
```swift
@Environment(\.accessibilityReduceMotion) var reduceMotion

// Terminal caret
if reduceMotion {
    Circle().fill(Color.accent).opacity(0.7) // Steady
} else {
    Circle().fill(Color.accent)
        .animation(.easeInOut(duration: 1).repeatForever(autoreverses: true), value: blinking)
}
```

### VoiceOver labels
```swift
Chart { /* ... */ }
    .accessibilityLabel("Score evolution chart")
    .accessibilityValue("Overall score improved from 1.20 to 1.38 between v2.7.0 and v2.8.0")
```

**Charts**: Provide data-table fallback via `.accessibilityChartDescriptor`.

### Keyboard nav
All interactive elements are keyboard-focusable by default. Visible focus rings via `.focusable()`.

---

## Testing

### Swift Testing (modern framework)
```swift
import Testing
@testable import BigPowersBenchmark

@Test func benchRowDecoding() throws {
    let json = """
    {"timestamp":"2026-05-23T14:32:08Z","modelName":"Claude 3.5 Sonnet","taskId":"T01","code_pass":1,"artifact_score":2,"convention_score":2,"overallScore":1.5}
    """
    let data = json.data(using: .utf8)!
    let row = try JSONDecoder().decode(BenchRow.self, from: data)
    #expect(row.overallScore == 1.5)
}
```

**XCUITest**: Only for flows that exercise sheets/menus (e.g., Settings add-provider flow).

---

## Models Layer

### Keep existing BenchRow shape
```swift
struct BenchRow: Codable, Identifiable {
    let id: UUID
    let timestamp: Date
    let bigpowersRef: String
    let modelName: String
    let taskId: String
    let codePass: Int
    let artifactScore: Int
    let conventionScore: Int
    let overallScore: Double
    let duration: TimeInterval
    let cost: Double
    let workspace: String
    
    enum CodingKeys: String, CodingKey {
        case id, timestamp, modelName, taskId, workspace, duration, cost
        case bigpowersRef = "bigpowers_ref"
        case codePass = "code_pass"
        case artifactScore = "artifact_score"
        case conventionScore = "convention_score"
        case overallScore = "overall_score"
    }
}
```

**Formula**: `(codePass*2 + artifactScore + conventionScore) / 4`

**JSON shards**: Must round-trip identically with Tauri version.

---

## Summary of Key Mappings

| UI Element | SwiftUI Primitive |
|---|---|
| Sidebar | `NavigationSplitView` + `List` + `Label` |
| Toolbar | `.toolbar(content:)` + `ToolbarItemGroup` |
| Data table | `Table` + `TableColumn` |
| Charts | Swift Charts (`LineMark`, `BarMark`, etc) |
| Radar | `Canvas` + `Path` (polar coords) |
| Forms | `Form` + `Section` + `LabeledContent` |
| Modal | `.sheet(isPresented:)` |
| Inspector | `.inspector(isPresented:)` |
| Terminal | `NSViewRepresentable(NSTextView)` |
| Run streaming | `Process()` + `Pipe` + `AsyncStream` |
| Persistence | `FileManager` + `JSONEncoder` + `DispatchSource` |
| Git | `Process()` shell-out |
| Keychain | Security framework (`SecItemAdd` / `SecItemCopyMatching`) |
| Notifications | `UserNotifications` + `UNNotificationAction` |
| Command palette | Custom `Window` + `.searchable` + global hotkey |
| Multi-window | `WindowGroup` per destination + `@SceneStorage` |
| Sleep prevention | `IOPMAssertionCreateWithName` |
| Light/Dark | `Color(light:dark:)` + `.preferredColorScheme` |
| Reduce Motion | `@Environment(\.accessibilityReduceMotion)` |

---

## Next Steps for Swift Developer

1. **Clone BenchRow schema** from existing Tauri codebase — must round-trip JSON identically.
2. **Implement BenchmarkStore** with FileManager + JSONEncoder + directory watcher.
3. **Build NavigationSplitView shell** with sidebar destinations.
4. **Wrap NSTextView** for terminal panel; add ANSI parser.
5. **Implement BenchmarkRunner actor** with Process + Pipe + AsyncStream.
6. **Wire up Swift Charts** for score evolution, heatmaps, sparklines.
7. **Add Keychain integration** for API key storage.
8. **Test round-trip**: Run benchmark → write JSON shard → reload → verify scores match.

---

**End of handoff document.**