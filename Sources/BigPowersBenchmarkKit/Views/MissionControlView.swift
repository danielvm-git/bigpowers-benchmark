// swiftlint:disable file_length
import AppKit
import Charts
import SwiftUI

public struct MissionControlView: View {
    @Environment(BenchmarkStore.self) private var store
    @Environment(ThemeManager.self) private var themeManager
    @Environment(DaytonaConfig.self) private var config
    @Environment(HostRunConfig.self) private var hostRunConfig
    @Environment(ModelIntelStore.self) private var intelStore

    @State private var viewModel: MissionControlViewModel?
    @State private var activeTab = 0 // 0 = Log Stream, 1 = Local Terminal

    public init() {}

    public var body: some View {
        let tokens = themeManager.resolvedTheme.tokens
        Group {
            if let vm = viewModel {
                VStack(spacing: 0) {
                    controlStrip(vm: vm, tokens: tokens)

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

                    VStack(spacing: 16) {
                        TaskStepperView(
                            taskResults: vm.taskResults.isEmpty
                                ? placeholderTaskResults(for: vm)
                                : vm.taskResults,
                            elapsedTime: vm.elapsedTime,
                            elapsedCost: vm.elapsedCost,
                            isRunning: vm.runState != .idle,
                            tokens: tokens
                        )
                        .padding(.horizontal)
                        .padding(.top, 16)

                        HSplitView {
                            cockpitPanel(vm: vm, tokens: tokens)
                            terminalPanel(vm: vm, tokens: tokens)
                        }
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
                viewModel = MissionControlViewModel(
                    daytonaClient: daytonaClient,
                    store: store,
                    daytonaConfig: config,
                    hostRunConfig: hostRunConfig,
                    intelStore: intelStore
                )
                if viewModel?.selectedModel.isEmpty == true {
                    let candidates = viewModel?.benchCandidateModels() ?? []
                    viewModel?.selectedModel = candidates.first?.modelId ?? ""
                }
            }
            Task {
                await viewModel?.loadSandboxes()
            }
        }
    }

    private func controlStrip(vm: MissionControlViewModel, tokens: ThemeTokens) -> some View {
        HStack(spacing: 12) {
            HStack(spacing: 8) {
                Picker("Model", selection: Bindable(vm).selectedModel) {
                    Text("Select Model").tag("")
                    let candidates = vm.benchCandidateModels()
                    if candidates.isEmpty {
                        Text("No bench candidates — ping models first").tag("")
                    } else {
                        ForEach(candidates, id: \.modelId) { profile in
                            Text(profile.label).tag(profile.modelId)
                        }
                    }
                }
                .frame(width: 180)
                .disabled(vm.runState != .idle)
                .accessibilityLabel("Model")

                if !vm.selectedModel.isEmpty {
                    Text(vm.selectedModelTier)
                        .font(.caption2.weight(.medium))
                        .foregroundColor(tokens.warn)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(tokens.warn.opacity(0.12))
                        .overlay(Capsule().stroke(tokens.warn, lineWidth: 1))
                        .clipShape(Capsule())
                        .accessibilityLabel("Model tier \(vm.selectedModelTier)")
                }
            }

            if !vm.isHostMode {
                Picker("Sandbox", selection: Bindable(vm).selectedSandbox) {
                    Text("Select Sandbox").tag(nil as Sandbox?)
                    ForEach(vm.sandboxes) { sb in
                        Text(sb.name).tag(sb as Sandbox?)
                    }
                }
                .frame(width: 180)
                .disabled(vm.runState != .idle)
                .accessibilityLabel("Sandbox")
            } else {
                Text("Host: \(hostRunConfig.bigpowersRef)")
                    .font(.caption)
                    .foregroundColor(tokens.fg3)
                    .frame(width: 120, alignment: .leading)
                    .accessibilityLabel("Git reference \(hostRunConfig.bigpowersRef)")
            }

            Text(vm.workspacePath)
                .font(.caption.monospaced())
                .foregroundColor(tokens.fg4)
                .lineLimit(1)
                .truncationMode(.middle)
                .accessibilityLabel("Workspace \(vm.workspacePath)")

            Picker("Suite", selection: Bindable(vm).selectedSuite) {
                Text("Select Suite").tag(nil as BenchmarkSuite?)
                ForEach(BenchmarkSuite.allSuites) { suite in
                    Text(suite.name).tag(suite as BenchmarkSuite?)
                }
            }
            .frame(width: 130)
            .disabled(vm.runState != .idle)
            .accessibilityLabel("Suite")

            Picker("Task", selection: Bindable(vm).selectedTask) {
                Text("Select Task").tag(nil as BenchmarkTask?)
                if let tasks = vm.selectedSuite?.tasks {
                    ForEach(tasks) { task in
                        Text("\(task.id) - \(task.name)").tag(task as BenchmarkTask?)
                    }
                }
            }
            .frame(width: 200)
            .disabled(vm.runState != .idle)
            .accessibilityLabel("Task")

            Spacer()

            HStack(spacing: 8) {
                Button {
                    Task { await vm.testConnection() }
                } label: {
                    Label(
                        "Test Connection",
                        systemImage: vm.isTestingConnection ? "arrow.triangle.2.circlepath" : "network"
                    )
                    .frame(width: 130)
                }
                .buttonStyle(.bordered)
                .disabled(vm.isTestingConnection)
                .accessibilityLabel("Test connection")

                Button {
                    Task { await vm.startRun() }
                } label: {
                    Label("Run Benchmark", systemImage: "play.fill")
                        .frame(width: 130)
                }
                .buttonStyle(.borderedProminent)
                .tint(tokens.accent)
                .disabled(vm.runState != .idle)
                .accessibilityLabel("Run benchmark")

                Button {
                    vm.stopRun()
                } label: {
                    Label("Stop", systemImage: "stop.fill")
                        .frame(width: 130)
                }
                .buttonStyle(.borderedProminent)
                .tint(tokens.bad)
                .disabled(vm.runState == .idle)
                .accessibilityLabel("Stop run")
            }
        }
        .padding()
        .background(tokens.bg1)
    }

    private func cockpitPanel(vm: MissionControlViewModel, tokens: ThemeTokens) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                    ThemedMetricCard(
                        title: "Overall",
                        value: vm.overallScore.map { String(format: "%.2f", $0) } ?? "—",
                        color: tokens.accent,
                        sparkData: vm.overallSparkData,
                        delta: vm.overallMetricDelta,
                        tokens: tokens
                    )
                    ThemedMetricCard(
                        title: "Code Pass",
                        value: vm.codePass.map { "\($0)/1" } ?? "—",
                        color: tokens.good,
                        sparkData: vm.codePassSparkData,
                        delta: vm.codePassMetricDelta,
                        tokens: tokens
                    )
                    ThemedMetricCard(
                        title: "Artifact",
                        value: vm.artifactScore.map { "\($0)/2" } ?? "—",
                        color: tokens.accent,
                        sparkData: vm.artifactSparkData,
                        delta: vm.artifactMetricDelta,
                        tokens: tokens
                    )
                    ThemedMetricCard(
                        title: "Convention",
                        value: vm.conventionScore.map { "\($0)/2" } ?? "—",
                        color: tokens.warn,
                        sparkData: vm.conventionSparkData,
                        delta: vm.conventionMetricDelta,
                        tokens: tokens
                    )
                }

                ScoreEvolutionView(viewModel: vm, tokens: tokens)

                TaskResultsTable(taskResults: vm.taskResults, tokens: tokens)
            }
            .padding()
        }
        .frame(minWidth: 320, maxWidth: .infinity)
        .background(tokens.bg)
    }

    private func terminalPanel(vm: MissionControlViewModel, tokens: ThemeTokens) -> some View {
        VStack(spacing: 0) {
            TerminalPanelHeaderView(
                viewModel: vm,
                activeTab: $activeTab,
                tokens: tokens
            )

            Rectangle()
                .fill(tokens.border)
                .frame(height: 1)

            if activeTab == 0 {
                TerminalView(logLines: vm.filteredLogLines)
            } else {
                LocalTerminalView()
            }
        }
        .background(tokens.surface)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(tokens.border, lineWidth: 1))
        .padding(.trailing)
        .padding(.bottom)
        .frame(minWidth: 400)
    }

    private func placeholderTaskResults(for vm: MissionControlViewModel) -> [TaskResult] {
        let tasks = vm.selectedSuite?.tasks ?? BenchmarkTask.allTasks
        return tasks.map { task in
            TaskResult(
                id: task.id,
                name: task.name,
                status: task.id == vm.selectedTask?.id ? .pending : .pending
            )
        }
    }
}

