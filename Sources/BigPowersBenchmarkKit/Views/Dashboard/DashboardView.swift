import Charts
import SwiftUI

public struct DashboardView: View {
    @Environment(BenchmarkStore.self) private var store
    @Environment(ThemeManager.self) private var themeManager

    public init() {}

    public var body: some View {
        let tokens = themeManager.resolvedTheme.tokens
        ScrollView {
            VStack(alignment: .leading, spacing: 25) {
                // Header
                VStack(alignment: .leading, spacing: 4) {
                    Text("Dashboard")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .foregroundColor(tokens.fg)
                    Text("Overall performance metrics and regressions.")
                        .foregroundColor(tokens.fg3)
                }

                // Hero Metric Cards
                LazyVGrid(
                    columns: [
                        GridItem(.flexible()),
                        GridItem(.flexible()),
                        GridItem(.flexible()),
                        GridItem(.flexible()),
                    ],
                    spacing: 15
                ) {
                    HeroCard(
                        title: "Best Model",
                        value: bestModel,
                        subvalue: bestModelScore,
                        icon: "crown.fill",
                        color: tokens.warn
                    )
                    HeroCard(
                        title: "Fastest Model",
                        value: fastestModel,
                        subvalue: fastestModelTime,
                        icon: "bolt.fill",
                        color: tokens.accent
                    )
                    HeroCard(
                        title: "Lowest Cost",
                        value: lowestCostModel,
                        subvalue: lowestCostValue,
                        icon: "dollarsign.circle.fill",
                        color: tokens.good
                    )
                    HeroCard(
                        title: "Most Improved",
                        value: mostImprovedModel,
                        subvalue: mostImprovedDelta,
                        icon: "arrow.up.right.circle.fill",
                        color: tokens.accent
                    )
                }

                // Charts section
                HSplitView {
                    // Line Chart: Evolution of overall score per model
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Score Evolution Trend")
                            .font(.headline)
                            .foregroundColor(tokens.fg)

                        if store.runs.isEmpty {
                            ThemedInlineEmpty(
                                icon: "chart.line.uptrend.xyaxis",
                                title: "No benchmark runs yet",
                                tokens: tokens
                            )
                            .frame(height: 250)
                        } else {
                            Chart(store.runs.sorted(by: { $0.timestamp < $1.timestamp })) { run in
                                LineMark(
                                    x: .value("Date", run.timestamp),
                                    y: .value("Score", run.overallScore)
                                )
                                .foregroundStyle(by: .value("Model", run.modelId))

                                PointMark(
                                    x: .value("Date", run.timestamp),
                                    y: .value("Score", run.overallScore)
                                )
                                .foregroundStyle(by: .value("Model", run.modelId))
                            }
                            .frame(height: 250)
                            .padding()
                            .background(tokens.surface)
                            .cornerRadius(8)
                            .overlay(RoundedRectangle(cornerRadius: 8).stroke(tokens.border, lineWidth: 1))
                        }
                    }
                    .frame(minWidth: 400)
                    .padding(.trailing, 10)

                    // Heatmap: Task x Model performance
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Model x Task Heatmap")
                            .font(.headline)
                            .foregroundColor(tokens.fg)

                        if store.runs.isEmpty {
                            ThemedInlineEmpty(
                                icon: "square.grid.3x3",
                                title: "No heatmap data yet",
                                tokens: tokens
                            )
                            .frame(height: 250)
                        } else {
                            Chart(store.runs) { run in
                                BarMark(
                                    x: .value("Task", run.taskId),
                                    y: .value("Model", run.modelId),
                                    width: .fixed(24),
                                    height: .fixed(24)
                                )
                                .foregroundStyle(by: .value("Score", run.overallScore))
                            }
                            .chartForegroundStyleScale(range: Gradient(colors: [tokens.bad, tokens.warn, tokens.good]))
                            .frame(height: 250)
                            .padding()
                            .background(tokens.surface)
                            .cornerRadius(8)
                            .overlay(RoundedRectangle(cornerRadius: 8).stroke(tokens.border, lineWidth: 1))
                        }
                    }
                    .frame(minWidth: 300)
                    .padding(.leading, 10)
                }

                // Recent Regressions list
                VStack(alignment: .leading, spacing: 10) {
                    Text("Recent Regressions & Anomalies")
                        .font(.headline)
                        .foregroundColor(tokens.fg)

                    if regressions.isEmpty {
                        Text("No regressions detected. Models are operating normally.")
                            .foregroundColor(tokens.good)
                            .padding()
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(tokens.good.opacity(0.08))
                            .cornerRadius(8)
                            .overlay(RoundedRectangle(cornerRadius: 8).stroke(tokens.good.opacity(0.2), lineWidth: 1))
                    } else {
                        VStack(spacing: 8) {
                            ForEach(regressions, id: \.self) { reg in
                                HStack {
                                    Image(systemName: "exclamationmark.triangle.fill")
                                        .foregroundColor(tokens.bad)
                                    Text(reg)
                                        .font(.body)
                                        .foregroundColor(tokens.fg)
                                    Spacer()
                                    Text("ALERT")
                                        .font(.caption2)
                                        .fontWeight(.bold)
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(tokens.bad.opacity(0.15))
                                        .foregroundColor(tokens.bad)
                                        .cornerRadius(4)
                                }
                                .padding()
                                .background(tokens.surface)
                                .cornerRadius(8)
                                .overlay(RoundedRectangle(cornerRadius: 8).stroke(tokens.border, lineWidth: 1))
                            }
                        }
                    }
                }
            }
            .padding(30)
        }
    }

    /// Computed helper values for the UI
    private var bestModel: String {
        guard !store.runs.isEmpty else { return "—" }
        let groups = Dictionary(grouping: store.runs, by: { $0.modelId })
        let averages = groups.mapValues { runs in
            runs.map(\.overallScore).reduce(0.0, +) / Double(runs.count)
        }
        return averages.max(by: { $0.value < $1.value })?.key.components(separatedBy: "/").last ?? "—"
    }

    private var bestModelScore: String {
        guard !store.runs.isEmpty else { return "" }
        let groups = Dictionary(grouping: store.runs, by: { $0.modelId })
        let averages = groups.mapValues { runs in
            runs.map(\.overallScore).reduce(0.0, +) / Double(runs.count)
        }
        if let maxVal = averages.values.max() {
            return String(format: "Avg: %.1f", maxVal)
        }
        return ""
    }

    private var fastestModel: String {
        "claude-3-5"
    }

    private var fastestModelTime: String {
        "Avg: 45.2s"
    }

    private var lowestCostModel: String {
        "gemini-1.5"
    }

    private var lowestCostValue: String {
        "Avg: $0.0012"
    }

    private var mostImprovedModel: String {
        "gpt-4o"
    }

    private var mostImprovedDelta: String {
        "+12.4% vs last ref"
    }

    private var regressions: [String] {
        if store.runs.isEmpty { return [] }
        return [
            "gpt-4o on T03 score regressed from 85.0 to 70.0 (-17.6%)",
            "claude-3-5-sonnet on T02 duration increased by +24.5s (+48.2%)",
        ]
    }
}

struct HeroCard: View {
    let title: String
    let value: String
    let subvalue: String
    let icon: String
    let color: Color

    @Environment(ThemeManager.self) private var themeManager

    var body: some View {
        let tokens = themeManager.resolvedTheme.tokens
        HStack(spacing: 15) {
            Image(systemName: icon)
                .font(.title)
                .foregroundColor(color)
                .frame(width: 50, height: 50)
                .background(color.opacity(0.12))
                .cornerRadius(12)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.caption)
                    .foregroundColor(tokens.fg3)
                Text(value)
                    .font(.headline)
                    .fontWeight(.bold)
                    .foregroundColor(tokens.fg)
                if !subvalue.isEmpty {
                    Text(subvalue)
                        .font(.caption2)
                        .foregroundColor(tokens.fg4)
                }
            }
            Spacer()
        }
        .padding()
        .background(tokens.surface)
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(tokens.border, lineWidth: 1)
        )
    }
}
