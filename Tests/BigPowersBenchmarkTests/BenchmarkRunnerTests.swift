@testable import BigPowersBenchmarkKit
import Foundation
import Testing

@Suite("BenchmarkRunner")
struct BenchmarkRunnerTests {
    @Test("Workspace reset calls createSession and executeCommand")
    func workspaceReset() async {
        let mockClient = MockDaytonaClient()
        let store = BenchmarkStore(gitService: MockGitService())
        let config = DaytonaConfig(keychainService: MockKeychainService())
        config.taskRepoURL = "https://github.com/test/repo"

        let runner = BenchmarkRunner(daytonaClient: mockClient, store: store, config: config)
        let sandbox = Sandbox(
            id: "sb-1",
            name: "s1",
            state: .started,
            labels: ["bigpowers_ref": "v1.0"],
            toolboxProxyUrl: ""
        )
        let task = BenchmarkTask(id: "T01", name: "Task 1", description: "Desc")

        let events = runner.run(sandbox: sandbox, task: task, model: "gpt-4o")

        var receivedPhases: [BenchmarkPhase] = []
        for await event in events {
            if case let .phase(phase) = event {
                receivedPhases.append(phase)
            }
            if case .completed = event { break }
            if case .failed = event { break }
        }

        #expect(receivedPhases.contains(.resettingWorkspace))
    }

    @Test("opencode streaming yields logLine events")
    func opencodeStreaming() async {
        let mockClient = MockDaytonaClient()
        let store = BenchmarkStore(gitService: MockGitService())
        let config = DaytonaConfig(keychainService: MockKeychainService())

        let runner = BenchmarkRunner(daytonaClient: mockClient, store: store, config: config)
        let sandbox = Sandbox(id: "sb-1", name: "s1", state: .started, labels: [:], toolboxProxyUrl: "")
        let task = BenchmarkTask(id: "T01", name: "Task 1", description: "Desc")

        let events = runner.run(sandbox: sandbox, task: task, model: "gpt-4o")

        var logLines: [LogLine] = []
        for await event in events {
            if case let .logLine(line) = event {
                logLines.append(line)
            }
            if case .completed = event { break }
            if case .failed = event { break }
        }

        // Mock yields "log line 1" and "log line 2"
        #expect(logLines.count >= 2)
    }

    @Test("Grading phase decodes score_run.sh output correctly")
    func grading() async {
        let mockClient = MockDaytonaClient()
        // Mock score_run.sh output
        mockClient.nextCommandOutput = """
        { "code_pass": 1, "artifact_score": 2, "convention_score": 1, "token_cost": 0.05 }
        """

        let store = BenchmarkStore(gitService: MockGitService())
        let config = DaytonaConfig(keychainService: MockKeychainService())

        let runner = BenchmarkRunner(daytonaClient: mockClient, store: store, config: config)
        let sandbox = Sandbox(id: "sb-1", name: "s1", state: .started, labels: [:], toolboxProxyUrl: "")
        let task = BenchmarkTask(id: "T01", name: "Task 1", description: "Desc")

        let events = runner.run(sandbox: sandbox, task: task, model: "gpt-4o")

        var completedRow: BenchRow?
        for await event in events {
            if case let .completed(row) = event {
                completedRow = row
            }
        }

        #expect(completedRow?.codePass == 1)
        #expect(completedRow?.artifactScore == 2)
        #expect(completedRow?.conventionScore == 1)
        #expect(completedRow?.cost == 0.05)
    }

    @Test("Runner emits timeout error if phase hangs")
    func testTimeout() async {
        let mockClient = HangingMockDaytonaClient()
        let store = BenchmarkStore(gitService: MockGitService())
        let config = DaytonaConfig(keychainService: MockKeychainService())

        let runner = BenchmarkRunner(daytonaClient: mockClient, store: store, config: config, phaseTimeout: 0.1)
        let sandbox = Sandbox(id: "sb-1", name: "s1", state: .started, labels: [:], toolboxProxyUrl: "")
        let task = BenchmarkTask(id: "T01", name: "Task 1", description: "Desc")

        let events = runner.run(sandbox: sandbox, task: task, model: "gpt-4o")

        var timeoutError: RunnerError?
        for await event in events {
            if case let .failed(error) = event, let runnerError = error as? RunnerError {
                if case .timeout = runnerError {
                    timeoutError = runnerError
                }
            }
        }

        #expect(timeoutError != nil)
    }
}

final class HangingMockDaytonaClient: DaytonaClientProtocol, @unchecked Sendable {
    func listSandboxes() async throws -> [Sandbox] {
        []
    }

    func createSession(sandboxId _: String) async throws -> String {
        try await Task.sleep(for: .seconds(10))
        return "session"
    }

    func executeCommand(
        sandboxId _: String,
        sessionId _: String,
        command _: String,
        runAsync _: Bool
    ) async throws -> String {
        ""
    }

    func getCommandStatus(sandboxId _: String, sessionId _: String, commandId _: String) async throws -> CommandStatus {
        CommandStatus(exitCode: 0, running: false)
    }

    func streamLogs(sandboxId _: String, sessionId _: String, commandId _: String) -> AsyncStream<String> {
        AsyncStream { $0.finish() }
    }

    func deleteDirectory(sandboxId _: String, path _: String) async throws {}
    func writeFile(sandboxId _: String, path _: String, content _: String) async throws {}
    func pingDetailed() async -> PingResult {
        .success
    }

    func ping() async -> Bool {
        true
    }
}
