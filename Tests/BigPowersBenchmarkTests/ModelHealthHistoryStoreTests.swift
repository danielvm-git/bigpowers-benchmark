@testable import BigPowersBenchmarkKit
import Foundation
import Testing

@Suite("ModelHealthHistoryStore")
struct ModelHealthHistoryStoreTests {
    @Test("save and loadAll round-trip snapshot")
    func saveLoadRoundTrip() throws {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        let store = ModelHealthHistoryStore(snapshotsURL: tempDir)

        let snapshot = ModelHealthSnapshot(
            timestamp: Date(timeIntervalSince1970: 1_700_000_000),
            scope: "free",
            rows: [
                SnapshotRow(
                    modelId: "openai/gpt-4o:free",
                    label: "GPT-4o Free",
                    p50: 120,
                    status: "live",
                    suitability: "recommended",
                    responded: true,
                    modelMatched: true,
                    notContentFiltered: true,
                    isFree: true,
                    hasTools: true,
                    hasContext: true,
                    cost: 0
                ),
            ]
        )

        try store.save(snapshot)
        #expect(store.snapshots.count == 1)
        #expect(store.snapshots.first?.scope == "free")
        #expect(store.snapshots.first?.rows.first?.modelId == "openai/gpt-4o:free")

        let reloaded = ModelHealthHistoryStore(snapshotsURL: tempDir)
        try reloaded.loadAll()
        #expect(reloaded.snapshots.count == 1)
        #expect(reloaded.snapshots.first?.rows == snapshot.rows)
    }

    @Test("make builds snapshot rows from ping results")
    func makeSnapshotFromRows() {
        let registry = [
            ModelInfo(
                id: "openai/gpt-4o:free",
                name: "GPT-4o Free",
                provider: "openai",
                contextWindow: 128_000,
                tier: .deep,
                capabilities: [.tools],
                pricing: ModelPricing(inputPer1k: 0, outputPer1k: 0)
            ),
        ]
        let rows = [
            ModelHealthPingResult(
                id: "openai/gpt-4o:free",
                label: "GPT-4o Free",
                status: .live,
                latencySamples: [100],
                cost: 0
            ),
        ]

        let snapshot = ModelHealthSnapshot.make(
            from: rows,
            registry: registry,
            scope: .free,
            timestamp: Date(timeIntervalSince1970: 1_700_000_000)
        )

        #expect(snapshot.scope == "free")
        #expect(snapshot.rows.count == 1)
        #expect(snapshot.rows[0].status == "live")
        #expect(snapshot.rows[0].responded)
        #expect(snapshot.rows[0].modelMatched)
        #expect(snapshot.rows[0].notContentFiltered)
        #expect(snapshot.rows[0].suitability == "recommended")
        #expect(snapshot.rows[0].isFree)
        #expect(snapshot.rows[0].hasTools)
        #expect(snapshot.rows[0].hasContext)
    }
}