struct TerminalPanelHeaderView: View {
    @Bindable var viewModel: MissionControlViewModel
    @Binding var activeTab: Int
    let tokens: ThemeTokens

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var pulse = false

    var body: some View {
        VStack(spacing: 8) {
            HStack(spacing: 8) {
                TrafficLightsView()

                HStack(spacing: 5) {
                    if viewModel.runState != .idle {
                        Circle()
                            .fill(tokens.good)
                            .frame(width: 7, height: 7)
                            .opacity(pulse ? 1.0 : 0.25)
                        Text("running · \(viewModel.activeTaskId ?? "—") · \(formatDuration(viewModel.elapsedTime))")
                            .font(.caption.monospacedDigit())
                            .foregroundColor(tokens.good)
                    } else {
                        Circle()
                            .fill(tokens.fg4)
                            .frame(width: 7, height: 7)
                        Text("idle · bench:progress")
                            .font(.caption.monospaced())
                            .foregroundColor(tokens.fg3)
                    }
                }

                if let activeTaskId = viewModel.activeTaskId {
                    Text(activeTaskId)
                        .font(.caption2.weight(.medium))
                        .foregroundColor(tokens.fg2)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(tokens.surface2)
                        .overlay(Capsule().stroke(tokens.border, lineWidth: 1))
                        .clipShape(Capsule())
                }

                Text(viewModel.workspacePath)
                    .font(.caption2.monospaced())
                    .foregroundColor(tokens.fg4)
                    .lineLimit(1)
                    .truncationMode(.middle)

                Spacer()

                Picker("", selection: $activeTab) {
                    Text("Log Stream").tag(0)
                    Text("Local Terminal").tag(1)
                }
                .pickerStyle(.segmented)
                .frame(width: 220)
            }

            HStack(spacing: 8) {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 4) {
                        ForEach(viewModel.taskResults) { task in
                            Button(task.id) {
                                viewModel.toggleTaskFilter(task.id)
                            }
                            .buttonStyle(.plain)
                            .font(.caption2.monospaced())
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(
                                viewModel.visibleTaskIds.contains(task.id)
                                    ? tokens.accentF
                                    : tokens.surface2
                            )
                            .foregroundColor(
                                viewModel.visibleTaskIds.contains(task.id)
                                    ? tokens.accent
                                    : tokens.fg3
                            )
                            .overlay(
                                Capsule().stroke(
                                    viewModel.visibleTaskIds.contains(task.id)
                                        ? tokens.accent
                                        : tokens.border,
                                    lineWidth: 1
                                )
                            )
                            .clipShape(Capsule())
                            .accessibilityLabel("Filter logs for \(task.id)")
                        }
                    }
                }

                Spacer()

                Button {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(viewModel.copyFilteredLogs(), forType: .string)
                } label: {
                    Image(systemName: "doc.on.doc")
                }
                .buttonStyle(.borderless)
                .foregroundColor(tokens.fg3)
                .accessibilityLabel("Copy log")

                Button {
                    viewModel.logLines = []
                } label: {
                    Image(systemName: "trash")
                }
                .buttonStyle(.borderless)
                .foregroundColor(tokens.fg3)
                .accessibilityLabel("Clear log")
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(tokens.bg1)
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(.easeInOut(duration: 1.4).repeatForever(autoreverses: true)) {
                pulse = true
            }
        }
    }

    private func formatDuration(_ duration: TimeInterval) -> String {
        guard duration > 0 else { return "0s" }
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = duration >= 60 ? [.minute, .second] : [.second]
        formatter.unitsStyle = .abbreviated
        formatter.zeroFormattingBehavior = .pad
        return formatter.string(from: duration) ?? "0s"
    }
}

