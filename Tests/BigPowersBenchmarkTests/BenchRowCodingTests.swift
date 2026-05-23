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
