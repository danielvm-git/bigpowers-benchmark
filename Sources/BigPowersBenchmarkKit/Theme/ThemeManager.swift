import AppKit
import Observation

@Observable
@MainActor
public final class ThemeManager {
    private static let defaultsKey = "bigpowers.theme"

    public var current: Theme {
        didSet { defaults.set(current.rawValue, forKey: Self.defaultsKey) }
    }

    private let defaults: UserDefaults

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        if let raw = defaults.string(forKey: Self.defaultsKey),
           let saved = Theme(rawValue: raw) {
            current = saved
        } else {
            current = .dark
        }
    }

    public var resolvedTheme: Theme {
        guard current == .auto else { return current }
        let isDark = NSApp?.effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
        return isDark ? .dark : .light
    }

    public var tokens: ThemeTokens {
        resolvedTheme.tokens
    }
}
