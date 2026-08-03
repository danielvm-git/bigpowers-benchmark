import Foundation
import SwiftTerm

/// Runs CLI health-check commands through SwiftTerm `LocalProcess` (PTY) and a login shell.
public struct SwiftTermCLIProcessRunner: CLIProcessRunning {
    public let shellPath: String

    public init(shellPath: String = CLIPathResolver.loginShellPath()) {
        self.shellPath = shellPath
    }

    public func run(
        executable: String,
        arguments: [String],
        timeoutMs: Int
    ) async throws -> ShellCommandResult {
        try await withCheckedThrowingContinuation { continuation in
            let capture = LocalProcessOutputCapture(continuation: continuation, timeoutMs: timeoutMs)
            let process = LocalProcess(delegate: capture, dispatchQueue: DispatchQueue(label: "cli-ping-runner"))
            capture.process = process
            process.startProcess(
                executable: executable,
                args: arguments,
                environment: Self.loginShellEnvironment()
            )
            capture.scheduleTimeout()
        }
    }

    private static func loginShellEnvironment() -> [String] {
        var env = ProcessInfo.processInfo.environment.map { "\($0.key)=\($0.value)" }
        env.removeAll { $0.hasPrefix("TERM=") }
        env.append("TERM=dumb")
        env.append("CI=true")
        env.append("NO_COLOR=1")
        if !env.contains(where: { $0.hasPrefix("LANG=") }) {
            env.append("LANG=en_US.UTF-8")
        }
        return env
    }
}

private final class LocalProcessOutputCapture: LocalProcessDelegate, @unchecked Sendable {
    var process: LocalProcess?
    private var continuation: CheckedContinuation<ShellCommandResult, Error>?
    private var output = Data()
    private var didFinish = false
    private let lock = NSLock()
    private var timeoutTask: Task<Void, Never>?
    private let timeoutMs: Int

    init(continuation: CheckedContinuation<ShellCommandResult, Error>, timeoutMs: Int) {
        self.continuation = continuation
        self.timeoutMs = timeoutMs
    }

    func getWindowSize() -> winsize {
        var size = winsize()
        size.ws_row = 24
        size.ws_col = 80
        return size
    }

    func dataReceived(slice: ArraySlice<UInt8>) {
        lock.lock()
        output.append(contentsOf: slice)
        lock.unlock()
    }

    func processTerminated(_: LocalProcess, exitCode: Int32?) {
        finish(exitCode: exitCode ?? -1, timedOut: false)
    }

    func scheduleTimeout() {
        timeoutTask = Task {
            try? await Task.sleep(nanoseconds: UInt64(max(timeoutMs, 1)) * 1_000_000)
            process?.terminate()
            finish(exitCode: -1, timedOut: true)
        }
    }

    private func finish(exitCode: Int32, timedOut: Bool) {
        lock.lock()
        defer { lock.unlock() }
        guard !didFinish, let continuation else { return }
        didFinish = true
        timeoutTask?.cancel()

        if timedOut {
            continuation.resume(throwing: CLIPingError.timeout)
            return
        }

        let text = String(data: output, encoding: .utf8) ?? ""
        continuation.resume(returning: ShellCommandResult(
            stdout: text,
            stderr: "",
            exitCode: exitCode
        ))
    }
}
