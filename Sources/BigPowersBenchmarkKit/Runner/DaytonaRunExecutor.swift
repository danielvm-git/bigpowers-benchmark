// swiftlint:disable function_body_length
import Foundation

public struct DaytonaRunExecutor: RunExecutorProtocol {
    private let daytonaClient: DaytonaClientProtocol
    private let store: BenchmarkStore
    private let config: DaytonaConfig
    private let sandbox: Sandbox
    private let resetTimeout: Double
    private let opencodeTimeout: Double
    private let gradingTimeout: Double

    public init(
        daytonaClient: DaytonaClientProtocol,
        store: BenchmarkStore,
        config: DaytonaConfig,
        sandbox: Sandbox,
        phaseTimeout: Double? = nil
    ) {
        self.daytonaClient = daytonaClient
        self.store = store
        self.config = config
        self.sandbox = sandbox
        if let phaseTimeout {
            resetTimeout = phaseTimeout
            opencodeTimeout = phaseTimeout
            gradingTimeout = phaseTimeout
        } else {
            resetTimeout = 60.0
            opencodeTimeout = 600.0
            gradingTimeout = 60.0
        }
    }

    public func run(task: BenchmarkTask, model: String, catalogModelId _: String?) -> AsyncStream<RunEvent> {
        let client = daytonaClient
        let localStore = store
        let localConfig = config
        let sandboxId = sandbox.id
        let bigpowersRef = sandbox.labels["bigpowers_ref"] ?? "HEAD"
        let taskId = task.id
        let taskDescription = task.description
        let taskRepoURL = localConfig.taskRepoURL
        let resetTimeout = resetTimeout
        let opencodeTimeout = opencodeTimeout
        let gradingTimeout = gradingTimeout

        return AsyncStream { continuation in
            Task {
                let runId = UUID()
                let taskDir = "/home/daytona/\(taskId)"
                let promptPath = "/tmp/bigpowers_prompt_\(runId.uuidString).txt"

                AppLogger.runner.info("Run started", metadata: [
                    "runId": .string(runId.uuidString),
                    "taskId": .string(taskId),
                    "sandboxId": .string(sandboxId),
                    "model": .string(model),
                    "executor": .string("daytona"),
                ])

                do {
                    continuation.yield(.phase(.resettingWorkspace))
                    AppLogger.runner.info("Phase started", metadata: [
                        "runId": .string(runId.uuidString),
                        "phase": .string(BenchmarkPhase.resettingWorkspace.rawValue),
                    ])

                    let sessionId = try await withThrowingTaskGroup(of: String.self) { group in
                        group.addTask {
                            let sid = try await client.createSession(sandboxId: sandboxId)

                            _ = try await client.executeCommand(
                                sandboxId: sandboxId,
                                sessionId: sid,
                                command: "rm -rf \(taskDir)",
                                runAsync: false
                            )

                            _ = try await client.executeCommand(
                                sandboxId: sandboxId,
                                sessionId: sid,
                                command: "git clone \(taskRepoURL) \(taskDir)",
                                runAsync: false
                            )

                            _ = try await client.executeCommand(
                                sandboxId: sandboxId,
                                sessionId: sid,
                                command: "git -C \(taskDir) checkout \(bigpowersRef)",
                                runAsync: false
                            )

                            return sid
                        }
                        group.addTask {
                            try await Task.sleep(nanoseconds: UInt64(resetTimeout * 1_000_000_000))
                            throw RunnerError.timeout(phase: .resettingWorkspace)
                        }
                        guard let result = try await group.next() else {
                            throw RunnerError.timeout(phase: .resettingWorkspace)
                        }
                        group.cancelAll()
                        return result
                    }

                    continuation.yield(.phase(.runningOpencode))
                    AppLogger.runner.info("Phase started", metadata: [
                        "runId": .string(runId.uuidString),
                        "phase": .string(BenchmarkPhase.runningOpencode.rawValue),
                    ])

                    try await client.writeFile(sandboxId: sandboxId, path: promptPath, content: taskDescription)

                    let opencodeCmd = "opencode run --model \(model) --dir \(taskDir) --dangerously-skip-permissions --format json @\(promptPath)"

                    let opencodeExitCode = try await withThrowingTaskGroup(of: Int.self) { group in
                        group.addTask {
                            let cmdId = try await client.executeCommand(
                                sandboxId: sandboxId,
                                sessionId: sessionId,
                                command: opencodeCmd,
                                runAsync: true
                            )

                            let logStream = client.streamLogs(
                                sandboxId: sandboxId,
                                sessionId: sessionId,
                                commandId: cmdId
                            )
                            for await line in logStream {
                                if let data = line.data(using: .utf8) {
                                    do {
                                        let decoded = try JSONDecoder().decode(LogLine.self, from: data)
                                        continuation.yield(.logLine(decoded))
                                    } catch {
                                        continuation.yield(.logLine(LogLine(
                                            t: ISO8601DateFormatter().string(from: Date()),
                                            kind: .err,
                                            text: line
                                        )))
                                    }
                                }
                            }

                            while true {
                                let status = try await client.getCommandStatus(
                                    sandboxId: sandboxId,
                                    sessionId: sessionId,
                                    commandId: cmdId
                                )
                                if !status.running {
                                    return status.exitCode ?? 0
                                }
                                try await Task.sleep(for: .seconds(1))
                            }
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

                    if opencodeExitCode != 0 {
                        AppLogger.runner.error("Opencode non-zero exit", metadata: [
                            "runId": .string(runId.uuidString),
                            "exitCode": .stringConvertible(opencodeExitCode),
                        ])
                        throw RunnerError.opencodeNonZeroExit(code: opencodeExitCode, stderr: nil)
                    }

                    continuation.yield(.phase(.grading))
                    AppLogger.runner.info("Phase started", metadata: [
                        "runId": .string(runId.uuidString),
                        "phase": .string(BenchmarkPhase.grading.rawValue),
                    ])

                    struct GradingResult {
                        let codePass: Int
                        let artifactScore: Int
                        let conventionScore: Int
                        let cost: Double
                    }

                    let gradingResult = try await withThrowingTaskGroup(of: GradingResult.self) { group in
                        group.addTask {
                            let scoreCmd = "score_run.sh \(taskDir)"
                            let scoreCmdId = try await client.executeCommand(
                                sandboxId: sandboxId,
                                sessionId: sessionId,
                                command: scoreCmd,
                                runAsync: true
                            )

                            var scoreExitCode: Int?
                            while true {
                                let status = try await client.getCommandStatus(
                                    sandboxId: sandboxId,
                                    sessionId: sessionId,
                                    commandId: scoreCmdId
                                )
                                if !status.running {
                                    scoreExitCode = status.exitCode
                                    break
                                }
                                try await Task.sleep(for: .seconds(1))
                            }

                            if let code = scoreExitCode, code != 0 {
                                throw RunnerError.gradingScriptMissing
                            }

                            let logStream = client.streamLogs(
                                sandboxId: sandboxId,
                                sessionId: sessionId,
                                commandId: scoreCmdId
                            )
                            var rawOutput = ""
                            for await line in logStream {
                                rawOutput += line
                            }

                            guard let data = rawOutput.data(using: .utf8) else {
                                throw RunnerError.gradingOutputInvalid
                            }

                            struct ScoreResult: Decodable {
                                let code_pass: Int?
                                let artifact_score: Int?
                                let convention_score: Int?
                                let token_cost: Double?
                            }

                            let scores = try JSONDecoder().decode(ScoreResult.self, from: data)
                            return GradingResult(
                                codePass: scores.code_pass ?? 0,
                                artifactScore: scores.artifact_score ?? 0,
                                conventionScore: scores.convention_score ?? 0,
                                cost: scores.token_cost ?? 0.0
                            )
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

                    _ = try await client.executeCommand(
                        sandboxId: sandboxId,
                        sessionId: sessionId,
                        command: "rm -f \(promptPath)",
                        runAsync: false
                    )

                    continuation.yield(.phase(.persisting))
                    AppLogger.runner.info("Phase started", metadata: [
                        "runId": .string(runId.uuidString),
                        "phase": .string(BenchmarkPhase.persisting.rawValue),
                    ])

                    let benchRow = BenchRow(
                        id: runId,
                        schemaVersion: 1,
                        timestamp: Date(),
                        bigpowersRef: bigpowersRef,
                        modelId: model,
                        taskId: taskId,
                        codePass: gradingResult.codePass,
                        artifactScore: gradingResult.artifactScore,
                        conventionScore: gradingResult.conventionScore,
                        duration: 0.0,
                        cost: gradingResult.cost,
                        workspace: taskDir
                    )

                    try localStore.saveBenchRow(benchRow)

                    AppLogger.runner.info("Run completed", metadata: [
                        "runId": .string(runId.uuidString),
                        "taskId": .string(taskId),
                        "overallScore": .stringConvertible(benchRow.overallScore),
                    ])

                    continuation.yield(.completed(benchRow))
                    continuation.finish()

                } catch {
                    let described = BenchFailureRow.describe(error: error)
                    let failure = BenchFailureRow(
                        timestamp: Date(),
                        modelId: model,
                        taskId: taskId,
                        phase: described.phase,
                        errorKind: described.kind,
                        errorMessage: described.message,
                        duration: 0,
                        workspace: taskDir
                    )
                    try? localStore.saveBenchFailureRow(failure)

                    AppLogger.runner.error("Run failed", metadata: [
                        "runId": .string(runId.uuidString),
                        "taskId": .string(taskId),
                        "error": .string(LogSanitizer.sanitize(String(describing: error))),
                    ])
                    continuation.yield(.failed(error))
                    continuation.finish()
                }
            }
        }
    }
}

public typealias BenchmarkRunner = DaytonaRunExecutor
