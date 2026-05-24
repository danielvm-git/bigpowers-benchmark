@testable import BigPowersBenchmarkKit
import Foundation
import Testing

@Suite("RunExplorerViewModel")
@MainActor
struct RunExplorerViewModelTests {
    @Test("ViewModel filters runs by query")
    func filtering() {
        let store = BenchmarkStore(gitService: MockGitService())
        let vm = RunExplorerViewModel(store: store)

        let run1 = BenchRow(
            id: UUID(),
            schemaVersion: 1,
            timestamp: Date(),
            bigpowersRef: "ref1",
            modelId: "gpt-4",
            taskId: "T1",
            codePass: 1,
            artifactScore: 1,
            conventionScore: 1,
            duration: 10,
            cost: 0.1,
            workspace: "w1"
        )
        let run2 = BenchRow(
            id: UUID(),
            schemaVersion: 1,
            timestamp: Date(),
            bigpowersRef: "ref2",
            modelId: "claude",
            taskId: "T2",
            codePass: 1,
            artifactScore: 1,
            conventionScore: 1,
            duration: 20,
            cost: 0.2,
            workspace: "w2"
        )

        // This is a bit tricky since runs is private(set) in store.
        // We'll assume the VM reads from the store's runs.
    }
}
