@testable import BigPowersBenchmarkKit
import Foundation
import Testing

@Suite("ClaudeCodeCredentialStore")
struct ClaudeCodeCredentialStoreTests {
    @Test("resolveToken prefers ANTHROPIC_API_KEY")
    func envPreferred() {
        let token = ClaudeCodeCredentialStore.resolveToken(
            environment: ["ANTHROPIC_API_KEY": "sk-ant-api-test"]
        )
        #expect(token == "sk-ant-api-test")
    }

    @Test("readClaudeCodeOAuthToken reads accessToken from credentials file")
    func credentialsFile() throws {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let fileURL = dir.appendingPathComponent(".credentials.json")
        let json = """
        {
          "claudeAiOauth": {
            "accessToken": "cc-test-token"
          }
        }
        """
        try json.write(to: fileURL, atomically: true, encoding: .utf8)

        let token = ClaudeCodeCredentialStore.readClaudeCodeOAuthToken(from: fileURL)
        #expect(token == "cc-test-token")
    }

    @Test("isOAuthToken distinguishes API keys from OAuth tokens")
    func oauthDetection() {
        #expect(!ClaudeCodeCredentialStore.isOAuthToken("sk-ant-api03-test"))
        #expect(ClaudeCodeCredentialStore.isOAuthToken("sk-ant-oat-test"))
        #expect(ClaudeCodeCredentialStore.isOAuthToken("cc-test"))
        #expect(ClaudeCodeCredentialStore.isOAuthToken("eyJhbGciOi"))
    }
}
