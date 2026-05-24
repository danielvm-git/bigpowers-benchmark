import AppKit
@testable import BigPowersBenchmarkKit
import Testing

@MainActor
@Suite("ThemeManager")
struct ThemeManagerTests {
    @Test("default theme is .dark")
    func defaultTheme() throws {
        let defaults = try #require(UserDefaults(suiteName: "ThemeManagerTests-\(UUID().uuidString)"))
        let manager = ThemeManager(defaults: defaults)
        #expect(manager.current == .dark)
    }

    @Test("persists and restores current theme via UserDefaults")
    func persistence() throws {
        let suiteName = "ThemeManagerTests-\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        let manager = ThemeManager(defaults: defaults)
        manager.current = .light

        let newManager = ThemeManager(defaults: defaults)
        #expect(newManager.current == .light)
    }

    @Test(".auto resolves to .dark or .light, never .auto itself")
    func autoResolution() throws {
        let defaults = try #require(UserDefaults(suiteName: "ThemeManagerTests-\(UUID().uuidString)"))
        let manager = ThemeManager(defaults: defaults)
        manager.current = .auto

        let resolved = manager.resolvedTheme
        #expect(resolved != .auto)
        #expect(resolved == .dark || resolved == .light)
    }
}
