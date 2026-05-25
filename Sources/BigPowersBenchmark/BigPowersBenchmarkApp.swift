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
    private let hostRunConfig = HostRunConfig()
    private let providerStore = ProviderStore()
    private let modelHealthHistoryStore = ModelHealthHistoryStore()
    private let modelIntelStore = ModelIntelStore()
    private let modelHealthViewModel: ModelHealthViewModel
    private let modelRegistry = ModelRegistry()
    private let modelHealthColumnStore = ModelHealthColumnCustomizationStore()

    init() {
        try? modelIntelStore.loadFromDisk()
        modelHealthViewModel = ModelHealthViewModel(intelStore: modelIntelStore)
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(benchmarkStore)
                .environment(themeManager)
                .environment(daytonaConfig)
                .environment(hostRunConfig)
                .environment(providerStore)
                .environment(modelHealthHistoryStore)
                .environment(modelIntelStore)
                .environment(modelHealthViewModel)
                .environment(modelRegistry)
                .environment(modelHealthColumnStore)
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
                .environment(hostRunConfig)
                .environment(providerStore)
                .environment(modelHealthHistoryStore)
                .environment(modelIntelStore)
                .environment(modelHealthViewModel)
                .environment(modelRegistry)
                .environment(modelHealthColumnStore)
        }

        WindowGroup(id: "run-explorer") {
            RunExplorerView()
                .environment(benchmarkStore)
                .environment(themeManager)
                .environment(daytonaConfig)
                .environment(hostRunConfig)
                .environment(providerStore)
                .environment(modelHealthHistoryStore)
                .environment(modelIntelStore)
                .environment(modelHealthViewModel)
                .environment(modelRegistry)
                .environment(modelHealthColumnStore)
        }

        Settings {
            SettingsView()
                .environment(benchmarkStore)
                .environment(themeManager)
                .environment(daytonaConfig)
                .environment(hostRunConfig)
                .environment(providerStore)
                .environment(modelHealthHistoryStore)
                .environment(modelIntelStore)
                .environment(modelHealthViewModel)
                .environment(modelRegistry)
                .environment(modelHealthColumnStore)
        }

        MenuBarExtra("BigPowers", systemImage: "gauge.with.dots.needle.bottom.50percent") {
            MenuBarContent()
                .environment(benchmarkStore)
                .environment(themeManager)
                .environment(daytonaConfig)
                .environment(hostRunConfig)
                .environment(providerStore)
                .environment(modelHealthHistoryStore)
                .environment(modelIntelStore)
                .environment(modelHealthViewModel)
                .environment(modelRegistry)
                .environment(modelHealthColumnStore)
        }
        .menuBarExtraStyle(.window)
    }
}
