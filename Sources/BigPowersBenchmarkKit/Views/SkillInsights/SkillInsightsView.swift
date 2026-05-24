import SwiftUI

public struct SkillInsightsView: View {
    @Environment(ThemeManager.self) private var themeManager
    @State private var selectedModel: String = "openai/gpt-4o"

    /// Skills configuration
    private let skills = [
        "Coding",
        "Specs",
        "Conventional Commits",
        "Architecture",
        "Speed",
    ]

    /// Hardcoded model skill values for illustration
    private var modelSkills: [String: [Double]] {
        [
            "openai/gpt-4o": [0.85, 0.90, 0.75, 0.80, 0.70],
            "anthropic/claude-3-5-sonnet": [0.92, 0.85, 0.80, 0.88, 0.65],
            "google/gemini-1.5-pro": [0.78, 0.82, 0.70, 0.75, 0.85],
        ]
    }

    public init() {}

    public var body: some View {
        let tokens = themeManager.resolvedTheme.tokens
        ScrollView {
            VStack(alignment: .leading, spacing: 25) {
                // Header
                VStack(alignment: .leading, spacing: 4) {
                    Text("Skill Insights")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .foregroundColor(tokens.fg)
                    Text("Analyze model capabilities across core software-driven development skills.")
                        .foregroundColor(tokens.fg3)
                }

                Picker("Model Selector", selection: $selectedModel) {
                    Text("gpt-4o").tag("openai/gpt-4o")
                    Text("claude-3-5-sonnet").tag("anthropic/claude-3-5-sonnet")
                    Text("gemini-1.5-pro").tag("google/gemini-1.5-pro")
                }
                .pickerStyle(.segmented)
                .frame(maxWidth: 440)

                // Use HStack with explicit widths — HSplitView clips Canvas content
                HStack(alignment: .top, spacing: 30) {
                    // Left Side: Radar Chart Canvas
                    VStack(alignment: .center, spacing: 12) {
                        Text("Skill Capability Radar")
                            .font(.headline)
                            .foregroundColor(tokens.fg)

                        RadarChart(
                            skills: skills,
                            values: modelSkills[selectedModel] ?? [],
                            tokens: tokens
                        )
                        .frame(width: 340, height: 340)
                        .background(tokens.surface)
                        .cornerRadius(16)
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(tokens.border, lineWidth: 1)
                        )

                        // Legend
                        HStack(spacing: 8) {
                            Circle()
                                .fill(tokens.accent)
                                .frame(width: 8, height: 8)
                            Text(selectedModel.components(separatedBy: "/").last ?? selectedModel)
                                .font(.caption)
                                .foregroundColor(tokens.fg3)
                        }
                    }
                    .frame(width: 340)

                    // Right Side: Linear Skill Bars
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Skill Breakdown Detail")
                            .font(.headline)
                            .foregroundColor(tokens.fg)

                        if let values = modelSkills[selectedModel] {
                            VStack(spacing: 0) {
                                ForEach(0 ..< skills.count, id: \.self) { idx in
                                    SkillRow(name: skills[idx], score: values[idx], tokens: tokens)

                                    if idx < skills.count - 1 {
                                        Rectangle()
                                            .fill(tokens.border)
                                            .frame(height: 1)
                                            .padding(.vertical, 2)
                                    }
                                }
                            }
                            .padding()
                            .background(tokens.surface)
                            .cornerRadius(12)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(tokens.border, lineWidth: 1)
                            )

                            // Score Summary Card
                            let avg = values.reduce(0.0, +) / Double(values.count)
                            HStack(spacing: 20) {
                                SummaryChip(
                                    label: "Average",
                                    value: String(format: "%.0f%%", avg * 100),
                                    color: tokens.accent,
                                    tokens: tokens
                                )
                                SummaryChip(
                                    label: "Peak",
                                    value: String(format: "%.0f%%", (values.max() ?? 0) * 100),
                                    color: tokens.good,
                                    tokens: tokens
                                )
                                SummaryChip(
                                    label: "Lowest",
                                    value: String(format: "%.0f%%", (values.min() ?? 0) * 100),
                                    color: tokens.warn,
                                    tokens: tokens
                                )
                            }
                            .padding(.top, 4)
                        } else {
                            ThemedEmptyState(
                                icon: "chart.radar",
                                title: "No Skill Data",
                                subtitle: "Run benchmarks to see detailed skill breakdown for this model.",
                                tokens: tokens
                            )
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .padding(30)
        }
        .background(tokens.bg)
    }
}

/// Extracted Canvas radar chart to a dedicated View for clarity
private struct RadarChart: View {
    let skills: [String]
    let values: [Double]
    let tokens: ThemeTokens

