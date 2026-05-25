@testable import BigPowersBenchmarkKit
import Foundation
import Testing

@Suite("MissionControlViewModel")
@MainActor
struct MissionControlViewModelTests {
    private func makeConfig() -> (DaytonaConfig, HostRunConfig) {
        (DaytonaConfig(keychainService: MockKeychainService()), HostRunConfig())
    }

    @Test("ViewModel loads sandboxes on init in daytona mode")
    func sandboxesLoad() async {
        let mockClient = MockDaytonaClient()
        let store = BenchmarkStore(gitService: MockGitService())
        let (config, hostConfig) = makeConfig()
        hostConfig.executionMode = .daytona

        let vm = MissionControlViewModel(
            daytonaClient: mockClient,
            store: store,
            daytonaConfig: config,
            hostRunConfig: hostConfig
        )

        await vm.loadSandboxes()

        #expect(vm.sandboxes.count == 2)
    }

    @Test("host mode skips sandbox loading")
    func hostModeSkipsSandboxes() async {
        let mockClient = MockDaytonaClient()
        let store = BenchmarkStore(gitService: MockGitService())
        let (config, hostConfig) = makeConfig()
        hostConfig.executionMode = .host

        let vm = MissionControlViewModel(
            daytonaClient: mockClient,
            store: store,
            daytonaConfig: config,
            hostRunConfig: hostConfig
        )

        await vm.loadSandboxes()

        #expect(vm.sandboxes.isEmpty)
        #expect(vm.isHostMode)
    }

    @Test("startRun updates state to running")
    func testStartRun() async {
        let mockClient = MockDaytonaClient()
        let store = BenchmarkStore(gitService: MockGitService())
        let (config, hostConfig) = makeConfig()
        hostConfig.executionMode = .daytona

        let vm = MissionControlViewModel(
            daytonaClient: mockClient,
            store: store,
            daytonaConfig: config,
            hostRunConfig: hostConfig
        )

        let sandbox = Sandbox(id: "sb-1", name: "s1", state: .started, labels: [:], toolboxProxyUrl: "")
        let task = BenchmarkTask(id: "T1", name: "T1", description: "D")

        vm.selectedSandbox = sandbox
        vm.selectedTask = task
        vm.selectedModel = "gpt-4"

        await vm.startRun()

        #expect(vm.runState == .running)
    }

    @Test("startRun populates task results from selected suite")
    func taskResultsPopulate() async {
        let mockClient = MockDaytonaClient()
        let store = BenchmarkStore(gitService: MockGitService())
        let (config, hostConfig) = makeConfig()
        hostConfig.executionMode = .daytona

        let vm = MissionControlViewModel(
            daytonaClient: mockClient,
            store: store,
            daytonaConfig: config,
            hostRunConfig: hostConfig
        )

        let sandbox = Sandbox(id: "sb-1", name: "s1", state: .started, labels: [:], toolboxProxyUrl: "")
        vm.selectedSandbox = sandbox
        vm.selectedSuite = BenchmarkSuite.allSuites.first
        vm.selectedTask = BenchmarkSuite.allSuites.first?.tasks.first
        vm.selectedModel = "gpt-4"

        await vm.startRun()

        #expect(!vm.taskResults.isEmpty)
        #expect(vm.taskResults.contains(where: { $0.status == .active }))
        #expect(vm.visibleTaskIds.count == vm.taskResults.count)
    }

    @Test("filteredLogLines respects visible task filters")
    func testFilteredLogLines() async {
        let mockClient = MockDaytonaClient()
        let store = BenchmarkStore(gitService: MockGitService())
        let (config, hostConfig) = makeConfig()
        hostConfig.executionMode = .daytona

        let vm = MissionControlViewModel(
            daytonaClient: mockClient,
            store: store,
            daytonaConfig: config,
            hostRunConfig: hostConfig
        )

        let sandbox = Sandbox(id: "sb-1", name: "s1", state: .started, labels: [:], toolboxProxyUrl: "")
        vm.selectedSandbox = sandbox
        vm.selectedTask = BenchmarkTask.allTasks.first
        vm.selectedModel = "gpt-4"

        await vm.startRun()

        vm.logLines = [
            LogLine(t: "1", kind: .info, text: "line one"),
            LogLine(t: "2", kind: .ok, text: "line two"),
        ]

        let activeTaskId = vm.activeTaskId ?? "T01"
        vm.toggleTaskFilter(activeTaskId)
        #expect(vm.filteredLogLines.isEmpty)

        vm.toggleTaskFilter(activeTaskId)
        #expect(vm.filteredLogLines.count == 2)
    }

