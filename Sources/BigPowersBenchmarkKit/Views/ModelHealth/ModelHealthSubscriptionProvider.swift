import Foundation

/// Subscription channels for Model Health — matches the multi-provider sessions in `test_all_models.mjs`.
public enum ModelHealthSubscriptionProvider: String, CaseIterable, Sendable {
    case openrouter
    case nousresearchDirect = "nousresearch-direct"
    case opencode
    case claudecli
    case geminicli

    public var displayName: String {
        switch self {
        case .openrouter: "OpenRouter"
        case .nousresearchDirect: "Nous Portal"
        case .opencode: "OpenCode Zen"
        case .claudecli: "Claude CLI"
        case .geminicli: "Gemini CLI"
        }
    }

    public var pingTransport: PingTransport {
        switch self {
        case .openrouter: .openRouter
        case .nousresearchDirect: .nousResearch
        case .opencode: .openCode
        case .claudecli: .claudeCLI
        case .geminicli: .geminiCLI
        }
    }

    public func matches(_ model: ModelInfo) -> Bool {
        model.pingTransport == pingTransport
    }

    public static func displayName(for providerId: String) -> String {
        ModelHealthSubscriptionProvider(rawValue: providerId)?.displayName ?? providerId
    }

    public static func available(
        providerStore: ProviderStore,
        dotEnvPaths: [URL],
        keychain: KeychainServiceProtocol = KeychainService()
    ) -> [ModelHealthSubscriptionProvider] {
        allCases.filter {
            $0.isAvailable(
                providerStore: providerStore,
                dotEnvPaths: dotEnvPaths,
                keychain: keychain
            )
        }
    }

    private func isAvailable(
        providerStore: ProviderStore,
        dotEnvPaths: [URL],
        keychain: KeychainServiceProtocol
    ) -> Bool {
        switch self {
        case .openrouter:
            isProviderEnabled("openrouter", providerStore: providerStore)
                && ProviderCredentialResolver.isConfigured(
                    providerId: "openrouter",
                    keychain: keychain,
                    dotEnvPaths: dotEnvPaths
                )
        case .nousresearchDirect:
            NousPortalCredentialStore.isConfigured()
        case .opencode, .claudecli, .geminicli:
            true
        }
    }

    private func isProviderEnabled(_ id: String, providerStore: ProviderStore) -> Bool {
        providerStore.providers.first(where: { $0.id == id })?.enabled ?? true
    }
}
