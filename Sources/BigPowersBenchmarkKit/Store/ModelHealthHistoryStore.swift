import Foundation
import Observation

@Observable
public final class ModelHealthHistoryStore: @unchecked Sendable {
    public static let defaultDirectory: URL = {
        let appSupport = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first ?? FileManager.default.homeDirectoryForCurrentUser
        let bundleID = Bundle.main.bundleIdentifier ?? "BigPowersBenchmark"
        return appSupport
            .appendingPathComponent(bundleID)
            .appendingPathComponent("model-health")
    }()

    public let snapshotsURL: URL
    public private(set) var snapshots: [ModelHealthSnapshot] = []

    public init(snapshotsURL: URL = ModelHealthHistoryStore.defaultDirectory) {
        self.snapshotsURL = snapshotsURL
    }

    public func save(_ snapshot: ModelHealthSnapshot) throws {
        try FileManager.default.createDirectory(
            at: snapshotsURL,
            withIntermediateDirectories: true
        )
        let fileName = "snapshot_\(isoTimestamp(snapshot.timestamp)).json"
        let fileURL = snapshotsURL.appendingPathComponent(fileName)
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.sortedKeys]
        let data = try encoder.encode(snapshot)
        try data.write(to: fileURL, options: .atomic)

        AppLogger.modelHealth.info("Model health snapshot saved", metadata: [
            "action": .string("snapshotSaved"),
            "snapshotId": .string(snapshot.id.uuidString),
            "rowCount": .stringConvertible(snapshot.rows.count),
            "scope": .string(snapshot.scope),
        ])

        try loadAll()
    }

    public func loadAll() throws {
        guard FileManager.default.fileExists(atPath: snapshotsURL.path) else {
            snapshots = []
            return
        }

        let urls = try FileManager.default.contentsOfDirectory(
            at: snapshotsURL,
            includingPropertiesForKeys: nil
        ).filter { $0.pathExtension == "json" }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        var loaded: [ModelHealthSnapshot] = []
        for url in urls {
            do {
                let data = try Data(contentsOf: url)
                try loaded.append(decoder.decode(ModelHealthSnapshot.self, from: data))
            } catch {
                AppLogger.modelHealth.warning("Failed to decode model health snapshot", metadata: [
                    "action": .string("snapshotDecodeFailed"),
                    "path": .string(url.path),
                    "error": .string(LogSanitizer.sanitize(error.localizedDescription)),
                ])
            }
        }

        snapshots = loaded.sorted { $0.timestamp > $1.timestamp }
    }

    private func isoTimestamp(_ date: Date) -> String {
        let fmt = ISO8601DateFormatter()
        fmt.formatOptions = [.withInternetDateTime, .withDashSeparatorInDate, .withColonSeparatorInTime]
        return fmt.string(from: date)
            .replacingOccurrences(of: ":", with: "-")
            .replacingOccurrences(of: "+", with: "Z")
    }
}