    @Test("testConnection reports success and failure")
    func connectionTest() async {
        let mockClient = MockDaytonaClient()
        let store = BenchmarkStore(gitService: MockGitService())
        let (config, hostConfig) = makeConfig()

        let vm = MissionControlViewModel(
            daytonaClient: mockClient,
            store: store,
            daytonaConfig: config,
            hostRunConfig: hostConfig
        )

        mockClient.pingDetailedResult = .success
        await vm.testConnection()
        #expect(vm.connectionStatus == .ok)

        mockClient.pingDetailedResult = .failure(message: "unreachable")
        await vm.testConnection()
        #expect(vm.connectionStatus == .failed("unreachable"))
    }

    @Test("suite run completes all tasks and keeps running until finished")
    func suiteRunCompletesAllTasks() async throws {
        let mockClient = MockDaytonaClient()
        let store = BenchmarkStore(gitService: MockGitService())
        let (config, hostConfig) = makeConfig()

        let vm = MissionControlViewModel(
            daytonaClient: mockClient,
            store: store,
            daytonaConfig: config,
            hostRunConfig: hostConfig
        )

        vm.selectedModel = "gpt-4"
        vm.selectedSuite = BenchmarkSuite(
            id: "test",
            name: "Test",
            tasks: [
                BenchmarkTask(id: "T01", name: "One", description: "D1"),
                BenchmarkTask(id: "T02", name: "Two", description: "D2"),
            ]
        )
        try vm.buildTaskResultsForTest(activeTask: #require(vm.selectedSuite?.tasks[0]))

        let executor = SequentialMockExecutor(mode: .success)
        vm.runState = .running
        try await vm.runSuiteTasks(
            #require(vm.selectedSuite?.tasks),
            executor: executor,
            runnerModel: "gpt-4",
            catalogModelId: nil
        )

        #expect(vm.runState == .idle)
        #expect(vm.taskResults.filter { $0.status == .complete }.count == 2)
        #expect(vm.taskResults.allSatisfy { $0.status != .active })
    }

    @Test("suite run stops on first failure")
    func suiteRunStopsOnFailure() async throws {
        let mockClient = MockDaytonaClient()
        let store = BenchmarkStore(gitService: MockGitService())
        let (config, hostConfig) = makeConfig()

        let vm = MissionControlViewModel(
            daytonaClient: mockClient,
            store: store,
            daytonaConfig: config,
            hostRunConfig: hostConfig
        )

        vm.selectedModel = "gpt-4"
        vm.selectedSuite = BenchmarkSuite(
            id: "test",
            name: "Test",
            tasks: [
                BenchmarkTask(id: "T01", name: "One", description: "D1"),
                BenchmarkTask(id: "T02", name: "Two", description: "D2"),
            ]
        )
        try vm.buildTaskResultsForTest(activeTask: #require(vm.selectedSuite?.tasks[0]))

        let executor = SequentialMockExecutor(mode: .failOnFirst)
        vm.runState = .running
        try await vm.runSuiteTasks(
            #require(vm.selectedSuite?.tasks),
            executor: executor,
            runnerModel: "gpt-4",
            catalogModelId: nil
        )

        #expect(vm.runState == .idle)
        #expect(vm.taskResults.first(where: { $0.id == "T01" })?.status == .fail)
        #expect(vm.taskResults.first(where: { $0.id == "T02" })?.status == .pending)
    }
}

private enum SequentialMockMode {
    case success
    case failOnFirst
}

private struct SequentialMockExecutor: RunExecutorProtocol {
    let mode: SequentialMockMode

    func run(task: BenchmarkTask, model: String, catalogModelId _: String?) -> AsyncStream<RunEvent> {
        AsyncStream { continuation in
            switch mode {
            case .success:
                continuation.yield(.completed(mockRow(taskId: task.id, modelId: model)))
                continuation.finish()
            case .failOnFirst:
                continuation.yield(.failed(RunnerError.opencodeNonZeroExit(code: 1, stderr: "mock failure")))
                continuation.finish()
            }
        }
    }

    private func mockRow(taskId: String, modelId: String) -> BenchRow {
        BenchRow(
            id: UUID(),
            schemaVersion: 1,
            timestamp: Date(),
            bigpowersRef: "HEAD",
            modelId: modelId,
            taskId: taskId,
            codePass: 1,
            artifactScore: 2,
            conventionScore: 2,
            duration: 1.0,
            cost: 0.01,
            workspace: "/tmp/mock"
        )
    }
}

@MainActor
private extension MissionControlViewModel {
    func buildTaskResultsForTest(activeTask: BenchmarkTask) {
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
}
