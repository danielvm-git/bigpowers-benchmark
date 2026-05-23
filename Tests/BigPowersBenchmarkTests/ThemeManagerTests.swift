import AppKit
@testable import BigPowersBenchmarkKit
import Foundation
import Testing

@Suite("ThemeManager")
@MainActor
struct ThemeManagerTests {
    @Test("default theme is .dark")
    func defaultTheme() throws {
        let defaults = try #require(UserDefaults(suiteName: UUID().uuidString))
        let manager = ThemeManager(defaults: defaults)
        #expect(manager.current == .dark)
    }

    @Test("persists and restores current theme via UserDefaults")
    func persistence() throws {
        let suiteName = UUID().uuidString
        defer { UserDefaults.standard.removePersistentDomain(forName: suiteName) }

        let defaults1 = try #require(UserDefaults(suiteName: suiteName))
        let manager1 = ThemeManager(defaults: defaults1)
        manager1.current = .ocean

        let defaults2 = try #require(UserDefaults(suiteName: suiteName))
        let manager2 = ThemeManager(defaults: defaults2)
        #expect(manager2.current == .ocean)
    }

    @Test(".auto resolves to .dark or .light, never .auto itself")
    func autoResolution() throws {
        let defaults = try #require(UserDefaults(suiteName: UUID().uuidString))
        let manager = ThemeManager(defaults: defaults)
        manager.current = .auto
        let resolved = manager.resolvedTheme
        #expect(resolved == .dark || resolved == .light)
        #expect(resolved != .auto)
    }
}
