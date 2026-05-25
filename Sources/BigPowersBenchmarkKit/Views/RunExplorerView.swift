// swiftlint:disable file_length
import SwiftUI

public struct RunExplorerView: View {
    @Environment(BenchmarkStore.self) private var store
    @Environment(ThemeManager.self) private var themeManager
    @Environment(RunExplorerViewModel.self) private var viewModel

    @State private var showComparePanel = false

    public init() {}

    public var body: some View {
        let tokens = themeManager.resolvedTheme.tokens
        let vm = viewModel
        HSplitView {
            // Left Column: Table of runs and filters
            VStack(spacing: 0) {
                Table(
                    vm.filteredRuns,
                    selection: Bindable(vm).selectedRunIDs,
                    sortOrder: Bindable(vm).sortOrder
                ) {
                    TableColumn("Date", value: \.timestamp) { row in
                        Text(row.timestamp, style: .date)
                            .foregroundColor(tokens.fg)
                    }
                    TableColumn("Model", value: \.modelId) { row in
                        Text(row.modelId)
                            .foregroundColor(tokens.fg2)
                    }
                    TableColumn("Task", value: \.taskId) { row in
                        Text(row.taskId)
                            .foregroundColor(tokens.fg2)
                    }
                    TableColumn("Ref", value: \.bigpowersRef) { row in
                        Text(row.bigpowersRef)
                            .foregroundColor(tokens.fg3)
                    }
                    TableColumn("Code", value: \.codePass) { row in
                        Text("\(row.codePass)")
                            .foregroundColor(tokens.fg2)
                    }
                    TableColumn("Artifact", value: \.artifactScore) { row in
                        Text("\(row.artifactScore)")
                            .foregroundColor(tokens.fg2)
                    }
                    TableColumn("Conv", value: \.conventionScore) { row in
                        Text("\(row.conventionScore)")
                            .foregroundColor(tokens.fg2)
                    }
                    TableColumn("Overall", value: \.overallScore) { row in
                        Text(String(format: "%.1f", row.overallScore))
                            .foregroundColor(scoreColor(row.overallScore, tokens: tokens))
                    }
                    TableColumn("Duration", value: \.duration) { row in
                        Text(String(format: "%.1fs", row.duration))
                            .foregroundColor(tokens.fg3)
                    }
                    TableColumn("Cost", value: \.cost) { row in
                        Text(String(format: "$%.4f", row.cost))
                            .foregroundColor(tokens.fg3)
                    }
                }
                .searchable(text: Bindable(vm).query)
                .toolbar {
                    ToolbarItemGroup(placement: .navigation) {
                        Picker("Model", selection: Bindable(vm).selectedModel) {
                            Text("All Models").tag(nil as String?)
                            ForEach(vm.availableModels, id: \.self) { model in
                                Text(model).tag(model as String?)
                            }
                        }
                        .frame(width: 150)
                        .accessibilityLabel("Filter by Model")

                        Picker("Ref", selection: Bindable(vm).selectedRef) {
                            Text("All Refs").tag(nil as String?)
                            ForEach(vm.availableRefs, id: \.self) { ref in
                                Text(ref).tag(ref as String?)
                            }
                        }
                        .frame(width: 120)
                        .accessibilityLabel("Filter by BigPowers Ref")

                        Picker("Task", selection: Bindable(vm).selectedTask) {
                            Text("All Tasks").tag(nil as String?)
                            ForEach(vm.availableTasks, id: \.self) { task in
                                Text(task).tag(task as String?)
                            }
                        }
                        .frame(width: 100)
                        .accessibilityLabel("Filter by Task ID")
                    }

                    ToolbarItemGroup(placement: .primaryAction) {
                        Button {
                            copyMarkdownSummary(vm.filteredRuns)
                        } label: {
                            Label("Copy Markdown Summary", systemImage: "doc.richtext")
                        }

                        Button {
                            exportCSV(vm.filteredRuns)
                        } label: {
                            Label("Export CSV", systemImage: "doc.text")
                        }

                        Button {
                            exportJSON(vm.filteredRuns)
                        } label: {
                            Label("Export JSON", systemImage: "braces")
                        }

                        if vm.selectedRunIDs.count == 2 {
                            Button {
                                showComparePanel.toggle()
                            } label: {
                                Label("Compare Selected", systemImage: "arrow.left.and.right")
                            }
                        }
                    }
                }
            }
            .frame(minWidth: 500)

            // Right Column: Drawer/Details/Compare Inspector
            VStack {
                let run: BenchRow? = {
                    guard vm.selectedRunIDs.count == 1, let id = vm.selectedRunIDs.first else { return nil }
                    return store.runs.first(where: { $0.id == id })
                }()
                if let run {
                    RunInspectorView(run: run, tokens: tokens)
                } else if vm.selectedRunIDs.count == 2, showComparePanel {
                    let selected = store.runs.filter { vm.selectedRunIDs.contains($0.id) }
                    if selected.count == 2 {
                        CompareInspectorView(runA: selected[0], runB: selected[1], tokens: tokens)
                    }
                } else {
                    ThemedEmptyState(
                        icon: "info.circle",
                        title: "Nothing Selected",
                        subtitle: "Select a single run to inspect details, or select two runs to compare them side by side.",
                        tokens: tokens
                    )
                }
            }
            .frame(width: 320)
            .background(tokens.bg1)
        }
        .background(tokens.bg)
    }

