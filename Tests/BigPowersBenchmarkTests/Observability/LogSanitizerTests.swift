@testable import BigPowersBenchmarkKit
import Foundation
import Testing

@Suite("LogSanitizer")
struct LogSanitizerTests {
    @Test("redacts Bearer tokens")
    func redactsBearerTokens() {
        let input = "Request failed: Authorization Bearer sk-secret-token-12345"
        let sanitized = LogSanitizer.sanitize(input)
        #expect(!sanitized.contains("sk-secret-token-12345"))
        #expect(sanitized.contains("Bearer [REDACTED]"))
    }

    @Test("redacts Authorization header values")
    func redactsAuthorizationHeader() {
        let input = "Error: Authorization: Bearer abc.def.ghi"
        let sanitized = LogSanitizer.sanitize(input)
        #expect(sanitized.contains("[REDACTED]"))
        #expect(!sanitized.contains("abc.def.ghi"))
    }
}
