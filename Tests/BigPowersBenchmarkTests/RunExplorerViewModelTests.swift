@testable import BigPowersBenchmarkKit
import Foundation
import Testing

@Suite("RunExplorerViewModel")
@MainActor
struct RunExplorerViewModelTests {
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
        offset: TimeInterval = 0
    ) -> BenchRow {
        BenchRow(
            id: id,
            schemaVersion: 1,
            timestamp: Date().addingTimeInterval(offset),
            bigpowersRef: bigpowersRef,
            modelId: modelId,
            taskId: taskId,
            codePass: 1,
            artifactScore: 1,
            conventionScore: 1,
            duration: 10,
            cost: 0.1,
            workspace: "w"
        )
    }

    @Test("ViewModel filters runs by text query")
    func filteringByQuery() throws {
        let (store, tempDir) = try makeStore()
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let run1 = makeRow(modelId: "gpt-4", taskId: "T01", offset: 0)
        let run2 = makeRow(modelId: "claude-3", taskId: "T02", offset: 1)
        let run3 = makeRow(modelId: "gpt-3.5", taskId: "T03", bigpowersRef: "feat-x", offset: 2)

        try store.saveBenchRow(run1)
        try store.saveBenchRow(run2)
        try store.saveBenchRow(run3)
        try store.loadAllRuns()

        let vm = RunExplorerViewModel(store: store)

        // Initial state
        #expect(vm.filteredRuns.count == 3)

        // Filter by model
        vm.query = "gpt"
        #expect(vm.filteredRuns.count == 2)
        #expect(vm.filteredRuns.contains { $0.id == run1.id })
        #expect(vm.filteredRuns.contains { $0.id == run3.id })

        // Filter by task
        vm.query = "T02"
        #expect(vm.filteredRuns.count == 1)
        #expect(vm.filteredRuns.first?.id == run2.id)

        // Filter by ref
        vm.query = "feat"
        #expect(vm.filteredRuns.count == 1)
        #expect(vm.filteredRuns.first?.id == run3.id)

        // Case insensitive
        vm.query = "CLAUDE"
        #expect(vm.filteredRuns.count == 1)
        #expect(vm.filteredRuns.first?.id == run2.id)
    }

    @Test("ViewModel filters runs by specific model/ref/task pickers")
    func filteringByPickers() throws {
        let (store, tempDir) = try makeStore()
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let run1 = makeRow(modelId: "m1", taskId: "t1", bigpowersRef: "r1", offset: 0)
        let run2 = makeRow(modelId: "m1", taskId: "t2", bigpowersRef: "r2", offset: 1)
        let run3 = makeRow(modelId: "m2", taskId: "t1", bigpowersRef: "r1", offset: 2)

        try store.saveBenchRow(run1)
        try store.saveBenchRow(run2)
        try store.saveBenchRow(run3)
        try store.loadAllRuns()

        let vm = RunExplorerViewModel(store: store)

        // Filter by model picker
        vm.selectedModel = "m1"
        #expect(vm.filteredRuns.count == 2)
        #expect(vm.filteredRuns.allSatisfy { $0.modelId == "m1" })

        // Filter by ref picker
        vm.selectedRef = "r1"
        #expect(vm.filteredRuns.count == 1)
        #expect(vm.filteredRuns.first?.id == run1.id)

        // Filter by task picker
        vm.selectedModel = nil
        vm.selectedRef = nil
        vm.selectedTask = "t1"
        #expect(vm.filteredRuns.count == 2)
        #expect(vm.filteredRuns.allSatisfy { $0.taskId == "t1" })

        // Reset
        vm.selectedModel = nil
        vm.selectedTask = nil
        #expect(vm.filteredRuns.count == 3)
    }

    @Test("ViewModel provides available filter options")
    func availableOptions() throws {
        let (store, tempDir) = try makeStore()
        defer { try? FileManager.default.removeItem(at: tempDir) }

        try store.saveBenchRow(makeRow(modelId: "m1", taskId: "t1", bigpowersRef: "r1", offset: 0))
        try store.saveBenchRow(makeRow(modelId: "m2", taskId: "t1", bigpowersRef: "r2", offset: 1))
        try store.loadAllRuns()

        let vm = RunExplorerViewModel(store: store)

        #expect(vm.availableModels == ["m1", "m2"])
        #expect(vm.availableTasks == ["t1"])
        #expect(vm.availableRefs == ["r1", "r2"])
    }
}
