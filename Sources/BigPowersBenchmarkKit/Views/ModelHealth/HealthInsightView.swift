// swiftlint:disable type_body_length
import Charts
import SwiftUI

private struct LatencyChartPoint: Identifiable {
    let id: String
    let label: String
    let p50: Double
    let suitability: BenchmarkSuitability
}

private struct ReliabilityPoint: Identifiable {
    let id: String
    let timestamp: Date
    let provider: String
    let livePercent: Double
}

private struct BenchScatterPoint: Identifiable {
    let id: String
    let label: String
    let provider: String
    let p50: Double
    let benchScore: Double
}

private struct ProviderSummary: Identifiable {
    let id: String
    let name: String
    let liveCount: Int
    let totalCount: Int
    let averageP50: Double

    var livePercent: Double {
        guard totalCount > 0 else { return 0 }
        return Double(liveCount) / Double(totalCount) * 100
    }
}

public struct HealthInsightView: View {
    @Environment(ModelIntelStore.self) private var intelStore
    @Environment(ModelHealthHistoryStore.self) private var historyStore
    @Environment(BenchmarkStore.self) private var store
    @Environment(ModelRegistry.self) private var registry
    @Environment(ThemeManager.self) private var themeManager

    public init() {}

    public var body: some View {
        let tokens = themeManager.resolvedTheme.tokens
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                header(tokens: tokens)
                recommendationSection(tokens: tokens)
                latencySection(tokens: tokens)
                reliabilitySection(tokens: tokens)
                scatterSection(tokens: tokens)
                providerSummarySection(tokens: tokens)
            }
            .padding(30)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(tokens.bg)
        .task {
            try? historyStore.loadAll()
        }
    }

    private func header(tokens: ThemeTokens) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Health Insight")
                .font(.largeTitle)
                .fontWeight(.bold)
                .foregroundColor(tokens.fg)
            Text("Analysis and recommendations to help you choose the best benchmark model.")
                .foregroundColor(tokens.fg3)
        }
    }

    private func recommendationSection(tokens: ThemeTokens) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Best Bench Candidate")
                .font(.headline)
                .foregroundColor(tokens.fg)

            if let candidate = bestBenchCandidate {
                recommendationCard(for: candidate, tokens: tokens)
            } else {
                ThemedInlineEmpty(
                    icon: "star.circle",
                    title: "No bench candidates yet — run pings in Model Health first.",
                    tokens: tokens
                )
                .frame(maxWidth: .infinity)
            }
        }
    }

    @ViewBuilder
    private func recommendationCard(for model: ModelInfo, tokens: ThemeTokens) -> some View {
        let profile = intelStore.profile(for: model.id)
        let provider = profile?.testedProviderLabel
            ?? ModelHealthSubscriptionProvider.displayName(for: model.provider)
        let benchScore = profile?.lastBenchScore
            ?? store.runs.filter { $0.modelId == model.id }.max(by: { $0.timestamp < $1.timestamp })?.overallScore

        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(model.name)
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(tokens.fg)
                    Text(model.apiModelId)
                        .font(.caption)
                        .foregroundColor(tokens.fg4)
                }
                Spacer()
                HStack(spacing: 8) {
                    HealthProviderBadge(label: provider, tokens: tokens)
                    Text(model.isFreeModel ? "Free" : "Paid")
                        .font(.caption2)
                        .fontWeight(.semibold)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background((model.isFreeModel ? tokens.good : tokens.warn).opacity(0.15))
                        .foregroundColor(model.isFreeModel ? tokens.good : tokens.warn)
                        .clipShape(Capsule())
                }
            }

            HStack(spacing: 20) {
                metricBlock(
                    title: "Latency",
                    value: profile.map { "\(Int($0.lastP50))ms" } ?? "—",
                    tokens: tokens
                )
                metricBlock(
                    title: "Bench Score",
                    value: benchScore.map { String(format: "%.0f", $0) } ?? "—",
                    tokens: tokens
                )
                metricBlock(
                    title: "Cost",
                    value: profile.map { String(format: "$%.4f", $0.lastMeasuredCost) } ?? "—",
                    tokens: tokens
                )
            }

            HStack(spacing: 10) {
                if let profile {
                    SignalCell(pass: profile.lastPingStatus == "live", tooltip: "Responded", tokens: tokens)
                    SignalCell(pass: profile.modelMatched, tooltip: "Model matched", tokens: tokens)
                    SignalCell(pass: profile.notContentFiltered, tooltip: "Not filtered", tokens: tokens)
                    SignalCell(pass: profile.hasTools, tooltip: "Tools", tokens: tokens)
                    SignalCell(pass: profile.hasContext, tooltip: "Context", tokens: tokens)
                }
            }
        }
        .padding(20)
        .background(tokens.surface)
        .cornerRadius(12)
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(tokens.border, lineWidth: 1))
    }

    @ViewBuilder
    private func latencySection(tokens: ThemeTokens) -> some View {
        sectionHeader("Latency Distribution", tokens: tokens)
        let points = latencyChartPoints
        if points.isEmpty {
            inlineEmpty("No latency data", tokens: tokens)
        } else {
            Chart(points) { point in
                BarMark(
                    x: .value("Latency", point.p50),
                    y: .value("Model", point.label)
                )
                .foregroundStyle(suitabilityColor(point.suitability, tokens: tokens))
            }
            .chartYAxis {
                AxisMarks { _ in
                    AxisValueLabel()
                        .font(.caption2)
                }
            }
            .frame(height: min(CGFloat(points.count) * 28 + 40, 560))
            .padding()
            .background(tokens.surface)
            .cornerRadius(12)
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(tokens.border, lineWidth: 1))
        }
    }

    @ViewBuilder
    private func reliabilitySection(tokens: ThemeTokens) -> some View {
        sectionHeader("Reliability Over Time", tokens: tokens)
        let points = reliabilityPoints
        if points.count < 2 {
            inlineEmpty("Need at least two ping snapshots", tokens: tokens)
        } else {
            Chart(points) { point in
                LineMark(
                    x: .value("Time", point.timestamp),
                    y: .value("Live %", point.livePercent)
                )
                .foregroundStyle(by: .value("Provider", point.provider))
                .symbol(Circle())
            }
            .chartYScale(domain: 0 ... 100)
            .frame(height: 280)
            .padding()
            .background(tokens.surface)
            .cornerRadius(12)
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(tokens.border, lineWidth: 1))
        }
    }

    @ViewBuilder
    private func scatterSection(tokens: ThemeTokens) -> some View {
        sectionHeader("Bench Score vs Latency", tokens: tokens)
        let points = scatterPoints
        if points.isEmpty {
            inlineEmpty("No models with both ping and bench data", tokens: tokens)
        } else {
            Chart(points) { point in
                PointMark(
                    x: .value("Latency", point.p50),
                    y: .value("Bench Score", point.benchScore)
                )
                .foregroundStyle(by: .value("Provider", point.provider))
            }
            .frame(height: 280)
            .padding()
            .background(tokens.surface)
            .cornerRadius(12)
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(tokens.border, lineWidth: 1))
        }
    }

    @ViewBuilder
    private func providerSummarySection(tokens: ThemeTokens) -> some View {
        sectionHeader("Provider Health Summary", tokens: tokens)
        let summaries = providerSummaries
        if summaries.isEmpty {
            inlineEmpty("No provider data", tokens: tokens)
        } else {
            LazyVGrid(
                columns: [GridItem(.adaptive(minimum: 220), spacing: 12)],
                spacing: 12
            ) {
                ForEach(summaries) { summary in
                    providerCard(summary, tokens: tokens)
                }
            }
        }
    }

    private func providerCard(_ summary: ProviderSummary, tokens: ThemeTokens) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(summary.name)
                .font(.headline)
                .foregroundColor(tokens.fg)
            Text("\(summary.liveCount)/\(summary.totalCount) live · \(Int(summary.livePercent))%")
                .font(.caption)
                .foregroundColor(tokens.fg3)
            Text("Avg latency \(summary.averageP50 > 0 ? "\(Int(summary.averageP50))ms" : "—")")
                .font(.caption)
                .foregroundColor(tokens.fg4)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(tokens.surface)
        .cornerRadius(10)
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(tokens.border, lineWidth: 1))
    }

    private func sectionHeader(_ title: String, tokens: ThemeTokens) -> some View {
        Text(title)
            .font(.headline)
            .foregroundColor(tokens.fg)
    }

    private func inlineEmpty(_ title: String, tokens: ThemeTokens) -> some View {
        ThemedInlineEmpty(icon: "chart.bar", title: title, tokens: tokens)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 24)
            .background(tokens.surface)
            .cornerRadius(12)
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(tokens.border, lineWidth: 1))
    }

    private func metricBlock(title: String, value: String, tokens: ThemeTokens) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.caption)
                .foregroundColor(tokens.fg4)
            Text(value)
                .font(.title3)
                .fontWeight(.semibold)
                .foregroundColor(tokens.fg)
        }
    }

    private var bestBenchCandidate: ModelInfo? {
        let candidates = intelStore.benchCandidateModels(from: registry.models)
        guard !candidates.isEmpty else { return nil }
        return candidates.min { lhs, rhs in
            let lhsP50 = intelStore.profile(for: lhs.id)?.lastP50 ?? .infinity
            let rhsP50 = intelStore.profile(for: rhs.id)?.lastP50 ?? .infinity
            return lhsP50 < rhsP50
        }
    }

    private var latencyChartPoints: [LatencyChartPoint] {
        intelStore.profiles.values
            .filter { $0.lastP50 > 0 }
            .sorted { $0.lastP50 < $1.lastP50 }
            .prefix(20)
            .map { profile in
                let suitability: BenchmarkSuitability = if profile.benchCandidate {
                    .recommended
                } else if profile.lastPingStatus == ModelHealthSnapshot.statusString(.live) {
                    .limited
                } else {
                    .notSuitable
                }
                return LatencyChartPoint(
                    id: profile.modelId,
                    label: profile.label,
                    p50: profile.lastP50,
                    suitability: suitability
                )
            }
    }

    private var reliabilityPoints: [ReliabilityPoint] {
        let snapshots = historyStore.snapshots.prefix(20).reversed()
        var points: [ReliabilityPoint] = []
        for snapshot in snapshots {
            let grouped = Dictionary(grouping: snapshot.rows) { row in
                providerLabel(for: row.pingTransport, fallback: row.testedProviderLabel)
            }
            for (provider, rows) in grouped {
                guard !rows.isEmpty else { continue }
                let liveCount = rows.filter { $0.status == "live" }.count
                let percent = Double(liveCount) / Double(rows.count) * 100
                points.append(
                    ReliabilityPoint(
                        id: "\(snapshot.id.uuidString)-\(provider)",
                        timestamp: snapshot.timestamp,
                        provider: provider,
                        livePercent: percent
                    )
                )
            }
        }
        return points
    }

    private var scatterPoints: [BenchScatterPoint] {
        intelStore.profiles.values.compactMap { profile in
            guard profile.lastP50 > 0, let benchScore = profile.lastBenchScore else { return nil }
            return BenchScatterPoint(
                id: profile.modelId,
                label: profile.label,
                provider: providerLabel(for: profile.pingTransport, fallback: profile.testedProviderLabel),
                p50: profile.lastP50,
                benchScore: benchScore
            )
        }
    }

    private var providerSummaries: [ProviderSummary] {
        let grouped = Dictionary(grouping: intelStore.profiles.values) { profile in
            providerLabel(for: profile.pingTransport, fallback: profile.testedProviderLabel)
        }
        return grouped.map { name, profiles in
            let live = profiles.filter { $0.lastPingStatus == ModelHealthSnapshot.statusString(.live) }
            let withLatency = profiles.filter { $0.lastP50 > 0 }
            let average = withLatency.isEmpty
                ? 0
                : withLatency.map(\.lastP50).reduce(0, +) / Double(withLatency.count)
            return ProviderSummary(
                id: name,
                name: name,
                liveCount: live.count,
                totalCount: profiles.count,
                averageP50: average
            )
        }
        .sorted { $0.name < $1.name }
    }

    private func providerLabel(for pingTransport: String?, fallback: String?) -> String {
        if let fallback, !fallback.isEmpty { return fallback }
        if let raw = pingTransport, let transport = PingTransport(rawValue: raw) {
            return transport.channelDisplayName
        }
        return pingTransport ?? "Unknown"
    }

    private func suitabilityColor(_ suitability: BenchmarkSuitability, tokens: ThemeTokens) -> Color {
        switch suitability {
        case .recommended: tokens.good
        case .limited: tokens.warn
        case .notSuitable: tokens.bad
        }
    }
}
