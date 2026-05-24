import Foundation

public protocol DaytonaClientProtocol: Sendable {
    func listSandboxes() async throws -> [Sandbox]
    func createSession(sandboxId: String) async throws -> String
    func executeCommand(sandboxId: String, sessionId: String, command: String, runAsync: Bool) async throws -> String
    func getCommandStatus(sandboxId: String, sessionId: String, commandId: String) async throws -> CommandStatus
    func streamLogs(sandboxId: String, sessionId: String, commandId: String) -> AsyncStream<String>
    func deleteDirectory(sandboxId: String, path: String) async throws
    func writeFile(sandboxId: String, path: String, content: String) async throws
    func pingDetailed() async -> PingResult
    func ping() async -> Bool
}

public struct CommandStatus: Codable, Sendable {
    public let exitCode: Int?
    public let running: Bool

    public init(exitCode: Int?, running: Bool) {
        self.exitCode = exitCode
        self.running = running
    }
}