struct TrafficLightsView: View {
    var body: some View {
        HStack(spacing: 4) {
            Circle().fill(Color(red: 1.0, green: 0.37, blue: 0.34)).frame(width: 10, height: 10)
            Circle().fill(Color(red: 1.0, green: 0.74, blue: 0.18)).frame(width: 10, height: 10)
            Circle().fill(Color(red: 0.16, green: 0.79, blue: 0.26)).frame(width: 10, height: 10)
        }
        .accessibilityHidden(true)
    }
}

struct TaskResultsTable: View {
    let taskResults: [TaskResult]
    let tokens: ThemeTokens

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("").frame(width: 40)
                Text("Task").frame(maxWidth: .infinity, alignment: .leading)
                Text("Duration").frame(width: 70, alignment: .leading)
                Text("Cost").frame(width: 60, alignment: .leading)
                Text("Overall").frame(width: 60, alignment: .leading)
                Text("Δ prev").frame(width: 70, alignment: .leading)
            }
            .font(.caption2.weight(.semibold))
            .textCase(.uppercase)
            .foregroundColor(tokens.fg3)
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(tokens.surface)
            .overlay(alignment: .bottom) {
                Rectangle().fill(tokens.border).frame(height: 1)
            }

            if taskResults.isEmpty {
                Text("No tasks in suite")
                    .font(.caption)
                    .foregroundColor(tokens.fg3)
                    .frame(maxWidth: .infinity, minHeight: 80)
            } else {
                ForEach(taskResults) { task in
                    HStack {
                        StatusIconCell(status: task.status, tokens: tokens)
                            .frame(width: 40)

                        Text(task.name)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .foregroundColor(tokens.fg2)

                        MonoCell(text: formatDuration(task.duration), tokens: tokens)
                            .frame(width: 70, alignment: .leading)

                        MonoCell(text: formatCost(task.cost), tokens: tokens)
                            .frame(width: 60, alignment: .leading)

                        MonoCell(
                            text: task.overallScore.map { String(format: "%.2f", $0) } ?? "—",
                            tokens: tokens
                        )
                        .frame(width: 60, alignment: .leading)

                        DeltaBadge(delta: task.delta, tokens: tokens)
                            .frame(width: 70, alignment: .leading)
                    }
                    .font(.caption)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(tokens.surface)
                    .overlay(alignment: .bottom) {
                        Rectangle().fill(tokens.border).frame(height: 1)
                    }
                }
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(tokens.border, lineWidth: 1))
        .frame(maxHeight: 220)
    }

    private func formatDuration(_ duration: TimeInterval?) -> String {
        guard let duration else { return "—" }
        if duration >= 60 {
            return String(format: "%dm %ds", Int(duration) / 60, Int(duration) % 60)
        }
        return String(format: "%ds", Int(duration))
    }

    private func formatCost(_ cost: Double?) -> String {
        guard let cost else { return "—" }
        return String(format: "$%.2f", cost)
    }
}

