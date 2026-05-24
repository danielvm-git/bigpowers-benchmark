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

extension Color {
    init(hex: String, opacity: Double = 1.0) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (r, g, b) = ((int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (r, g, b) = (int >> 16, int >> 8 & 0xFF, int & 0xFF)
        default:
            (r, g, b) = (0, 0, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: opacity
        )
    }
}

public extension Theme {
    var tokens: ThemeTokens {
        switch self {
        case .auto:
            // Auto resolves dynamically, this is a fallback
            Theme.dark.tokens

        case .light:
            ThemeTokens(
                bg: Color(hex: "#ffffff"),
                bg1: Color(hex: "#f8f9fa"),
                surface: Color(hex: "#ffffff"),
                surface2: Color(hex: "#f1f3f5"),
                border: Color(hex: "#e1e4e8"),
                border2: Color(hex: "#d1d5db"),
                fg: Color(hex: "#1a1d23"),
                fg2: Color(hex: "#4a5160"),
                fg3: Color(hex: "#6b7280"),
                fg4: Color(hex: "#9ca3af"),
                accent: Color(hex: "#14b8a6"),
                accentD: Color(hex: "#0d9488"),
                accentF: Color(hex: "#14b8a6", opacity: 0.12),
                good: Color(hex: "#10b981"),
                bad: Color(hex: "#ef4444"),
                warn: Color(hex: "#f59e0b"),
                grid: Color.black.opacity(0.04),
                grid2: Color.black.opacity(0.07),
                shadow: Color.black.opacity(0.08)
            )

        case .dark:
            ThemeTokens(
                bg: Color(hex: "#0f1117"),
                bg1: Color(hex: "#141823"),
                surface: Color(hex: "#161922"),
                surface2: Color(hex: "#1c2030"),
                border: Color(hex: "#232838"),
                border2: Color(hex: "#2d3346"),
                fg: Color(hex: "#e6e8ee"),
                fg2: Color(hex: "#b4bac9"),
                fg3: Color(hex: "#9ca3b3"),
                fg4: Color(hex: "#7a8191"),
                accent: Color(hex: "#2dd4bf"),
                accentD: Color(hex: "#14b8a6"),
                accentF: Color(hex: "#2dd4bf", opacity: 0.12),
                good: Color(hex: "#34d399"),
                bad: Color(hex: "#f87171"),
                warn: Color(hex: "#fbbf24"),
                grid: Color.white.opacity(0.04),
                grid2: Color.white.opacity(0.07),
                shadow: Color.black.opacity(0.35)
            )

        case .mono:
            ThemeTokens(
                bg: Color(hex: "#0d0d0d"),
                bg1: Color(hex: "#141414"),
                surface: Color(hex: "#1a1a1a"),
                surface2: Color(hex: "#202020"),
                border: Color(hex: "#2a2a2a"),
                border2: Color(hex: "#353535"),
                fg: Color(hex: "#f0f0f0"),
                fg2: Color(hex: "#c0c0c0"),
                fg3: Color(hex: "#a0a0a0"),
                fg4: Color(hex: "#808080"),
                accent: Color(hex: "#ffffff"),
                accentD: Color(hex: "#e8e8e8"),
                accentF: Color(hex: "#ffffff", opacity: 0.10),
                good: Color(hex: "#b0b0b0"),
                bad: Color(hex: "#707070"),
                warn: Color(hex: "#909090"),
                grid: Color.white.opacity(0.05),
                grid2: Color.white.opacity(0.08),
                shadow: Color.black.opacity(0.6)
            )

        case .ocean:
            ThemeTokens(
                bg: Color(hex: "#0a1628"),
                bg1: Color(hex: "#0d1b33"),
                surface: Color(hex: "#12213d"),
                surface2: Color(hex: "#1a2d4f"),
                border: Color(hex: "#1e3a5f"),
                border2: Color(hex: "#2a4a75"),
                fg: Color(hex: "#e1f0ff"),
                fg2: Color(hex: "#b5d5f0"),
                fg3: Color(hex: "#90b8da"),
                fg4: Color(hex: "#6b9bc4"),
                accent: Color(hex: "#38bdf8"),
                accentD: Color(hex: "#0ea5e9"),
                accentF: Color(hex: "#38bdf8", opacity: 0.12),
                good: Color(hex: "#22d3ee"),
                bad: Color(hex: "#f87171"),
                warn: Color(hex: "#fbbf24"),
                grid: Color(hex: "#38bdf8", opacity: 0.05),
                grid2: Color(hex: "#38bdf8", opacity: 0.08),
                shadow: Color(hex: "#000a14", opacity: 0.5)
            )

        case .forest:
            ThemeTokens(
                bg: Color(hex: "#0a1510"),
                bg1: Color(hex: "#0e1d18"),
                surface: Color(hex: "#122520"),
                surface2: Color(hex: "#1a332d"),
                border: Color(hex: "#1f3d35"),
                border2: Color(hex: "#2a5045"),
                fg: Color(hex: "#e6f5ed"),
                fg2: Color(hex: "#b8dbca"),
                fg3: Color(hex: "#92c2a8"),
                fg4: Color(hex: "#6da886"),
                accent: Color(hex: "#10b981"),
                accentD: Color(hex: "#059669"),
                accentF: Color(hex: "#10b981", opacity: 0.12),
                good: Color(hex: "#34d399"),
                bad: Color(hex: "#f87171"),
                warn: Color(hex: "#fbbf24"),
                grid: Color(hex: "#10b981", opacity: 0.04),
                grid2: Color(hex: "#10b981", opacity: 0.07),
                shadow: Color.black.opacity(0.45)
            )

        case .ember:
            ThemeTokens(
                bg: Color(hex: "#1a0f0a"),
                bg1: Color(hex: "#231612"),
                surface: Color(hex: "#2d1f1a"),
                surface2: Color(hex: "#3a2a24"),
                border: Color(hex: "#4a352e"),
                border2: Color(hex: "#5d443b"),
                fg: Color(hex: "#fff4ed"),
                fg2: Color(hex: "#f5d0ba"),
                fg3: Color(hex: "#e0b59e"),
                fg4: Color(hex: "#c99a82"),
                accent: Color(hex: "#fb923c"),
                accentD: Color(hex: "#f97316"),
                accentF: Color(hex: "#fb923c", opacity: 0.12),
                good: Color(hex: "#34d399"),
                bad: Color(hex: "#ef4444"),
                warn: Color(hex: "#fbbf24"),
                grid: Color(hex: "#fb923c", opacity: 0.04),
                grid2: Color(hex: "#fb923c", opacity: 0.07),
                shadow: Color.black.opacity(0.5)
            )

        case .violet:
            ThemeTokens(
                bg: Color(hex: "#14091a"),
                bg1: Color(hex: "#1c1023"),
                surface: Color(hex: "#25172e"),
                surface2: Color(hex: "#31213d"),
                border: Color(hex: "#3d2a4d"),
                border2: Color(hex: "#4d3760"),
                fg: Color(hex: "#f4edff"),
                fg2: Color(hex: "#d5c3f0"),
                fg3: Color(hex: "#b8a0da"),
                fg4: Color(hex: "#9b7dc4"),
                accent: Color(hex: "#a78bfa"),
                accentD: Color(hex: "#8b5cf6"),
                accentF: Color(hex: "#a78bfa", opacity: 0.12),
                good: Color(hex: "#34d399"),
                bad: Color(hex: "#f87171"),
                warn: Color(hex: "#fbbf24"),
                grid: Color(hex: "#a78bfa", opacity: 0.05),
                grid2: Color(hex: "#a78bfa", opacity: 0.08),
                shadow: Color.black.opacity(0.45)
            )

        case .midnight:
            ThemeTokens(
                bg: Color(hex: "#0b0e1a"),
                bg1: Color(hex: "#111528"),
                surface: Color(hex: "#161c33"),
                surface2: Color(hex: "#1e2640"),
                border: Color(hex: "#252f4d"),
                border2: Color(hex: "#303c5f"),
                fg: Color(hex: "#e5e9ff"),
                fg2: Color(hex: "#b8c2e8"),
                fg3: Color(hex: "#8f9dcf"),
                fg4: Color(hex: "#6c7ab6"),
                accent: Color(hex: "#818cf8"),
                accentD: Color(hex: "#6366f1"),
                accentF: Color(hex: "#818cf8", opacity: 0.12),
                good: Color(hex: "#34d399"),
                bad: Color(hex: "#f87171"),
                warn: Color(hex: "#fbbf24"),
                grid: Color(hex: "#818cf8", opacity: 0.04),
                grid2: Color(hex: "#818cf8", opacity: 0.07),
                shadow: Color.black.opacity(0.5)
            )

        case .crimson:
            ThemeTokens(
                bg: Color(hex: "#1a0a0e"),
                bg1: Color(hex: "#231115"),
                surface: Color(hex: "#2d171d"),
                surface2: Color(hex: "#3d2128"),
                border: Color(hex: "#4d2a32"),
                border2: Color(hex: "#603641"),
                fg: Color(hex: "#ffecf0"),
                fg2: Color(hex: "#f5c5d1"),
                fg3: Color(hex: "#dfa0b0"),
                fg4: Color(hex: "#c97d90"),
                accent: Color(hex: "#fb7185"),
                accentD: Color(hex: "#f43f5e"),
                accentF: Color(hex: "#fb7185", opacity: 0.12),
                good: Color(hex: "#34d399"),
                bad: Color(hex: "#ef4444"),
                warn: Color(hex: "#fbbf24"),
                grid: Color(hex: "#fb7185", opacity: 0.04),
                grid2: Color(hex: "#fb7185", opacity: 0.07),
                shadow: Color.black.opacity(0.5)
            )

        case .slate:
            ThemeTokens(
                bg: Color(hex: "#0f1419"),
                bg1: Color(hex: "#151b23"),
                surface: Color(hex: "#1a222d"),
                surface2: Color(hex: "#222d3a"),
                border: Color(hex: "#2a3847"),
                border2: Color(hex: "#354557"),
                fg: Color(hex: "#e8ecf2"),
                fg2: Color(hex: "#b8c5d6"),
                fg3: Color(hex: "#90a0ba"),
                fg4: Color(hex: "#6b7c9e"),
                accent: Color(hex: "#64748b"),
                accentD: Color(hex: "#475569"),
                accentF: Color(hex: "#64748b", opacity: 0.15),
                good: Color(hex: "#34d399"),
                bad: Color(hex: "#f87171"),
                warn: Color(hex: "#fbbf24"),
                grid: Color(hex: "#64748b", opacity: 0.05),
                grid2: Color(hex: "#64748b", opacity: 0.08),
                shadow: Color.black.opacity(0.45)
            )

        case .amber:
            ThemeTokens(
                bg: Color(hex: "#1a1508"),
                bg1: Color(hex: "#231d0f"),
                surface: Color(hex: "#2d2616"),
                surface2: Color(hex: "#3a3120"),
                border: Color(hex: "#4a3d28"),
                border2: Color(hex: "#5d4d35"),
                fg: Color(hex: "#fffaeb"),
                fg2: Color(hex: "#f5e5b8"),
                fg3: Color(hex: "#e0cf8f"),
                fg4: Color(hex: "#c9b96b"),
                accent: Color(hex: "#fbbf24"),
                accentD: Color(hex: "#f59e0b"),
                accentF: Color(hex: "#fbbf24", opacity: 0.12),
                good: Color(hex: "#34d399"),
                bad: Color(hex: "#f87171"),
                warn: Color(hex: "#fb923c"),
                grid: Color(hex: "#fbbf24", opacity: 0.04),
                grid2: Color(hex: "#fbbf24", opacity: 0.07),
                shadow: Color.black.opacity(0.5)
            )

        case .rose:
            ThemeTokens(
                bg: Color(hex: "#1a0d14"),
                bg1: Color(hex: "#23141c"),
                surface: Color(hex: "#2d1a26"),
                surface2: Color(hex: "#3a2332"),
                border: Color(hex: "#4a2d3f"),
                border2: Color(hex: "#5d3a50"),
                fg: Color(hex: "#fff0f6"),
                fg2: Color(hex: "#f5c9dd"),
                fg3: Color(hex: "#dfa3c0"),
                fg4: Color(hex: "#c97ea3"),
                accent: Color(hex: "#f472b6"),
                accentD: Color(hex: "#ec4899"),
                accentF: Color(hex: "#f472b6", opacity: 0.12),
                good: Color(hex: "#34d399"),
                bad: Color(hex: "#f87171"),
                warn: Color(hex: "#fbbf24"),
                grid: Color(hex: "#f472b6", opacity: 0.04),
                grid2: Color(hex: "#f472b6", opacity: 0.07),
                shadow: Color.black.opacity(0.45)
            )
        }
    }
}
