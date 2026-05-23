import SwiftUI

public enum Theme: String, CaseIterable, Codable, Sendable {
    case auto, light, dark, mono, ocean, forest, ember, violet, midnight, crimson, slate, amber, rose
}

public struct ThemeTokens: Sendable {
    public let bg: Color
    public let bg1: Color
    public let surface: Color
    public let surface2: Color
    public let border: Color
    public let border2: Color
    public let fg: Color
    public let fg2: Color
    public let fg3: Color
    public let fg4: Color
    public let accent: Color
    public let accentD: Color
    public let accentF: Color
    public let good: Color
    public let bad: Color
    public let warn: Color
    public let grid: Color
    public let grid2: Color
    public let shadow: Color
}

public extension Theme {
    var tokens: ThemeTokens {
        switch self {
        case .auto: Theme.dark.tokens
        case .dark: .dark
        case .light: .light
        case .mono: .mono
        case .ocean: .ocean
        case .forest: .forest
        case .ember: .ember
        case .violet: .violet
        case .midnight: .midnight
        case .crimson: .crimson
        case .slate: .slate
        case .amber: .amber
        case .rose: .rose
        }
    }
}

// MARK: - Hex / RGBA helpers (file-private)

private func hex(_ value: String) -> Color {
    var str = value
    if str.hasPrefix("#") { str = String(str.dropFirst()) }
    var rgb: UInt64 = 0
    Scanner(string: str).scanHexInt64(&rgb)
    return Color(
        red: Double((rgb >> 16) & 0xFF) / 255,
        green: Double((rgb >> 8) & 0xFF) / 255,
        blue: Double(rgb & 0xFF) / 255
    )
}

private func rgba(_ red: Int, _ green: Int, _ blue: Int, _ opacity: Double) -> Color {
    Color(red: Double(red) / 255, green: Double(green) / 255, blue: Double(blue) / 255, opacity: opacity)
}

// MARK: - Token tables

private extension ThemeTokens {
    static let dark = ThemeTokens(
        bg: hex("#0f1117"), bg1: hex("#141823"),
        surface: hex("#161922"), surface2: hex("#1c2030"),
        border: hex("#232838"), border2: hex("#2d3346"),
        fg: hex("#e6e8ee"), fg2: hex("#b4bac9"), fg3: hex("#9ca3b3"), fg4: hex("#7a8191"),
        accent: hex("#2dd4bf"), accentD: hex("#14b8a6"), accentF: rgba(45, 212, 191, 0.12),
        good: hex("#34d399"), bad: hex("#f87171"), warn: hex("#fbbf24"),
        grid: rgba(255, 255, 255, 0.04), grid2: rgba(255, 255, 255, 0.07),
        shadow: rgba(0, 0, 0, 0.35)
    )

    static let light = ThemeTokens(
        bg: hex("#ffffff"), bg1: hex("#f8f9fa"),
        surface: hex("#ffffff"), surface2: hex("#f1f3f5"),
        border: hex("#e1e4e8"), border2: hex("#d1d5db"),
        fg: hex("#1a1d23"), fg2: hex("#4a5160"), fg3: hex("#6b7280"), fg4: hex("#9ca3af"),
        accent: hex("#14b8a6"), accentD: hex("#0d9488"), accentF: rgba(20, 184, 166, 0.12),
        good: hex("#10b981"), bad: hex("#ef4444"), warn: hex("#f59e0b"),
        grid: rgba(0, 0, 0, 0.04), grid2: rgba(0, 0, 0, 0.07),
        shadow: rgba(0, 0, 0, 0.08)
    )

