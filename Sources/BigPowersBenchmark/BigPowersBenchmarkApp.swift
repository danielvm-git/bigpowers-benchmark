import AppKit
import BigPowersBenchmarkKit
import Logging
import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_: Notification) {
        AppLogger.bootstrap()
        var metadata = Logger.Metadata()
        metadata["baseURL"] = .string(UserDefaults.standard.string(forKey: "bigpowers.daytona.baseURL") ?? "")
        AppLogger.app.info("App launched", metadata: metadata)
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
    }
}

@main
struct BigPowersBenchmarkApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    private let benchmarkStore = BenchmarkStore()
    private let themeManager = ThemeManager()
    private let daytonaConfig = DaytonaConfig()
    private let providerStore = ProviderStore()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(benchmarkStore)
                .environment(themeManager)
                .environment(daytonaConfig)
                .environment(providerStore)
        }
        .commands {
            CommandGroup(after: .help) {
                Button("Copy Debug Log") {
                    AppLogger.copyDebugLogToClipboard()
                }
                .keyboardShortcut("L", modifiers: [.command, .shift])

                Button("Reveal Log File") {
                    AppLogger.revealLogFile()
                }
            }
        }

        WindowGroup(id: "mission-control") {
            MissionControlView()
                .environment(benchmarkStore)
                .environment(themeManager)
                .environment(daytonaConfig)
                .environment(providerStore)
        }

        WindowGroup(id: "run-explorer") {
            RunExplorerView()
                .environment(benchmarkStore)
                .environment(themeManager)
                .environment(daytonaConfig)
                .environment(providerStore)
        }

        Settings {
            SettingsView()
                .environment(benchmarkStore)
                .environment(themeManager)
                .environment(daytonaConfig)
                .environment(providerStore)
        }

        MenuBarExtra("BigPowers", systemImage: "gauge.with.dots.needle.bottom.50percent") {
            MenuBarContent()
                .environment(benchmarkStore)
                .environment(themeManager)
                .environment(daytonaConfig)
                .environment(providerStore)
        }
        .menuBarExtraStyle(.window)
    }
}
