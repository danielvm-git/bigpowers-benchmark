import Foundation

public final class DaytonaClient: DaytonaClientProtocol {
    private let config: DaytonaConfig
    private let session: URLSession
    private let logger = AppLogger.daytona

    public init(config: DaytonaConfig, session: URLSession = .shared) {
        self.config = config
        self.session = session
    }

    public func listSandboxes() async throws -> [Sandbox] {
        let url = try baseURL().appendingPathComponent("sandbox")
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        try addAuthHeader(to: &request)
        logRequest(method: "GET", path: "/sandbox")

        let (data, response) = try await performData(for: request)
        try validateResponse(response, path: "/sandbox")

        return try JSONDecoder().decode([Sandbox].self, from: data)
    }

    public func createSession(sandboxId: String) async throws -> String {
        let path = "/toolbox/\(sandboxId)/toolbox/process/session"
        let url = try baseURL()
            .appendingPathComponent("toolbox")
            .appendingPathComponent(sandboxId)
            .appendingPathComponent("toolbox")
            .appendingPathComponent("process")
            .appendingPathComponent("session")

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        try addAuthHeader(to: &request)
        logRequest(method: "POST", path: path)

        let (data, response) = try await performData(for: request)
        try validateResponse(response, path: path)

        if let sessionId = String(data: data, encoding: .utf8) {
            return sessionId.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        throw DaytonaError.invalidResponse
    }

    public func executeCommand(
        sandboxId: String,
        sessionId: String,
        command: String,
        runAsync: Bool
    ) async throws -> String {
        let path = "/toolbox/\(sandboxId)/toolbox/process/session/\(sessionId)/exec"
        let url = try baseURL()
            .appendingPathComponent("toolbox")
            .appendingPathComponent(sandboxId)
            .appendingPathComponent("toolbox")
            .appendingPathComponent("process")
            .appendingPathComponent("session")
            .appendingPathComponent(sessionId)
            .appendingPathComponent("exec")

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        try addAuthHeader(to: &request)
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body = ["command": command, "runAsync": runAsync] as [String: Any]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        logRequest(method: "POST", path: path)

        let (data, response) = try await performData(for: request)
        try validateResponse(response, path: path)

        if let cmdId = String(data: data, encoding: .utf8) {
            return cmdId.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        throw DaytonaError.invalidResponse
    }

    public func getCommandStatus(
        sandboxId: String,
        sessionId: String,
        commandId: String
    ) async throws -> CommandStatus {
        let path = "/toolbox/\(sandboxId)/toolbox/process/session/\(sessionId)/command/\(commandId)"
        let url = try baseURL()
            .appendingPathComponent("toolbox")
            .appendingPathComponent(sandboxId)
            .appendingPathComponent("toolbox")
            .appendingPathComponent("process")
            .appendingPathComponent("session")
            .appendingPathComponent(sessionId)
            .appendingPathComponent("command")
            .appendingPathComponent(commandId)

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        try addAuthHeader(to: &request)
        logRequest(method: "GET", path: path)

        let (data, response) = try await performData(for: request)
        try validateResponse(response, path: path)

        return try JSONDecoder().decode(CommandStatus.self, from: data)
    }

    public func streamLogs(sandboxId: String, sessionId: String, commandId: String) -> AsyncStream<String> {
        AsyncStream { continuation in
            guard var baseWSURL = config.baseURL.replacingOccurrences(of: "https://", with: "wss://")
                .replacingOccurrences(
                    of: "http://",
                    with: "ws://"
                ) as String?
            else {
                logger.error("WebSocket URL invalid", metadata: ["sandboxId": .string(sandboxId)])
                continuation.finish()
                return
            }
            if !baseWSURL.hasSuffix("/") {
                baseWSURL += "/"
            }
            let wsPath = "/toolbox/\(sandboxId)/toolbox/process/session/\(sessionId)/command/\(commandId)/logs"
            guard let url =
                URL(
                    string: "\(baseWSURL)toolbox/\(sandboxId)/toolbox/process/session/\(sessionId)/command/\(commandId)/logs?follow=true"
                )
            else {
                logger.error("WebSocket URL construction failed", metadata: ["path": .string(wsPath)])
                continuation.finish()
                return
            }

            var request = URLRequest(url: url)
            do {
                try addAuthHeader(to: &request)
            } catch {
                logger.error(
                    "WebSocket auth failed",
                    metadata: ["error": .string(DaytonaError.userMessage(for: error))]
                )
                continuation.finish()
                return
            }

            logger.info("WebSocket connecting", metadata: ["path": .string(wsPath)])
            let webSocketTask = session.webSocketTask(with: request)

            continuation.onTermination = { @Sendable _ in
                webSocketTask.cancel(with: .goingAway, reason: nil)
            }

            webSocketTask.resume()

            @Sendable func receiveNext() {
                webSocketTask.receive { [weak webSocketTask] result in
                    guard webSocketTask != nil else {
                        continuation.finish()
                        return
                    }
                    switch result {
                    case let .success(message):
                        switch message {
                        case let .string(text):
                            continuation.yield(text)
                        case let .data(data):
                            if let text = String(data: data, encoding: .utf8) {
                                continuation.yield(text)
                            }
                        @unknown default:
                            break
                        }
                        receiveNext()
                    case let .failure(error):
                        AppLogger.daytona.warning("WebSocket closed", metadata: [
                            "error": .string(LogSanitizer.sanitize(error.localizedDescription)),
                        ])
                        continuation.finish()
                    }
                }
            }

            receiveNext()
        }
    }

    public func deleteDirectory(sandboxId: String, path: String) async throws {
        guard var components = try URLComponents(url: baseURL(), resolvingAgainstBaseURL: false) else {
            throw DaytonaError.invalidBaseURL
        }
        components.path = (components.path as NSString).appendingPathComponent("toolbox/\(sandboxId)/toolbox/files")
        components.queryItems = [URLQueryItem(name: "path", value: path)]
        guard let url = components.url else {
            throw DaytonaError.invalidBaseURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        try addAuthHeader(to: &request)
        logRequest(method: "DELETE", path: "/toolbox/\(sandboxId)/toolbox/files")

        let (_, response) = try await performData(for: request)
        try validateResponse(response, path: "/toolbox/\(sandboxId)/toolbox/files")
    }

    public func writeFile(sandboxId: String, path: String, content: String) async throws {
        guard var components = try URLComponents(url: baseURL(), resolvingAgainstBaseURL: false) else {
            throw DaytonaError.invalidBaseURL
        }
        components.path = (components.path as NSString)
            .appendingPathComponent("toolbox/\(sandboxId)/toolbox/files/upload")
        components.queryItems = [URLQueryItem(name: "path", value: path)]
        guard let url = components.url else {
            throw DaytonaError.invalidBaseURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        try addAuthHeader(to: &request)

        let boundary = "Boundary-\(UUID().uuidString)"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

        var body = Data()
        body.append(Data("--\(boundary)\r\n".utf8))
        body.append(Data("Content-Disposition: form-data; name=\"file\"; filename=\"prompt.txt\"\r\n".utf8))
        body.append(Data("Content-Type: text/plain\r\n\r\n".utf8))
        body.append(Data(content.utf8))
        body.append(Data("\r\n--\(boundary)--\r\n".utf8))
        request.httpBody = body
        logRequest(method: "POST", path: "/toolbox/\(sandboxId)/toolbox/files/upload")

        let (_, response) = try await performData(for: request)
        try validateResponse(response, path: "/toolbox/\(sandboxId)/toolbox/files/upload")
    }

    public func pingDetailed() async -> PingResult {
        do {
            _ = try await listSandboxes()
            logger.info("Ping succeeded")
            return .success
        } catch {
            let message = DaytonaError.userMessage(for: error)
            logger.error("Ping failed", metadata: ["error": .string(message)])
            return .failure(message: message)
        }
    }

    public func ping() async -> Bool {
        if case .success = await pingDetailed() { return true }
        return false
    }

    private func performData(for request: URLRequest) async throws -> (Data, URLResponse) {
        do {
            return try await session.data(for: request)
        } catch {
            logger.error("Network request failed", metadata: [
                "error": .string(LogSanitizer.sanitize(error.localizedDescription)),
                "path": .string(request.url?.path ?? "unknown"),
            ])
            throw error
        }
    }

    private func logRequest(method: String, path: String) {
        logger.info("HTTP request", metadata: [
            "method": .string(method),
            "path": .string(path),
        ])
    }

    private func baseURL() throws -> URL {
        guard let url = URL(string: config.baseURL) else {
            throw DaytonaError.invalidBaseURL
        }
        return url
    }

    private func addAuthHeader(to request: inout URLRequest) throws {
        let token = config.apiKey
        guard !token.isEmpty else {
            throw DaytonaError.missingApiKey
        }
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
    }

    private func validateResponse(_ response: URLResponse, path: String) throws {
        guard let httpResponse = response as? HTTPURLResponse else {
            throw DaytonaError.invalidResponse
        }

        guard (200 ... 299).contains(httpResponse.statusCode) else {
            logger.error("HTTP error", metadata: [
                "statusCode": .stringConvertible(httpResponse.statusCode),
                "path": .string(path),
            ])
            throw DaytonaError.httpError(statusCode: httpResponse.statusCode)
        }
    }
}

public enum DaytonaError: Error {
    case invalidBaseURL
    case missingApiKey
    case invalidResponse
    case httpError(statusCode: Int)
}
