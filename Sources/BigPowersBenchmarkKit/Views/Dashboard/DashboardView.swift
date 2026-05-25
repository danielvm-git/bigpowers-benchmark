import Charts
import SwiftUI

public struct DashboardView: View {
    @Environment(BenchmarkStore.self) private var store
    @Environment(ThemeManager.self) private var themeManager
    @Environment(DashboardViewModel.self) private var vm

    public init() {}

    public var body: some View {
        let tokens = themeManager.resolvedTheme.tokens
        ScrollView {
            VStack(alignment: .leading, spacing: 25) {
                header(tokens: tokens)
                heroCards(tokens: tokens)
                charts(tokens: tokens)
                regressionsSection(tokens: tokens)
                recentRunsSection(tokens: tokens)
            }
            .padding(30)
        }
    }

    private func header(tokens: ThemeTokens) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Dashboard")
                .font(.largeTitle)
                .fontWeight(.bold)
                .foregroundColor(tokens.fg)
            Text("Overall performance metrics and regressions.")
                .foregroundColor(tokens.fg3)
        }
    }

    private func heroCards(tokens: ThemeTokens) -> some View {
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
                value: vm.bestModel?.name ?? "—",
                subvalue: vm.bestModel.map { String(format: "Avg: %.1f", $0.avgScore) } ?? "",
                icon: "crown.fill",
                color: tokens.warn
            )
            .accessibilityLabel("Best Model")
            .accessibilityValue(vm.bestModel?.name ?? "None")

            HeroCard(
                title: "Fastest Model",
                value: vm.fastestModel?.name ?? "—",
                subvalue: vm.fastestModel.map { String(format: "Avg: %.1fs", $0.avgDuration) } ?? "",
                icon: "bolt.fill",
                color: tokens.accent
            )
            .accessibilityLabel("Fastest Model")
            .accessibilityValue(vm.fastestModel?.name ?? "None")

            HeroCard(
                title: "Lowest Cost",
                value: vm.cheapestModel?.name ?? "—",
                subvalue: vm.cheapestModel.map { String(format: "Avg: $%.4f", $0.avgCost) } ?? "",
                icon: "dollarsign.circle.fill",
                color: tokens.good
            )
            .accessibilityLabel("Lowest Cost Model")
            .accessibilityValue(vm.cheapestModel?.name ?? "None")

            HeroCard(
                title: "Most Improved",
                value: vm.mostImproved?.model ?? "—",
                subvalue: vm.mostImproved.map { String(format: "+%.1f pts", $0.delta) } ?? "Need 2+ refs",
                icon: "arrow.up.right.circle.fill",
                color: tokens.accent
            )
            .accessibilityLabel("Most Improved Model")
            .accessibilityValue(vm.mostImproved?.model ?? "None")
        }
    }

    private func charts(tokens: ThemeTokens) -> some View {
        HSplitView {
            scoreEvolutionChart(tokens: tokens)
            heatmapChart(tokens: tokens)
        }
    }

    private func scoreEvolutionChart(tokens: ThemeTokens) -> some View {
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
                .accessibilityLabel("Score evolution chart")
                .accessibilityValue("Shows overall score trends over time per model")
            }
        }
        .frame(minWidth: 400)
        .padding(.trailing, 10)
    }

    private func heatmapChart(tokens: ThemeTokens) -> some View {
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
                    RectangleMark(
                        x: .value("Task", run.taskId),
                        y: .value("Model", run.modelId)
                    )
                    .foregroundStyle(by: .value("Score", run.overallScore))
                }
                .chartForegroundStyleScale(range: Gradient(colors: [tokens.bad, tokens.warn, tokens.good]))
                .frame(height: 250)
                .padding()
                .background(tokens.surface)
                .cornerRadius(8)
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(tokens.border, lineWidth: 1))
                .accessibilityLabel("Model by Task heatmap")
                .accessibilityValue("Shows score distribution across models and tasks")
            }
        }
        .frame(minWidth: 300)
        .padding(.leading, 10)
    }

    private func regressionsSection(tokens: ThemeTokens) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Recent Regressions & Anomalies")
                .font(.headline)
                .foregroundColor(tokens.fg)

            if vm.recentRegressions.isEmpty {
                Text("No regressions detected. Models are operating normally.")
                    .foregroundColor(tokens.good)
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(tokens.good.opacity(0.08))
                    .cornerRadius(8)
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(tokens.good.opacity(0.2), lineWidth: 1))
            } else {
                VStack(spacing: 8) {
                    ForEach(vm.recentRegressions) { reg in
                        HStack {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(tokens.bad)
                            Text("\(reg.model) on \(reg.task): \(String(format: "%.1f", reg.delta)) pts")
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
                        .accessibilityLabel("Regression")
                        .accessibilityValue(
                            "\(reg.model) on task \(reg.task) dropped \(String(format: "%.1f", abs(reg.delta))) points"
                        )
                    }
                }
            }
        }
    }

    private func recentRunsSection(tokens: ThemeTokens) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Recent Runs")
                .font(.headline)
                .foregroundColor(tokens.fg)

            if store.runs.isEmpty {
                Text("No runs yet.")
                    .foregroundColor(tokens.fg3)
                    .padding()
            } else {
                let recent = store.runs
                    .sorted(by: { $0.timestamp > $1.timestamp })
                    .prefix(5)
                VStack(spacing: 6) {
                    ForEach(Array(recent)) { run in
                        HStack {
                            Text(run.modelId)
                                .font(.body)
                                .foregroundColor(tokens.fg)
                            Text(run.taskId)
                                .font(.caption)
                                .foregroundColor(tokens.fg3)
                            Spacer()
                            Text(String(format: "%.1f", run.overallScore))
                                .font(.body.monospacedDigit())
                                .foregroundColor(tokens.accent)
                        }
                        .padding(.horizontal)
                        .padding(.vertical, 6)
                        .background(tokens.surface)
                        .cornerRadius(6)
                        .accessibilityLabel("Run \(run.modelId) \(run.taskId)")
                        .accessibilityValue("Score: \(String(format: "%.1f", run.overallScore))")
                    }
                }
            }
        }
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
