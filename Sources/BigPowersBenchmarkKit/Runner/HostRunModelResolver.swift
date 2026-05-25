import Foundation

public enum HostRunModelResolver {
    private static let hostCompatibleTransports: Set<PingTransport> = [.openCode, .openRouter]

    /// Resolves a catalog model ID to the `provider/model` slug opencode expects.
    public static func opencodeModelSlug(
        catalogModelId: String,
        profile: ModelIntelProfile? = nil,
        catalog: [ModelInfo] = StaticModelCatalogs.all
    ) throws -> String {
        if let profile {
            if let transportRaw = profile.pingTransport,
               let transport = PingTransport(rawValue: transportRaw) {
                try validateHostTransport(transport)
                if let alias = profile.modelAlias, !alias.isEmpty {
                    return alias
                }
            }
        }

        if let info = catalog.first(where: { $0.id == catalogModelId || $0.apiModelId == catalogModelId }) {
            try validateHostTransport(info.pingTransport)
            return info.apiModelId
        }

        if catalogModelId.contains("/"), !catalogModelId.contains(":") {
            return catalogModelId
        }

        throw RunnerError.unknownCatalogModel(catalogModelId)
    }

    public static func isHostCompatible(profile: ModelIntelProfile) -> Bool {
        guard let transportRaw = profile.pingTransport,
              let transport = PingTransport(rawValue: transportRaw)
        else {
            return false
        }
        return hostCompatibleTransports.contains(transport)
    }

    private static func validateHostTransport(_ transport: PingTransport) throws {
        guard hostCompatibleTransports.contains(transport) else {
            throw RunnerError.unsupportedHostTransport(transport.channelDisplayName)
        }
    }
}
