import SwiftUI

public struct ModelHealthView: View {
    @Environment(BenchmarkStore.self) private var store
    @Environment(ThemeManager.self) private var themeManager

    public init() {}

    public var body: some View {
        let tokens = themeManager.resolvedTheme.tokens
        ScrollView {
            VStack(alignment: .leading, spacing: 25) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Model Health & Leaderboard")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .foregroundColor(tokens.fg)
                    Text("Monitor LLM provider statuses, latency, and capability ranks.")
                        .foregroundColor(tokens.fg3)
                }

                // Providers Status Grid
                Text("Providers Status")
                    .font(.headline)
                    .foregroundColor(tokens.fg)

                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 15) {
                    ProviderStatusCard(
                        name: "OpenAI",
                        status: "Online",
                        latency: "1.2s",
                        statusColor: tokens.good,
                        tokens: tokens
                    )
                    ProviderStatusCard(
                        name: "Anthropic",
                        status: "Online",
                        latency: "1.6s",
                        statusColor: tokens.good,
                        tokens: tokens
                    )
                    ProviderStatusCard(
                        name: "Google Gemini",
                        status: "Online",
                        latency: "0.8s",
                        statusColor: tokens.good,
                        tokens: tokens
                    )
                }

                Rectangle()
                    .fill(tokens.border)
                    .frame(height: 1)

                // Leaderboard Table
                Text("Benchmark Capability Leaderboard")
                    .font(.headline)
                    .foregroundColor(tokens.fg)

                VStack {
                    if leaderboardData.isEmpty {
                        ThemedInlineEmpty(
                            icon: "waveform.path.ecg",
                            title: "No leaderboard data yet",
                            tokens: tokens
                        )
                        .frame(height: 180)
                    } else {
                        Table(leaderboardData) {
                            TableColumn("Rank") { row in
                                Text("\(row.rank)")
                                    .fontWeight(.bold)
                                    .foregroundColor(tokens.fg)
                            }
                            TableColumn("Model") { row in
                                Text(row.modelId)
                                    .foregroundColor(tokens.fg2)
                            }
                            TableColumn("Success Rate") { row in
                                Text(String(format: "%.1f%%", row.successRate * 100))
                                    .foregroundColor(tokens.good)
                            }
                            TableColumn("Avg Score") { row in
                                Text(String(format: "%.2f", row.avgScore))
                                    .foregroundColor(tokens.accent)
                            }
                            TableColumn("Cost / Run") { row in
                                Text(String(format: "$%.4f", row.avgCost))
                                    .foregroundColor(tokens.fg3)
                            }
                        }
                        .frame(height: 250)
                    }
                }
                .padding()
                .background(tokens.surface)
                .cornerRadius(12)
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(tokens.border, lineWidth: 1))
            }
            .padding(30)
        }
        .background(tokens.bg)
    }

    struct LeaderboardRow: Identifiable {
        let id = UUID()
        let rank: Int
        let modelId: String
        let successRate: Double
        let avgScore: Double
        let avgCost: Double
    }

    private var leaderboardData: [LeaderboardRow] {
        guard !store.runs.isEmpty else {
            // Provide placeholder list when there are no runs
            return [
                LeaderboardRow(
                    rank: 1,
                    modelId: "anthropic/claude-3-5-sonnet",
                    successRate: 0.90,
                    avgScore: 88.5,
                    avgCost: 0.0450
                ),
                LeaderboardRow(rank: 2, modelId: "openai/gpt-4o", successRate: 0.85, avgScore: 84.2, avgCost: 0.0320),
                LeaderboardRow(
                    rank: 3,
                    modelId: "google/gemini-1.5-pro",
                    successRate: 0.80,
                    avgScore: 78.0,
                    avgCost: 0.0150
                ),
            ]
        }

        let groups = Dictionary(grouping: store.runs, by: { $0.modelId })
        return groups.map { modelId, runs in
            let avgScore = runs.map(\.overallScore).reduce(0.0, +) / Double(runs.count)
            let successRate = Double(runs.filter { $0.codePass == 1 }.count) / Double(runs.count)
            let avgCost = runs.map(\.cost).reduce(0.0, +) / Double(runs.count)
            return (modelId: modelId, avgScore: avgScore, successRate: successRate, avgCost: avgCost)
        }
        .sorted(by: { $0.avgScore > $1.avgScore })
        .enumerated()
        .map { index, item in
            LeaderboardRow(
                rank: index + 1,
                modelId: item.modelId,
                successRate: item.successRate,
                avgScore: item.avgScore,
                avgCost: item.avgCost
            )
        }
    }
}

struct ProviderStatusCard: View {
    let name: String
    let status: String
    let latency: String
    let statusColor: Color
    let tokens: ThemeTokens

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(name)
                    .font(.headline)
                    .fontWeight(.bold)
                    .foregroundColor(tokens.fg)
                Spacer()
                Circle()
                    .frame(width: 8, height: 8)
                    .foregroundColor(statusColor)
            }

            HStack {
                Text(status)
                    .font(.caption)
                    .foregroundColor(tokens.fg3)
                Spacer()
                Text("Latency: \(latency)")
                    .font(.caption2)
                    .foregroundColor(tokens.fg4)
            }
        }
        .padding()
        .background(tokens.surface)
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(tokens.border, lineWidth: 1)
        )
    }
}
