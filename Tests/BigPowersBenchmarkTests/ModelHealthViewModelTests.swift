// swiftlint:disable file_length type_body_length
@testable import BigPowersBenchmarkKit
import Foundation
import Testing

private final class ModelHealthMockClient: OpenRouterClientProtocol, @unchecked Sendable {
    struct PingCall {
        let modelId: String
        let apiKey: String
    }

    var pingResponses: [String: Result<(OpenRouterChatCompletion, Double), Error>] = [:]
    var pingCalls: [PingCall] = []
    var generationResponses: [String: OpenRouterGenerationMetadata] = [:]
    var generationCalls: [String] = []

    func fetchModels(apiKey: String) async throws -> [ModelInfo] {
        _ = apiKey
        return []
    }

    func ping(
        modelId: String,
        apiKey: String,
        maxTokens: Int,
        timeoutMs: Int
    ) async throws -> (completion: OpenRouterChatCompletion, latencyMs: Double) {
        _ = maxTokens
        _ = timeoutMs
        pingCalls.append(PingCall(modelId: modelId, apiKey: apiKey))
        guard let result = pingResponses[modelId] else {
            throw OpenRouterClientError.invalidResponse
        }
        return try result.get()
    }

    func fetchGeneration(id: String, apiKey: String) async throws -> OpenRouterGenerationMetadata {
        _ = apiKey
        generationCalls.append(id)
        guard let metadata = generationResponses[id] else {
            throw OpenRouterClientError.invalidResponse
        }
        return metadata
    }
}

@Suite("ModelHealthViewModel", .serialized)
@MainActor
struct ModelHealthViewModelTests {
    private func sampleModel(id: String = "openai/gpt-4o", name: String = "GPT-4o") -> ModelInfo {
        ModelInfo(
            id: id,
            name: name,
            provider: "openai",
            contextWindow: 128_000,
            tier: .deep,
            capabilities: [.tools, .streaming],
            pricing: ModelPricing(inputPer1k: 5, outputPer1k: 15)
        )
    }

    private func completion(
        id: String = "gen-1",
        model: String,
        finishReason: String? = "stop",
        cost: Double = 0.001
    ) -> OpenRouterChatCompletion {
        OpenRouterChatCompletion(
            id: id,
            model: model,
            finishReason: finishReason,
            promptTokens: 10,
            completionTokens: 3,
            reasoningTokens: 0,
            cachedTokens: 0,
            cost: cost,
            upstreamCost: 0.0005,
            routingStrategy: "direct",
            attemptCount: 1
        )
    }

    @Test("ping succeeds and computes p50")
    func pingSucceeds() async {
        let mock = ModelHealthMockClient()
        mock.pingResponses["openai/gpt-4o"] = .success((completion(model: "openai/gpt-4o"), 120))
        mock.generationResponses["gen-1"] = OpenRouterGenerationMetadata(
            latency: 100,
            generationTime: 80,
            providerName: "Azure"
        )

        let vm = ModelHealthViewModel(client: mock)
        vm.sampleCount = 1
        vm.pingScope = .filtered
        await vm.pingAll(models: [sampleModel()], apiKey: "secret-key")

        #expect(vm.rows.count == 1)
        #expect(vm.rows[0].status == .live)
        #expect(vm.rows[0].p50 == 120)
        #expect(vm.rows[0].providerName == "Azure")
        #expect(mock.generationCalls.contains("gen-1"))
    }

    @Test("all timeout populates timeout rows without crash")
    func allTimeout() async {
        let mock = ModelHealthMockClient()
        mock.pingResponses["openai/gpt-4o"] = .failure(OpenRouterClientError.timedOut)
        mock.pingResponses["anthropic/claude-3.5-sonnet"] = .failure(OpenRouterClientError.timedOut)

        let vm = ModelHealthViewModel(client: mock)
        vm.pingScope = .filtered
        await vm.pingAll(
            models: [
                sampleModel(),
                sampleModel(id: "anthropic/claude-3.5-sonnet", name: "Claude 3.5 Sonnet"),
            ],
            apiKey: "secret-key"
        )

        #expect(vm.rows.count == 2)
        #expect(vm.rows.allSatisfy { $0.status == .timeout })
        #expect(vm.timeoutCount == 2)
    }

