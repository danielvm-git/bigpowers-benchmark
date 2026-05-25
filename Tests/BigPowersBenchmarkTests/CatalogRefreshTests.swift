@testable import BigPowersBenchmarkKit
import Foundation
import Testing

@Suite("StaticCatalogCache")
struct StaticCatalogCacheTests {
    @Test("save and load round-trip")
    func roundTrip() throws {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathComponent("static-catalog.json")
        let model = StaticModelCatalogs.portalModel(id: "test/model", name: "Test Model")
        let cache = StaticCatalogCache(
            fetchedAt: Date(timeIntervalSince1970: 1_700_000_000),
            nousResearch: [model],
            openCode: [],
            claudeCLI: [StaticModelCatalogs.claudeCLIModel(modelArg: "sonnet")],
            geminiCLI: [StaticModelCatalogs.geminiCLIModel(modelArg: "gemini-3-flash-preview")]
        )

        try cache.save(to: url)
        let loaded = StaticCatalogCache.load(from: url)

        #expect(loaded == cache)
    }

    @Test("applyCache ignores poisoned nous catalog over 50 models")
    func applyCacheRejectsPoisonedNous() {
        let saved = StaticModelCatalogs.nousResearch
        defer { StaticModelCatalogs.nousResearch = saved }

        let poisoned = (0 ..< 60).map { index in
            StaticModelCatalogs.portalModel(id: "vendor/model-\(index)", name: "Model \(index)")
        }
        StaticModelCatalogs.applyCache(
            StaticCatalogCache(
                fetchedAt: Date(),
                nousResearch: poisoned,
                openCode: []
            )
        )

        #expect(StaticModelCatalogs.nousResearch.count == 24)
    }
}

@Suite("CatalogRefreshService", .serialized)
struct CatalogRefreshServiceTests {
    private final class StubURLProtocol: URLProtocol, @unchecked Sendable {
        nonisolated(unsafe) static var responder: (@Sendable (URLRequest) throws -> (HTTPURLResponse, Data))?

        override static func canInit(with request: URLRequest) -> Bool {
            responder != nil && (
                request.url?.host?.contains("nousresearch") == true
                    || request.url?.host == "api.anthropic.com"
                    || request.url?.host == "models.dev"
            )
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

    @Test("refreshNous uses curated manifest and filters live /v1/models")
    func refreshNous() async throws {
        let manifestURL = try #require(URL(string: "https://hermes-agent.nousresearch.com/docs/api/model-catalog.json"))
        let modelsURL = try #require(URL(string: "https://inference-api.nousresearch.com/v1/models"))

        StubURLProtocol.responder = { request in
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 200,
                httpVersion: nil,
                headerFields: nil
            )!
            if request.url == manifestURL {
                let data = Data("""
                {
                  "version": 1,
                  "providers": {
                    "nous": {
                      "models": [
                        { "id": "anthropic/claude-opus-4.7" },
                        { "id": "anthropic/claude-sonnet-4.6" }
                      ]
                    }
                  }
                }
                """.utf8)
                return (response, data)
            }
            if request.url == modelsURL {
                #expect(request.value(forHTTPHeaderField: "Authorization") == "Bearer test-key")
                let liveEntries = (0 ..< 400).map { index in
                    """
                    { "id": "vendor/noise-model-\(index)", "name": "Noise \(index)" }
                    """
                }.joined(separator: ",")
                let data = Data("""
                {
                  "data": [
                    { "id": "anthropic/claude-opus-4.7", "name": "Claude Opus 4.7", "context_length": 200000 },
                    { "id": "hermes/test", "name": "Hermes Test" },
                    \(liveEntries)
                  ]
                }
                """.utf8)
                return (response, data)
            }
            Issue.record("Unexpected URL: \(request.url?.absoluteString ?? "nil")")
            return (response, Data())
        }
        defer { StubURLProtocol.responder = nil }

        let service = CatalogRefreshService(
            session: makeStubSession(),
            modelsURL: modelsURL,
            nousManifestURL: manifestURL
        )
        let models = try await service.refreshNous(apiKey: "test-key", timeoutMs: 5000)

        #expect(models.count == 2)
        #expect(models[0].id == "nousresearch-direct:anthropic/claude-opus-4.7")
        #expect(models[0].contextWindow == 200_000)
        #expect(models[0].pingTransport == .nousResearch)
        #expect(models[1].id == "nousresearch-direct:anthropic/claude-sonnet-4.6")
    }

    @Test("refreshNous falls back to static curated ids when manifest is unavailable")
    func refreshNousManifestFallback() async throws {
        let manifestURL = try #require(URL(string: "https://hermes-agent.nousresearch.com/docs/api/model-catalog.json"))
        let modelsURL = try #require(URL(string: "https://inference-api.nousresearch.com/v1/models"))

        StubURLProtocol.responder = { request in
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: request.url == manifestURL ? 404 : 200,
                httpVersion: nil,
                headerFields: nil
            )!
            if request.url == manifestURL {
                return (response, Data())
            }
            let data = Data("""
            {
              "data": [
                { "id": "anthropic/claude-opus-4.7", "name": "Claude Opus 4.7", "context_length": 200000 }
              ]
            }
            """.utf8)
            return (response, data)
        }
        defer { StubURLProtocol.responder = nil }

