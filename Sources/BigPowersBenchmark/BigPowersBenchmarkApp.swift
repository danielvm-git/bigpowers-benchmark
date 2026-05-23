import BigPowersBenchmarkKit
import SwiftUI

@main
struct BigPowersBenchmarkApp: App {
    private let benchmarkStore = BenchmarkStore()
    private let themeManager = ThemeManager()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(benchmarkStore)
                .environment(themeManager)
        }

        WindowGroup(id: "mission-control") {
            MissionControlView()
                .environment(benchmarkStore)
                .environment(themeManager)
        }

        WindowGroup(id: "run-explorer") {
            RunExplorerView()
                .environment(benchmarkStore)
                .environment(themeManager)
        }

        MenuBarExtra("BigPowers", systemImage: "gauge.with.dots.needle.bottom.50percent") {
            MenuBarContent()
                .environment(benchmarkStore)
                .environment(themeManager)
        }
        .menuBarExtraStyle(.window)
    }
}
