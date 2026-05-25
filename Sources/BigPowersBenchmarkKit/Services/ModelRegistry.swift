import Foundation
import Observation

public struct ModelRegistryCache: Codable, Sendable {
    public let fetchedAt: Date
    public let models: [ModelInfo]

    public init(fetchedAt: Date, models: [ModelInfo]) {
        self.fetchedAt = fetchedAt
        self.models = models
    }
}

public enum ModelRegistryError: Error, Sendable, Equatable {
    case missingAPIKey
    case fetchFailed(String)
}

@Observable
public final class ModelRegistry: @unchecked Sendable {
    public static let defaultCacheURL: URL = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent("Library/Caches/BigPowersBenchmark/models-cache.json")

    public static let cacheTTL: TimeInterval = 3600

    private let cacheURL: URL
    private let client: OpenRouterClientProtocol
    private let now: @Sendable () -> Date
    private let logger = AppLogger.modelHealth

    public private(set) var models: [ModelInfo] = []

    public init(
        cacheURL: URL = ModelRegistry.defaultCacheURL,
        client: OpenRouterClientProtocol = OpenRouterClient(),
        now: @escaping @Sendable () -> Date = { Date() }
    ) {
        self.cacheURL = cacheURL
        self.client = client
        self.now = now
        StaticModelCatalogs.loadFromDisk()
    }

    @discardableResult
    public func loadModels(apiKey: String, forceRefresh: Bool = false) async throws -> [ModelInfo] {
        if !forceRefresh, let cached = try readCacheIfFresh() {
            models = Self.mergeStaticModels(cached)
            return models
        }

        logger.debug("Registry fetch started", metadata: [
            "action": .string("registryFetch"),
            "source": .string("openrouter"),
        ])

        guard !apiKey.isEmpty else {
            throw ModelRegistryError.missingAPIKey
        }

        do {
            let fetched = try await client.fetchModels(apiKey: apiKey)
            try writeCache(models: fetched)
            models = Self.mergeStaticModels(fetched)
            return models
        } catch let error as OpenRouterClientError {
            let message = Self.sanitize(error, apiKey: apiKey)
            logger.error("Registry fetch failed", metadata: [
                "action": .string("registryFetchFailed"),
                "error": .string(message),
            ])
            throw ModelRegistryError.fetchFailed(message)
        } catch {
            let message = LogSanitizer.sanitize(error.localizedDescription)
            logger.error("Registry fetch failed", metadata: [
                "action": .string("registryFetchFailed"),
                "error": .string(message),
            ])
            throw ModelRegistryError.fetchFailed(message)
        }
    }

    func readCacheIfFresh() throws -> [ModelInfo]? {
        guard FileManager.default.fileExists(atPath: cacheURL.path) else { return nil }

        let data = try Data(contentsOf: cacheURL)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let cache = try decoder.decode(ModelRegistryCache.self, from: data)
        let age = now().timeIntervalSince(cache.fetchedAt)
        guard age < Self.cacheTTL else { return nil }

        logger.debug("Registry cache hit", metadata: [
            "action": .string("registryCacheHit"),
            "ageSeconds": .stringConvertible(Int(age)),
        ])
        return cache.models
    }

    private func writeCache(models: [ModelInfo]) throws {
        let directory = cacheURL.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

        let cache = ModelRegistryCache(fetchedAt: now(), models: models)
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(cache)
        try data.write(to: cacheURL, options: .atomic)
    }

    static func sanitize(_ error: OpenRouterClientError, apiKey: String) -> String {
        switch error {
        case .missingAPIKey:
            "Missing API key"
        case .invalidResponse:
            "Invalid response"
        case .timedOut:
            "Request timed out"
        case let .httpError(statusCode: statusCode, message: message):
            OpenRouterClient.sanitize("HTTP \(statusCode): \(message)", apiKey: apiKey)
        }
    }

    static func mergeStaticModels(_ openRouterModels: [ModelInfo]) -> [ModelInfo] {
        let openRouterOnly = openRouterModels.filter { $0.pingTransport == .openRouter }
        let existingIDs = Set(openRouterOnly.map(\.id))
        let staticModels = StaticModelCatalogs.all.filter { !existingIDs.contains($0.id) }
        return openRouterOnly + staticModels
    }

    /// Re-merge OpenRouter models with updated static subscription catalogs.
    public func remergeStaticCatalog() {
        let openRouterOnly = models.filter { $0.pingTransport == .openRouter }
        if openRouterOnly.isEmpty, let cached = try? readCacheIfFresh() {
            models = Self.mergeStaticModels(cached)
        } else {
            models = Self.mergeStaticModels(openRouterOnly)
        }
    }
}