        let service = CatalogRefreshService(
            session: makeStubSession(),
            modelsURL: modelsURL,
            nousManifestURL: manifestURL
        )
        let models = try await service.refreshNous(apiKey: "test-key", timeoutMs: 5000)

        #expect(models.count == 24)
        #expect(models.contains { $0.apiModelId == "anthropic/claude-opus-4.7" && $0.contextWindow == 200_000 })
    }

    @Test("refreshNous maps 401 to missing credentials")
    func refreshNousUnauthorized() async {
        StubURLProtocol.responder = { request in
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 401,
                httpVersion: nil,
                headerFields: nil
            )!
            let data = Data("""
            { "error": { "message": "Unauthorized" } }
            """.utf8)
            return (response, data)
        }
        defer { StubURLProtocol.responder = nil }

        let service = CatalogRefreshService(session: makeStubSession())
        do {
            _ = try await service.refreshNous(apiKey: "test-key", timeoutMs: 5000)
            Issue.record("Expected missingCredentials")
        } catch let CatalogRefreshError.missingCredentials(message) {
            #expect(message == "Session expired — run: hermes login")
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
    }

    @Test("refreshOpenCode parses opencode model lines")
    func refreshOpenCode() async throws {
        let runner = MockCLIProcessRunner { executable, arguments, timeoutMs in
            #expect(executable == "opencode")
            #expect(arguments == ["models", "opencode"])
            #expect(timeoutMs == 5000)
            return ShellCommandResult(
                stdout: """
                opencode/big-pickle
                opencode/deepseek-v4-flash-free
                """,
                stderr: "",
                exitCode: 0
            )
        }

        let service = CatalogRefreshService(processRunner: runner)
        let models = try await service.refreshOpenCode(timeoutMs: 5000)

        #expect(models.count == 2)
        #expect(models[0].apiModelId == "opencode/big-pickle")
        #expect(models[1].apiModelId == "opencode/deepseek-v4-flash-free")
        #expect(models[1].isFreeModel)
    }

    @Test("refreshClaudeCLI maps Anthropic /v1/models")
    func refreshClaudeCLIAnthropic() async throws {
        StubURLProtocol.responder = { request in
            #expect(request.url?.host == "api.anthropic.com")
            #expect(request.value(forHTTPHeaderField: "Authorization") == "Bearer cc-oauth-token")
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 200,
                httpVersion: nil,
                headerFields: nil
            )!
            let data = Data("""
            {
              "data": [
                { "id": "claude-sonnet-4-6" },
                { "id": "claude-opus-4-7" }
              ]
            }
            """.utf8)
            return (response, data)
        }
        defer { StubURLProtocol.responder = nil }

        let service = CatalogRefreshService(
            session: makeStubSession(),
            anthropicTokenProvider: { "cc-oauth-token" }
        )
        let models = try await service.refreshClaudeCLI(timeoutMs: 5000)

        #expect(models.count == 2)
        #expect(models[0].apiModelId == "claude-opus-4-7")
        #expect(models[0].pingTransport == .claudeCLI)
        #expect(models[1].apiModelId == "claude-sonnet-4-6")
    }

    @Test("refreshClaudeCLI falls back to models.dev when Anthropic auth is missing")
    func refreshClaudeCLIModelsDevFallback() async throws {
        StubURLProtocol.responder = { request in
            let host = request.url?.host ?? ""
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 200,
                httpVersion: nil,
                headerFields: nil
            )!
            if host == "models.dev" {
                let data = Data("""
                {
                  "anthropic": {
                    "models": {
                      "claude-sonnet-4-6": { "tool_call": true },
                      "claude-embed-v1": { "tool_call": true }
                    }
                  }
                }
                """.utf8)
                return (response, data)
            }
            Issue.record("Unexpected host: \(host)")
            return (response, Data())
        }
        defer { StubURLProtocol.responder = nil }

        let service = CatalogRefreshService(
            session: makeStubSession(),
            anthropicTokenProvider: { nil }
        )
        let models = try await service.refreshClaudeCLI(timeoutMs: 5000)

        #expect(models.count == 1)
        #expect(models[0].apiModelId == "claude-sonnet-4-6")
    }

    @Test("refreshGeminiCLI merges models.dev with curated Gemini CLI ids")
    func refreshGeminiCLI() async throws {
        StubURLProtocol.responder = { request in
            #expect(request.url?.host == "models.dev")
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 200,
                httpVersion: nil,
                headerFields: nil
            )!
            let data = Data("""
            {
              "google": {
                "models": {
                  "gemini-2.5-flash": { "tool_call": true },
                  "gemini-2.0-flash": { "tool_call": true },
                  "gemma-4-26b-it": { "tool_call": true }
                }
              }
            }
            """.utf8)
            return (response, data)
        }
        defer { StubURLProtocol.responder = nil }

        let service = CatalogRefreshService(session: makeStubSession())
        let models = try await service.refreshGeminiCLI(timeoutMs: 5000)

        #expect(models.contains { $0.apiModelId == "gemini-2.5-flash" })
        #expect(models.contains { $0.apiModelId == "gemini-3.1-pro-preview" })
        #expect(!models.contains { $0.apiModelId == "gemini-2.0-flash" })
        #expect(!models.contains { $0.apiModelId == "gemma-4-26b-it" })
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
