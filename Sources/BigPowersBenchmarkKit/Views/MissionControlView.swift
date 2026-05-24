import SwiftUI

public struct MissionControlView: View {
    @Environment(BenchmarkStore.self) private var store
    @Environment(ThemeManager.self) private var themeManager
    @Environment(DaytonaConfig.self) private var config

    @State private var viewModel: MissionControlViewModel?
    @State private var activeTab = 0 // 0 = Log Stream, 1 = Local Terminal

    public init() {}

    public var body: some View {
        let tokens = themeManager.resolvedTheme.tokens
        Group {
            if let vm = viewModel {
                VStack(spacing: 0) {
                    // Control Strip
                    HStack(spacing: 20) {
                        Picker("Sandbox", selection: Bindable(vm).selectedSandbox) {
                            Text("Select Sandbox").tag(nil as Sandbox?)
                            ForEach(vm.sandboxes) { sb in
                                Text(sb.name).tag(sb as Sandbox?)
                            }
                        }
                        .frame(width: 180)

                        Picker("Suite", selection: Bindable(vm).selectedSuite) {
                            Text("Select Suite").tag(nil as BenchmarkSuite?)
                            ForEach(BenchmarkSuite.allSuites) { suite in
                                Text(suite.name).tag(suite as BenchmarkSuite?)
                            }
                        }
                        .frame(width: 150)

                        Picker("Task", selection: Bindable(vm).selectedTask) {
                            Text("Select Task").tag(nil as BenchmarkTask?)
                            if let tasks = vm.selectedSuite?.tasks {
                                ForEach(tasks) { task in
                                    Text("\(task.id) - \(task.name)").tag(task as BenchmarkTask?)
                                }
                            }
                        }
                        .frame(width: 220)

                        Picker("Model", selection: Bindable(vm).selectedModel) {
                            Text("Select Model").tag("")
                            Text("gpt-4o").tag("openai/gpt-4o")
                            Text("claude-3-5-sonnet").tag("anthropic/claude-3-5-sonnet")
                            Text("gemini-1.5-pro").tag("google/gemini-1.5-pro")
                        }
                        .frame(width: 180)

                        if vm.runState == .idle {
                            Button {
                                Task { await vm.startRun() }
                            } label: {
                                Label("Run Benchmark", systemImage: "play.fill")
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(tokens.good)
                        } else {
                            Button {
                                vm.stopRun()
                            } label: {
                                Label("Stop Run", systemImage: "stop.fill")
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(tokens.bad)
                        }

                        Spacer()
                    }
                    .padding()
                    .background(tokens.bg1)

                    Rectangle()
                        .fill(tokens.border)
                        .frame(height: 1)

                    if let err = vm.errorMessage {
                        Text(err)
                            .foregroundColor(tokens.bad)
                            .padding()
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(tokens.bad.opacity(0.1))
                        Rectangle()
                            .fill(tokens.border)
                            .frame(height: 1)
                    }

                    HSplitView {
                        // Left Column: Cockpit details, Phase Tracker, and KPI Results
                        VStack(alignment: .leading, spacing: 20) {
                            // Phase Stepper
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Phase Tracker")
                                    .font(.headline)
                                    .foregroundColor(tokens.fg)

                                VStack(alignment: .leading, spacing: 10) {
                                    PhaseRow(
                                        name: "1. Reset Workspace",
                                        isActive: vm.runState == .running && vm.logLines
                                            .contains(where: { $0.text.contains("Phase: resettingWorkspace") }),
                                        isCompleted: vm.logLines
                                            .contains(where: { $0.text.contains("Phase: runningOpencode") }),
                                        tokens: tokens
                                    )
                                    PhaseRow(
                                        name: "2. Run opencode",
                                        isActive: vm.runState == .running && vm.logLines
                                            .contains(where: { $0.text.contains("Phase: runningOpencode") }),
                                        isCompleted: vm.logLines
                                            .contains(where: { $0.text.contains("Phase: grading") }),
                                        tokens: tokens
                                    )
                                    PhaseRow(
                                        name: "3. Grading & Testing",
                                        isActive: vm.runState == .running && vm.logLines
                                            .contains(where: { $0.text.contains("Phase: grading") }),
                                        isCompleted: vm.logLines
                                            .contains(where: { $0.text.contains("Phase: persisting") }),
                                        tokens: tokens
                                    )
                                    PhaseRow(
                                        name: "4. Persisting Results",
                                        isActive: vm.runState == .running && vm.logLines
                                            .contains(where: { $0.text.contains("Phase: persisting") }),
                                        isCompleted: vm.runState == .idle && vm.overallScore != nil,
                                        tokens: tokens
                                    )
                                }
                                .padding()
                                .background(tokens.surface)
                                .cornerRadius(8)
                                .overlay(RoundedRectangle(cornerRadius: 8).stroke(tokens.border, lineWidth: 1))
                            }

                            // Metrics
                            VStack(alignment: .leading, spacing: 10) {
                                HStack {
                                    Text("Run Metrics")
                                        .font(.headline)
                                        .foregroundColor(tokens.fg)
                                    Spacer()
                                    if vm.runState == .running {
                                        Text(formatDuration(vm.elapsedTime))
                                            .font(.caption.monospacedDigit())
                                            .foregroundColor(tokens.fg3)
                                    }
                                }

                                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 15) {
                                    ThemedMetricCard(
                                        title: "Code Pass",
                                        value: vm.codePass.map { "\($0 * 100)%" } ?? "—",
                                        color: tokens.good,
                                        tokens: tokens
                                    )
                                    ThemedMetricCard(
                                        title: "Artifacts",
                                        value: vm.artifactScore.map { "\($0)/2" } ?? "—",
                                        color: tokens.accent,
                                        tokens: tokens
                                    )
                                    ThemedMetricCard(
                                        title: "Convention",
                                        value: vm.conventionScore.map { "\($0)/2" } ?? "—",
                                        color: tokens.warn,
                                        tokens: tokens
                                    )
                                    ThemedMetricCard(
                                        title: "Overall",
                                        value: vm.overallScore.map { String(format: "%.1f", $0) } ?? "—",
                                        color: tokens.accentD,
                                        tokens: tokens
                                    )
                                }
                            }

                            Spacer()
                        }
                        .padding()
                        .frame(minWidth: 320, maxWidth: 450)
                        .background(tokens.bg)

                        // Right Column: Dual terminal tabs
                        VStack(spacing: 0) {
                            HStack {
                                Picker("", selection: $activeTab) {
                                    Text("Log Stream").tag(0)
                                    Text("Local Terminal").tag(1)
                                }
                                .pickerStyle(.segmented)
                                .frame(width: 250)

                                Spacer()

                                Button("Clear") {
                                    vm.logLines = []
                                }
                                .buttonStyle(.borderless)
                                .font(.caption)
                                .foregroundColor(tokens.fg3)
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 6)
                            .background(tokens.bg1)

                            Rectangle()
                                .fill(tokens.border)
                                .frame(height: 1)

                            if activeTab == 0 {
                                TerminalView(logLines: vm.logLines)
                            } else {
                                LocalTerminalView()
                            }
                        }
                        .frame(minWidth: 400)
                    }
                }
            } else {
                ProgressView("Initializing...")
                    .foregroundColor(tokens.fg3)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(tokens.bg)
            }
        }
        .background(tokens.bg)
        .onAppear {
            if viewModel == nil {
                let daytonaClient = DaytonaClient(config: config)
                viewModel = MissionControlViewModel(daytonaClient: daytonaClient, store: store, config: config)
            }
            Task {
                await viewModel?.loadSandboxes()
            }
        }
    }