    private func scoreColor(_ score: Double, tokens: ThemeTokens) -> Color {
        if score >= 90 { return tokens.good }
        if score >= 70 { return tokens.warn }
        return tokens.bad
    }

    /// Copies a markdown table of the runs to the clipboard
    private func copyMarkdownSummary(_ runs: [BenchRow]) {
        var markdown = "| Date | Model | Task | Score | Cost |\n| :--- | :--- | :--- | :--- | :--- |\n"
        let fmt = DateFormatter()
        fmt.dateStyle = .short
        for run in runs {
            let line = "| \(fmt.string(from: run.timestamp)) | \(run.modelId) | \(run.taskId) | \(String(format: "%.1f", run.overallScore)) | \(String(format: "$%.4f", run.cost)) |\n"
            markdown.append(line)
        }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(markdown, forType: .string)
    }

    /// CSV RFC-4180 compliant exporter
    private func exportCSV(_ runs: [BenchRow]) {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.commaSeparatedText]
        panel.nameFieldStringValue = "benchmark_runs.csv"

        panel.begin { result in
            if result == .OK, let url = panel.url {
                var csv = "id,timestamp,bigpowersRef,modelId,taskId,codePass,artifactScore,conventionScore,overallScore,duration,cost,workspace\n"
                let fmt = ISO8601DateFormatter()
                for run in runs {
                    let line = "\"\(run.id.uuidString)\",\"\(fmt.string(from: run.timestamp))\",\"\(run.bigpowersRef)\",\"\(run.modelId)\",\"\(run.taskId)\",\(run.codePass),\(run.artifactScore),\(run.conventionScore),\(run.overallScore),\(run.duration),\(run.cost),\"\(run.workspace)\"\n"
                    csv.append(line)
                }
                try? csv.write(to: url, atomically: true, encoding: .utf8)
            }
        }
    }

    /// JSON exporter
    private func exportJSON(_ runs: [BenchRow]) {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.json]
        panel.nameFieldStringValue = "benchmark_runs.json"

        panel.begin { result in
            if result == .OK, let url = panel.url {
                let encoder = JSONEncoder()
                encoder.outputFormatting = .prettyPrinted
                encoder.dateEncodingStrategy = .iso8601
                if let data = try? encoder.encode(runs) {
                    try? data.write(to: url)
                }
            }
        }
    }
}

struct RunInspectorView: View {
    let run: BenchRow
    let tokens: ThemeTokens

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("Run Details")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(tokens.fg)

                Rectangle()
                    .fill(tokens.border)
                    .frame(height: 1)

                Group {
                    DetailRow(label: "Model", value: run.modelId, tokens: tokens)
                    DetailRow(label: "Task", value: run.taskId, tokens: tokens)
                    DetailRow(label: "Ref", value: run.bigpowersRef, tokens: tokens)
                    DetailRow(label: "Duration", value: String(format: "%.1fs", run.duration), tokens: tokens)
                    DetailRow(label: "Cost", value: String(format: "$%.4f", run.cost), tokens: tokens)
                    DetailRow(label: "Workspace", value: run.workspace, tokens: tokens)
                }

                Rectangle()
                    .fill(tokens.border)
                    .frame(height: 1)

                Text("Scores Breakdown")
                    .font(.headline)
                    .foregroundColor(tokens.fg)

                VStack(spacing: 12) {
                    ScoreBar(
                        label: "Code Pass (Weight: 2x)",
                        score: Double(run.codePass),
                        maxScore: 1.0,
                        color: tokens.good,
                        tokens: tokens
                    )
                    ScoreBar(
                        label: "Artifacts Score",
                        score: Double(run.artifactScore),
                        maxScore: 2.0,
                        color: tokens.accent,
                        tokens: tokens
                    )
                    ScoreBar(
                        label: "Convention Score",
                        score: Double(run.conventionScore),
                        maxScore: 2.0,
                        color: tokens.warn,
                        tokens: tokens
                    )

                    Rectangle()
                        .fill(tokens.border)
                        .frame(height: 1)

                    HStack {
                        Text("Overall Score:")
                            .fontWeight(.bold)
                            .foregroundColor(tokens.fg)
                        Spacer()
                        Text(String(format: "%.2f", run.overallScore))
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(tokens.accentD)
                    }
                }
                .padding()
                .background(tokens.surface)
                .cornerRadius(8)
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(tokens.border, lineWidth: 1))
            }
            .padding()
        }
        .background(tokens.bg1)
    }
}

