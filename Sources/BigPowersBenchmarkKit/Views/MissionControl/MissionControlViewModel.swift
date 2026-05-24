import Foundation
import Observation

@Observable @MainActor
public final class MissionControlViewModel {
    public var sandboxes: [Sandbox] = []
    public var selectedSandbox: Sandbox?
    public var selectedSuite: BenchmarkSuite? = BenchmarkSuite.allSuites.first {
        didSet {
            selectedTask = selectedSuite?.tasks.first
        }
    }

    public var selectedTask: BenchmarkTask? = BenchmarkTask.allTasks.first
    public var selectedModel: String = "openai/gpt-4o"
    public var runState: RunState = .idle
    public var logLines: [LogLine] = []
    public var errorMessage: String?

    // Score results from the run
    public var codePass: Int?
    public var artifactScore: Int?
    public var conventionScore: Int?
    public var overallScore: Double?

    /// Time tracking
    public var elapsedTime: TimeInterval = 0.0

    private let daytonaClient: DaytonaClientProtocol
    private let store: BenchmarkStore
    private let config: DaytonaConfig
    private var runTask: Task<Void, Never>?
    private var timerTask: Task<Void, Never>?

    public init(daytonaClient: DaytonaClientProtocol, store: BenchmarkStore, config: DaytonaConfig) {
        self.daytonaClient = daytonaClient
        self.store = store
        self.config = config
    }

    public func loadSandboxes() async {
        do {
            let allSandboxes = try await daytonaClient.listSandboxes()
            sandboxes = allSandboxes.filter(\.isRunnable)
            if selectedSandbox == nil {
                selectedSandbox = sandboxes.first
            }
        } catch {
            errorMessage = "Failed to load sandboxes: \(error.localizedDescription)"
        }
    }

    public func startRun() async {
        guard let sandbox = selectedSandbox, let task = selectedTask else { return }

        AppLogger.runner.info("User started run", metadata: [
            "taskId": .string(task.id),
            "sandboxId": .string(sandbox.id),
            "model": .string(selectedModel),
        ])

        runState = .running
        logLines = []
        errorMessage = nil
        elapsedTime = 0.0
        codePass = nil
        artifactScore = nil
        conventionScore = nil
        overallScore = nil

        let runner = BenchmarkRunner(daytonaClient: daytonaClient, store: store, config: config)
        let stream = runner.run(sandbox: sandbox, task: task, model: selectedModel)

        let runId = UUID()
        let startTime = Date()
        store.currentRun = RunProgress(runId: runId, taskId: task.id, elapsed: 0.0)

        timerTask = Task {
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(1))
                if Task.isCancelled { break }
                let elapsed = Date().timeIntervalSince(startTime)
                self.elapsedTime = elapsed
                self.store.currentRun?.elapsed = elapsed
            }
        }

        runTask = Task {
            for await event in stream {
                switch event {
                case let .logLine(line):
                    logLines.append(line)
                case let .phase(phase):
                    logLines.append(LogLine(
                        t: ISO8601DateFormatter().string(from: Date()),
                        kind: .info,
                        text: "Phase: \(phase.rawValue)"
                    ))
                case let .completed(row):
                    runState = .idle
                    codePass = row.codePass
                    artifactScore = row.artifactScore
                    conventionScore = row.conventionScore
                    overallScore = row.overallScore
                    store.currentRun = nil
                    timerTask?.cancel()
                case let .failed(error):
                    let message = LogSanitizer.sanitize(error.localizedDescription)
                    errorMessage = message
                    AppLogger.runner.error("Run failed in UI", metadata: [
                        "taskId": .string(task.id),
                        "error": .string(message),
                    ])
                    runState = .idle
                    store.currentRun = nil
                    timerTask?.cancel()
                }
            }
        }
    }

    public func stopRun() {
        AppLogger.runner.info("User stopped run")
        runTask?.cancel()
        runTask = nil
        timerTask?.cancel()
        timerTask = nil
        runState = .idle
        store.currentRun = nil
    }
}

public enum RunState: String, Sendable {
    case idle
    case running
    case stopping
}
