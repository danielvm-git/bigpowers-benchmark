@testable import BigPowersBenchmarkKit
import Foundation
import Testing

@Suite("HostRunExecutor")
struct HostRunExecutorTests {
    @Test("completes run with echo opencode and score script")
    func fullHostRun() async throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("host-run-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let bigpowersRepo = root.appendingPathComponent("bigpowers", isDirectory: true)
        let sandboxRoot = root.appendingPathComponent("SANDBOX", isDirectory: true)
        let worktreeRoot = root.appendingPathComponent("worktrees", isDirectory: true)
        let runsURL = root.appendingPathComponent("runs/data", isDirectory: true)
        try FileManager.default.createDirectory(at: runsURL, withIntermediateDirectories: true)

        try setupBigpowersRepo(at: bigpowersRepo)
        try setupSandboxTask(at: sandboxRoot, taskId: "T01")

        let scoreScript = root.appendingPathComponent("score_run.sh")
        try """
        #!/usr/bin/env bash
        printf '{"code_pass":1,"artifact_score":2,"convention_score":1,"token_cost":0.01}\\n'
        """.write(to: scoreScript, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: scoreScript.path)

        let defaults = try #require(UserDefaults(suiteName: "HostRunExecutor-\(UUID().uuidString)"))
        let config = HostRunConfig(userDefaults: defaults)
        config.bigpowersRepo = bigpowersRepo.path
        config.sandboxPath = sandboxRoot.path
        config.worktreeRoot = worktreeRoot.path
        config.bigpowersRef = "ref-v1"
        config.scoreScriptPath = scoreScript.path

        let store = BenchmarkStore(runsURL: runsURL, gitService: MockGitService())
        let executor = HostRunExecutor(
            store: store,
            config: config,
            phaseTimeout: 5.0,
            opencodePath: "/bin/echo"
        )

        let task = BenchmarkTask(id: "T01", name: "Task", description: "Fix the bug")
        let events = executor.run(task: task, model: "test/model")

        var completed: BenchRow?
        for await event in events {
            if case let .completed(row) = event {
                completed = row
            }
            if case let .failed(error) = event {
                Issue.record("Run failed: \(error)")
            }
        }

        #expect(completed?.bigpowersRef == "ref-v1")
        #expect(completed?.codePass == 1)
        #expect(completed?.artifactScore == 2)
        try store.loadAllRuns()
        #expect(store.runs.count == 1)
    }

    @Test("yields log lines during opencode before run completes")
    func streamsOpencodeLogLinesIncrementally() async throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("host-stream-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let bigpowersRepo = root.appendingPathComponent("bigpowers", isDirectory: true)
        let sandboxRoot = root.appendingPathComponent("SANDBOX", isDirectory: true)
        let worktreeRoot = root.appendingPathComponent("worktrees", isDirectory: true)
        let runsURL = root.appendingPathComponent("runs/data", isDirectory: true)
        try FileManager.default.createDirectory(at: runsURL, withIntermediateDirectories: true)

        try setupBigpowersRepo(at: bigpowersRepo)
        try setupSandboxTask(at: sandboxRoot, taskId: "T01")

        let scoreScript = root.appendingPathComponent("score_run.sh")
        try """
        #!/usr/bin/env bash
        printf '{"code_pass":1,"artifact_score":2,"convention_score":1,"token_cost":0.01}\\n'
        """.write(to: scoreScript, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: scoreScript.path)

        let defaults = try #require(UserDefaults(suiteName: "HostRunExecutor-stream-\(UUID().uuidString)"))
        let config = HostRunConfig(userDefaults: defaults)
        config.bigpowersRepo = bigpowersRepo.path
        config.sandboxPath = sandboxRoot.path
        config.worktreeRoot = worktreeRoot.path
        config.bigpowersRef = "ref-v1"
        config.scoreScriptPath = scoreScript.path

        let store = BenchmarkStore(runsURL: runsURL, gitService: MockGitService())
        let shell = DelayedLineMockShell()
        let executor = HostRunExecutor(
            store: store,
            config: config,
            shell: shell,
            phaseTimeout: 5.0,
            opencodePath: "/mock/opencode"
        )

        let task = BenchmarkTask(id: "T01", name: "Task", description: "Fix the bug")
        let events = executor.run(task: task, model: "test/model")

        var eventKinds: [String] = []
        var logLineBeforeCompleted = false
        var sawLogLine = false

        for await event in events {
            switch event {
            case .logLine:
                sawLogLine = true
                eventKinds.append("logLine")
            case .completed:
                logLineBeforeCompleted = sawLogLine
                eventKinds.append("completed")
            case .phase:
                eventKinds.append("phase")
            case .failed:
                eventKinds.append("failed")
            }
        }

        #expect(logLineBeforeCompleted)
        #expect(eventKinds.firstIndex(of: "logLine") ?? Int.max < eventKinds.firstIndex(of: "completed") ?? 0)
    }

