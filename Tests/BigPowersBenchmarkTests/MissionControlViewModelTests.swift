@testable import BigPowersBenchmarkKit
import Foundation
import Testing

@Suite("MissionControlViewModel")
@MainActor
struct MissionControlViewModelTests {
    @Test("ViewModel loads sandboxes on init")
    func sandboxesLoad() async {
        let mockClient = MockDaytonaClient()
        let store = BenchmarkStore(gitService: MockGitService())
        let config = DaytonaConfig(keychainService: MockKeychainService())

        let vm = MissionControlViewModel(daytonaClient: mockClient, store: store, config: config)

        // Trigger load
        await vm.loadSandboxes()

        #expect(vm.sandboxes.count == 2)
    }

    @Test("startRun updates state to running")
    func testStartRun() async {
        let mockClient = MockDaytonaClient()
        let store = BenchmarkStore(gitService: MockGitService())
        let config = DaytonaConfig(keychainService: MockKeychainService())

        let vm = MissionControlViewModel(daytonaClient: mockClient, store: store, config: config)

        let sandbox = Sandbox(id: "sb-1", name: "s1", state: .started, labels: [:], toolboxProxyUrl: "")
        let task = BenchmarkTask(id: "T1", name: "T1", description: "D")

        vm.selectedSandbox = sandbox
        vm.selectedTask = task
        vm.selectedModel = "gpt-4"

        await vm.startRun()

        #expect(vm.runState == .running)
    }
}
