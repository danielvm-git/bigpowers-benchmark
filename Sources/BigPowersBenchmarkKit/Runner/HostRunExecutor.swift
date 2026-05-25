import Foundation

public struct HostRunExecutor: RunExecutorProtocol {
    private let store: BenchmarkStore
    private let config: HostRunConfig
    private let workspaceResetter: HostWorkspaceResetter
    private let shell: ShellCommandRunning
    private let opencodeTimeout: Double
    private let gradingTimeout: Double
    private let opencodePath: String

    public init(
        store: BenchmarkStore,
        config: HostRunConfig,
        workspaceResetter: HostWorkspaceResetter = HostWorkspaceResetter(),
        shell: ShellCommandRunning = ShellCommandRunner(),
        phaseTimeout: Double? = nil,
        opencodePath: String? = nil
    ) {
        self.store = store
        self.config = config
        self.workspaceResetter = workspaceResetter
        self.shell = shell
        opencodeTimeout = phaseTimeout ?? 600.0
        gradingTimeout = phaseTimeout ?? 60.0
        self.opencodePath = opencodePath ?? Self.resolveOpencodePath(shell: shell)
    }

    public func run(task: BenchmarkTask, model: String, catalogModelId: String?) -> AsyncStream<RunEvent> {
        let localStore = store
        let localConfig = config
        let resetter = workspaceResetter
        let shellRunner = shell
        let opencode = opencodePath
        let opencodeTimeout = opencodeTimeout
        let gradingTimeout = gradingTimeout
        let bigpowersRef = config.bigpowersRef
        let scoreScript = config.scoreScriptPath
        let storedModelId = catalogModelId ?? model
        let opencodeModel = model

        return AsyncStream { continuation in
            Task {
                let runId = UUID()
                let runFolderId = "\(task.id)_\(runId.uuidString.prefix(8))"
                let startTime = Date()

                AppLogger.runner.info("Run started", metadata: [
                    "runId": .string(runId.uuidString),
                    "taskId": .string(task.id),
                    "model": .string(opencodeModel),
                    "catalogModelId": .string(storedModelId),
                    "executor": .string("host"),
                    "bigpowersRef": .string(bigpowersRef),
                ])

                do {
                    continuation.yield(.phase(.resettingWorkspace))
                    AppLogger.runner.info("Phase started", metadata: [
                        "runId": .string(runId.uuidString),
                        "phase": .string(BenchmarkPhase.resettingWorkspace.rawValue),
                    ])

                    let worktreeURL = try resetter.reset(
                        taskId: task.id,
                        runId: runFolderId,
                        config: localConfig
                    )

                    continuation.yield(.phase(.runningOpencode))
                    AppLogger.runner.info("Phase started", metadata: [
                        "runId": .string(runId.uuidString),
                        "phase": .string(BenchmarkPhase.runningOpencode.rawValue),
                    ])

                    var exitCode: Int32 = -1
                    var lastStderrLine: String?
                    let outputStream = shellRunner.streamOutput(
                        executable: opencode,
                        arguments: [
                            "run",
                            "--model", opencodeModel,
                            "--format", "json",
                            "--dangerously-skip-permissions",
                            "--dir", worktreeURL.path,
                            task.description,
                        ],
                        workingDirectory: worktreeURL
                    )

                    struct OpencodeStreamResult: Sendable {
                        let exitCode: Int32
                        let lastStderrLine: String?
                    }

                    let streamResult = try await withThrowingTaskGroup(of: OpencodeStreamResult.self) { group in
                        group.addTask {
                            var code: Int32 = -1
                            var lastStderr: String?
                            for await event in outputStream {
                                switch event {
                                case let .line(raw):
                                    let line = Self.decodeLogLine(raw)
                                    if line.kind == .err {
                                        lastStderr = line.text
                                    }
                                    continuation.yield(.logLine(line))
                                case let .completed(exitCode):
                                    code = exitCode
                                }
                            }
                            return OpencodeStreamResult(exitCode: code, lastStderrLine: lastStderr)
                        }
                        group.addTask {
                            try await Task.sleep(nanoseconds: UInt64(opencodeTimeout * 1_000_000_000))
                            throw RunnerError.timeout(phase: .runningOpencode)
                        }
                        guard let result = try await group.next() else {
                            throw RunnerError.timeout(phase: .runningOpencode)
                        }
                        group.cancelAll()
                        return result
                    }

                    exitCode = streamResult.exitCode
                    lastStderrLine = streamResult.lastStderrLine

                    if exitCode != 0 {
                        let stderr = lastStderrLine?.trimmingCharacters(in: .whitespacesAndNewlines)
                        AppLogger.runner.error("Opencode failed", metadata: [
                            "runId": .string(runId.uuidString),
                            "exitCode": .stringConvertible(exitCode),
                            "model": .string(opencodeModel),
                            "stderr": .string(LogSanitizer.sanitize(stderr ?? "")),
                        ])
                        throw RunnerError.opencodeNonZeroExit(
                            code: Int(exitCode),
                            stderr: stderr?.isEmpty == false ? stderr : nil
                        )
                    }

                    continuation.yield(.phase(.grading))
                    AppLogger.runner.info("Phase started", metadata: [
                        "runId": .string(runId.uuidString),
                        "phase": .string(BenchmarkPhase.grading.rawValue),
                    ])

                    let gradingResult = try await withThrowingTaskGroup(of: GradingScores.self) { group in
                        group.addTask {
                            let result = try shellRunner.run(
                                executable: "/bin/bash",
                                arguments: [scoreScript, worktreeURL.path],
                                workingDirectory: worktreeURL
                            )
                            if result.exitCode != 0 {
                                throw RunnerError.gradingScriptMissing
                            }
                            return try Self.decodeScores(from: result.stdout)
                        }
                        group.addTask {
                            try await Task.sleep(nanoseconds: UInt64(gradingTimeout * 1_000_000_000))
                            throw RunnerError.timeout(phase: .grading)
                        }
                        guard let result = try await group.next() else {
                            throw RunnerError.timeout(phase: .grading)
                        }
                        group.cancelAll()
                        return result
                    }

                    continuation.yield(.phase(.persisting))

                    let duration = Date().timeIntervalSince(startTime)
                    let benchRow = BenchRow(
                        id: runId,
                        schemaVersion: 1,
                        timestamp: Date(),
                        bigpowersRef: bigpowersRef,
                        modelId: storedModelId,
                        taskId: task.id,
                        codePass: gradingResult.codePass,
                        artifactScore: gradingResult.artifactScore,
                        conventionScore: gradingResult.conventionScore,
                        duration: duration,
                        cost: gradingResult.cost,
                        workspace: worktreeURL.path
                    )

                    try localStore.saveBenchRow(benchRow)

                    AppLogger.runner.info("Run completed", metadata: [
                        "runId": .string(runId.uuidString),
                        "taskId": .string(task.id),
                        "overallScore": .stringConvertible(benchRow.overallScore),
                    ])

                    continuation.yield(.completed(benchRow))
                    continuation.finish()
                } catch {
                    let described = BenchFailureRow.describe(error: error)
                    let duration = Date().timeIntervalSince(startTime)
                    let failure = BenchFailureRow(
                        timestamp: Date(),
                        modelId: storedModelId,
                        taskId: task.id,
                        phase: described.phase,
                        errorKind: described.kind,
                        errorMessage: described.message,
                        duration: duration,
                        workspace: ""
                    )
                    try? localStore.saveBenchFailureRow(failure)

                    AppLogger.runner.error("Run failed", metadata: [
                        "runId": .string(runId.uuidString),
                        "taskId": .string(task.id),
                        "error": .string(LogSanitizer.sanitize(String(describing: error))),
                    ])
                    continuation.yield(.failed(error))
                    continuation.finish()
                }
            }
        }
    }

