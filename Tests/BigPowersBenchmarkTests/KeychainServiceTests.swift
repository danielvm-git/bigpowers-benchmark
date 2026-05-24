@testable import BigPowersBenchmarkKit
import Foundation
import Testing

@Suite("KeychainService")
struct KeychainServiceTests {
    let service = KeychainService()
    let testAccount = "bigpowers.test.\(UUID().uuidString)"

    @Test("save and load round-trip")
    func saveLoadRoundTrip() throws {
        let secret = "test-secret-value"

        // Ensure clean state
        service.delete(account: testAccount)

        // Save
        try service.save(secret, account: testAccount)

        // Load
        let loaded = service.load(account: testAccount)
        #expect(loaded == secret)

        // Cleanup
        service.delete(account: testAccount)
    }

    @Test("delete removes the item")
    func testDelete() throws {
        let secret = "to-be-deleted"
        try service.save(secret, account: testAccount)

        service.delete(account: testAccount)

        let loaded = service.load(account: testAccount)
        #expect(loaded == nil)
    }
}
