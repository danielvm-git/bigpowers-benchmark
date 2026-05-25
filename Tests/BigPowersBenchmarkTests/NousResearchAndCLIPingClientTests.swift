@testable import BigPowersBenchmarkKit
import Foundation
import Testing

private final class StubURLProtocol: URLProtocol, @unchecked Sendable {
    nonisolated(unsafe) static var responder: (@Sendable (URLRequest) throws -> (HTTPURLResponse, Data))?

    override static func canInit(with request: URLRequest) -> Bool {
        guard responder != nil else { return false }
        return request.url?.host?.contains("nousresearch") == true
    }

    override static func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        guard let responder = Self.responder else {
            client?.urlProtocol(self, didFailWithError: URLError(.badURL))
            return
        }
        do {
            let (response, data) = try responder(request)
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {}
}

private func makeStubSession() -> URLSession {
    let config = URLSessionConfiguration.ephemeral
    config.protocolClasses = [StubURLProtocol.self]
    return URLSession(configuration: config)
}

@Suite("NousResearchClient", .serialized)
struct NousResearchClientTests {
    @Test("ping succeeds with reply")
    func pingSuccess() async throws {
        StubURLProtocol.responder = { request in
            #expect(request.httpMethod == "POST")
            #expect(request.value(forHTTPHeaderField: "Authorization") == nil)
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 200,
                httpVersion: nil,
                headerFields: nil
            )!
            let data = Data("""
            {
              "choices": [{ "message": { "content": "pong" } }],
              "usage": { "prompt_tokens": 5, "completion_tokens": 2 }
            }
            """.utf8)
            return (response, data)
        }
        defer { StubURLProtocol.responder = nil }

        let client = NousResearchClient(session: makeStubSession())
        let result = try await client.ping(
            modelId: "deepseek/deepseek-v4-flash",
            prompt: "Reply with just the word: pong",
            maxTokens: 10,
            timeoutMs: 5000,
            apiKey: nil
        )

        #expect(result.reply == "pong")
        #expect(result.promptTokens == 5)
        #expect(result.completionTokens == 2)
        #expect(result.latencyMs >= 0)
    }

    @Test("ping sends Bearer token when apiKey provided")
    func pingSendsBearerToken() async throws {
        StubURLProtocol.responder = { request in
            #expect(request.value(forHTTPHeaderField: "Authorization") == "Bearer nous-test-key")
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 200,
                httpVersion: nil,
                headerFields: nil
            )!
            let data = Data("""
            {
              "choices": [{ "message": { "content": "pong" } }],
              "usage": { "prompt_tokens": 1, "completion_tokens": 1 }
            }
            """.utf8)
            return (response, data)
        }
        defer { StubURLProtocol.responder = nil }

        let client = NousResearchClient(session: makeStubSession())
        let result = try await client.ping(
            modelId: "deepseek/deepseek-v4-pro",
            prompt: "pong",
            maxTokens: 10,
            timeoutMs: 5000,
            apiKey: "nous-test-key"
        )
        #expect(result.reply == "pong")
    }

    @Test("ping maps HTTP errors")
    func pingHTTPError() async {
        StubURLProtocol.responder = { request in
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 503,
                httpVersion: nil,
                headerFields: nil
            )!
            let data = Data("""
            { "error": { "message": "Service unavailable" } }
            """.utf8)
            return (response, data)
        }
        defer { StubURLProtocol.responder = nil }

        let client = NousResearchClient(session: makeStubSession())
        do {
            _ = try await client.ping(
                modelId: "deepseek/deepseek-v4-flash",
                prompt: "pong",
                maxTokens: 10,
                timeoutMs: 5000,
                apiKey: nil
            )
            Issue.record("Expected HTTP error")
        } catch let NousResearchClientError.httpError(statusCode: code, message: message) {
            #expect(code == 503)
            #expect(message == "Service unavailable")
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
    }
}

private struct MockCLIProcessRunner: CLIProcessRunning {
    var handler: @Sendable (String, [String], Int) async throws -> ShellCommandResult

    func run(
        executable: String,
        arguments: [String],
        timeoutMs: Int
    ) async throws -> ShellCommandResult {
        try await handler(executable, arguments, timeoutMs)
    }
}

@Suite("CLIPingClient")
struct CLIPingClientTests {
    @Test("pingClaude builds expected command")
    func pingClaude() async throws {
        let runner = MockCLIProcessRunner { executable, arguments, timeoutMs in
            #expect(executable == "claude")
            #expect(arguments == ["-p", "pong", "--model", "haiku", "--output-format", "text"])
            #expect(timeoutMs == 1000)
            return ShellCommandResult(stdout: "pong", stderr: "", exitCode: 0)
        }

        let client = CLIPingClient(processRunner: runner)
        let result = try await client.pingClaude(model: "haiku", prompt: "pong", timeoutMs: 1000)
        #expect(result.reply == "pong")
    }

    @Test("pingGemini builds expected command with --skip-trust")
    func pingGeminiSuccess() async throws {
        let runner = MockCLIProcessRunner { executable, arguments, timeoutMs in
            #expect(executable == "gemini")
            #expect(arguments == ["-p", "pong", "-m", "gemini-2.5-flash", "-o", "text", "--skip-trust"])
            #expect(timeoutMs == 1000)
            return ShellCommandResult(stdout: "pong", stderr: "", exitCode: 0)
        }

        let client = CLIPingClient(processRunner: runner)
        let result = try await client.pingGemini(model: "gemini-2.5-flash", prompt: "pong", timeoutMs: 1000)
        #expect(result.reply == "pong")
    }

    @Test("pingGemini maps non-zero exit to error")
    func pingGeminiFailure() async {
        let runner = MockCLIProcessRunner { _, _, _ in
            ShellCommandResult(stdout: "", stderr: "model not found", exitCode: 1)
        }

        let client = CLIPingClient(processRunner: runner)
        do {
            _ = try await client.pingGemini(model: "gemini-2.5-flash", prompt: "pong", timeoutMs: 1000)
            Issue.record("Expected nonZeroExit")
        } catch let CLIPingError.nonZeroExit(message) {
            #expect(message == "model not found")
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
    }

    @Test("pingOpenCode builds expected command")
    func pingOpenCode() async throws {
        let runner = MockCLIProcessRunner { executable, arguments, timeoutMs in
            #expect(executable == "opencode")
            #expect(arguments == [
                "run",
                "--model",
                "opencode/deepseek-v4-flash-free",
                "--dangerously-skip-permissions",
                "pong",
            ])
            #expect(timeoutMs == 2000)
            return ShellCommandResult(stdout: "pong", stderr: "", exitCode: 0)
        }

        let client = CLIPingClient(processRunner: runner)
        let result = try await client.pingOpenCode(
            model: "opencode/deepseek-v4-flash-free",
            prompt: "pong",
            timeoutMs: 2000
        )
        #expect(result.reply == "pong")
    }

    @Test("stripANSI removes terminal color codes")
    func stripANSI() {
        #expect(CLIPingClient.stripANSI("\u{001B}[91mError: missing") == "Error: missing")
    }
}
