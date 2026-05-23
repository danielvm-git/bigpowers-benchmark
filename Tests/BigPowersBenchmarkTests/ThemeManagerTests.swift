import AppKit
@testable import BigPowersBenchmarkKit
import Testing

@MainActor
@Suite("ThemeManager")
struct ThemeManagerTests {
    @Test("default theme is .dark")
    func defaultTheme() {
        let manager = ThemeManager()
        #expect(manager.current == .dark)
    }

    @Test("persists and restores current theme via UserDefaults")
    func persistence() {
        let manager = ThemeManager()
        manager.current = .light

        let newManager = ThemeManager()
        #expect(newManager.current == .light)

        // Cleanup
        UserDefaults.standard.removeObject(forKey: "bigpowers.theme")
    }

    @Test(".auto resolves to .dark or .light, never .auto itself")
    func autoResolution() {
        let manager = ThemeManager()
        manager.current = .auto

        let resolved = manager.resolvedTheme
        #expect(resolved != .auto)
        #expect(resolved == .dark || resolved == .light)
    }
}
