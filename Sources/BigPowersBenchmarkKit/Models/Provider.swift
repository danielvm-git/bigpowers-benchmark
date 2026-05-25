import Foundation

public struct Provider: Codable, Identifiable {
    public static let openRouterKeychainAccount = "bigpowers.benchmark.openrouter"

    public let id: String
    public let name: String
    public let baseURL: String
    public var enabled: Bool

    public init(id: String, name: String, baseURL: String, enabled: Bool = true) {
        self.id = id
        self.name = name
        self.baseURL = baseURL
        self.enabled = enabled
    }

    public var keychainAccount: String {
        "bigpowers.benchmark.\(id)"
    }

    public func apiKeyStatus(
        keychain: KeychainServiceProtocol,
        dotEnvPaths: [URL] = ProviderCredentialResolver.defaultDotEnvPaths()
    ) -> ApiKeyStatus {
        if ProviderCredentialResolver.isConfigured(
            providerId: id,
            keychain: keychain,
            dotEnvPaths: dotEnvPaths
        ) {
            .configured
        } else {
            .notSet
        }
    }

    public func resolvedCredential(
        keychain: KeychainServiceProtocol = KeychainService(),
        dotEnvPaths: [URL] = ProviderCredentialResolver.defaultDotEnvPaths()
    ) -> ResolvedProviderCredential? {
        ProviderCredentialResolver.resolve(providerId: id, keychain: keychain, dotEnvPaths: dotEnvPaths)
    }
}

public enum ApiKeyStatus: String, Codable {
    case notSet
    case configured
    case error
}