struct CompareInspectorView: View {
    let runA: BenchRow
    let runB: BenchRow
    let tokens: ThemeTokens

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("Compare Runs")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(tokens.fg)

                Rectangle()
                    .fill(tokens.border)
                    .frame(height: 1)

                CompareHeaderRow(
                    aName: runA.modelId.components(separatedBy: "/").last ?? "Run A",
                    bName: runB.modelId.components(separatedBy: "/").last ?? "Run B",
                    tokens: tokens
                )

                Rectangle()
                    .fill(tokens.border)
                    .frame(height: 1)

                CompareMetricRow(
                    label: "Overall Score",
                    valA: String(format: "%.1f", runA.overallScore),
                    valB: String(format: "%.1f", runB.overallScore),
                    diff: runB.overallScore - runA.overallScore,
                    tokens: tokens
                )

                CompareMetricRow(
                    label: "Code Pass",
                    valA: "\(runA.codePass * 100)%",
                    valB: "\(runB.codePass * 100)%",
                    diff: Double(runB.codePass - runA.codePass),
                    tokens: tokens
                )

                CompareMetricRow(
                    label: "Artifacts",
                    valA: "\(runA.artifactScore)/2",
                    valB: "\(runB.artifactScore)/2",
                    diff: Double(runB.artifactScore - runA.artifactScore),
                    tokens: tokens
                )

                CompareMetricRow(
                    label: "Convention",
                    valA: "\(runA.conventionScore)/2",
                    valB: "\(runB.conventionScore)/2",
                    diff: Double(runB.conventionScore - runA.conventionScore),
                    tokens: tokens
                )

                CompareMetricRow(
                    label: "Duration (s)",
                    valA: String(format: "%.1fs", runA.duration),
                    valB: String(format: "%.1fs", runB.duration),
                    diff: runA.duration - runB.duration,
                    tokens: tokens
                )

                CompareMetricRow(
                    label: "Cost ($)",
                    valA: String(format: "$%.4f", runA.cost),
                    valB: String(format: "$%.4f", runB.cost),
                    diff: runA.cost - runB.cost,
                    tokens: tokens
                )
            }
            .padding()
        }
        .background(tokens.bg1)
    }
}

struct DetailRow: View {
    let label: String
    let value: String
    let tokens: ThemeTokens

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.caption)
                .foregroundColor(tokens.fg3)
            Text(value)
                .font(.body)
                .foregroundColor(tokens.fg)
                .lineLimit(2)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(label): \(value)")
    }
}

struct ScoreBar: View {
    let label: String
    let score: Double
    let maxScore: Double
    let color: Color
    let tokens: ThemeTokens

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(label)
                    .font(.caption)
                    .foregroundColor(tokens.fg3)
                Spacer()
                Text(String(format: "%.1f / %.1f", score, maxScore))
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundColor(tokens.fg)
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 3)
                        .frame(height: 6)
                        .foregroundColor(tokens.grid2)

                    RoundedRectangle(cornerRadius: 3)
                        .frame(width: geo.size.width * CGFloat(score / maxScore), height: 6)
                        .foregroundColor(color)
                }
            }
            .frame(height: 6)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(label): \(String(format: "%.1f", score)) out of \(String(format: "%.1f", maxScore))")
    }
}

struct CompareHeaderRow: View {
    let aName: String
    let bName: String
    let tokens: ThemeTokens

    var body: some View {
        HStack {
            Spacer()
            Text(aName)
                .font(.caption)
                .fontWeight(.bold)
                .foregroundColor(tokens.fg2)
                .frame(width: 90, alignment: .trailing)
            Text(bName)
                .font(.caption)
                .fontWeight(.bold)
                .foregroundColor(tokens.fg2)
                .frame(width: 90, alignment: .trailing)
        }
    }
}

struct CompareMetricRow: View {
    let label: String
    let valA: String
    let valB: String
    let diff: Double
    let tokens: ThemeTokens

    var body: some View {
        HStack {
            Text(label)
                .font(.body)
                .foregroundColor(tokens.fg)
            Spacer()
            Text(valA)
                .foregroundColor(tokens.fg2)
                .frame(width: 90, alignment: .trailing)
            Text(valB)
                .foregroundColor(tokens.fg2)
                .frame(width: 90, alignment: .trailing)
        }
        .padding(.vertical, 4)

        HStack {
            Spacer()
            Text(diff == 0 ? "No change" : (diff > 0 ? "+\(String(format: "%.2f", diff))" : String(
                format: "%.2f",
                diff
            )))
            .font(.caption2)
            .foregroundColor(diff == 0 ? tokens.fg4 : (diff > 0 ? tokens.good : tokens.bad))
        }
        Rectangle()
            .fill(tokens.border)
            .frame(height: 1)
    }
}
