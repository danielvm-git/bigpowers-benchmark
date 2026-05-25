@testable import BigPowersBenchmarkKit
import Foundation
import Testing

@Suite("DashboardViewModel")
@MainActor
struct DashboardViewModelTests {
    private func makeStore() throws -> (BenchmarkStore, URL) {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        let store = BenchmarkStore(runsURL: tempDir, gitService: MockGitService())
        return (store, tempDir)
    }

    private func makeRow(
        id: UUID = UUID(),
        modelId: String = "gpt-4",
        taskId: String = "T01",
        bigpowersRef: String = "v1.0.0",
        codePass: Int = 1,
        artifactScore: Int = 1,
        conventionScore: Int = 1,
        duration: Double = 10,
        cost: Double = 0.1,
        workspace: String = "w",
        offset: TimeInterval = 0
    ) -> BenchRow {
        BenchRow(
            id: id,
            schemaVersion: 1,
            timestamp: Date().addingTimeInterval(offset),
            bigpowersRef: bigpowersRef,
            modelId: modelId,
            taskId: taskId,
            codePass: codePass,
            artifactScore: artifactScore,
            conventionScore: conventionScore,
            duration: duration,
            cost: cost,
            workspace: workspace
        )
    }

    @Test("bestModel returns model with highest average score")
    func bestModel() throws {
        let (store, tempDir) = try makeStore()
        defer { try? FileManager.default.removeItem(at: tempDir) }

        try store.saveBenchRow(makeRow(modelId: "m1", codePass: 1, artifactScore: 1, conventionScore: 1, offset: 0))
        try store.saveBenchRow(makeRow(modelId: "m1", codePass: 2, artifactScore: 2, conventionScore: 2, offset: 1))
        try store.saveBenchRow(makeRow(modelId: "m2", codePass: 0, artifactScore: 0, conventionScore: 0, offset: 2))
        try store.loadAllRuns()

        let vm = DashboardViewModel(store: store)

        #expect(vm.bestModel != nil)
        #expect(vm.bestModel?.name == "m1")
    }

    @Test("fastestModel returns model with lowest average duration")
    func fastestModel() throws {
        let (store, tempDir) = try makeStore()
        defer { try? FileManager.default.removeItem(at: tempDir) }

        try store.saveBenchRow(makeRow(modelId: "fast", duration: 5, offset: 0))
        try store.saveBenchRow(makeRow(modelId: "slow", duration: 50, offset: 1))
        try store.loadAllRuns()

        let vm = DashboardViewModel(store: store)

        #expect(vm.fastestModel != nil)
        #expect(vm.fastestModel?.name == "fast")
    }

    @Test("cheapestModel returns model with lowest average cost")
    func cheapestModel() throws {
        let (store, tempDir) = try makeStore()
        defer { try? FileManager.default.removeItem(at: tempDir) }

        try store.saveBenchRow(makeRow(modelId: "cheap", cost: 0.01, offset: 0))
        try store.saveBenchRow(makeRow(modelId: "pricey", cost: 0.99, offset: 1))
        try store.loadAllRuns()

        let vm = DashboardViewModel(store: store)

        #expect(vm.cheapestModel != nil)
        #expect(vm.cheapestModel?.name == "cheap")
    }

    @Test("mostImproved is nil when no model has 2 distinct refs")
    func mostImprovedNilWithOneRun() throws {
        let (store, tempDir) = try makeStore()
        defer { try? FileManager.default.removeItem(at: tempDir) }

        try store.saveBenchRow(makeRow(modelId: "m1", bigpowersRef: "v1", offset: 0))
        try store.loadAllRuns()

        let vm = DashboardViewModel(store: store)

        #expect(vm.mostImproved == nil)
    }

    @Test("mostImproved computes delta between refs for a model")
    func mostImprovedWithMultipleRefs() throws {
        let (store, tempDir) = try makeStore()
        defer { try? FileManager.default.removeItem(at: tempDir) }

        try store.saveBenchRow(makeRow(
            modelId: "m1",
            bigpowersRef: "v1",
            codePass: 0,
            artifactScore: 0,
            conventionScore: 0,
            offset: 0
        ))
        try store.saveBenchRow(makeRow(
            modelId: "m1",
            bigpowersRef: "v2",
            codePass: 2,
            artifactScore: 2,
            conventionScore: 2,
            offset: 1
        ))
        try store.saveBenchRow(makeRow(
            modelId: "m2",
            bigpowersRef: "v1",
            codePass: 1,
            artifactScore: 1,
            conventionScore: 1,
            offset: 2
        ))
        try store.loadAllRuns()

        let vm = DashboardViewModel(store: store)

        let improvement = try #require(vm.mostImproved)
        #expect(improvement.model == "m1")
        #expect(improvement.delta > 0)
    }

    @Test("mostImproved is nil when multiple models exist but none have 2+ refs")
    func mostImprovedNilWhenNoModelHasTwoRefs() throws {
        let (store, tempDir) = try makeStore()
        defer { try? FileManager.default.removeItem(at: tempDir) }

        try store.saveBenchRow(makeRow(modelId: "m1", bigpowersRef: "v1", offset: 0))
        try store.saveBenchRow(makeRow(modelId: "m2", bigpowersRef: "v1", offset: 1))
        try store.loadAllRuns()

        let vm = DashboardViewModel(store: store)

        #expect(vm.mostImproved == nil)
    }

    @Test("recentRegressions detects scores that dropped below threshold")
    func regressionDetection() throws {
        let (store, tempDir) = try makeStore()
        defer { try? FileManager.default.removeItem(at: tempDir) }

        try store.saveBenchRow(makeRow(
            modelId: "m1",
            taskId: "T01",
            bigpowersRef: "v1",
            codePass: 2,
            artifactScore: 2,
            conventionScore: 2,
            offset: 0
        ))
        try store.saveBenchRow(makeRow(
            modelId: "m1",
            taskId: "T01",
            bigpowersRef: "v2",
            codePass: 0,
            artifactScore: 0,
            conventionScore: 0,
            offset: 1
        ))
        try store.loadAllRuns()

        let vm = DashboardViewModel(store: store)

        #expect(!vm.recentRegressions.isEmpty)
        #expect(vm.recentRegressions.contains { $0.model == "m1" && $0.task == "T01" })
    }

    @Test("recentRegressions is empty when scores are stable")
    func noRegressionsWhenStable() throws {
        let (store, tempDir) = try makeStore()
        defer { try? FileManager.default.removeItem(at: tempDir) }

        try store.saveBenchRow(makeRow(
            modelId: "m1",
            taskId: "T01",
            bigpowersRef: "v1",
            codePass: 1,
            artifactScore: 1,
            conventionScore: 1,
            offset: 0
        ))
        try store.saveBenchRow(makeRow(
            modelId: "m1",
            taskId: "T01",
            bigpowersRef: "v2",
            codePass: 1,
            artifactScore: 1,
            conventionScore: 1,
            offset: 1
        ))
        try store.loadAllRuns()

        let vm = DashboardViewModel(store: store)

        #expect(vm.recentRegressions.isEmpty)
    }

    @Test("all computed values return nil when store has no runs")
    func emptyState() throws {
        let (store, tempDir) = try makeStore()
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let vm = DashboardViewModel(store: store)

        #expect(vm.bestModel == nil)
        #expect(vm.fastestModel == nil)
        #expect(vm.cheapestModel == nil)
        #expect(vm.mostImproved == nil)
        #expect(vm.recentRegressions.isEmpty)
    }
}
