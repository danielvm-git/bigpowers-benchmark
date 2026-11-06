import Foundation

/// Reads harness output from `benchmarks/reports/`. It never writes: the runner owns the files.
public struct HarnessReportStore: Sendable {
    public let reportsDir: URL

    public init(reportsDir: URL) {
        self.reportsDir = reportsDir
    }

    public func reportURLs() throws -> [URL] {
        try FileManager.default.contentsOfDirectory(
            at: reportsDir,
            includingPropertiesForKeys: nil
        )
        .filter { $0.pathExtension == "json" && $0.lastPathComponent.hasPrefix("AB-") }
        .sorted { $0.lastPathComponent > $1.lastPathComponent }
    }

    public func loadLatestReport() throws -> ABReport? {
        guard let url = try reportURLs().first else { return nil }
        return try JSONDecoder().decode(ABReport.self, from: Data(contentsOf: url))
    }

    public func loadRecords() throws -> [ABRunRecord] {
        try recordURLs().flatMap(decodeJSONLines)
    }

    public func loadLiveRecords() throws -> [ABRunRecord] {
        let live = reportsDir.appendingPathComponent("ab-live.jsonl")
        guard FileManager.default.fileExists(atPath: live.path) else { return [] }
        return try decodeJSONLines(live)
    }

    private func recordURLs() throws -> [URL] {
        try FileManager.default.contentsOfDirectory(
            at: reportsDir,
            includingPropertiesForKeys: nil
        )
        .filter { $0.lastPathComponent.hasPrefix("ab-runs-") && $0.pathExtension == "jsonl" }
        .sorted { $0.lastPathComponent < $1.lastPathComponent }
    }

    private func decodeJSONLines(_ url: URL) throws -> [ABRunRecord] {
        let text = try String(contentsOf: url, encoding: .utf8)
        return text.split(separator: "\n").compactMap { line in
            try? JSONDecoder().decode(ABRunRecord.self, from: Data(line.utf8))
        }
    }
}
