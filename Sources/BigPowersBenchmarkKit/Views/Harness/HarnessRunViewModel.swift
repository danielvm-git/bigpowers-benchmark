import Foundation
import Observation

@MainActor
@Observable
public final class HarnessRunViewModel {
    public var runnerRoot: String
    public var subjectRoot: String = ""
    public var reportsDir: String
    public var tasksText: String = "ab-11"
    public var armsText: String = "vanilla,bigpowers"
    public var runsPerTask: Int = 1
    public var adapter: String = "pi-docker"

    public private(set) var logLines: [String] = []
    public private(set) var records: [ABRunRecord] = []
    public private(set) var latestReport: ABReport?
    public private(set) var isRunning = false
    public var errorMessage: String?

    private var runTask: Task<Void, Never>?

    public init(runnerRoot: String? = nil) {
        let root = runnerRoot ?? FileManager.default.currentDirectoryPath
        self.runnerRoot = root
        reportsDir = URL(fileURLWithPath: root)
            .appendingPathComponent("benchmarks/reports", isDirectory: true)
            .path
    }

    public var canRun: Bool {
        !isRunning && !subjectRoot.trimmingCharacters(in: .whitespaces).isEmpty
    }

    public func run() {
        guard canRun else { return }
        let command: HarnessCommand
        do {
            command = try makeCommand()
        } catch {
            errorMessage = error.localizedDescription
            return
        }

        errorMessage = nil
        logLines = []
        records = []
        latestReport = nil
        isRunning = true

        runTask = Task { [weak self] in
            guard let self else { return }
            for await event in HarnessRunner().run(command) {
                switch event {
                case let .line(line):
                    appendLog(line)
                case let .record(record):
                    records.append(record)
                case let .completed(_, report):
                    latestReport = report
                case let .failed(error):
                    errorMessage = error.localizedDescription
                }
            }
            isRunning = false
        }
    }

    public func cancel() {
        runTask?.cancel()
        runTask = nil
        isRunning = false
    }

    private func makeCommand() throws -> HarnessCommand {
        let tasks = tasksText.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        let arms = armsText.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        guard !tasks.isEmpty else { throw HarnessError.reportUnreadable("no tasks selected") }
        guard !arms.isEmpty else { throw HarnessError.reportUnreadable("no arms selected") }

        let runner = URL(fileURLWithPath: runnerRoot, isDirectory: true)
        let reports = reportsDir.isEmpty
            ? runner.appendingPathComponent("benchmarks/reports", isDirectory: true)
            : URL(fileURLWithPath: reportsDir, isDirectory: true)
        return HarnessCommand(
            runnerRoot: runner,
            subjectRoot: URL(fileURLWithPath: subjectRoot, isDirectory: true),
            tasks: tasks,
            arms: arms,
            runsPerTask: runsPerTask,
            adapter: adapter,
            outDir: reports,
            jsonOut: reports.appendingPathComponent("AB-latest.json")
        )
    }

    private func appendLog(_ line: String) {
        logLines.append(line)
        if logLines.count > 2000 {
            logLines.removeFirst(logLines.count - 2000)
        }
    }
}
