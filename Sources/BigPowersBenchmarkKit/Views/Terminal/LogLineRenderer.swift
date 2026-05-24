import AppKit

public struct LogLineRenderer {
    public init() {}

    public func color(for kind: LogKind) -> NSColor {
        switch kind {
        case .info: NSColor(hex: "#c9d1d9")
        case .ok: NSColor(hex: "#2dd4bf")
        case .warn: NSColor(hex: "#fb923c")
        case .err: NSColor(hex: "#f87171")
        case .cmd: NSColor(hex: "#818cf8")
        }
    }

    public func attributedString(for line: LogLine) -> NSAttributedString {
        let color = color(for: line.kind)
        let font = NSFont.monospacedSystemFont(ofSize: 11, weight: .regular)

        let attributes: [NSAttributedString.Key: Any] = [
            .foregroundColor: color,
            .font: font,
        ]

        return NSAttributedString(string: line.text + "\n", attributes: attributes)
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
