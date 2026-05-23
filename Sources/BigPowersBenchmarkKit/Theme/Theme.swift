import SwiftUI

public enum Theme: String, CaseIterable, Codable {
    case auto, light, dark, mono, ocean, forest, ember, violet, midnight, crimson, slate, amber, rose
}

public struct ThemeTokens {
    public let bg: Color
    // Add other tokens here as per THEME_SYSTEM.md when needed
}

public extension Theme {
    var tokens: ThemeTokens {
        // Simple mock for now
        ThemeTokens(bg: .black)
    }
}
