@testable import BigPowersBenchmarkKit
import Testing

@Suite("AppShell")
struct AppShellTests {
    @Test("Screen has exactly 8 cases")
    func screenCaseCount() {
        #expect(Screen.allCases.count == 8)
    }

    @Test("all Screen cases have non-empty title and systemImage")
    func screenMetadata() {
        for screen in Screen.allCases {
            #expect(!screen.title.isEmpty, "title empty for \(screen)")
            #expect(!screen.systemImage.isEmpty, "systemImage empty for \(screen)")
        }
    }
}
