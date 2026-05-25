@testable import BigPowersBenchmarkKit
import Foundation
import Testing

@Suite("NousPortalCredentialStore")
struct NousPortalCredentialStoreTests {
    private func writeAuth(
        agentKey: String?,
        agentKeyExpiresAt: String?,
        accessToken: String? = nil,
        accessTokenExpiresAt: String? = nil,
        to url: URL
    ) throws {
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        let keyJSON = agentKey.map { "\"\($0)\"" } ?? "null"
        let expiresJSON = agentKeyExpiresAt.map { "\"\($0)\"" } ?? "null"
        let accessTokenJSON = accessToken.map { "\"\($0)\"" } ?? "null"
        let accessExpiresJSON = accessTokenExpiresAt.map { "\"\($0)\"" } ?? "null"
        let json = """
        {
          "providers": {
            "nous": {
              "agent_key": \(keyJSON),
              "agent_key_expires_at": \(expiresJSON),
              "access_token": \(accessTokenJSON),
              "expires_at": \(accessExpiresJSON)
            }
          }
        }
        """
        try json.write(to: url, atomically: true, encoding: .utf8)
    }

    @Test("resolveAgentKey returns key when not expired")
    func validKey() throws {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathComponent("auth.json")
        let expiresAt = ISO8601DateFormatter().string(from: Date().addingTimeInterval(3600))
        try writeAuth(agentKey: "portal-key", agentKeyExpiresAt: expiresAt, to: url)

        #expect(NousPortalCredentialStore.resolveAgentKey(from: url) == "portal-key")
    }

    @Test("resolveAgentKey falls back to access_token when agent_key expired")
    func expiredKeyFallsBackToAccessToken() throws {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathComponent("auth.json")
        let expired = ISO8601DateFormatter().string(from: Date().addingTimeInterval(-60))
        let valid = ISO8601DateFormatter().string(from: Date().addingTimeInterval(3600))
        try writeAuth(
            agentKey: "old-key",
            agentKeyExpiresAt: expired,
            accessToken: "access-bearer-token",
            accessTokenExpiresAt: valid,
            to: url
        )

        #expect(NousPortalCredentialStore.resolveAgentKey(from: url) == "access-bearer-token")
    }

    @Test("resolveAgentKey returns access_token even when expired (ping will show 401 error visibly)")
    func bothExpiredReturnsAccessToken() throws {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathComponent("auth.json")
        let expired = ISO8601DateFormatter().string(from: Date().addingTimeInterval(-60))
        try writeAuth(
            agentKey: "old-key",
            agentKeyExpiresAt: expired,
            accessToken: "stale-access-token",
            accessTokenExpiresAt: expired,
            to: url
        )

        #expect(NousPortalCredentialStore.resolveAgentKey(from: url) == "stale-access-token")
    }

    @Test("isConfigured returns true when any token is present")
    func isConfiguredWithToken() throws {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathComponent("auth.json")
        let expired = ISO8601DateFormatter().string(from: Date().addingTimeInterval(-60))
        try writeAuth(agentKey: "old-key", agentKeyExpiresAt: expired, to: url)

        #expect(NousPortalCredentialStore.isConfigured(from: url))
    }

    @Test("resolveAgentKey returns nil when file missing")
    func missingFile() {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathComponent("missing-auth.json")
        #expect(NousPortalCredentialStore.resolveAgentKey(from: url) == nil)
        #expect(!NousPortalCredentialStore.isConfigured(from: url))
    }
}
