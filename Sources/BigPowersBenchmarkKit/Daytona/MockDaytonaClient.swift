import Foundation

public final class MockDaytonaClient: DaytonaClientProtocol, @unchecked Sendable {
    public var nextCommandOutput: String = ""
    /// Lines yielded by the first streamLogs call (e.g. opencode output).
    /// Consumed on first use; subsequent calls fall back to nextCommandOutput.
    public var opcodeLogLines: [String] = []
    private var streamLogsCallCount = 0
    public init() {}

    public func listSandboxes() async throws -> [Sandbox] {
        [
            Sandbox(id: "sb-1", name: "Sandbox 1", state: .started, labels: [:], toolboxProxyUrl: ""),
            Sandbox(id: "sb-2", name: "Sandbox 2", state: .started, labels: [:], toolboxProxyUrl: ""),
        ]
    }

    public func createSession(sandboxId _: String) async throws -> String {
        "session-123"
    }

    public func executeCommand(
        sandboxId _: String,
        sessionId _: String,
        command _: String,
        runAsync: Bool
    ) async throws -> String {
        if runAsync {
            "cmd-123"
        } else {
            nextCommandOutput
        }
    }

    public func getCommandStatus(
        sandboxId _: String,
        sessionId _: String,
        commandId _: String
    ) async throws -> CommandStatus {
        CommandStatus(exitCode: 0, running: false)
    }

    public func streamLogs(sandboxId _: String, sessionId _: String, commandId _: String) -> AsyncStream<String> {
        let isFirstCall = streamLogsCallCount == 0
        streamLogsCallCount += 1
        let lines = isFirstCall && !opcodeLogLines.isEmpty ? opcodeLogLines : nil
        let fallback = nextCommandOutput
        return AsyncStream { continuation in
            if let lines {
                for line in lines {
                    continuation.yield(line)
                }
            } else if !fallback.isEmpty {
                continuation.yield(fallback)
            } else {
                continuation.yield("log line 1")
                continuation.yield("log line 2")
            }
            continuation.finish()
        }
    }

    public func deleteDirectory(sandboxId _: String, path _: String) async throws {}

    public func writeFile(sandboxId _: String, path _: String, content _: String) async throws {}

    public var pingDetailedResult: PingResult = .success

    public func pingDetailed() async -> PingResult {
        pingDetailedResult
    }

    public func ping() async -> Bool {
        if case .success = await pingDetailed() { return true }
        return false
    }
}
