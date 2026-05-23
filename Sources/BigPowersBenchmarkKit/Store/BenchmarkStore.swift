import Foundation
import Observation

@Observable
public final class BenchmarkStore: @unchecked Sendable {
    public static let runsDidChangeNotification = Notification.Name("BenchmarkStore.runsDidChange")

    public let runsURL: URL
    public private(set) var runs: [BenchRow] = []
    public private(set) var loadErrors: [URL: Error] = [:]
    public var currentRun: RunProgress?
    public var autoCommit = false
    public var autoPush = false

    private let gitService: GitServiceProtocol
    private var watchSource: DispatchSourceFileSystemObject?
    private var watchFD: Int32 = -1

    public var isRunsDirectoryGitRepo: Bool {
        gitService.isGitRepo(at: runsURL)
    }

    public init(
        runsURL: URL = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("runs/data"),
        gitService: GitServiceProtocol = GitService()
    ) {
        self.runsURL = runsURL
        self.gitService = gitService
    }

    public func saveBenchRow(_ row: BenchRow) throws {
        try FileManager.default.createDirectory(at: runsURL, withIntermediateDirectories: true)
        let fileName = "run_\(isoTimestamp(row.timestamp))_\(row.taskId).json"
        let fileURL = runsURL.appendingPathComponent(fileName)
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(row)
        try data.write(to: fileURL, options: .atomic)

        if autoCommit {
            try gitService.commit(message: "chore: add run \(row.id)", in: runsURL)
            if autoPush {
                try gitService.push(in: runsURL)
            }
        }
    }

    public func loadAllRuns() throws {
        let urls = try FileManager.default.contentsOfDirectory(
            at: runsURL,
            includingPropertiesForKeys: nil
        ).filter { $0.pathExtension == "json" }

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
            }
        }

        runs = loaded
        loadErrors = errors
    }

    public func startWatching() {
        stopWatching()
        let fileDescriptor = open(runsURL.path, O_EVTONLY)
        guard fileDescriptor >= 0 else { return }
        watchFD = fileDescriptor

        let source = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: fileDescriptor,
            eventMask: .write,
            queue: DispatchQueue.global()
        )
        source.setEventHandler { [weak self] in
            guard let self else { return }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                try? self.loadAllRuns()
                NotificationCenter.default.post(
                    name: BenchmarkStore.runsDidChangeNotification,
                    object: self
                )
            }
        }
        source.setCancelHandler { [weak self] in
            guard let openFD = self?.watchFD, openFD >= 0 else { return }
            close(openFD)
            self?.watchFD = -1
        }
        source.resume()
        watchSource = source
    }

    private func stopWatching() {
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
