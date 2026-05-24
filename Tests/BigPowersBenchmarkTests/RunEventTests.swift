@testable import BigPowersBenchmarkKit
import Foundation
import Testing

@Suite("RunEvent")
struct RunEventTests {
    @Test("LogLine decodes from valid JSON")
    func logLineDecoding() throws {
        let json = """
        {"t":"2026-05-23T21:46:00Z","kind":"info","text":"Starting task..."}
        """
        let data = try #require(json.data(using: .utf8))
        let line = try JSONDecoder().decode(LogLine.self, from: data)

        #expect(line.kind == .info)
        #expect(line.text == "Starting task...")
    }
}