    private func formatDuration(_ duration: TimeInterval) -> String {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.minute, .second]
        formatter.unitsStyle = .positional
        formatter.zeroFormattingBehavior = .pad
        return formatter.string(from: duration) ?? "00:00"
    }
}

struct PhaseRow: View {
    let name: String
    let isActive: Bool
    let isCompleted: Bool
    let tokens: ThemeTokens

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: isCompleted ? "checkmark.circle.fill" : (isActive ? "arrow.right.circle.fill" : "circle"))
                .foregroundColor(isCompleted ? tokens.good : (isActive ? tokens.accent : tokens.fg4))
            Text(name)
                .font(.body)
                .foregroundColor(isActive ? tokens.fg : tokens.fg3)
            if isActive {
                ProgressView()
                    .controlSize(.small)
                    .tint(tokens.accent)
            }
        }
    }
}

public struct MetricCard: View {
    let title: String
    let value: String
    let color: Color

    public init(title: String, value: String, color: Color) {
        self.title = title
        self.value = value
        self.color = color
    }

    public var body: some View {
        VStack(alignment: .leading) {
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
            Text(value)
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(color)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color.secondary.opacity(0.1))
        .cornerRadius(8)
    }
}

/// Themed variant used by MissionControlView
struct ThemedMetricCard: View {
    let title: String
    let value: String
    let color: Color
    let tokens: ThemeTokens

    var body: some View {
        VStack(alignment: .leading) {
            Text(title)
                .font(.caption)
                .foregroundColor(tokens.fg3)
            Text(value)
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(color)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(tokens.surface)
        .cornerRadius(8)
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(tokens.border, lineWidth: 1))
    }
}
