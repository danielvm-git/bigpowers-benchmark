import SwiftUI

public struct TaskResult: Identifiable, Sendable, Equatable {
    public let id: String
    public let name: String
    public var status: TaskStatus
    public var duration: TimeInterval?
    public var cost: Double?
    public var overallScore: Double?
    public var delta: Double?

    public init(
        id: String,
        name: String,
        status: TaskStatus,
        duration: TimeInterval? = nil,
        cost: Double? = nil,
        overallScore: Double? = nil,
        delta: Double? = nil
    ) {
        self.id = id
        self.name = name
        self.status = status
        self.duration = duration
        self.cost = cost
        self.overallScore = overallScore
        self.delta = delta
    }
}

public enum TaskStatus: String, Sendable, Equatable {
    case pending
    case active
    case complete
    case fail
}

public enum HistoricalRange: String, CaseIterable, Sendable, Hashable {
    case last5 = "Last 5"
    case last10 = "Last 10"
    case all = "All"
}

public enum ConnectionTestResult: Equatable, Sendable {
    case ok
    case failed(String)
}

struct DeltaBadge: View {
    let delta: Double?
    let tokens: ThemeTokens

    var body: some View {
        if let delta {
            Text(badgeLabel(for: delta))
                .font(.caption2.weight(.medium))
                .foregroundColor(badgeColor(for: delta))
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(badgeColor(for: delta).opacity(0.12))
                .clipShape(Capsule())
                .accessibilityLabel("Delta \(String(format: "%+.2f", delta))")
        } else {
            Text("—")
                .font(.caption.monospaced())
                .foregroundColor(tokens.fg4)
        }
    }

    private func badgeLabel(for delta: Double) -> String {
        let formatted = String(format: "%+.2f", delta)
        if delta > 0.001 {
            return "↑ \(formatted)"
        }
        if delta < -0.001 {
            return "↓ \(formatted)"
        }
        return "→ 0"
    }

    private func badgeColor(for delta: Double) -> Color {
        if delta > 0.001 { return tokens.good }
        if delta < -0.001 { return tokens.bad }
        return tokens.fg3
    }
}
