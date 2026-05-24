import AppKit
import SwiftTerm
import SwiftUI

public struct LocalTerminalView: NSViewRepresentable {
    @Environment(DaytonaConfig.self) private var config
    @Environment(ThemeManager.self) private var themeManager

    public init() {}

    @MainActor
    public class Coordinator: NSObject, @preconcurrency LocalProcessTerminalViewDelegate {
        var parent: LocalTerminalView

        init(_ parent: LocalTerminalView) {
            self.parent = parent
        }

        public func sizeChanged(source _: LocalProcessTerminalView, newCols _: Int, newRows _: Int) {
            // Layout dimensions updated
        }

        public func setTerminalTitle(source _: LocalProcessTerminalView, title _: String) {
            // Terminal title updated
        }

        public func hostCurrentDirectoryUpdate(source _: SwiftTerm.TerminalView, directory _: String?) {
            // Working directory updated
        }

        public func processTerminated(source: SwiftTerm.TerminalView, exitCode _: Int32?) {
            // Restart process if terminated
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in
                guard let self else { return }
                if let localView = source as? LocalProcessTerminalView {
                    startShell(in: localView)
                }
            }
        }

        func startShell(in view: LocalProcessTerminalView) {
            var env = ProcessInfo.processInfo.environment.map { "\($0.key)=\($0.value)" }
            env.removeAll { $0.hasPrefix("TERM=") }
            env.append("TERM=xterm-256color")

            if !env.contains(where: { $0.hasPrefix("LANG=") }) {
                env.append("LANG=en_US.UTF-8")
            }

            view.startProcess(
                executable: parent.config.terminalShellPath,
                args: ["-l"],
                environment: env
            )
        }
    }

    public func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    public func makeNSView(context: Context) -> LocalProcessTerminalView {
        let view = LocalProcessTerminalView(frame: .zero)
        view.processDelegate = context.coordinator
        view.disableFullRedrawOnAnyChanges = false

        applySettings(to: view)
        context.coordinator.startShell(in: view)

        DispatchQueue.main.async {
            view.window?.makeFirstResponder(view)
        }

        return view
    }

    public func updateNSView(_ nsView: LocalProcessTerminalView, context: Context) {
        context.coordinator.parent = self
        applySettings(to: nsView)
    }

    private func applySettings(to view: LocalProcessTerminalView) {
        let tokens = themeManager.resolvedTheme.tokens
        let nsBg = NSColor(tokens.bg)
        let nsFg = NSColor(tokens.fg)
        let nsCaret = NSColor(tokens.accent)
        let nsSelection = NSColor(tokens.accentF)

        if view.nativeBackgroundColor != nsBg {
            view.nativeBackgroundColor = nsBg
        }
        if view.nativeForegroundColor != nsFg {
            view.nativeForegroundColor = nsFg
        }
        if view.caretColor != nsCaret {
            view.caretColor = nsCaret
        }
        if view.selectedTextBackgroundColor != nsSelection {
            view.selectedTextBackgroundColor = nsSelection
        }

        if view.optionAsMetaKey != config.terminalOptionAsMeta {
            view.optionAsMetaKey = config.terminalOptionAsMeta
        }
        if view.useBrightColors != config.terminalUseBrightColors {
            view.useBrightColors = config.terminalUseBrightColors
        }

        let fontSize = CGFloat(config.terminalFontSize)
        let systemMonospaced = NSFont.monospacedSystemFont(ofSize: fontSize, weight: .regular)
        let preferredFont = NSFont(name: "Menlo-Regular", size: fontSize) ?? systemMonospaced

        if view.font.pointSize != fontSize || view.font.fontName != preferredFont.fontName {
            view.font = preferredFont
        }
    }
}
