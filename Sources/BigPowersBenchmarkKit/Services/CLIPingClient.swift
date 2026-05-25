import Foundation

public enum CLIPingError: Error, Sendable, Equatable {
    case timeout
    case nonZeroExit(String)
    case executableNotFound(String)
}

public protocol CLIPingClientProtocol: Sendable {
    func pingClaude(model: String, prompt: String, timeoutMs: Int) async throws -> (reply: String, latencyMs: Double)
    func pingGemini(model: String, prompt: String, timeoutMs: Int) async throws -> (reply: String, latencyMs: Double)
    func pingOpenCode(model: String, prompt: String, timeoutMs: Int) async throws -> (reply: String, latencyMs: Double)
}

public protocol CLIProcessRunning: Sendable {
    func run(
        executable: String,
        arguments: [String],
        timeoutMs: Int
    ) async throws -> ShellCommandResult
}

public struct CLIPingClient: CLIPingClientProtocol {
    private let processRunner: CLIProcessRunning

    public init(processRunner: CLIProcessRunning = AsyncShellProcessRunner()) {
        self.processRunner = processRunner
    }

    public func pingClaude(
        model: String,
        prompt: String,
        timeoutMs: Int
    ) async throws -> (reply: String, latencyMs: Double) {
        try await run(
            executable: "claude",
            arguments: ["-p", prompt, "--model", model, "--output-format", "text"],
            timeoutMs: timeoutMs
        )
    }

    public func pingGemini(
        model: String,
        prompt: String,
        timeoutMs: Int
    ) async throws -> (reply: String, latencyMs: Double) {
        try await run(
            executable: "gemini",
            arguments: ["-p", prompt, "-m", model, "-o", "text", "--skip-trust"],
            timeoutMs: timeoutMs
        )
    }

    public func pingOpenCode(
        model: String,
        prompt: String,
        timeoutMs: Int
    ) async throws -> (reply: String, latencyMs: Double) {
        try await run(
            executable: "opencode",
            arguments: ["run", "--model", model, "--dangerously-skip-permissions", prompt],
            timeoutMs: timeoutMs
        )
    }

    private func run(
        executable: String,
        arguments: [String],
        timeoutMs: Int
    ) async throws -> (reply: String, latencyMs: Double) {
        let start = Date()
        let result: ShellCommandResult
        do {
            result = try await processRunner.run(
                executable: executable,
                arguments: arguments,
                timeoutMs: timeoutMs
            )
        } catch CLIPingError.timeout {
            throw CLIPingError.timeout
        } catch {
            throw CLIPingError.executableNotFound(error.localizedDescription)
        }

        let latencyMs = Date().timeIntervalSince(start) * 1000
        guard result.exitCode == 0 else {
            let message = CLIPingClient.stripANSI(
                (result.stderr.isEmpty ? result.stdout : result.stderr)
                    .trimmingCharacters(in: .whitespacesAndNewlines)
            )
            throw CLIPingError.nonZeroExit(message.isEmpty ? "Exit code \(result.exitCode)" : message)
        }

        return (CLIPingClient.stripANSI(result.stdout.trimmingCharacters(in: .whitespacesAndNewlines)), latencyMs)
    }

    static func stripANSI(_ text: String) -> String {
        text.replacingOccurrences(
            of: "\u{001B}\\[[0-9;]*m",
            with: "",
            options: .regularExpression
        )
    }
}

public struct AsyncShellProcessRunner: CLIProcessRunning {
    public init() {}

    public func run(
        executable: String,
        arguments: [String],
        timeoutMs: Int
    ) async throws -> ShellCommandResult {
        try await withCheckedThrowingContinuation { continuation in
            let state = ProcessRunState(continuation: continuation)

            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
            process.arguments = [executable] + arguments
            process.environment = Self.cliEnvironment()

            let stdoutPipe = Pipe()
            let stderrPipe = Pipe()
            process.standardOutput = stdoutPipe
            process.standardError = stderrPipe

            let timeoutNanoseconds = UInt64(max(timeoutMs, 1)) * 1_000_000

            let timeoutTask = Task {
                try await Task.sleep(nanoseconds: timeoutNanoseconds)
                if process.isRunning {
                    process.terminate()
                }
                state.finish(with: .failure(CLIPingError.timeout))
            }

            process.terminationHandler = { process in
                timeoutTask.cancel()
                let stdoutData = stdoutPipe.fileHandleForReading.readDataToEndOfFile()
                let stderrData = stderrPipe.fileHandleForReading.readDataToEndOfFile()
                state.finish(with: .success(ShellCommandResult(
                    stdout: String(data: stdoutData, encoding: .utf8) ?? "",
                    stderr: String(data: stderrData, encoding: .utf8) ?? "",
                    exitCode: process.terminationStatus
                )))
            }

            do {
                try process.run()
            } catch {
                timeoutTask.cancel()
                state.finish(with: .failure(error))
            }
        }
    }

    private static func cliEnvironment() -> [String: String] {
        var env = ProcessInfo.processInfo.environment
        let path = env["PATH"] ?? "/usr/bin:/bin"
        if !path.contains("homebrew") {
            env["PATH"] = path + ":/opt/homebrew/bin:/usr/local/bin"
        }
        env["CI"] = "true"
        env["NO_COLOR"] = "1"
        return env
    }
}

private final class ProcessRunState: @unchecked Sendable {
    private let lock = NSLock()
    private var didFinish = false
    private let continuation: CheckedContinuation<ShellCommandResult, Error>

    init(continuation: CheckedContinuation<ShellCommandResult, Error>) {
        self.continuation = continuation
    }

    func finish(with result: Result<ShellCommandResult, Error>) {
        lock.lock()
        defer { lock.unlock() }
        guard !didFinish else { return }
        didFinish = true
        continuation.resume(with: result)
    }
}