    var body: some View {
        Canvas { context, size in
            let center = CGPoint(x: size.width / 2, y: size.height / 2)
            let maxRadius = min(size.width, size.height) / 2 - 48
            let count = skills.count
            guard count > 0 else { return }
            let angles = (0 ..< count).map {
                Double($0) * (2 * Double.pi / Double(count)) - Double.pi / 2
            }

            // Concentric grid rings at 25/50/75/100%
            for (levelIdx, level) in [0.25, 0.50, 0.75, 1.0].enumerated() {
                var path = Path()
                for (i, angle) in angles.enumerated() {
                    let r = maxRadius * level
                    let pt = CGPoint(
                        x: center.x + CGFloat(cos(angle) * r),
                        y: center.y + CGFloat(sin(angle) * r)
                    )
                    if i == 0 { path.move(to: pt) } else { path.addLine(to: pt) }
                }
                path.closeSubpath()
                let opacity = levelIdx == 3 ? 0.20 : 0.10
                context.stroke(path, with: .color(tokens.fg4.opacity(opacity)), lineWidth: levelIdx == 3 ? 1.5 : 0.8)
            }

            // Axis spokes
            for angle in angles {
                var path = Path()
                path.move(to: center)
                path.addLine(to: CGPoint(
                    x: center.x + CGFloat(cos(angle) * maxRadius),
                    y: center.y + CGFloat(sin(angle) * maxRadius)
                ))
                context.stroke(path, with: .color(tokens.fg4.opacity(0.15)), lineWidth: 0.8)
            }

            // Filled model shape
            guard !values.isEmpty else { return }
            var shapePath = Path()
            for (i, angle) in angles.enumerated() {
                let val = i < values.count ? values[i] : 0.0
                let r = maxRadius * val
                let pt = CGPoint(
                    x: center.x + CGFloat(cos(angle) * r),
                    y: center.y + CGFloat(sin(angle) * r)
                )
                if i == 0 { shapePath.move(to: pt) } else { shapePath.addLine(to: pt) }
            }
            shapePath.closeSubpath()
            context.fill(shapePath, with: .color(tokens.accentF))
            context.stroke(shapePath, with: .color(tokens.accent), lineWidth: 2.5)

            // Vertex dots
            for (i, angle) in angles.enumerated() {
                let val = i < values.count ? values[i] : 0.0
                let r = maxRadius * val
                let dotCenter = CGPoint(
                    x: center.x + CGFloat(cos(angle) * r),
                    y: center.y + CGFloat(sin(angle) * r)
                )
                let dotRect = CGRect(x: dotCenter.x - 4, y: dotCenter.y - 4, width: 8, height: 8)
                context.fill(Path(ellipseIn: dotRect), with: .color(tokens.accent))
                let innerRect = CGRect(x: dotCenter.x - 2, y: dotCenter.y - 2, width: 4, height: 4)
                context.fill(Path(ellipseIn: innerRect), with: .color(tokens.bg))
            }

            // Labels
            let labelRadius = maxRadius + 26
            for (i, angle) in angles.enumerated() {
                let x = center.x + CGFloat(cos(angle) * labelRadius)
                let y = center.y + CGFloat(sin(angle) * labelRadius)
                context.draw(
                    Text(skills[i]).font(.caption2).bold().foregroundColor(tokens.fg2),
                    at: CGPoint(x: x, y: y),
                    anchor: .center
                )
            }
        }
    }
}

struct SkillRow: View {
    let name: String
    let score: Double
    let tokens: ThemeTokens

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(name)
                    .font(.subheadline)
                    .foregroundColor(tokens.fg)
                Spacer()
                Text(String(format: "%.0f%%", score * 100))
                    .font(.subheadline)
                    .fontWeight(.bold)
                    .foregroundColor(scoreColor)
                    .monospacedDigit()
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 5)
                        .frame(height: 8)
                        .foregroundColor(tokens.grid2)

                    RoundedRectangle(cornerRadius: 5)
                        .frame(width: max(0, geo.size.width * CGFloat(score)), height: 8)
                        .foregroundColor(scoreColor)
                        .animation(.easeOut(duration: 0.4), value: score)
                }
            }
            .frame(height: 8)
        }
        .padding(.vertical, 10)
    }

    private var scoreColor: Color {
        if score >= 0.85 { return tokens.good }
        if score >= 0.65 { return tokens.accent }
        return tokens.warn
    }
}

private struct SummaryChip: View {
    let label: String
    let value: String
    let color: Color
    let tokens: ThemeTokens

    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.title3)
                .fontWeight(.bold)
                .foregroundColor(color)
                .monospacedDigit()
            Text(label)
                .font(.caption2)
                .foregroundColor(tokens.fg4)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(tokens.surface)
        .cornerRadius(10)
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(tokens.border, lineWidth: 1))
    }
}
