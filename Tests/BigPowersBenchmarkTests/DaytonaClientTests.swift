@testable import BigPowersBenchmarkKit
import Foundation
import Testing

@Suite("DaytonaClient")
struct DaytonaClientTests {
    @Test("listSandboxes decodes fixture correctly")
    func testListSandboxes() async throws {
        let mock = MockDaytonaClient()
        let sandboxes = try await mock.listSandboxes()

        #expect(sandboxes.count == 2)
        #expect(sandboxes[0].id == "sb-1")
        #expect(sandboxes[1].state == .started)
    }

    @Test("Sandbox isRunnable predicate")
    func sandboxIsRunnable() {
        let started = Sandbox(id: "1", name: "s1", state: .started, labels: [:], toolboxProxyUrl: "")
        let stopped = Sandbox(id: "2", name: "s2", state: .stopped, labels: [:], toolboxProxyUrl: "")

        #expect(started.isRunnable == true)
        #expect(stopped.isRunnable == false)
    }
}
