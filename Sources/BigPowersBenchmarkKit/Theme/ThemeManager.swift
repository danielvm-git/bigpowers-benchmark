import AppKit
import SwiftUI

@Observable
public final class ThemeManager {
    private static let defaultsKey = "bigpowers.theme"
    private let defaults: UserDefaults

    public var current: Theme {
        didSet { defaults.set(current.rawValue, forKey: Self.defaultsKey) }
    }

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        if let raw = defaults.string(forKey: Self.defaultsKey),
           let theme = Theme(rawValue: raw) {
            current = theme
        } else {
            current = .dark
        }
    }

    @MainActor
    public var resolvedTheme: Theme {
        guard current == .auto else { return current }
        let isDark = NSApplication.shared.effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
        return isDark ? .dark : .light
    }
}
