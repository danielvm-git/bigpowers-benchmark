@testable import BigPowersBenchmarkKit
import Foundation
import Logging
import Testing

@Suite("NDJSONLogHandler")
struct NDJSONLogHandlerTests {
    @Test("writes valid NDJSON with required fields")
    func writesValidNDJSON() throws {
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("debug-\(UUID().uuidString).ndjson")
        defer { try? FileManager.default.removeItem(at: tempURL) }

        let handler = NDJSONLogHandler(label: "test", logURL: tempURL)
        let event = LogEvent(
            level: .info,
            message: "Test message",
            metadata: ["taskId": .string("T01")],
            source: "test",
            file: "test.swift",
            function: "test",
            line: 1
        )
        handler.log(event: event)

        let content = try String(contentsOf: tempURL, encoding: .utf8)
        let line = content.trimmingCharacters(in: .whitespacesAndNewlines)
        let data = try #require(line.data(using: .utf8))
        let json = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])

        #expect(json["level"] as? String == "info")
        #expect(json["message"] as? String == "Test message")
        #expect(json["component"] as? String == "test")
        #expect(json["taskId"] as? String == "T01")
        #expect(json["timestamp"] != nil)
    }
}

@Suite("DebugLogExporter")
struct DebugLogExporterTests {
    @Test("returns last N lines")
    func lastLines() throws {
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("export-\(UUID().uuidString).ndjson")
        defer { try? FileManager.default.removeItem(at: tempURL) }

        let lines = (1 ... 5).map { "{\"line\":\($0)}" }.joined(separator: "\n") + "\n"
        try lines.write(to: tempURL, atomically: true, encoding: .utf8)

        let exported = DebugLogExporter.lastLines(from: tempURL, count: 2)
        #expect(exported.contains("{\"line\":4}"))
        #expect(exported.contains("{\"line\":5}"))
        #expect(!exported.contains("{\"line\":1}"))
    }

    @Test("exports full log file")
    func exportsFullLogFile() throws {
        let tempSourceURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("source-\(UUID().uuidString).ndjson")
        let tempDestinationURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("destination-\(UUID().uuidString).ndjson")
        defer {
            try? FileManager.default.removeItem(at: tempSourceURL)
            try? FileManager.default.removeItem(at: tempDestinationURL)
        }

        let testContent = "{\"message\":\"test log 1\"}\n{\"message\":\"test log 2\"}\n"
        try testContent.write(to: tempSourceURL, atomically: true, encoding: .utf8)

        try DebugLogExporter.exportLogFile(from: tempSourceURL, to: tempDestinationURL)

        let exportedContent = try String(contentsOf: tempDestinationURL, encoding: .utf8)
        #expect(exportedContent == testContent)
    }
}

@Suite("AppLogger")
struct AppLoggerTests {
    @Test("defaultLogURL uses BigPowersBenchmark debug.ndjson path")
    func defaultLogURLPath() {
        let url = AppLogger.defaultLogURL()
        #expect(url.path.hasSuffix("Library/Logs/BigPowersBenchmark/debug.ndjson"))
    }
}