    @Test("partial failure keeps valid and error rows")
    func partialFailure() async {
        let mock = ModelHealthMockClient()
        mock.pingResponses["openai/gpt-4o"] = .success((completion(model: "openai/gpt-4o"), 150))
        mock.pingResponses["anthropic/claude-3.5-sonnet"] = .failure(
            OpenRouterClientError.httpError(statusCode: 503, message: "Unavailable")
        )
        mock.pingResponses["google/gemini-1.5-pro"] = .failure(OpenRouterClientError.timedOut)

        let vm = ModelHealthViewModel(client: mock)
        vm.pingScope = .filtered
        await vm.pingAll(
            models: [
                sampleModel(),
                sampleModel(id: "anthropic/claude-3.5-sonnet", name: "Claude 3.5 Sonnet"),
                sampleModel(id: "google/gemini-1.5-pro", name: "Gemini 1.5 Pro"),
            ],
            apiKey: "secret-key"
        )

        #expect(vm.rows.count == 3)
        #expect(vm.rows.contains { if case .live = $0.status { true } else { false } })
        #expect(vm.rows.contains { if case .error = $0.status { true } else { false } })
        #expect(vm.rows.contains { $0.status == .timeout })
    }

    @Test("content filter marks row as contentFilter")
    func testContentFilter() async {
        let mock = ModelHealthMockClient()
        mock.pingResponses["openai/gpt-4o"] = .success((
            completion(model: "openai/gpt-4o", finishReason: "content_filter"),
            90
        ))

        let vm = ModelHealthViewModel(client: mock)
        vm.sampleCount = 1
        vm.pingScope = .filtered
        await vm.pingAll(models: [sampleModel()], apiKey: "secret-key")

        #expect(vm.rows[0].status == .contentFilter)
    }

    @Test("mismatch when responded model differs")
    func testMismatch() async {
        let mock = ModelHealthMockClient()
        mock.pingResponses["openrouter/free"] = .success((
            completion(model: "meta-llama/llama-3.3-70b-instruct:free"),
            200
        ))

        let vm = ModelHealthViewModel(client: mock)
        vm.sampleCount = 1
        vm.pingScope = .filtered
        await vm.pingAll(
            models: [sampleModel(id: "openrouter/free", name: "OpenRouter Free")],
            apiKey: "secret-key"
        )

        if case let .mismatch(actual) = vm.rows[0].status {
            #expect(actual == "meta-llama/llama-3.3-70b-instruct:free")
        } else {
            Issue.record("Expected mismatch status")
        }
    }

    @Test("versioned slug counts as live")
    func versionedSlugIsLive() async {
        let mock = ModelHealthMockClient()
        mock.pingResponses["anthropic/claude-3-haiku"] = .success((
            completion(model: "anthropic/claude-3-haiku-20240307"),
            180
        ))

        let vm = ModelHealthViewModel(client: mock)
        vm.sampleCount = 1
        vm.pingScope = .filtered
        await vm.pingAll(
            models: [sampleModel(id: "anthropic/claude-3-haiku", name: "Claude 3 Haiku")],
            apiKey: "secret-key"
        )

        #expect(vm.rows[0].status == .live)
    }

    @Test("default ping scope targets smart free models")
    func freeScopeDefault() {
        let vm = ModelHealthViewModel(client: ModelHealthMockClient())
        #expect(vm.pingScope == .smartFree)
        let models = [
            ModelInfo(
                id: "openai/gpt-4o",
                name: "GPT-4o",
                provider: "openai",
                contextWindow: 128_000,
                tier: .deep,
                capabilities: [.tools],
                pricing: ModelPricing(inputPer1k: 5, outputPer1k: 15)
            ),
            ModelInfo(
                id: "meta-llama/llama-3.3-70b-instruct:free",
                name: "Llama Free",
                provider: "meta-llama",
                contextWindow: 128_000,
                tier: .deep,
                capabilities: [.streaming],
                pricing: ModelPricing(inputPer1k: 0, outputPer1k: 0)
            ),
        ]

        #expect(vm.pingTargets(from: models).count == 1)
        #expect(vm.pingTargets(from: models)[0].id.contains(":free"))
    }

    @Test("HTTP 402 maps to noCredit status")
    func noCreditStatus() async {
        let mock = ModelHealthMockClient()
        mock.pingResponses["openai/gpt-4o"] = .failure(
            OpenRouterClientError.httpError(statusCode: 402, message: "Insufficient credits")
        )

        let vm = ModelHealthViewModel(client: mock)
        vm.pingScope = .filtered
        await vm.pingAll(models: [sampleModel()], apiKey: "secret-key")

        #expect(vm.rows[0].status == .noCredit)
        #expect(vm.noCreditCount == 1)
    }

