import Foundation

public struct ShellCommandResult: Sendable {
    public let stdout: String
    public let stderr: String
    public let exitCode: Int32

    public init(stdout: String, stderr: String, exitCode: Int32) {
        self.stdout = stdout
        self.stderr = stderr
        self.exitCode = exitCode
    }
}

public enum ShellOutputEvent: Sendable {
    case line(String)
    case completed(exitCode: Int32)
}

public protocol ShellCommandRunning: Sendable {
    func run(
        executable: String,
        arguments: [String],
        workingDirectory: URL?
    ) throws -> ShellCommandResult

    func streamLines(
        executable: String,
        arguments: [String],
        workingDirectory: URL?
    ) -> AsyncStream<String>

    func streamOutput(
        executable: String,
        arguments: [String],
        workingDirectory: URL?
    ) -> AsyncStream<ShellOutputEvent>
}

public struct ShellCommandRunner: ShellCommandRunning {
    /// Git sets these when invoking hooks; strip so subprocesses use `workingDirectory`.
    private static let gitEnvOverrideKeys = [
        "GIT_DIR", "GIT_WORK_TREE", "GIT_INDEX_FILE",
        "GIT_OBJECT_DIRECTORY", "GIT_COMMON_DIR",
    ]

    public init() {}

    private func sanitizedEnvironment() -> [String: String] {
        var env = ProcessInfo.processInfo.environment
        for key in Self.gitEnvOverrideKeys {
            env.removeValue(forKey: key)
        }
        return env
    }

    public func run(
        executable: String,
        arguments: [String],
        workingDirectory: URL?
    ) throws -> ShellCommandResult {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = arguments
        process.currentDirectoryURL = workingDirectory
        process.environment = sanitizedEnvironment()

        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()
        process.standardOutput = stdoutPipe
        process.standardError = stderrPipe

        try process.run()
        process.waitUntilExit()

        let stdoutData = stdoutPipe.fileHandleForReading.readDataToEndOfFile()
        let stderrData = stderrPipe.fileHandleForReading.readDataToEndOfFile()

        return ShellCommandResult(
            stdout: String(data: stdoutData, encoding: .utf8) ?? "",
            stderr: String(data: stderrData, encoding: .utf8) ?? "",
            exitCode: process.terminationStatus
        )
    }

    public func streamLines(
        executable: String,
        arguments: [String],
        workingDirectory: URL?
    ) -> AsyncStream<String> {
        AsyncStream { continuation in
            Task {
                for await event in streamOutput(
                    executable: executable,
                    arguments: arguments,
                    workingDirectory: workingDirectory
                ) {
                    if case let .line(text) = event {
                        continuation.yield(text)
                    }
                }
                continuation.finish()
            }
        }
    }

    public func streamOutput(
        executable: String,
        arguments: [String],
        workingDirectory: URL?
    ) -> AsyncStream<ShellOutputEvent> {
        AsyncStream { continuation in
            let process = Process()
            process.executableURL = URL(fileURLWithPath: executable)
            process.arguments = arguments
            process.currentDirectoryURL = workingDirectory
            process.environment = sanitizedEnvironment()

            let pipe = Pipe()
            process.standardOutput = pipe
            process.standardError = pipe

            final class LineBuffer: @unchecked Sendable {
                var remainder = ""
                func append(_ chunk: String) -> [String] {
                    remainder += chunk
                    var lines: [String] = []
                    while let range = remainder.range(of: "\n") {
                        let line = String(remainder[..<range.lowerBound])
                        lines.append(line)
                        remainder = String(remainder[range.upperBound...])
                    }
                    return lines
                }

                func flush() -> String? {
                    guard !remainder.isEmpty else { return nil }
                    defer { remainder = "" }
                    return remainder
                }
            }

            let buffer = LineBuffer()
            let finishState = StreamFinishState()

            pipe.fileHandleForReading.readabilityHandler = { handle in
                let data = handle.availableData
                guard !data.isEmpty else { return }
                guard let chunk = String(data: data, encoding: .utf8) else { return }
                for line in buffer.append(chunk) {
                    continuation.yield(.line(line))
                }
            }

            do {
                try process.run()
            } catch {
                finishState.finish(exitCode: -1, continuation: continuation)
                return
            }

            process.terminationHandler = { proc in
                pipe.fileHandleForReading.readabilityHandler = nil
                let remaining = pipe.fileHandleForReading.readDataToEndOfFile()
                if !remaining.isEmpty,
                   let chunk = String(data: remaining, encoding: .utf8) {
                    for line in buffer.append(chunk) {
                        continuation.yield(.line(line))
                    }
                }
                if let tail = buffer.flush() {
                    continuation.yield(.line(tail))
                }
                finishState.finish(exitCode: proc.terminationStatus, continuation: continuation)
            }
        }
    }
}

private final class StreamFinishState: @unchecked Sendable {
    private let lock = NSLock()
    private var finished = false

    func finish(exitCode: Int32, continuation: AsyncStream<ShellOutputEvent>.Continuation) {
        lock.lock()
        defer { lock.unlock() }
        guard !finished else { return }
        finished = true
        continuation.yield(.completed(exitCode: exitCode))
        continuation.finish()
    }
}