    private struct GradingScores {
        let codePass: Int
        let artifactScore: Int
        let conventionScore: Int
        let cost: Double
    }

    private static func decodeScores(from output: String) throws -> GradingScores {
        guard let data = output.data(using: .utf8) else {
            throw RunnerError.gradingOutputInvalid
        }
        struct ScoreResult: Decodable {
            let code_pass: Int?
            let artifact_score: Int?
            let convention_score: Int?
            let token_cost: Double?
        }
        let scores = try JSONDecoder().decode(ScoreResult.self, from: data)
        return GradingScores(
            codePass: scores.code_pass ?? 0,
            artifactScore: scores.artifact_score ?? 0,
            conventionScore: scores.convention_score ?? 0,
            cost: scores.token_cost ?? 0.0
        )
    }

    private static func decodeLogLine(_ raw: String) -> LogLine {
        if let data = raw.data(using: .utf8),
           let decoded = try? JSONDecoder().decode(LogLine.self, from: data) {
            return decoded
        }
        return LogLine(
            t: ISO8601DateFormatter().string(from: Date()),
            kind: .info,
            text: raw
        )
    }

    private static func resolveOpencodePath(shell: ShellCommandRunning) -> String {
        if let result = try? shell.run(
            executable: "/usr/bin/which",
            arguments: ["opencode"],
            workingDirectory: nil
        ), result.exitCode == 0 {
            let path = result.stdout.trimmingCharacters(in: .whitespacesAndNewlines)
            if !path.isEmpty { return path }
        }
        return "/usr/local/bin/opencode"
    }
}