    @Test("selectProvider sets pingScope to provider when a provider is chosen")
    func selectProviderSetsProviderScope() {
        let vm = ModelHealthViewModel(client: ModelHealthMockClient())
        #expect(vm.pingScope == .smartFree)

        vm.selectProvider("openai")

        #expect(vm.selectedProvider == "openai")
        #expect(vm.pingScope == .provider)
    }

    @Test("selectProvider resets pingScope to smartFree when provider is cleared")
    func selectProviderClearsScope() {
        let vm = ModelHealthViewModel(client: ModelHealthMockClient())
        vm.selectProvider("openai")
        #expect(vm.pingScope == .provider)

        vm.selectProvider(nil)

        #expect(vm.selectedProvider == nil)
        #expect(vm.pingScope == .smartFree)
    }

    @Test("provider scope pings only models for selected provider")
    func providerScopeTargets() {
        let vm = ModelHealthViewModel(client: ModelHealthMockClient())
        let models = [
            ModelInfo(
                id: "openai/gpt-4o",
                name: "GPT-4o",
                provider: "openai",
                contextWindow: 128_000,
                tier: .deep,
                capabilities: [.tools],
                pricing: ModelPricing(inputPer1k: 5, outputPer1k: 15),
                pingTransport: .openRouter
            ),
            StaticModelCatalogs.geminiCLI[0],
        ]
        vm.selectProvider(ModelHealthSubscriptionProvider.openrouter.rawValue)

        let targets = vm.pingTargets(from: models)
        #expect(targets.count == 1)
        #expect(targets[0].pingTransport == .openRouter)
    }

    @Test("rows update incrementally during batch")
    func incrementalRows() async {
        let mock = ModelHealthMockClient()
        mock.pingResponses["openai/gpt-4o"] = .success((completion(model: "openai/gpt-4o"), 100))
        mock.pingResponses["anthropic/claude-3.5-sonnet"] = .success((
            completion(model: "anthropic/claude-3.5-sonnet"),
            200
        ))

        let vm = ModelHealthViewModel(client: mock)
        vm.pingScope = .filtered
        vm.parallelism = 1
        await vm.pingAll(
            models: [
                sampleModel(),
                sampleModel(id: "anthropic/claude-3.5-sonnet", name: "Claude 3.5 Sonnet"),
            ],
            apiKey: "secret-key"
        )

        #expect(vm.rows.count == 2)
    }

    @Test("generation metadata fetched when ping succeeds")
    func generationMetadataFetched() async {
        let mock = ModelHealthMockClient()
        mock.pingResponses["openai/gpt-4o"] = .success((completion(id: "gen-abc", model: "openai/gpt-4o"), 100))
        mock.generationResponses["gen-abc"] = OpenRouterGenerationMetadata(
            latency: 95,
            generationTime: 70,
            providerName: "OpenAI"
        )

        let vm = ModelHealthViewModel(client: mock)
        vm.sampleCount = 1
        vm.pingScope = .filtered
        await vm.pingAll(models: [sampleModel()], apiKey: "secret-key")

        #expect(mock.generationCalls == ["gen-abc"])
        #expect(vm.rows[0].generationTime == 70)
    }

    @Test("api key not leaked in error status")
    func apiKeyNotLeaked() async {
        let secret = "super-secret-key-12345"
        let mock = ModelHealthMockClient()
        mock.pingResponses["openai/gpt-4o"] = .failure(
            OpenRouterClientError.httpError(
                statusCode: 401,
                message: "Invalid token Bearer \(secret)"
            )
        )

        let vm = ModelHealthViewModel(client: mock)
        vm.pingScope = .filtered
        await vm.pingAll(models: [sampleModel()], apiKey: secret)

        if case let .error(message) = vm.rows[0].status {
            #expect(!message.contains(secret))
        } else {
            Issue.record("Expected error status")
        }
    }