struct StatusIconCell: View {
    let status: TaskStatus
    let tokens: ThemeTokens

    var body: some View {
        ZStack {
            Circle()
                .fill(backgroundColor)
                .frame(width: 20, height: 20)

            Text(symbol)
                .font(.system(size: 10, weight: .semibold))
                .foregroundColor(foregroundColor)
        }
        .accessibilityLabel(status.rawValue)
    }

    private var symbol: String {
        switch status {
        case .complete: "✓"
        case .active: "●"
        case .pending: "○"
        case .fail: "✗"
        }
    }

    private var backgroundColor: Color {
        switch status {
        case .complete: tokens.good.opacity(0.12)
        case .active: tokens.accentF
        case .pending: tokens.surface2
        case .fail: tokens.bad.opacity(0.12)
        }
    }

    private var foregroundColor: Color {
        switch status {
        case .complete: tokens.good
        case .active: tokens.accent
        case .pending: tokens.fg4
        case .fail: tokens.bad
        }
    }
}

struct MonoCell: View {
    let text: String
    let tokens: ThemeTokens

    var body: some View {
        Text(text)
            .font(.caption.monospaced())
            .foregroundColor(tokens.fg2)
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

struct ThemedMetricCard: View {
    let title: String
    let value: String
    let color: Color
    let sparkData: [Double]
    let delta: Double?
    let tokens: ThemeTokens

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.caption)
                .foregroundColor(tokens.fg3)

            Text(value)
                .font(.title2.weight(.bold))
                .foregroundColor(color)

            if !sparkData.isEmpty {
                Chart(Array(sparkData.enumerated()), id: \.offset) { index, point in
                    LineMark(
                        x: .value("Index", index),
                        y: .value("Value", point)
                    )
                    .foregroundStyle(color)
                    .interpolationMethod(.catmullRom)
                }
                .chartXAxis(.hidden)
                .chartYAxis(.hidden)
                .frame(height: 32)
            }

            DeltaBadge(delta: delta, tokens: tokens)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(tokens.surface)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(tokens.border, lineWidth: 1))
        .accessibilityElement(children: .combine)
        .accessibilityLabel(title)
        .accessibilityValue(accessibilityValueText)
    }

    private var accessibilityValueText: String {
        if let delta {
            let direction = delta > 0 ? "up" : (delta < 0 ? "down" : "unchanged")
            return "\(value), \(direction) \(String(format: "%.2f", delta))"
        }
        return value
    }
}
