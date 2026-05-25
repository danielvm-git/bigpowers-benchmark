@testable import BigPowersBenchmarkKit
import Foundation
import Testing

private final class MockOpenRouterClient: OpenRouterClientProtocol, @unchecked Sendable {
    var fetchModelsHandler: @Sendable () async throws -> [ModelInfo] = { [] }
    var fetchModelsCallCount = 0

    func fetchModels(apiKey _: String) async throws -> [ModelInfo] {
        fetchModelsCallCount += 1
        return try await fetchModelsHandler()
    }

    func ping(
        modelId: String,
        apiKey: String,
        maxTokens: Int,
        timeoutMs: Int
    ) async throws -> (completion: OpenRouterChatCompletion, latencyMs: Double) {
        _ = modelId
        _ = apiKey
        _ = maxTokens
        _ = timeoutMs
        throw OpenRouterClientError.invalidResponse
    }

    func fetchGeneration(id: String, apiKey: String) async throws -> OpenRouterGenerationMetadata {
        _ = id
        _ = apiKey
        throw OpenRouterClientError.invalidResponse
    }
}

@Suite("ModelRegistry")
struct ModelRegistryTests {
    @Test("cache used within TTL")
    func cacheUsedWithinTTL() async throws {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let cacheURL = tempDir.appendingPathComponent("models-cache.json")
        let model = ModelInfo(
            id: "openai/gpt-4o",
            name: "GPT-4o",
            provider: "openai",
            contextWindow: 128_000,
            tier: .deep,
            capabilities: [.tools, .streaming],
            pricing: ModelPricing(inputPer1k: 5, outputPer1k: 15)
        )
        let cache = ModelRegistryCache(fetchedAt: Date(), models: [model])
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        try encoder.encode(cache).write(to: cacheURL)

        var mockClient = MockOpenRouterClient()
        mockClient.fetchModelsHandler = {
            Issue.record("Network fetch should not be called when cache is fresh")
            return []
        }

        let registry = ModelRegistry(cacheURL: cacheURL, client: mockClient, now: { Date() })
        let models = try await registry.loadModels(apiKey: "test-key")

        #expect(models.contains { $0.id == "openai/gpt-4o" })
        #expect(models.count >= StaticModelCatalogs.all.count + 1)
        #expect(mockClient.fetchModelsCallCount == 0)
    }

    @Test("cache expires after one hour")
    func cacheExpires() async throws {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let cacheURL = tempDir.appendingPathComponent("models-cache.json")
        let staleDate = Date().addingTimeInterval(-ModelRegistry.cacheTTL - 60)
        let staleModel = ModelInfo(
            id: "stale/model",
            name: "Stale",
            provider: "stale",
            contextWindow: 8000,
            tier: .light,
            capabilities: [],
            pricing: ModelPricing(inputPer1k: 0, outputPer1k: 0)
        )
        let cache = ModelRegistryCache(fetchedAt: staleDate, models: [staleModel])
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        try encoder.encode(cache).write(to: cacheURL)

        let freshModel = ModelInfo(
            id: "fresh/model",
            name: "Fresh",
            provider: "fresh",
            contextWindow: 128_000,
            tier: .deep,
            capabilities: [.tools],
            pricing: ModelPricing(inputPer1k: 1, outputPer1k: 2)
        )

        var mockClient = MockOpenRouterClient()
        mockClient.fetchModelsHandler = { [freshModel] in
            [freshModel]
        }

        let registry = ModelRegistry(cacheURL: cacheURL, client: mockClient, now: { Date() })
        let models = try await registry.loadModels(apiKey: "test-key")

        #expect(models.contains { $0.id == "fresh/model" })
        #expect(models.count >= StaticModelCatalogs.all.count + 1)
        #expect(mockClient.fetchModelsCallCount == 1)
    }
}
