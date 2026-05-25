import SwiftUI

struct BenchSuitabilityBadge: View {
    let suitability: BenchmarkSuitability
    let tokens: ThemeTokens

    var body: some View {
        Text(label)
            .font(.caption2)
            .fontWeight(.semibold)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(color.opacity(0.15))
            .foregroundColor(color)
            .clipShape(Capsule())
            .help(tooltip)
            .accessibilityLabel(accessibilityLabel)
    }

    private var label: String {
        switch suitability {
        case .recommended: "✓ Bench"
        case .limited: "~ Limited"
        case .notSuitable: "✗ No"
        }
    }

    private var color: Color {
        switch suitability {
        case .recommended: tokens.good
        case .limited: tokens.warn
        case .notSuitable: tokens.bad
        }
    }

    private var tooltip: String {
        switch suitability {
        case .recommended:
            "Rsp · Match · Clear · Tools · Context ≥ 32K — ready to benchmark"
        case .limited:
            "Missing tools or context window — may underperform"
        case .notSuitable:
            "Not responding or filtered — cannot benchmark"
        }
    }

    private var accessibilityLabel: String {
        switch suitability {
        case .recommended: "Recommended for benchmark"
        case .limited: "Limited benchmark suitability"
        case .notSuitable: "Not suitable for benchmark"
        }
    }
}

struct SignalCell: View {
    let pass: Bool
    let tooltip: String
    let tokens: ThemeTokens

    var body: some View {
        Image(systemName: pass ? "checkmark.circle.fill" : "xmark.circle.fill")
            .foregroundColor(pass ? tokens.good : tokens.bad)
            .help(tooltip)
            .accessibilityLabel(pass ? "Pass: \(tooltip)" : "Fail: \(tooltip)")
    }
}

struct LatencyRaceBar: View {
    let p50: Double
    let maxP50: Double
    let tokens: ThemeTokens

    var body: some View {
        GeometryReader { geometry in
            let width = maxP50 > 0 ? geometry.size.width * (p50 / maxP50) : 0
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 3)
                    .fill(tokens.grid)
                    .frame(height: 8)
                RoundedRectangle(cornerRadius: 3)
                    .fill(tokens.accent)
                    .frame(width: max(width, p50 > 0 ? 4 : 0), height: 8)
            }
        }
        .frame(height: 12)
    }
}

struct LatencyCell: View {
    let p50: Double
    let maxP50: Double
    let tokens: ThemeTokens

    var body: some View {
        HStack(spacing: 8) {
            LatencyRaceBar(p50: p50, maxP50: maxP50, tokens: tokens)
                .frame(maxWidth: 120)
            Text(p50 > 0 ? "\(Int(p50))ms" : "—")
                .font(.caption)
                .foregroundColor(tokens.fg2)
                .monospacedDigit()
        }
        .accessibilityLabel(p50 > 0 ? "Latency \(Int(p50)) milliseconds" : "No latency data")
    }
}

public struct ModelHealthTableRow: Identifiable {
    public let id: String
    public let label: String
    public let rank: Int?
    public let p50: Double
    public let cost: Double
    public let reasoningTokens: Int
    public let responded: Bool
    public let modelMatched: Bool
    public let notContentFiltered: Bool
    public let hasTools: Bool
    public let isFree: Bool
    public let hasContext: Bool
    public let suitability: BenchmarkSuitability

    public init(
        id: String,
        label: String,
        rank: Int?,
        p50: Double,
        cost: Double,
        reasoningTokens: Int,
        responded: Bool,
        modelMatched: Bool,
        notContentFiltered: Bool,
        hasTools: Bool,
        isFree: Bool,
        hasContext: Bool,
        suitability: BenchmarkSuitability
    ) {
        self.id = id
        self.label = label
        self.rank = rank
        self.p50 = p50
        self.cost = cost
        self.reasoningTokens = reasoningTokens
        self.responded = responded
        self.modelMatched = modelMatched
        self.notContentFiltered = notContentFiltered
        self.hasTools = hasTools
        self.isFree = isFree
        self.hasContext = hasContext
        self.suitability = suitability
    }
}
