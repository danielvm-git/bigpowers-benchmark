import AppKit
import Foundation
import Logging

public enum AppLogger {
    private static let bootstrapLock = NSLock()
    private nonisolated(unsafe) static var bootstrapped = false

    public private(set) nonisolated(unsafe) static var logFileURL: URL = defaultLogURL()

    public static func defaultLogURL() -> URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Logs/BigPowersBenchmark/debug.ndjson")
    }

    public static func bootstrap(logURL: URL? = nil) {
        bootstrapLock.lock()
        defer { bootstrapLock.unlock() }
        guard !bootstrapped else { return }

        let url = logURL ?? defaultLogURL()
        logFileURL = url
        LoggingSystem.bootstrap { label in
            NDJSONLogHandler(label: label, logURL: url)
        }
        bootstrapped = true

        var metadata = Logger.Metadata()
        metadata["logPath"] = .string(url.path)
        if let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String {
            metadata["version"] = .string(version)
        }
        app.info("App logger bootstrapped", metadata: metadata)
    }

    public static var app: Logger {
        Logger(label: "app")
    }

    public static var daytona: Logger {
        Logger(label: "daytona")
    }

    public static var runner: Logger {
        Logger(label: "runner")
    }

    public static var store: Logger {
        Logger(label: "store")
    }

    public static var git: Logger {
        Logger(label: "git")
    }

    public static var settings: Logger {
        Logger(label: "settings")
    }

    public static var modelHealth: Logger {
        Logger(label: "modelHealth")
    }

    public static func copyDebugLogToClipboard(lineCount: Int = 100) {
        let content = DebugLogExporter.lastLines(from: logFileURL, count: lineCount)
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(content, forType: .string)
    }

    public static func revealLogFile() {
        let directory = logFileURL.deletingLastPathComponent()
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        if !FileManager.default.fileExists(atPath: logFileURL.path) {
            FileManager.default.createFile(atPath: logFileURL.path, contents: nil)
        }
        NSWorkspace.shared.activateFileViewerSelecting([logFileURL])
    }

    public static func exportLogFile(to destinationURL: URL) throws {
        do {
            try DebugLogExporter.exportLogFile(from: logFileURL, to: destinationURL)
        } catch {
            AppLogger.app.error("Failed to export log file: \(error)")
            throw error
        }
    }
}
