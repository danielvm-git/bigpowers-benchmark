import AppKit
import SwiftTerm
import SwiftUI

public struct TerminalView: NSViewRepresentable {
    let logLines: [LogLine]

    public class Coordinator: NSObject {
        var fedCount = 0
    }

    public init(logLines: [LogLine]) {
        self.logLines = logLines
    }

    public func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    public func makeNSView(context _: Context) -> SwiftTerm.TerminalView {
        let view = SwiftTerm.TerminalView()
        view.nativeBackgroundColor = NSColor(hex: "#0a0c10")
        view.font = NSFont.monospacedSystemFont(ofSize: 11, weight: .regular)
        return view
    }

    public func updateNSView(_ nsView: SwiftTerm.TerminalView, context: Context) {
        let count = logLines.count
        if count < context.coordinator.fedCount {
            // Logs were cleared/reset
            nsView.feed(text: "\u{001b}[2J\u{001b}[H")
            context.coordinator.fedCount = 0
        }

        if context.coordinator.fedCount < count {
            for i in context.coordinator.fedCount ..< count {
                let line = logLines[i]
                nsView.feed(text: ansiString(for: line))
            }
            context.coordinator.fedCount = count
        }
    }

    private func ansiString(for line: LogLine) -> String {
        let colorCode = switch line.kind {
        case .info: "\u{001b}[0m"
        case .ok: "\u{001b}[32;1m"
        case .warn: "\u{001b}[33;1m"
        case .err: "\u{001b}[31;1m"
        case .cmd: "\u{001b}[36;1m"
        }
        return "\(colorCode)\(line.text)\u{001b}[0m\r\n"
    }
}
