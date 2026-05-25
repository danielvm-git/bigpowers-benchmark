@testable import BigPowersBenchmarkKit
import Foundation
import Testing

@Suite("BenchRow Coding")
struct BenchRowCodingTests {
    @Test("round-trips all fields through JSON")
    func roundTrip() throws {
        let uuid = try #require(UUID(uuidString: "550e8400-e29b-41d4-a716-446655440000"))
        let original = BenchRow(
            id: uuid,
            schemaVersion: 1,
            timestamp: Date(timeIntervalSince1970: 1_716_480_000),
            bigpowersRef: "v1.2.0",
            modelId: "openrouter/anthropic/claude-sonnet-4-6",
            taskId: "T01_bug_investigation",
            codePass: 1,
            artifactScore: 2,
            conventionScore: 2,
            duration: 47.3,
            cost: 0.0024,
            workspace: "/home/user/workspace/T01"
        )

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(original)

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode(BenchRow.self, from: data)

        #expect(decoded.id == original.id)
        #expect(decoded.schemaVersion == original.schemaVersion)
        #expect(decoded.timestamp == original.timestamp)
        #expect(decoded.bigpowersRef == original.bigpowersRef)
        #expect(decoded.modelId == original.modelId)
        #expect(decoded.taskId == original.taskId)
        #expect(decoded.codePass == original.codePass)
        #expect(decoded.artifactScore == original.artifactScore)
        #expect(decoded.conventionScore == original.conventionScore)
        #expect(decoded.overallScore == original.overallScore)
        #expect(decoded.duration == original.duration)
        #expect(decoded.cost == original.cost)
        #expect(decoded.workspace == original.workspace)
    }

    @Test("overall score formula: (codePass * 2 + artifactScore + conventionScore) / 4")
    func overallScoreFormula() {
        let row = BenchRow(
            id: UUID(),
            schemaVersion: 1,
            timestamp: Date(),
            bigpowersRef: "v1.0.0",
            modelId: "test/model",
            taskId: "T01",
            codePass: 1,
            artifactScore: 2,
            conventionScore: 2,
            duration: 10,
            cost: 0.001,
            workspace: "/tmp/test"
        )
        let expected = Double(row.codePass * 2 + row.artifactScore + row.conventionScore) / 4.0
        #expect(row.overallScore == expected)
    }

    @Test("token fields round-trip through JSON")
    func tokenFieldsRoundTrip() throws {
        let row = BenchRow(
            id: UUID(),
            schemaVersion: 2,
            timestamp: Date(timeIntervalSince1970: 1_716_480_000),
            bigpowersRef: "v2.0.0",
            modelId: "test/model",
            taskId: "T01",
            codePass: 1,
            artifactScore: 1,
            conventionScore: 1,
            duration: 10,
            cost: 0.042,
            inputTokens: 3200,
            outputTokens: 1800,
            cacheReadTokens: 800,
            cacheWriteTokens: 120,
            workspace: "/tmp"
        )
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(row)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode(BenchRow.self, from: data)

        #expect(decoded.inputTokens == 3200)
        #expect(decoded.outputTokens == 1800)
        #expect(decoded.cacheReadTokens == 800)
        #expect(decoded.cacheWriteTokens == 120)
    }

    @Test("legacy JSON without token fields decodes with zeros")
    func legacyJsonDecodesWithZeroTokens() throws {
        let legacy = """
        {"id":"550e8400-e29b-41d4-a716-446655440000","schema_version":1,
         "timestamp":"2025-01-01T00:00:00Z","bigpowers_ref":"ref",
         "model_id":"m","task_id":"T01","code_pass":1,"artifact_score":1,
         "convention_score":1,"overall_score":1.0,"duration":1.0,"cost":0.05,
         "workspace":"/tmp"}
        """
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let row = try decoder.decode(BenchRow.self, from: Data(legacy.utf8))
        #expect(row.inputTokens == 0)
        #expect(row.outputTokens == 0)
        #expect(row.cacheReadTokens == 0)
        #expect(row.cacheWriteTokens == 0)
    }

    @Test("cacheHitRate is cacheRead / (input + cacheRead)")
    func cacheHitRate() {
        let row = BenchRow(
            id: UUID(), schemaVersion: 2, timestamp: Date(),
            bigpowersRef: "ref", modelId: "m", taskId: "T01",
            codePass: 1, artifactScore: 1, conventionScore: 1,
            duration: 1, cost: 0.01,
            inputTokens: 3200, outputTokens: 0, cacheReadTokens: 800, cacheWriteTokens: 0,
            workspace: "/tmp"
        )
        #expect(abs(row.cacheHitRate - 0.2) < 0.001) // 800 / (3200 + 800)
    }

    @Test("cacheHitRate is zero when no tokens")
    func cacheHitRateZeroWhenNoTokens() {
        let row = BenchRow(
            id: UUID(), schemaVersion: 1, timestamp: Date(),
            bigpowersRef: "ref", modelId: "m", taskId: "T01",
            codePass: 0, artifactScore: 0, conventionScore: 0,
            duration: 0, cost: 0,
            inputTokens: 0, outputTokens: 0, cacheReadTokens: 0, cacheWriteTokens: 0,
            workspace: "/tmp"
        )
        #expect(row.cacheHitRate == 0)
    }

    @Test("token fields appear in JSON output with snake_case keys")
    func tokenFieldsSnakeCaseKeys() throws {
        let row = BenchRow(
            id: UUID(), schemaVersion: 2, timestamp: Date(timeIntervalSince1970: 0),
            bigpowersRef: "ref", modelId: "m", taskId: "T01",
            codePass: 1, artifactScore: 1, conventionScore: 1,
            duration: 1, cost: 0.01,
            inputTokens: 100, outputTokens: 50, cacheReadTokens: 10, cacheWriteTokens: 5,
            workspace: "/tmp"
        )
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(row)
        let json = try #require(try JSONSerialization.jsonObject(with: data) as? [String: Any])

        #expect(json["input_tokens"] as? Int == 100)
        #expect(json["output_tokens"] as? Int == 50)
        #expect(json["cache_read_tokens"] as? Int == 10)
        #expect(json["cache_write_tokens"] as? Int == 5)
    }

    @Test("snake_case JSON keys round-trip")
    func snakeCaseKeys() throws {
        let row = BenchRow(
            id: UUID(),
            schemaVersion: 1,
            timestamp: Date(timeIntervalSince1970: 1_716_480_000),
            bigpowersRef: "v1.0.0",
            modelId: "test/model",
            taskId: "T01",
            codePass: 1,
            artifactScore: 1,
            conventionScore: 1,
            duration: 5,
            cost: 0.001,
            workspace: "/tmp"
        )
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(row)
        let json = try #require(try JSONSerialization.jsonObject(with: data) as? [String: Any])

        #expect(json["schema_version"] != nil)
        #expect(json["bigpowers_ref"] != nil)
        #expect(json["model_id"] != nil)
        #expect(json["task_id"] != nil)
        #expect(json["code_pass"] != nil)
        #expect(json["artifact_score"] != nil)
        #expect(json["convention_score"] != nil)
        #expect(json["overall_score"] != nil)
    }
}
