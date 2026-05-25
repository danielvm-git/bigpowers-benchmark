import Charts
import SwiftUI

struct ScoreEvolutionView: View {
    @Bindable var viewModel: MissionControlViewModel
    let tokens: ThemeTokens

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Score Evolution")
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(tokens.fg)

                Spacer()

                HStack(spacing: 4) {
                    ForEach(HistoricalRange.allCases, id: \.self) { range in
                        Button(range.rawValue) {
                            viewModel.historicalRange = range
                        }
                        .buttonStyle(.plain)
                        .font(.caption2)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(
                            viewModel.historicalRange == range
                                ? tokens.accentF
                                : Color.clear
                        )
                        .foregroundColor(
                            viewModel.historicalRange == range
                                ? tokens.accent
                                : tokens.fg3
                        )
                        .overlay(
                            Capsule().stroke(
                                viewModel.historicalRange == range
                                    ? tokens.accent
                                    : tokens.border,
                                lineWidth: 1
                            )
                        )
                        .clipShape(Capsule())
                        .accessibilityLabel("Show \(range.rawValue) runs")
                    }
                }
            }

            if viewModel.filteredHistory.isEmpty {
                Text("No score history yet")
                    .font(.caption)
                    .foregroundColor(tokens.fg3)
                    .frame(maxWidth: .infinity, minHeight: 180, alignment: .center)
            } else {
                Chart {
                    ForEach(Array(viewModel.filteredHistory.enumerated()), id: \.element.id) { index, row in
                        LineMark(
                            x: .value("Run", index),
                            y: .value("Overall", row.overallScore)
                        )
                        .foregroundStyle(tokens.accent)
                        .interpolationMethod(.catmullRom)

                        PointMark(
                            x: .value("Run", index),
                            y: .value("Overall", row.overallScore)
                        )
                        .foregroundStyle(tokens.accent)
                        .symbolSize(index == viewModel.filteredHistory.count - 1 ? 36 : 24)

                        LineMark(
                            x: .value("Run", index),
                            y: .value("Code Pass", Double(row.codePass))
                        )
                        .foregroundStyle(tokens.fg3)
                        .lineStyle(StrokeStyle(lineWidth: 1.5, dash: [4, 2]))
                        .interpolationMethod(.catmullRom)
                    }
                }
                .chartXAxis(.hidden)
                .chartYAxis {
                    AxisMarks(position: .leading) { _ in
                        AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                            .foregroundStyle(tokens.grid.opacity(0.3))
                        AxisValueLabel()
                            .foregroundStyle(tokens.fg3)
                    }
                }
                .frame(height: 180)
                .accessibilityLabel(
                    "Score evolution chart showing overall and code pass scores across recent runs"
                )
            }
        }
        .padding(16)
        .background(tokens.surface)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(tokens.border, lineWidth: 1))
    }
}
