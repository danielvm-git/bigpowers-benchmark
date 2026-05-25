@testable import BigPowersBenchmarkKit
import Foundation
import Testing

@Suite("ModelHealthSubscriptionProvider")
struct ModelHealthSubscriptionProviderTests {
    private func store(providers: [Provider]) -> ProviderStore {
        let store = ProviderStore(fileURL: FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathComponent("providers.json"))
        store.providers = providers
        return store
    }

    @Test("available includes OpenRouter when key is configured")
    func openRouterWhenConfigured() {
        let keychain = MockKeychainService()
        try? keychain.save("sk-test", account: "bigpowers.benchmark.openrouter")
        let providerStore = store(providers: [
            Provider(id: "openrouter", name: "OpenRouter", baseURL: "https://openrouter.ai/api/v1"),
        ])

        let available = ModelHealthSubscriptionProvider.available(
            providerStore: providerStore,
            dotEnvPaths: [],
            keychain: keychain
        )

        #expect(available.contains(.openrouter))
    }

    @Test("available excludes OpenRouter without API key")
    func openRouterWithoutKey() {
        let providerStore = store(providers: [
            Provider(id: "openrouter", name: "OpenRouter", baseURL: "https://openrouter.ai/api/v1"),
        ])

        let available = ModelHealthSubscriptionProvider.available(
            providerStore: providerStore,
            dotEnvPaths: [],
            keychain: MockKeychainService()
        )

        #expect(!available.contains(.openrouter))
    }

    @Test("CLI subscriptions are always available")
    func cliAlwaysAvailable() {
        let providerStore = store(providers: [])

        let available = ModelHealthSubscriptionProvider.available(
            providerStore: providerStore,
            dotEnvPaths: [],
            keychain: MockKeychainService()
        )

        #expect(available.contains(.claudecli))
        #expect(available.contains(.geminicli))
        #expect(available.contains(.opencode))
    }

    @Test("Nous Portal available when hermes auth file has any token — even expired")
    func nousWhenAgentKeyPresent() throws {
        let authURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathComponent("auth.json")
        try FileManager.default.createDirectory(
            at: authURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        // Expired token — still shows in dropdown; ping will surface the error
        let expired = ISO8601DateFormatter().string(from: Date().addingTimeInterval(-60))
        let authJSON = """
        {
          "providers": {
            "nous": {
              "agent_key": "test-key",
              "agent_key_expires_at": "\(expired)"
            }
          }
        }
        """
        try authJSON.write(to: authURL, atomically: true, encoding: .utf8)
        let previousAuthURL = NousPortalCredentialStore.authFileURL
        NousPortalCredentialStore.authFileURL = authURL
        defer { NousPortalCredentialStore.authFileURL = previousAuthURL }

        let available = ModelHealthSubscriptionProvider.available(
            providerStore: store(providers: []),
            dotEnvPaths: [],
            keychain: MockKeychainService()
        )

        #expect(available.contains(.nousresearchDirect))
    }

    @Test("Nous Portal unavailable without hermes agent key")
    func nousWithoutAgentKey() {
        let authURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathComponent("auth.json")
        let previousAuthURL = NousPortalCredentialStore.authFileURL
        NousPortalCredentialStore.authFileURL = authURL
        defer { NousPortalCredentialStore.authFileURL = previousAuthURL }

        let available = ModelHealthSubscriptionProvider.available(
            providerStore: store(providers: []),
            dotEnvPaths: [],
            keychain: MockKeychainService()
        )

        #expect(!available.contains(.nousresearchDirect))
    }

    @Test("displayName maps nousresearch-direct to Nous Portal")
    func nousPortalDisplayName() {
        #expect(ModelHealthSubscriptionProvider.displayName(for: "nousresearch-direct") == "Nous Portal")
        #expect(ModelHealthSubscriptionProvider.nousresearchDirect.displayName == "Nous Portal")
    }

    @Test("matches models by ping transport not upstream slug")
    func matchesByTransport() {
        let openRouterModel = ModelInfo(
            id: "poolside/laguna-xs.2:free",
            name: "Poolside",
            provider: "poolside",
            contextWindow: 131_000,
            tier: .deep,
            capabilities: [.tools],
            pricing: ModelPricing(inputPer1k: 0, outputPer1k: 0),
            pingTransport: .openRouter
        )
        let cliModel = StaticModelCatalogs.geminiCLI[0]

        #expect(ModelHealthSubscriptionProvider.openrouter.matches(openRouterModel))
        #expect(!ModelHealthSubscriptionProvider.geminicli.matches(openRouterModel))
        #expect(ModelHealthSubscriptionProvider.geminicli.matches(cliModel))
    }
}

@Suite("ModelHealthPingStatus")
struct ModelHealthPingStatusTests {
    @Test("statusDetail surfaces error timeout and content filter")
    func statusDetailMessages() {
        #expect(ModelHealthPingStatus.error("HTTP 429: Rate limit").statusDetail == "HTTP 429: Rate limit")
        #expect(ModelHealthPingStatus.timeout.statusDetail == "Timeout")
        #expect(ModelHealthPingStatus.contentFilter.statusDetail == "Content filtered")
        #expect(ModelHealthPingStatus.live.statusDetail == nil)
        #expect(ModelHealthPingStatus.stale.statusDetail == nil)
        #expect(ModelHealthPingStatus.mismatch(actual: "other-model").statusDetail == nil)
    }
}

@Suite("ModelHealthFreeTier")
struct ModelHealthFreeTierTests {
    @Test("live ping with zero cost counts as free")
    func runtimeFree() {
        let paidCatalog = ModelInfo(
            id: "nousresearch-direct:google/gemini-3-flash-preview",
            name: "Gemini 3 Flash Preview",
            provider: "nousresearch-direct",
            contextWindow: 128_000,
            tier: .deep,
            capabilities: [.tools],
            pricing: ModelPricing(inputPer1k: 1, outputPer1k: 1),
            pingTransport: .nousResearch,
            resolvedModelId: "google/gemini-3-flash-preview"
        )
        let liveZeroCost = ModelHealthPingResult(
            id: paidCatalog.id,
            label: paidCatalog.name,
            status: .live,
            latencySamples: [500],
            cost: 0
        )
        #expect(ModelHealthFreeTier.isFree(catalog: paidCatalog, pingResult: liveZeroCost))

        let failed = ModelHealthPingResult(
            id: paidCatalog.id,
            label: paidCatalog.name,
            status: .error("HTTP 404"),
            cost: 0
        )
        #expect(!ModelHealthFreeTier.isFree(catalog: paidCatalog, pingResult: failed))
    }
}

@MainActor
@Suite("ModelHealthViewModel subscription filter")
struct ModelHealthSubscriptionFilterTests {
    @Test("provider scope filters by subscription transport")
    func providerScopeByTransport() {
        let vm = ModelHealthViewModel()
        let models = [
            ModelInfo(
                id: "poolside/laguna-xs.2:free",
                name: "Poolside",
                provider: "poolside",
                contextWindow: 131_000,
                tier: .deep,
                capabilities: [.tools],
                pricing: ModelPricing(inputPer1k: 0, outputPer1k: 0),
                pingTransport: .openRouter
            ),
            StaticModelCatalogs.geminiCLI[0],
        ]
        vm.selectProvider(ModelHealthSubscriptionProvider.geminicli.rawValue)

        let targets = vm.pingTargets(from: models)
        #expect(targets.count == 1)
        #expect(targets[0].pingTransport == PingTransport.geminiCLI)
    }
}
