import SwiftUI

struct TaskStepperView: View {
    let taskResults: [TaskResult]
    let elapsedTime: TimeInterval
    let elapsedCost: Double
    let isRunning: Bool
    let tokens: ThemeTokens

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var pulse = false

    var body: some View {
        HStack(spacing: 8) {
            ForEach(Array(taskResults.enumerated()), id: \.element.id) { index, task in
                if index > 0 {
                    StepperConnector(
                        isComplete: taskResults[index - 1].status == .complete,
                        tokens: tokens
                    )
                }

                StepperNodeView(
                    task: task,
                    tokens: tokens,
                    pulse: pulse && task.status == .active,
                    reduceMotion: reduceMotion
                )
            }

            Spacer(minLength: 16)

            VStack(alignment: .trailing, spacing: 4) {
                Text(formatDuration(elapsedTime))
                    .font(.caption.monospacedDigit())
                    .foregroundColor(isRunning ? tokens.accent : tokens.fg3)
                    .fontWeight(isRunning ? .semibold : .regular)
                    .accessibilityLabel("Elapsed \(formatDuration(elapsedTime))")

                Text(formatCost(elapsedCost))
                    .font(.caption.monospacedDigit())
                    .foregroundColor(tokens.fg3)
                    .accessibilityLabel("Cost \(formatCost(elapsedCost))")
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 24)
        .background(tokens.surface)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(tokens.border, lineWidth: 1))
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(.easeInOut(duration: 2).repeatForever(autoreverses: true)) {
                pulse = true
            }
        }
    }

    private func formatDuration(_ duration: TimeInterval) -> String {
        guard duration > 0 else { return "0s" }
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = duration >= 60 ? [.minute, .second] : [.second]
        formatter.unitsStyle = .abbreviated
        formatter.zeroFormattingBehavior = .pad
        return formatter.string(from: duration) ?? "0s"
    }

    private func formatCost(_ cost: Double) -> String {
        guard cost > 0 else { return "$0.00" }
        return String(format: "$%.2f", cost)
    }
}

private struct StepperConnector: View {
    let isComplete: Bool
    let tokens: ThemeTokens

    var body: some View {
        Rectangle()
            .fill(isComplete ? tokens.good : tokens.border)
            .frame(width: 32, height: 2)
    }
}

private struct StepperNodeView: View {
    let task: TaskResult
    let tokens: ThemeTokens
    let pulse: Bool
    let reduceMotion: Bool

    var body: some View {
        VStack(spacing: 4) {
            Text(task.id)
                .font(.system(size: 9, weight: .semibold, design: .monospaced))
                .foregroundColor(tokens.fg3)

            ZStack {
                Circle()
                    .strokeBorder(borderColor, lineWidth: 2)
                    .background(Circle().fill(backgroundColor))
                    .frame(width: 40, height: 40)
                    .shadow(
                        color: pulse ? tokens.accent.opacity(0.35) : .clear,
                        radius: pulse ? 8 : 0
                    )

                Text(symbol)
                    .font(.system(size: 11, weight: .semibold, design: .monospaced))
                    .foregroundColor(foregroundColor)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(task.id) \(task.status.rawValue)")
    }

    private var symbol: String {
        switch task.status {
        case .complete: "✓"
        case .active: "●"
        case .pending: "○"
        case .fail: "✗"
        }
    }

    private var borderColor: Color {
        switch task.status {
        case .complete: tokens.good
        case .active: tokens.accent
        case .pending: tokens.border
        case .fail: tokens.bad
        }
    }

    private var backgroundColor: Color {
        switch task.status {
        case .complete: tokens.good.opacity(0.12)
        case .active: tokens.accentF
        case .pending: tokens.surface2
        case .fail: tokens.bad.opacity(0.12)
        }
    }

    private var foregroundColor: Color {
        switch task.status {
        case .complete: tokens.good
        case .active: tokens.accent
        case .pending: tokens.fg4
        case .fail: tokens.bad
        }
    }
}