    @Test("nous research transport uses NousResearchClient")
    func nousResearchPing() async throws {
        let authURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathComponent("auth.json")
        try FileManager.default.createDirectory(
            at: authURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        let expiresAt = ISO8601DateFormatter().string(from: Date().addingTimeInterval(3600))
        let authJSON = """
        {
          "providers": {
            "nous": {
              "agent_key": "test-agent-key",
              "agent_key_expires_at": "\(expiresAt)"
            }
          }
        }
        """
        try authJSON.write(to: authURL, atomically: true, encoding: .utf8)
        let previousAuthURL = NousPortalCredentialStore.authFileURL
        NousPortalCredentialStore.authFileURL = authURL
        defer { NousPortalCredentialStore.authFileURL = previousAuthURL }

        let mock = ModelHealthMockClient()
        let nousMock = MockNousResearchClient()
        nousMock.responses["deepseek/deepseek-v4-pro"] = .success(
            NousResearchPingResult(reply: "pong", latencyMs: 88, promptTokens: 4, completionTokens: 2)
        )

        let model = try #require(StaticModelCatalogs.nousResearch.first { $0.apiModelId == "deepseek/deepseek-v4-pro" })
        let vm = ModelHealthViewModel(client: mock, nousResearchClient: nousMock)
        vm.pingScope = .filtered
        vm.selectedProvider = "nousresearch-direct"
        await vm.pingAll(models: [model], apiKey: "unused")

        #expect(vm.rows.count == 1)
        #expect(vm.rows[0].status == .live)
        #expect(vm.rows[0].p50 == 88)
        #expect(mock.pingCalls.isEmpty)
        #expect(nousMock.calls.count == 1)
        #expect(nousMock.calls[0].modelId == "deepseek/deepseek-v4-pro")
        #expect(nousMock.calls[0].apiKey == "test-agent-key")
    }

    @Test("claude CLI transport uses CLIPingClient")
    func claudeCLIPing() async {
        let mock = ModelHealthMockClient()
        let cliMock = MockCLIPingClient()
        cliMock.claudeResponses["haiku"] = .success((reply: "pong", latencyMs: 150))

        let model = StaticModelCatalogs.claudeCLIModel(modelArg: "haiku", name: "Claude CLI (Haiku)")
        let vm = ModelHealthViewModel(client: mock, cliPingClient: cliMock)
        vm.pingScope = .filtered
        vm.selectedProvider = "claudecli"
        await vm.pingAll(models: [model], apiKey: "unused")

        #expect(vm.rows.count == 1)
        #expect(vm.rows[0].status == .live)
        #expect(vm.rows[0].providerName == "claudecli")
        #expect(vm.rows[0].testedProviderLabel == "Claude CLI")
        #expect(vm.rows[0].modelAlias == "haiku")
        #expect(mock.pingCalls.isEmpty)
        #expect(cliMock.claudeCalls == ["haiku"])
    }

    @Test("stopPing cancels an in-flight batch")
    func stopPing() async throws {
        let mock = DelayedMockClient()
        let vm = ModelHealthViewModel(client: mock)
        vm.parallelism = 1
        vm.sampleCount = 1

        let models = (1 ... 4).map { index in
            sampleModel(id: "openai/model-\(index)", name: "Model \(index)")
        }

        vm.startPingAll(models: models, apiKey: "secret-key") {}
        try await Task.sleep(for: .milliseconds(50))
        vm.stopPing()
        try await Task.sleep(for: .milliseconds(300))

        #expect(!vm.isPinging)
        #expect(mock.pingCalls.count < models.count)
        let cancelled = vm.rows.filter {
            if case let .error(message) = $0.status {
                return message == "Cancelled"
            }
            return false
        }
        #expect(!cancelled.isEmpty || vm.rows.count < models.count)
    }

    @Test("open router ping records provider channel and alias")
    func pingMetadata() async {
        let mock = ModelHealthMockClient()
        let model = sampleModel(id: "openai/gpt-4o", name: "GPT-4o")
        mock.pingResponses[model.id] = .success((completion(model: model.id), 120))
        let vm = ModelHealthViewModel(client: mock)
        vm.pingScope = .filtered

        await vm.pingAll(models: [model], apiKey: "secret-key")

        #expect(vm.rows.count == 1)
        #expect(vm.rows[0].testedProviderLabel == "OpenRouter")
        #expect(vm.rows[0].modelAlias == "openai/gpt-4o")
    }
}

private final class DelayedMockClient: OpenRouterClientProtocol, @unchecked Sendable {
    private(set) var pingCalls: [String] = []

    func fetchModels(apiKey: String) async throws -> [ModelInfo] {
        _ = apiKey
        return []
    }

