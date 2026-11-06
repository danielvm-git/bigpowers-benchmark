@testable import BigPowersBenchmarkKit
import Foundation
import Testing

@Suite("HarnessReportStore")
struct HarnessReportStoreTests {
    private func makeReportsDir() throws -> URL {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("harness-store-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    @Test("loads the newest JSON report")
    func loadsLatestReport() throws {
        let dir = try makeReportsDir()
        defer { try? FileManager.default.removeItem(at: dir) }

        try #"{"tasks":["old"],"arms":["vanilla"],"arms_summary":{}}"#
            .write(to: dir.appendingPathComponent("AB-2026-11-03.json"), atomically: true, encoding: .utf8)
        try #"{"tasks":["new"],"arms":["vanilla"],"arms_summary":{}}"#
            .write(to: dir.appendingPathComponent("AB-2026-11-04.json"), atomically: true, encoding: .utf8)

        let report = try HarnessReportStore(reportsDir: dir).loadLatestReport()
        #expect(report?.tasks == ["new"])
    }

    @Test("loads run shards and the live file")
    func loadsRecords() throws {
        let dir = try makeReportsDir()
        defer { try? FileManager.default.removeItem(at: dir) }

        let line = #"{"task":"ab-11","arm":"vanilla","run":1,"pass":true}"# + "\n"
        try line.write(
            to: dir.appendingPathComponent("ab-runs-2026-11-04.jsonl"),
            atomically: true,
            encoding: .utf8
        )
        try line.write(
            to: dir.appendingPathComponent("ab-live.jsonl"),
            atomically: true,
            encoding: .utf8
        )

        let store = HarnessReportStore(reportsDir: dir)
        #expect(try store.loadRecords().count == 1)
        #expect(try store.loadLiveRecords().count == 1)
    }

    @Test("an empty reports directory is not an error")
    func emptyDirectory() throws {
        let dir = try makeReportsDir()
        defer { try? FileManager.default.removeItem(at: dir) }
        let store = HarnessReportStore(reportsDir: dir)
        #expect(try store.loadLatestReport() == nil)
        #expect(try store.loadRecords().isEmpty)
        #expect(try store.loadLiveRecords().isEmpty)
    }
}
