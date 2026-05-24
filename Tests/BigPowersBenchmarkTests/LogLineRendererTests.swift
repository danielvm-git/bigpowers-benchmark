import AppKit
@testable import BigPowersBenchmarkKit
import Testing

@Suite("LogLineRenderer")
struct LogLineRendererTests {
    let renderer = LogLineRenderer()

    @Test("LogKind maps to correct NSColor")
    func colorMapping() {
        #expect(renderer.color(for: .info) == NSColor(hex: "#c9d1d9"))
        #expect(renderer.color(for: .ok) == NSColor(hex: "#2dd4bf"))
        #expect(renderer.color(for: .warn) == NSColor(hex: "#fb923c"))
        #expect(renderer.color(for: .err) == NSColor(hex: "#f87171"))
        #expect(renderer.color(for: .cmd) == NSColor(hex: "#818cf8"))
    }
}

extension NSColor {
    convenience init(hex: String) {
        var hexSanitized = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        hexSanitized = hexSanitized.replacingOccurrences(of: "#", with: "")

        var rgb: UInt64 = 0
        Scanner(string: hexSanitized).scanHexInt64(&rgb)

        let r = CGFloat((rgb & 0xFF0000) >> 16) / 255.0
        let g = CGFloat((rgb & 0x00FF00) >> 8) / 255.0
        let b = CGFloat(rgb & 0x0000FF) / 255.0

        self.init(red: r, green: g, blue: b, alpha: 1.0)
    }
}
