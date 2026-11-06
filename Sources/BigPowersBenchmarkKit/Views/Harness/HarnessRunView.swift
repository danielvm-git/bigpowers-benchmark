import SwiftUI

public struct HarnessRunView: View {
    @State private var model = HarnessRunViewModel()
    @Environment(ThemeManager.self) private var themeManager

    public init() {}

    public var body: some View {
        let tokens = themeManager.resolvedTheme.tokens
        VStack(alignment: .leading, spacing: 12) {
            header(tokens)
            form(tokens)
            if let error = model.errorMessage {
                Text(error)
                    .font(.callout)
                    .foregroundStyle(tokens.bad)
                    .accessibilityLabel("Harness error: \(error)")
            }
            if let report = model.latestReport {
                summary(report, tokens)
            }
            HSplitView {
                log(tokens)
                records(tokens)
            }
        }
        .padding(16)
        .background(tokens.bg)
        .navigationTitle("A/B Harness")
    }

    private func header(_ tokens: ThemeTokens) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("Outcome A/B benchmark")
                    .font(.title2.weight(.semibold))
                Text("Vanilla vs bigpowers on hidden-test tasks. Runner: scripts/run-ab-eval.sh")
                    .font(.callout)
                    .foregroundStyle(tokens.fg2)
            }
            Spacer()
            if model.isRunning {
                Button("Cancel", role: .destructive) { model.cancel() }
            } else {
                Button("Run") { model.run() }
                    .buttonStyle(.borderedProminent)
                    .disabled(!model.canRun)
            }
        }
    }

    private func form(_ tokens: ThemeTokens) -> some View {
        Grid(alignment: .leadingFirstTextBaseline, horizontalSpacing: 12, verticalSpacing: 8) {
            GridRow {
                Text("Runner root").foregroundStyle(tokens.fg2)
                TextField("/path/to/bigpowers-benchmark", text: $model.runnerRoot)
                    .textFieldStyle(.roundedBorder)
            }
            GridRow {
                Text("Bigpowers root").foregroundStyle(tokens.fg2)
                TextField("/path/to/bigpowers", text: $model.subjectRoot)
                    .textFieldStyle(.roundedBorder)
            }
            GridRow {
                Text("Reports dir").foregroundStyle(tokens.fg2)
                TextField("benchmarks/reports", text: $model.reportsDir)
                    .textFieldStyle(.roundedBorder)
            }
            GridRow {
                Text("Tasks").foregroundStyle(tokens.fg2)
                TextField("ab-11,ab-13", text: $model.tasksText)
                    .textFieldStyle(.roundedBorder)
            }
            GridRow {
                Text("Arms").foregroundStyle(tokens.fg2)
                TextField("vanilla,bigpowers", text: $model.armsText)
                    .textFieldStyle(.roundedBorder)
            }
            GridRow {
                Text("Adapter").foregroundStyle(tokens.fg2)
                Picker("Adapter", selection: $model.adapter) {
                    Text("pi-docker").tag("pi-docker")
                    Text("pi").tag("pi")
                    Text("claude").tag("claude")
                    Text("opencode").tag("opencode")
                }
                .labelsHidden()
            }
            GridRow {
                Text("Runs (k)").foregroundStyle(tokens.fg2)
                Stepper("\(model.runsPerTask)", value: $model.runsPerTask, in: 1 ... 50)
                    .labelsHidden()
            }
        }
        .textFieldStyle(.roundedBorder)
    }

    private func summary(_ report: ABReport, _ tokens: ThemeTokens) -> some View {
        HStack(spacing: 16) {
            Text("k=\(report.runsPerTask ?? 0)")
            ForEach(report.arms, id: \.self) { arm in
                if let summary = report.armsSummary[arm] {
                    Text("\(arm): \(percent(summary.passRate)) pass")
                        .foregroundStyle(tokens.fg2)
                }
            }
            if let delta = report.delta {
                Text("Δ \(percent(delta.passRate))")
                    .foregroundStyle((delta.passRate ?? 0) < 0 ? tokens.bad : tokens.good)
            }
        }
        .font(.callout.monospacedDigit())
    }

    private func log(_ tokens: ThemeTokens) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 1) {
                ForEach(Array(model.logLines.enumerated()), id: \.offset) { _, line in
                    Text(line)
                        .font(.caption.monospaced())
                        .foregroundStyle(tokens.fg2)
                        .textSelection(.enabled)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(8)
        }
        .frame(minWidth: 320)
        .background(tokens.surface)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private func records(_ tokens: ThemeTokens) -> some View {
        Table(model.records) {
            TableColumn("Task", value: \.task)
            TableColumn("Arm", value: \.arm)
            TableColumn("Pass") { record in
                Text(record.pass ? "PASS" : "FAIL")
                    .foregroundStyle(record.pass ? tokens.good : tokens.bad)
            }
            TableColumn("Score") { record in
                Text(record.score.map { String(format: "%.3f", $0) } ?? "—")
            }
            TableColumn("$") { record in
                Text(record.costUSD.map { String(format: "%.4f", $0) } ?? "—")
            }
            TableColumn("Sec") { record in
                Text(String(format: "%.0f", record.durationS))
            }
            TableColumn("Tamper") { record in
                Text(record.tampered ? "YES" : "no")
                    .foregroundStyle(record.tampered ? tokens.bad : tokens.fg3)
            }
        }
        .frame(minWidth: 360)
    }

    private func percent(_ value: Double?) -> String {
        guard let value else { return "—" }
        return String(format: "%.0f%%", value * 100)
    }
}
