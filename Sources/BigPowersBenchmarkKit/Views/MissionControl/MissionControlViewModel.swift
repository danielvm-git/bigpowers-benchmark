// swiftlint:disable file_length type_body_length
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
    public var selectedModel: String = ""
    public var runState: RunState = .idle
    public var logLines: [LogLine] = []
    public var errorMessage: String?

    public var codePass: Int?
    public var artifactScore: Int?
    public var conventionScore: Int?
    public var overallScore: Double?

    public var elapsedTime: TimeInterval = 0.0
    public var elapsedCost: Double = 0.0

    public var taskResults: [TaskResult] = []
    public var scoreHistory: [BenchRow] = []
    public var historicalRange: HistoricalRange = .last10
    public var visibleTaskIds: Set<String> = []
    public var isTestingConnection = false
    public var connectionStatus: ConnectionTestResult?

    public var isHostMode: Bool {
        hostRunConfig.executionMode == .host
    }

    public var workspacePath: String {
        if isHostMode {
            return (hostRunConfig.worktreeRoot as NSString).lastPathComponent
                + "/run_\(activeRunFolderSuffix())"
        }
        if let sandbox = selectedSandbox {
            return sandbox.name.isEmpty ? sandbox.id : sandbox.name
        }
        return "—"
    }

    public var activeTaskId: String? {
        taskResults.first(where: { $0.status == .active })?.id
    }

    public var selectedModelTier: String {
        let match = StaticModelCatalogs.all.first {
            $0.id == selectedModel || $0.apiModelId == selectedModel
        }
        return match?.tier.rawValue.capitalized ?? "Standard"
    }

    public var filteredHistory: [BenchRow] {
        let sorted = scoreHistory.sorted { $0.timestamp < $1.timestamp }
        switch historicalRange {
        case .last5:
            return Array(sorted.suffix(5))
        case .last10:
            return Array(sorted.suffix(10))
        case .all:
            return sorted
        }
    }

    public var filteredLogLines: [LogLine] {
        guard let currentLogTaskId else { return logLines }
        if visibleTaskIds.isEmpty || visibleTaskIds.contains(currentLogTaskId) {
            return logLines
        }
        return []
    }

    public var overallSparkData: [Double] {
        sparkValues { $0.overallScore }
    }

    public var codePassSparkData: [Double] {
        sparkValues { Double($0.codePass) }
    }

    public var artifactSparkData: [Double] {
        sparkValues { Double($0.artifactScore) }
    }

    public var conventionSparkData: [Double] {
        sparkValues { Double($0.conventionScore) }
    }

    public var overallMetricDelta: Double? {
        metricDelta { $0.overallScore }
    }

    public var codePassMetricDelta: Double? {
        metricDelta { Double($0.codePass) }
    }

    public var artifactMetricDelta: Double? {
        metricDelta { Double($0.artifactScore) }
    }

    public var conventionMetricDelta: Double? {
        metricDelta { Double($0.conventionScore) }
    }

    private let daytonaClient: DaytonaClientProtocol
    private let store: BenchmarkStore
    private let daytonaConfig: DaytonaConfig
    private let hostRunConfig: HostRunConfig
    private let intelStore: ModelIntelStore?
    private var runTask: Task<Void, Never>?
    private var timerTask: Task<Void, Never>?
    private var currentLogTaskId: String?
    private var activeRunStartedAt = Date()

    public init(
        daytonaClient: DaytonaClientProtocol,
        store: BenchmarkStore,
        daytonaConfig: DaytonaConfig,
        hostRunConfig: HostRunConfig,
        intelStore: ModelIntelStore? = nil
    ) {
        self.daytonaClient = daytonaClient
        self.store = store
        self.daytonaConfig = daytonaConfig
        self.hostRunConfig = hostRunConfig
        self.intelStore = intelStore
    }

    public func benchCandidateModels() -> [ModelIntelProfile] {
        guard let intelStore else { return [] }
        let candidates = intelStore.profiles.values
            .filter(\.benchCandidate)
            .sorted { $0.label.localizedCaseInsensitiveCompare($1.label) == .orderedAscending }
        if isHostMode {
            return candidates.filter(HostRunModelResolver.isHostCompatible)
        }
        return candidates
    }

    public func loadSandboxes() async {
        guard !isHostMode else {
            sandboxes = []
            selectedSandbox = nil
            return
        }

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

    public func testConnection() async {
        isTestingConnection = true
        defer { isTestingConnection = false }

        let result = await daytonaClient.pingDetailed()
        switch result {
        case .success:
            connectionStatus = .ok
        case let .failure(message):
            connectionStatus = .failed(message)
        }
    }

    public func toggleTaskFilter(_ taskId: String) {
        if visibleTaskIds.contains(taskId) {
            visibleTaskIds.remove(taskId)
        } else {
            visibleTaskIds.insert(taskId)
        }
    }

    public func copyFilteredLogs() -> String {
        filteredLogLines.map { "[\($0.t)] \($0.text)" }.joined(separator: "\n")
    }

    public func startRun() async {
        guard let selectedTask else { return }
        guard !selectedModel.isEmpty else { return }
        if !isHostMode, selectedSandbox == nil { return }

        let suiteTasks = selectedSuite?.tasks ?? [selectedTask]
        guard let firstTask = suiteTasks.first else { return }

        AppLogger.runner.info("User started run", metadata: [
            "taskId": .string(firstTask.id),
            "suiteTaskCount": .stringConvertible(suiteTasks.count),
            "model": .string(selectedModel),
            "executionMode": .string(hostRunConfig.executionMode.rawValue),
        ])

        runState = .running
        logLines = []
        errorMessage = nil
        elapsedTime = 0.0
        elapsedCost = 0.0
        codePass = nil
        artifactScore = nil
        conventionScore = nil
        overallScore = nil
        connectionStatus = nil

        buildTaskResults(activeTask: firstTask)
        currentLogTaskId = firstTask.id
        activeRunStartedAt = Date()

        let runnerModel: String
        let catalogModelId: String?
        if isHostMode {
            do {
                runnerModel = try HostRunModelResolver.opencodeModelSlug(
                    catalogModelId: selectedModel,
                    profile: intelStore?.profiles[selectedModel]
                )
                catalogModelId = selectedModel
            } catch {
                errorMessage = LogSanitizer.sanitize(error.localizedDescription)
                runState = .idle
                AppLogger.runner.error("Host run blocked", metadata: [
                    "taskId": .string(firstTask.id),
                    "model": .string(selectedModel),
                    "error": .string(errorMessage ?? ""),
                ])
                return
            }
        } else {
            runnerModel = selectedModel
            catalogModelId = nil
        }

        let executor: any RunExecutorProtocol
        if isHostMode {
            executor = HostRunExecutor(store: store, config: hostRunConfig)
        } else if let sandbox = selectedSandbox {
            executor = DaytonaRunExecutor(
                daytonaClient: daytonaClient,
                store: store,
                config: daytonaConfig,
                sandbox: sandbox
            )
        } else {
            return
        }

        let runId = UUID()
        let startTime = Date()
        store.currentRun = RunProgress(runId: runId, taskId: firstTask.id, elapsed: 0.0)

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
            await runSuiteTasks(
                suiteTasks,
                executor: executor,
                runnerModel: runnerModel,
                catalogModelId: catalogModelId
            )
        }
    }

    /// Runs each task in order; keeps `runState` and the elapsed timer alive until the suite finishes.
    func runSuiteTasks(
        _ tasks: [BenchmarkTask],
        executor: any RunExecutorProtocol,
        runnerModel: String,
        catalogModelId: String?
    ) async {
        for task in tasks {
            guard !Task.isCancelled else { break }

            activateTaskInStepper(task.id)
            currentLogTaskId = task.id
            store.currentRun?.taskId = task.id
            loadScoreHistory(model: selectedModel, taskId: task.id)
            appendSuiteBoundaryLog(task)

            let stream = executor.run(
                task: task,
                model: runnerModel,
                catalogModelId: catalogModelId
            )

            var taskFailed = false
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
                    codePass = row.codePass
                    artifactScore = row.artifactScore
                    conventionScore = row.conventionScore
                    overallScore = row.overallScore
                    elapsedCost += row.cost
                    completeTaskResult(taskId: task.id, row: row)
                    scoreHistory.append(row)
                    try? intelStore?.ingest(row: row)
                    appendTaskCompleteLog(taskId: task.id, row: row)
                case let .failed(error):
                    handleTaskFailure(task: task, error: error)
                    taskFailed = true
                }
            }

            if taskFailed { break }
        }

        finishSuiteRun()
    }

    public func stopRun() {
        AppLogger.runner.info("User stopped run")
        runTask?.cancel()
        runTask = nil
        if let activeId = activeTaskId {
            failTaskResult(taskId: activeId)
        }
        finishSuiteRun()
    }

    private func activateTaskInStepper(_ taskId: String) {
        guard let index = taskResults.firstIndex(where: { $0.id == taskId }) else { return }
        taskResults[index].status = .active
    }

    private func appendSuiteBoundaryLog(_ task: BenchmarkTask) {
        logLines.append(LogLine(
            t: ISO8601DateFormatter().string(from: Date()),
            kind: .cmd,
            text: "Starting \(task.id): \(task.name)"
        ))
    }

    private func appendTaskCompleteLog(taskId: String, row: BenchRow) {
        logLines.append(LogLine(
            t: ISO8601DateFormatter().string(from: Date()),
            kind: .ok,
            text: "\(taskId) complete · code_pass=\(row.codePass) artifact=\(row.artifactScore) convention=\(row.conventionScore)"
        ))
    }

    private func handleTaskFailure(task: BenchmarkTask, error: Error) {
        let message = LogSanitizer.sanitize(error.localizedDescription)
        errorMessage = message
        failTaskResult(taskId: task.id)
        let described = BenchFailureRow.describe(error: error)
        let failure = BenchFailureRow(
            timestamp: Date(),
            modelId: selectedModel,
            taskId: task.id,
            phase: described.phase,
            errorKind: described.kind,
            errorMessage: described.message,
            duration: elapsedTime,
            workspace: isHostMode ? hostRunConfig.sandboxPath : (selectedSandbox?.id ?? "")
        )
        try? intelStore?.ingest(failure: failure)
        AppLogger.runner.error("Run failed in UI", metadata: [
            "taskId": .string(task.id),
            "error": .string(message),
        ])
    }

    private func finishSuiteRun() {
        runState = .idle
        timerTask?.cancel()
        timerTask = nil
        store.currentRun = nil
    }

    private func buildTaskResults(activeTask: BenchmarkTask) {
        let suiteTasks = selectedSuite?.tasks ?? [activeTask]
        taskResults = suiteTasks.map { suiteTask in
            TaskResult(
                id: suiteTask.id,
                name: suiteTask.name,
                status: suiteTask.id == activeTask.id ? .active : .pending
            )
        }
        visibleTaskIds = Set(suiteTasks.map(\.id))
    }

    private func loadScoreHistory(model: String, taskId: String) {
        scoreHistory = store.runs
            .filter { $0.modelId == model && $0.taskId == taskId }
            .sorted { $0.timestamp < $1.timestamp }
    }

    private func completeTaskResult(taskId: String, row: BenchRow) {
        guard let index = taskResults.firstIndex(where: { $0.id == taskId }) else { return }
        let previousScore = scoreHistory.dropLast().last?.overallScore
        taskResults[index].status = .complete
        taskResults[index].duration = row.duration
        taskResults[index].cost = row.cost
        taskResults[index].overallScore = row.overallScore
        if let previousScore {
            taskResults[index].delta = row.overallScore - previousScore
        }
    }

    private func failTaskResult(taskId: String) {
        guard let index = taskResults.firstIndex(where: { $0.id == taskId }) else { return }
        taskResults[index].status = .fail
        taskResults[index].duration = elapsedTime
    }

    private func sparkValues(_ value: (BenchRow) -> Double) -> [Double] {
        Array(filteredHistory.suffix(7).map(value))
    }

    private func metricDelta(_ value: (BenchRow) -> Double) -> Double? {
        guard filteredHistory.count >= 2 else { return nil }
        let latest = value(filteredHistory[filteredHistory.count - 1])
        let previous = value(filteredHistory[filteredHistory.count - 2])
        return latest - previous
    }

    private func activeRunFolderSuffix() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd_HHmmss"
        return formatter.string(from: activeRunStartedAt)
    }
}

public enum RunState: String, Sendable {
    case idle
    case running
    case stopping
}
