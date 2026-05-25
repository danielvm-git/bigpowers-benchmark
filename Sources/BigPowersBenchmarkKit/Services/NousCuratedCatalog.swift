import Foundation

/// Hermes-aligned curated Nous Portal model IDs — not the full `/v1/models` catalog.
public enum NousCuratedCatalog {
    public static let defaultManifestURL = URL(
        string: "https://hermes-agent.nousresearch.com/docs/api/model-catalog.json"
    )!
    public static let maxCachedModelCount = 50

    public static func fallbackModelIds() -> [String] {
        StaticModelCatalogs.defaultNousResearchModelIds
    }

    public static func parseManifestModelIds(from data: Data) -> [String]? {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let version = json["version"] as? Int,
              version == 1,
              let providers = json["providers"] as? [String: Any],
              let nous = providers["nous"] as? [String: Any],
              let models = nous["models"] as? [[String: Any]]
        else {
            return nil
        }

        let ids = models.compactMap { entry -> String? in
            guard let id = entry["id"] as? String else { return nil }
            let trimmed = id.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.isEmpty ? nil : trimmed
        }
        return ids.isEmpty ? nil : ids
    }

    public static func parseLiveModelMetadata(from data: Data) throws -> [String: NousLiveModelMetadata] {
        let decoded = try JSONDecoder().decode(NousModelsResponse.self, from: data)
        var byId: [String: NousLiveModelMetadata] = [:]
        for item in decoded.data {
            byId[item.id] = NousLiveModelMetadata(name: item.name, contextLength: item.contextLength)
        }
        return byId
    }
}

public struct NousLiveModelMetadata: Sendable {
    public let name: String?
    public let contextLength: Int?
}

private struct NousModelsResponse: Decodable {
    let data: [NousModelDTO]
}

private struct NousModelDTO: Decodable {
    let id: String
    let name: String?
    let contextLength: Int?

    enum CodingKeys: String, CodingKey {
        case id, name
        case contextLength = "context_length"
    }
}
