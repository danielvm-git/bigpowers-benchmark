@testable import BigPowersBenchmarkKit
import Foundation
import Testing

@Suite("DaytonaConfig")
struct DaytonaConfigTests {
    @Test("baseURL validates as a well-formed URL")
    func baseURLValidation() {
        let config = DaytonaConfig(keychainService: MockKeychainService())

        config.baseURL = "https://app.daytona.io/api"
        #expect(config.baseURLError == nil)

        config.baseURL = "not a url"
        #expect(config.baseURLError != nil)
    }

    @Test("apiKey is stored in and loaded from Keychain")
    func apiKeyStorage() {
        let mockKeychain = MockKeychainService()
        let config = DaytonaConfig(keychainService: mockKeychain)

        let testKey = "daytona-api-key-123"
        config.apiKey = testKey

        #expect(mockKeychain.storedValues["bigpowers.benchmark.daytona"] == testKey)
        #expect(config.apiKey == testKey)
    }
}

final class MockKeychainService: KeychainServiceProtocol, @unchecked Sendable {
    var storedValues: [String: String] = [:]
    private let queue = DispatchQueue(label: "mock-keychain")

    func save(_ secret: String, account: String) throws {
        queue.sync { storedValues[account] = secret }
    }

    func load(account: String) -> String? {
        queue.sync { storedValues[account] }
    }

    func delete(account: String) {
        queue.sync { _ = storedValues.removeValue(forKey: account) }
    }
}
