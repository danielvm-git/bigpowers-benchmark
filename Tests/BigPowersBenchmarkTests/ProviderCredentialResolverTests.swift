@testable import BigPowersBenchmarkKit
import Foundation
import Testing

@Suite("ProviderCredentialResolver", .serialized)
struct ProviderCredentialResolverTests {
    @Test("keychain takes precedence over dotenv")
    func keychainPrecedence() throws {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let envFile = tempDir.appendingPathComponent(".env")
        try "OPENROUTER_API_KEY=from-dotenv\n".write(to: envFile, atomically: true, encoding: .utf8)

        let keychain = MockKeychainService()
        try keychain.save("from-keychain", account: "bigpowers.benchmark.openrouter")

        let resolved = ProviderCredentialResolver.resolve(
            providerId: "openrouter",
            keychain: keychain,
            dotEnvPaths: [envFile],
            environment: [:]
        )

        #expect(resolved?.value == "from-keychain")
        #expect(resolved?.source == .keychain)
    }

    @Test("dotenv is used when keychain is empty")
    func dotEnvFallback() throws {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let envFile = tempDir.appendingPathComponent(".env")
        try "OPENROUTER_API_KEY=sk-or-test\n".write(to: envFile, atomically: true, encoding: .utf8)

        let keychain = MockKeychainService()
        let resolved = ProviderCredentialResolver.resolve(
            providerId: "openrouter",
            keychain: keychain,
            dotEnvPaths: [envFile],
            environment: [:]
        )

        #expect(resolved?.value == "sk-or-test")
        #expect(resolved?.source == .dotEnv)
    }

    @Test("returns nil when no credential sources exist")
    func missingCredential() {
        let keychain = MockKeychainService()
        let resolved = ProviderCredentialResolver.resolve(
            providerId: "openrouter",
            keychain: keychain,
            dotEnvPaths: [],
            environment: [:]
        )
        #expect(resolved == nil)
    }

    @Test("parseDotEnv strips quotes and ignores comments")
    func parseDotEnv() throws {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let envFile = tempDir.appendingPathComponent(".env")
        try """
        # comment
        OPENROUTER_API_KEY=\"quoted-key\"
        OTHER=value
        """.write(to: envFile, atomically: true, encoding: .utf8)

        #expect(ProviderCredentialResolver.parseDotEnv(at: envFile, key: "OPENROUTER_API_KEY") == "quoted-key")
        #expect(ProviderCredentialResolver.parseDotEnv(at: envFile, key: "MISSING") == nil)
    }
}
