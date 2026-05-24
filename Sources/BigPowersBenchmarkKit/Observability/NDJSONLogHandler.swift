import Foundation
import Logging

public struct NDJSONLogHandler: LogHandler {
    private let label: String
    private let logURL: URL
    private static let writeLock = NSLock()

    public var logLevel: Logger.Level = .info
    public var metadata: Logger.Metadata = [:]

    public init(label: String, logURL: URL) {
        self.label = label
        self.logURL = logURL
        let directory = logURL.deletingLastPathComponent()
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        if !FileManager.default.fileExists(atPath: logURL.path) {
            FileManager.default.createFile(atPath: logURL.path, contents: nil)
        }
    }

    public subscript(metadataKey key: String) -> Logger.Metadata.Value? {
        get { metadata[key] }
        set { metadata[key] = newValue }
    }

    public func log(event: LogEvent) {
        var entry: [String: String] = [
            "level": event.level.rawValue,
            "timestamp": Self.timestamp(),
            "message": LogSanitizer.sanitize("\(event.message)"),
            "component": label,
        ]

        let combined = Self.prepareMetadata(base: metadata, explicit: event.metadata)
        for (key, value) in combined {
            entry[key] = LogSanitizer.sanitize("\(value)")
        }

        guard JSONSerialization.isValidJSONObject(entry),
              let data = try? JSONSerialization.data(withJSONObject: entry),
              var line = String(data: data, encoding: .utf8)
        else {
            return
        }
        line += "\n"
        Self.append(line, to: logURL)
    }

    private static func timestamp() -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter.string(from: Date())
    }

    private static func append(_ line: String, to url: URL) {
        writeLock.lock()
        defer { writeLock.unlock() }
        guard let data = line.data(using: .utf8) else { return }
        if let handle = FileHandle(forWritingAtPath: url.path) {
            handle.seekToEndOfFile()
            handle.write(data)
            try? handle.close()
        } else {
            try? data.write(to: url)
        }
    }

    private static func prepareMetadata(
        base: Logger.Metadata,
        explicit: Logger.Metadata?
    ) -> Logger.Metadata {
        var result = base
        if let explicit {
            result.merge(explicit) { _, new in new }
        }
        return result
    }
}
