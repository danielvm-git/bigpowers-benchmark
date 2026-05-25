import Foundation

public struct StaticCatalogCache: Codable, Sendable, Equatable {
    public let fetchedAt: Date
    public let nousResearch: [ModelInfo]
    public let openCode: [ModelInfo]
    public let claudeCLI: [ModelInfo]
    public let geminiCLI: [ModelInfo]

    public init(
        fetchedAt: Date,
        nousResearch: [ModelInfo],
        openCode: [ModelInfo],
        claudeCLI: [ModelInfo] = [],
        geminiCLI: [ModelInfo] = []
    ) {
        self.fetchedAt = fetchedAt
        self.nousResearch = nousResearch
        self.openCode = openCode
        self.claudeCLI = claudeCLI
        self.geminiCLI = geminiCLI
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        fetchedAt = try container.decode(Date.self, forKey: .fetchedAt)
        nousResearch = try container.decode([ModelInfo].self, forKey: .nousResearch)
        openCode = try container.decode([ModelInfo].self, forKey: .openCode)
        claudeCLI = try container.decodeIfPresent([ModelInfo].self, forKey: .claudeCLI) ?? []
        geminiCLI = try container.decodeIfPresent([ModelInfo].self, forKey: .geminiCLI) ?? []
    }

    public static let defaultCacheURL: URL = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent("Library/Caches/BigPowersBenchmark/static-catalog.json")

    public static func load(from url: URL = defaultCacheURL) -> StaticCatalogCache? {
        guard FileManager.default.fileExists(atPath: url.path),
              let data = try? Data(contentsOf: url)
        else { return nil }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try? decoder.decode(StaticCatalogCache.self, from: data)
    }

    public func save(to url: URL = defaultCacheURL) throws {
        let directory = url.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(self)
        try data.write(to: url, options: .atomic)
    }
}
