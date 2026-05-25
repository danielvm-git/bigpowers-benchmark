import SwiftUI

public struct MenuBarContent: View {
    @Environment(BenchmarkStore.self) private var store
    @Environment(ThemeManager.self) private var themeManager

    public init() {}

    public var body: some View {
        let tokens = themeManager.resolvedTheme.tokens
        VStack(alignment: .leading, spacing: 10) {
            Text("BigPowers Benchmark")
                .font(.headline)
                .foregroundColor(tokens.fg)

            Divider()

            if let currentRun = store.currentRun {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("Active Task:")
                            .fontWeight(.bold)
                        Text(currentRun.taskId)
                    }
                    HStack {
                        Text("Elapsed:")
                            .fontWeight(.bold)
                        Text(formatDuration(currentRun.elapsed))
                    }
                    ProgressView()
                        .progressViewStyle(.linear)
                }
                .font(.caption)
                .foregroundColor(tokens.fg)
            } else {
                Text("Idle")
                    .font(.caption)
                    .foregroundColor(tokens.fg3)
            }

            Divider()

            Text("Completed Runs: \(store.runs.count)")
                .font(.caption)
                .foregroundColor(tokens.fg)
        }
        .padding(12)
        .frame(minWidth: 200)
        .background(tokens.bg1)
    }

    private func formatDuration(_ duration: TimeInterval) -> String {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.minute, .second]
        formatter.unitsStyle = .positional
        formatter.zeroFormattingBehavior = .pad
        return formatter.string(from: duration) ?? "00:00"
    }
}