    func ping(
        modelId: String,
        apiKey: String,
        maxTokens: Int,
        timeoutMs: Int
    ) async throws -> (completion: OpenRouterChatCompletion, latencyMs: Double) {
        _ = apiKey
        _ = maxTokens
        _ = timeoutMs
        pingCalls.append(modelId)
        try await Task.sleep(for: .milliseconds(150))
        try Task.checkCancellation()
        return (
            OpenRouterChatCompletion(
                id: "gen-\(modelId)",
                model: modelId,
                finishReason: "stop",
                promptTokens: 1,
                completionTokens: 1,
                reasoningTokens: 0,
                cachedTokens: 0,
                cost: 0,
                upstreamCost: nil,
                routingStrategy: nil,
                attemptCount: 1
            ),
            100
        )
    }

    func fetchGeneration(id: String, apiKey: String) async throws -> OpenRouterGenerationMetadata {
        _ = id
        _ = apiKey
        throw OpenRouterClientError.invalidResponse
    }
}

private final class MockNousResearchClient: NousResearchClientProtocol, @unchecked Sendable {
    struct Call {
        let modelId: String
        let apiKey: String?
    }

    var responses: [String: Result<NousResearchPingResult, Error>] = [:]
    var calls: [Call] = []

    func ping(
        modelId: String,
        prompt: String,
        maxTokens: Int,
        timeoutMs: Int,
        apiKey: String?
    ) async throws -> NousResearchPingResult {
        _ = prompt
        _ = maxTokens
        _ = timeoutMs
        calls.append(Call(modelId: modelId, apiKey: apiKey))
        guard let result = responses[modelId] else {
            throw NousResearchClientError.invalidResponse
        }
        return try result.get()
    }
}

private final class MockCLIPingClient: CLIPingClientProtocol, @unchecked Sendable {
    var claudeResponses: [String: Result<(reply: String, latencyMs: Double), Error>] = [:]
    var claudeCalls: [String] = []

    func pingClaude(model: String, prompt: String, timeoutMs: Int) async throws -> (reply: String, latencyMs: Double) {
        _ = prompt
        _ = timeoutMs
        claudeCalls.append(model)
        guard let result = claudeResponses[model] else {
            throw CLIPingError.nonZeroExit("missing mock")
        }
        return try result.get()
    }

    func pingGemini(model: String, prompt: String, timeoutMs: Int) async throws -> (reply: String, latencyMs: Double) {
        _ = model
        _ = prompt
        _ = timeoutMs
        throw CLIPingError.nonZeroExit("not mocked")
    }

    func pingOpenCode(
        model: String,
        prompt: String,
        timeoutMs: Int
    ) async throws -> (reply: String, latencyMs: Double) {
        _ = model
        _ = prompt
        _ = timeoutMs
        throw CLIPingError.nonZeroExit("not mocked")
    }
}

@Suite("ModelHealthViewModel status mapping")
struct ModelHealthStatusTests {
    @Test("status helper maps finish reasons")
    func statusMapping() {
        let completion = OpenRouterChatCompletion(
            id: "gen-1",
            model: "openai/gpt-4o",
            finishReason: "content_filter",
            promptTokens: 1,
            completionTokens: 1,
            reasoningTokens: 0,
            cachedTokens: 0,
            cost: 0,
            upstreamCost: nil,
            routingStrategy: nil,
            attemptCount: 1
        )
        #expect(ModelHealthStatusResolver
            .resolve(requestedModelId: "openai/gpt-4o", completion: completion) == .contentFilter)
    }

    @Test("modelsMatch accepts version suffix")
    func versionSuffixMatch() {
        #expect(ModelHealthStatusResolver.modelsMatch(
            requested: "anthropic/claude-3-haiku",
            responded: "anthropic/claude-3-haiku-20240307"
        ))
        #expect(!ModelHealthStatusResolver.modelsMatch(
            requested: "google/gemini-pro-latest",
            responded: "google/gemini-1.5-pro-preview-0514"
        ))
    }
}

@Suite("ModelInfo helpers")
struct ModelInfoTests {
    @Test("percentile computes p50")
    func percentileP50() {
        #expect(percentile([100, 200, 300], 0.50) == 200)
    }

    @Test("context window formatting")
    func contextFormatting() {
        #expect(ModelInfoFormatting.contextWindow(200_000) == "200K")
        #expect(ModelInfoFormatting.contextWindow(1_000_000) == "1M")
    }
}
