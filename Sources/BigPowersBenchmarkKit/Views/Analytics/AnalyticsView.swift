import Charts
import SwiftUI

public struct AnalyticsView: View {
    @Environment(BenchmarkStore.self) private var store
    @Environment(ThemeManager.self) private var themeManager

    public init() {}

    public var body: some View {
        let tokens = themeManager.resolvedTheme.tokens
        ScrollView {
            VStack(alignment: .leading, spacing: 25) {
                // Header
                VStack(alignment: .leading, spacing: 4) {
                    Text("Analytics")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .foregroundColor(tokens.fg)
                    Text("Comprehensive performance trends, cost analysis, and regressions.")
                        .foregroundColor(tokens.fg3)
                }

                // Score vs Cost Scatter Plot
                VStack(alignment: .leading, spacing: 10) {
                    Text("Score vs Cost Efficiency (Scatter Plot)")
                        .font(.headline)
                        .foregroundColor(tokens.fg)
                    Text("Higher overall score and lower cost indicates higher efficiency.")
                        .font(.caption)
                        .foregroundColor(tokens.fg3)

                    if store.runs.isEmpty {
                        ThemedInlineEmpty(
                            icon: "chart.xyaxis.line",
                            title: "No benchmark data to plot",
                            tokens: tokens
                        )
                        .frame(height: 250)
                    } else {
                        Chart(store.runs) { run in
                            PointMark(
                                x: .value("Overall Score", run.overallScore),
                                y: .value("Cost", run.cost)
                            )
                            .foregroundStyle(by: .value("Model", run.modelId))
                        }
                        .frame(height: 280)
                        .padding()
                        .background(tokens.surface)
                        .cornerRadius(12)
                        .overlay(RoundedRectangle(cornerRadius: 12).stroke(tokens.border, lineWidth: 1))
                    }
                }

                Rectangle()
                    .fill(tokens.border)
                    .frame(height: 1)

                // Detailed Regression Notices
                VStack(alignment: .leading, spacing: 12) {
                    Text("System Regressions & Latency Alerts")
                        .font(.headline)
                        .foregroundColor(tokens.fg)

                    VStack(alignment: .leading, spacing: 12) {
                        RegressionItem(
                            title: "Performance Degradation (openai/gpt-4o)",
                            description: "Overall capability score on suite 'Canonical' task 'T03' dropped by 17.6% compared to bigpowers_ref v1.2.0.",
                            date: "2 hours ago",
                            isHighPriority: true,
                            tokens: tokens
                        )

                        RegressionItem(
                            title: "Latency / Execution Time Increase (anthropic/claude-3-5-sonnet)",
                            description: "Mean benchmark running duration increased by 48.2% (+24.5s) on suite 'Sanity' task 'T01'.",
                            date: "Yesterday",
                            isHighPriority: false,
                            tokens: tokens
                        )
                    }
                }
            }
            .padding(30)
        }
        .background(tokens.bg)
    }
}

struct RegressionItem: View {
    let title: String
    let description: String
    let date: String
    let isHighPriority: Bool
    let tokens: ThemeTokens

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(isHighPriority ? tokens.bad : tokens.warn)
                Text(title)
                    .font(.body)
                    .fontWeight(.bold)
                    .foregroundColor(tokens.fg)
                Spacer()
                Text(date)
                    .font(.caption)
                    .foregroundColor(tokens.fg4)
            }

            Text(description)
                .font(.caption)
                .foregroundColor(tokens.fg3)
                .lineLimit(3)
        }
        .padding()
        .background(tokens.surface)
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(isHighPriority ? tokens.bad.opacity(0.4) : tokens.warn.opacity(0.4), lineWidth: 1)
        )
    }
}