    static let mono = ThemeTokens(
        bg: hex("#0d0d0d"), bg1: hex("#141414"),
        surface: hex("#1a1a1a"), surface2: hex("#202020"),
        border: hex("#2a2a2a"), border2: hex("#353535"),
        fg: hex("#f0f0f0"), fg2: hex("#c0c0c0"), fg3: hex("#a0a0a0"), fg4: hex("#808080"),
        accent: hex("#ffffff"), accentD: hex("#e8e8e8"), accentF: rgba(255, 255, 255, 0.10),
        good: hex("#b0b0b0"), bad: hex("#707070"), warn: hex("#909090"),
        grid: rgba(255, 255, 255, 0.05), grid2: rgba(255, 255, 255, 0.08),
        shadow: rgba(0, 0, 0, 0.60)
    )

    static let ocean = ThemeTokens(
        bg: hex("#0a1628"), bg1: hex("#0d1b33"),
        surface: hex("#12213d"), surface2: hex("#1a2d4f"),
        border: hex("#1e3a5f"), border2: hex("#2a4a75"),
        fg: hex("#e1f0ff"), fg2: hex("#b5d5f0"), fg3: hex("#90b8da"), fg4: hex("#6b9bc4"),
        accent: hex("#38bdf8"), accentD: hex("#0ea5e9"), accentF: rgba(56, 189, 248, 0.12),
        good: hex("#22d3ee"), bad: hex("#f87171"), warn: hex("#fbbf24"),
        grid: rgba(56, 189, 248, 0.05), grid2: rgba(56, 189, 248, 0.08),
        shadow: rgba(0, 10, 20, 0.50)
    )

    static let forest = ThemeTokens(
        bg: hex("#0a1510"), bg1: hex("#0e1d18"),
        surface: hex("#122520"), surface2: hex("#1a332d"),
        border: hex("#1f3d35"), border2: hex("#2a5045"),
        fg: hex("#e6f5ed"), fg2: hex("#b8dbca"), fg3: hex("#92c2a8"), fg4: hex("#6da886"),
        accent: hex("#10b981"), accentD: hex("#059669"), accentF: rgba(16, 185, 129, 0.12),
        good: hex("#34d399"), bad: hex("#f87171"), warn: hex("#fbbf24"),
        grid: rgba(16, 185, 129, 0.04), grid2: rgba(16, 185, 129, 0.07),
        shadow: rgba(0, 0, 0, 0.45)
    )

    static let ember = ThemeTokens(
        bg: hex("#1a0f0a"), bg1: hex("#231612"),
        surface: hex("#2d1f1a"), surface2: hex("#3a2a24"),
        border: hex("#4a352e"), border2: hex("#5d443b"),
        fg: hex("#fff4ed"), fg2: hex("#f5d0ba"), fg3: hex("#e0b59e"), fg4: hex("#c99a82"),
        accent: hex("#fb923c"), accentD: hex("#f97316"), accentF: rgba(251, 146, 60, 0.12),
        good: hex("#34d399"), bad: hex("#ef4444"), warn: hex("#fbbf24"),
        grid: rgba(251, 146, 60, 0.04), grid2: rgba(251, 146, 60, 0.07),
        shadow: rgba(0, 0, 0, 0.50)
    )

    static let violet = ThemeTokens(
        bg: hex("#14091a"), bg1: hex("#1c1023"),
        surface: hex("#25172e"), surface2: hex("#31213d"),
        border: hex("#3d2a4d"), border2: hex("#4d3760"),
        fg: hex("#f4edff"), fg2: hex("#d5c3f0"), fg3: hex("#b8a0da"), fg4: hex("#9b7dc4"),
        accent: hex("#a78bfa"), accentD: hex("#8b5cf6"), accentF: rgba(167, 139, 250, 0.12),
        good: hex("#34d399"), bad: hex("#f87171"), warn: hex("#fbbf24"),
        grid: rgba(167, 139, 250, 0.05), grid2: rgba(167, 139, 250, 0.08),
        shadow: rgba(0, 0, 0, 0.45)
    )