    private struct DelayedLineMockShell: ShellCommandRunning {
        private let runner = ShellCommandRunner()

        func run(
            executable: String,
            arguments: [String],
            workingDirectory: URL?
        ) throws -> ShellCommandResult {
            try runner.run(executable: executable, arguments: arguments, workingDirectory: workingDirectory)
        }

        func streamLines(
            executable: String,
            arguments: [String],
            workingDirectory: URL?
        ) -> AsyncStream<String> {
            runner.streamLines(executable: executable, arguments: arguments, workingDirectory: workingDirectory)
        }

        func streamOutput(
            executable _: String,
            arguments _: [String],
            workingDirectory _: URL?
        ) -> AsyncStream<ShellOutputEvent> {
            AsyncStream { continuation in
                Task {
                    continuation.yield(.line("streamed line one"))
                    try await Task.sleep(nanoseconds: 50_000_000)
                    continuation.yield(.line("streamed line two"))
                    continuation.yield(.completed(exitCode: 0))
                    continuation.finish()
                }
            }
        }
    }

    private func setupBigpowersRepo(at url: URL) throws {
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        try runGit(["init"], in: url)
        let claude = "# Bigpowers\n## Session Start\nVERSION_ONE\n"
        try claude.write(to: url.appendingPathComponent("CLAUDE.md"), atomically: true, encoding: .utf8)
        try runGit(["add", "CLAUDE.md"], in: url)
        try runGit(["commit", "-m", "init"], in: url)
        try runGit(["tag", "ref-v1"], in: url)
    }

    private func setupSandboxTask(at sandboxRoot: URL, taskId: String) throws {
        let taskRoot = sandboxRoot.appendingPathComponent(taskId, isDirectory: true)
        let baselineSrc = taskRoot.appendingPathComponent("baseline/src", isDirectory: true)
        try FileManager.default.createDirectory(at: baselineSrc, withIntermediateDirectories: true)
        try "export default 1;\n".write(
            to: baselineSrc.appendingPathComponent("limiter.js"),
            atomically: true,
            encoding: .utf8
        )
        try "console.log('test');\n".write(
            to: taskRoot.appendingPathComponent("test.js"),
            atomically: true,
            encoding: .utf8
        )
        try "# Task\n".write(to: taskRoot.appendingPathComponent("TASK.md"), atomically: true, encoding: .utf8)
    }

    private func runGit(_ arguments: [String], in directory: URL) throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/git")
        process.arguments = arguments
        process.currentDirectoryURL = directory
        var env = ProcessInfo.processInfo.environment
        for key in ["GIT_DIR", "GIT_WORK_TREE", "GIT_INDEX_FILE", "GIT_OBJECT_DIRECTORY", "GIT_COMMON_DIR"] {
            env.removeValue(forKey: key)
        }
        env["GIT_AUTHOR_NAME"] = "test"
        env["GIT_AUTHOR_EMAIL"] = "test@test.com"
        env["GIT_COMMITTER_NAME"] = "test"
        env["GIT_COMMITTER_EMAIL"] = "test@test.com"
        process.environment = env
        try process.run()
        process.waitUntilExit()
        guard process.terminationStatus == 0 else {
            throw NSError(domain: "HostRunExecutorTests", code: Int(process.terminationStatus))
        }
    }
}
