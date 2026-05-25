@testable import BigPowersBenchmarkKit
import Testing

@Suite("AppShell")
struct AppShellTests {
    @Test("Screen has exactly 11 cases")
    func screenCaseCount() {
        #expect(Screen.allCases.count == 11)
    }

    @Test("all Screen cases have non-empty title and systemImage")
    func screenMetadata() {
        for screen in Screen.allCases {
            #expect(!screen.title.isEmpty, "title empty for \(screen)")
            #expect(!screen.systemImage.isEmpty, "systemImage empty for \(screen)")
        }
    }
}
