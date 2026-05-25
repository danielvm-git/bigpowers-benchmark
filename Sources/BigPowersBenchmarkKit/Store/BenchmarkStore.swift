import Foundation
import Observation

@Observable
// @unchecked: watchSource and pendingWatchTask are mutated only from @MainActor context
// (startWatching, stopWatching, and the inner @MainActor tasks in makeWatchSource).
public final class BenchmarkStore: @unchecked Sendable {
    public static let runsDidChangeNotification = Notification.Name("BenchmarkStore.runsDidChange")

    public let runsURL: URL
    public private(set) var runs: [BenchRow] = []
    public private(set) var loadErrors: [URL: Error] = [:]
    public var currentRun: RunProgress?
    public var autoCommit = false
    public var autoPush = false

    /// Optimistic default: assume repo exists until checkGitRepoStatus() confirms otherwise.
    public private(set) var isRunsDirectoryGitRepo = true

    private let gitService: GitServiceProtocol
    private var watchSource: DispatchSourceFileSystemObject?
    private var pendingWatchTask: Task<Void, Never>?

    public init(
        runsURL: URL = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("runs/data"),
        gitService: GitServiceProtocol = GitService()
    ) {
        self.runsURL = runsURL
        self.gitService = gitService
    }

    public func checkGitRepoStatus() {
        Task.detached { [gitService, runsURL, weak self] in
            let isRepo = gitService.isGitRepo(at: runsURL)
            await MainActor.run { self?.isRunsDirectoryGitRepo = isRepo }
        }
    }

    public func saveBenchRow(_ row: BenchRow) throws {
        try FileManager.default.createDirectory(at: runsURL, withIntermediateDirectories: true)
        let fileName = "run_\(isoTimestamp(row.timestamp))_\(row.taskId).json"
        let fileURL = runsURL.appendingPathComponent(fileName)
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(row)
        try data.write(to: fileURL, options: .atomic)

        AppLogger.store.info("Saved BenchRow", metadata: [
            "runId": .string(row.id.uuidString),
            "taskId": .string(row.taskId),
            "path": .string(fileURL.path),
        ])

        if autoCommit {
            try gitService.commit(message: "chore: add run \(row.id)", in: runsURL)
            if autoPush {
                try gitService.push(in: runsURL)
            }
        }
    }

    public func saveBenchFailureRow(_ row: BenchFailureRow) throws {
        try FileManager.default.createDirectory(at: runsURL, withIntermediateDirectories: true)
        let fileName = "\(BenchFailureRow.filePrefix)\(isoTimestamp(row.timestamp))_\(row.taskId).json"
        let fileURL = runsURL.appendingPathComponent(fileName)
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(row)
        try data.write(to: fileURL, options: .atomic)

        AppLogger.store.info("Saved BenchFailureRow", metadata: [
            "runId": .string(row.id.uuidString),
            "taskId": .string(row.taskId),
            "path": .string(fileURL.path),
            "errorKind": .string(row.errorKind),
        ])
    }

    public func loadAllRuns() throws {
        let urls = try FileManager.default.contentsOfDirectory(
            at: runsURL,
            includingPropertiesForKeys: nil
        ).filter { $0.pathExtension == "json" && !$0.lastPathComponent.hasPrefix(BenchFailureRow.filePrefix) }

        var loaded: [BenchRow] = []
        var errors: [URL: Error] = [:]
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        for url in urls {
            do {
                let data = try Data(contentsOf: url)
                let row = try decoder.decode(BenchRow.self, from: data)
                loaded.append(row)
            } catch {
                errors[url.standardizedFileURL] = error
                AppLogger.store.warning("Failed to decode BenchRow shard", metadata: [
                    "path": .string(url.path),
                    "error": .string(LogSanitizer.sanitize(error.localizedDescription)),
                ])
            }
        }

        runs = loaded
        loadErrors = errors
    }

    @MainActor
    public func startWatching() {
        stopWatching()
        let fileDescriptor = open(runsURL.path, O_EVTONLY)
        guard fileDescriptor >= 0 else { return }
        watchSource = makeWatchSource(fileDescriptor: fileDescriptor)
        watchSource?.resume()
    }

    private func makeWatchSource(fileDescriptor: Int32) -> DispatchSourceFileSystemObject {
        let source = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: fileDescriptor,
            eventMask: .write,
            queue: DispatchQueue.global()
        )
        source.setEventHandler { [weak self] in
            guard let self else { return }
            // Hop to main actor so pendingWatchTask mutations are actor-isolated.
            Task { @MainActor [weak self] in
                guard let self else { return }
                pendingWatchTask?.cancel()
                pendingWatchTask = Task { @MainActor [weak self] in
                    guard let self else { return }
                    try? await Task.sleep(for: .milliseconds(200))
                    try? loadAllRuns()
                    NotificationCenter.default.post(
                        name: BenchmarkStore.runsDidChangeNotification,
                        object: self
                    )
                }
            }
        }
        source.setCancelHandler {
            close(fileDescriptor)
        }
        return source
    }

    @MainActor
    private func stopWatching() {
        pendingWatchTask?.cancel()
        pendingWatchTask = nil
        watchSource?.cancel()
        watchSource = nil
    }

    private func isoTimestamp(_ date: Date) -> String {
        let fmt = ISO8601DateFormatter()
        fmt.formatOptions = [.withInternetDateTime, .withDashSeparatorInDate, .withColonSeparatorInTime]
        return fmt.string(from: date)
            .replacingOccurrences(of: ":", with: "-")
            .replacingOccurrences(of: "+", with: "Z")
    }
}

public struct RunProgress: Sendable {
    public var runId: UUID
    public var taskId: String
    public var elapsed: TimeInterval
    public var currentScore: Double?

    public init(runId: UUID, taskId: String, elapsed: TimeInterval, currentScore: Double? = nil) {
        self.runId = runId
        self.taskId = taskId
        self.elapsed = elapsed
        self.currentScore = currentScore
    }
}
