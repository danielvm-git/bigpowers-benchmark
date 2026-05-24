@testable import BigPowersBenchmarkKit
import Foundation
import Testing

@Suite("ProviderStore")
struct ProviderStoreTests {
    @Test("apiKeyStatus is configured when key exists in keychain")
    func testApiKeyStatus() throws {
        let mockKeychain = MockKeychainService()
        let provider = Provider(id: "anthropic", name: "Anthropic", baseURL: "https://api.anthropic.com")

        // Initial state
        #expect(provider.apiKeyStatus(keychain: mockKeychain) == .notSet)

        // Save key
        try mockKeychain.save("sk-ant-123", account: "bigpowers.benchmark.anthropic")

        // Configured state
        #expect(provider.apiKeyStatus(keychain: mockKeychain) == .configured)
    }

    @Test("providers.json round-trip")
    func persistence() throws {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let fileURL = tempDir.appendingPathComponent("providers.json")
        let store = ProviderStore(fileURL: fileURL)

        let providers = [
            Provider(id: "p1", name: "Provider 1", baseURL: "https://p1.com"),
            Provider(id: "p2", name: "Provider 2", baseURL: "https://p2.com"),
        ]

        store.providers = providers
        try store.save()

        let newStore = ProviderStore(fileURL: fileURL)
        try newStore.load()

        #expect(newStore.providers.count == 2)
        #expect(newStore.providers[0].id == "p1")
        #expect(newStore.providers[1].id == "p2")
    }
}