    static let midnight = ThemeTokens(
        bg: hex("#0b0e1a"), bg1: hex("#111528"),
        surface: hex("#161c33"), surface2: hex("#1e2640"),
        border: hex("#252f4d"), border2: hex("#303c5f"),
        fg: hex("#e5e9ff"), fg2: hex("#b8c2e8"), fg3: hex("#8f9dcf"), fg4: hex("#6c7ab6"),
        accent: hex("#818cf8"), accentD: hex("#6366f1"), accentF: rgba(129, 140, 248, 0.12),
        good: hex("#34d399"), bad: hex("#f87171"), warn: hex("#fbbf24"),
        grid: rgba(129, 140, 248, 0.04), grid2: rgba(129, 140, 248, 0.07),
        shadow: rgba(0, 0, 0, 0.50)
    )

    static let crimson = ThemeTokens(
        bg: hex("#1a0a0e"), bg1: hex("#231115"),
        surface: hex("#2d171d"), surface2: hex("#3d2128"),
        border: hex("#4d2a32"), border2: hex("#603641"),
        fg: hex("#ffecf0"), fg2: hex("#f5c5d1"), fg3: hex("#dfa0b0"), fg4: hex("#c97d90"),
        accent: hex("#fb7185"), accentD: hex("#f43f5e"), accentF: rgba(251, 113, 133, 0.12),
        good: hex("#34d399"), bad: hex("#ef4444"), warn: hex("#fbbf24"),
        grid: rgba(251, 113, 133, 0.04), grid2: rgba(251, 113, 133, 0.07),
        shadow: rgba(0, 0, 0, 0.50)
    )

    static let slate = ThemeTokens(
        bg: hex("#0f1419"), bg1: hex("#151b23"),
        surface: hex("#1a222d"), surface2: hex("#222d3a"),
        border: hex("#2a3847"), border2: hex("#354557"),
        fg: hex("#e8ecf2"), fg2: hex("#b8c5d6"), fg3: hex("#90a0ba"), fg4: hex("#6b7c9e"),
        accent: hex("#64748b"), accentD: hex("#475569"), accentF: rgba(100, 116, 139, 0.15),
        good: hex("#34d399"), bad: hex("#f87171"), warn: hex("#fbbf24"),
        grid: rgba(100, 116, 139, 0.05), grid2: rgba(100, 116, 139, 0.08),
        shadow: rgba(0, 0, 0, 0.45)
    )

    static let amber = ThemeTokens(
        bg: hex("#1a1508"), bg1: hex("#231d0f"),
        surface: hex("#2d2616"), surface2: hex("#3a3120"),
        border: hex("#4a3d28"), border2: hex("#5d4d35"),
        fg: hex("#fffaeb"), fg2: hex("#f5e5b8"), fg3: hex("#e0cf8f"), fg4: hex("#c9b96b"),
        accent: hex("#fbbf24"), accentD: hex("#f59e0b"), accentF: rgba(251, 191, 36, 0.12),
        good: hex("#34d399"), bad: hex("#f87171"), warn: hex("#fb923c"),
        grid: rgba(251, 191, 36, 0.04), grid2: rgba(251, 191, 36, 0.07),
        shadow: rgba(0, 0, 0, 0.50)
    )

    static let rose = ThemeTokens(
        bg: hex("#1a0d14"), bg1: hex("#23141c"),
        surface: hex("#2d1a26"), surface2: hex("#3a2332"),
        border: hex("#4a2d3f"), border2: hex("#5d3a50"),
        fg: hex("#fff0f6"), fg2: hex("#f5c9dd"), fg3: hex("#dfa3c0"), fg4: hex("#c97ea3"),
        accent: hex("#f472b6"), accentD: hex("#ec4899"), accentF: rgba(244, 114, 182, 0.12),
        good: hex("#34d399"), bad: hex("#f87171"), warn: hex("#fbbf24"),
        grid: rgba(244, 114, 182, 0.04), grid2: rgba(244, 114, 182, 0.07),
        shadow: rgba(0, 0, 0, 0.45)
    )
}
