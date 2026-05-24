@testable import BigPowersBenchmarkKit
import Foundation
import Testing

private final class MockHTTPURLProtocol: URLProtocol, @unchecked Sendable {
    nonisolated(unsafe) static var statusCode: Int = 200

    override static func canInit(with _: URLRequest) -> Bool {
        true
    }

    override static func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        guard let url = request.url else {
            client?.urlProtocol(self, didFailWithError: URLError(.badURL))
            return
        }
        let response = HTTPURLResponse(
            url: url,
            statusCode: Self.statusCode,
            httpVersion: nil,
            headerFields: nil
        )
        guard let response else {
            client?.urlProtocol(self, didFailWithError: URLError(.badServerResponse))
            return
        }
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: Data("[]".utf8))
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}

@Suite("DaytonaClient ping")
struct DaytonaClientPingTests {
    @Test("pingDetailed reports missing API key")
    func missingApiKey() async {
        let config = DaytonaConfig(keychainService: MockKeychainService())
        config.baseURL = "https://app.daytona.io/api"
        config.apiKey = ""

        let client = DaytonaClient(config: config)
        let result = await client.pingDetailed()

        if case let .failure(message: message) = result {
            #expect(message == "Missing API key")
        } else {
            Issue.record("Expected pingDetailed to fail with missing API key")
        }
    }

    @Test("pingDetailed reports HTTP status without token leakage")
    func http401() async {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [MockHTTPURLProtocol.self]
        let session = URLSession(configuration: config)
        MockHTTPURLProtocol.statusCode = 401

        let daytonaConfig = DaytonaConfig(keychainService: MockKeychainService())
        daytonaConfig.baseURL = "https://app.daytona.io/api"
        daytonaConfig.apiKey = "secret-test-key"

        let client = DaytonaClient(config: daytonaConfig, session: session)
        let result = await client.pingDetailed()

        if case let .failure(message: message) = result {
            #expect(message == "HTTP 401")
            #expect(!message.contains("secret-test-key"))
        } else {
            Issue.record("Expected pingDetailed to fail with HTTP 401")
        }
    }

    @Test("DaytonaError userMessage maps cases")
    func userMessages() {
        #expect(DaytonaError.missingApiKey.userMessage == "Missing API key")
        #expect(DaytonaError.httpError(statusCode: 503).userMessage == "HTTP 503")
        #expect(DaytonaError.invalidBaseURL.userMessage == "Invalid URL format")
    }
}
