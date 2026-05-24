import SwiftUI

public struct TaskLibraryView: View {
    @Environment(ThemeManager.self) private var themeManager
    @State private var selectedSuite: BenchmarkSuite? = BenchmarkSuite.allSuites.first
    @State private var selectedTask: BenchmarkTask?

    public init() {}

    public var body: some View {
        let tokens = themeManager.resolvedTheme.tokens
        NavigationSplitView {
            List(BenchmarkSuite.allSuites, id: \.self, selection: $selectedSuite) { suite in
                Text(suite.name)
                    .foregroundColor(tokens.fg)
            }
            .navigationTitle("Suites")
            .background(tokens.bg1)
        } detail: {
            if let suite = selectedSuite {
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(suite.name)
                                .font(.largeTitle)
                                .fontWeight(.bold)
                                .foregroundColor(tokens.fg)
                            Text("\(suite.tasks.count) tasks in this suite")
                                .font(.subheadline)
                                .foregroundColor(tokens.fg3)
                        }

                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 280))], spacing: 20) {
                            ForEach(suite.tasks) { task in
                                TaskCard(task: task, tokens: tokens) {
                                    selectedTask = task
                                }
                            }
                        }
                    }
                    .padding(30)
                }
                .background(tokens.bg)
                .sheet(item: $selectedTask) { task in
                    TaskDetailView(task: task, tokens: tokens)
                }
            } else {
                ThemedEmptyState(
                    icon: "tray.fill",
                    title: "Select a Suite",
                    subtitle: "Choose a benchmark suite from the sidebar to browse and run its tasks.",
                    tokens: tokens
                )
                .background(tokens.bg)
            }
        }
    }
}

struct TaskCard: View {
    let task: BenchmarkTask
    let tokens: ThemeTokens
    let action: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(task.id)
                    .font(.caption)
                    .fontWeight(.bold)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(tokens.accentF)
                    .foregroundColor(tokens.accent)
                    .cornerRadius(4)
                Spacer()
            }

            Text(task.name)
                .font(.headline)
                .fontWeight(.bold)
                .foregroundColor(tokens.fg)

            Text(task.description)
                .font(.caption)
                .foregroundColor(tokens.fg3)
                .lineLimit(3)

            Spacer()

            Button("Details & Run", action: action)
                .buttonStyle(.bordered)
                .tint(tokens.accent)
                .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .padding()
        .frame(height: 180)
        .background(tokens.surface)
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(tokens.border, lineWidth: 1)
        )
    }
}

struct TaskDetailView: View {
    let task: BenchmarkTask
    let tokens: ThemeTokens
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(task.id)
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundColor(tokens.accent)
                    Text(task.name)
                        .font(.title)
                        .fontWeight(.bold)
                        .foregroundColor(tokens.fg)
                }
                Spacer()
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title)
                        .foregroundColor(tokens.fg4)
                }
                .buttonStyle(.plain)
            }

            Rectangle()
                .fill(tokens.border)
                .frame(height: 1)

            Text("Description")
                .font(.headline)
                .foregroundColor(tokens.fg)
            Text(task.description)
                .font(.body)
                .foregroundColor(tokens.fg3)

            Rectangle()
                .fill(tokens.border)
                .frame(height: 1)

            Text("Artifact Checklists")
                .font(.headline)
                .foregroundColor(tokens.fg)
            VStack(alignment: .leading, spacing: 8) {
                CheckItem(text: "Verify compiler diagnostics and unit tests pass cleanly.", tokens: tokens)
                CheckItem(text: "Ensure specifications (.md specs) are created under specs/ directory.", tokens: tokens)
                CheckItem(text: "Verify Git commits adhere to Conventional Commits format.", tokens: tokens)
            }

            Spacer()

            Button("Run Task inside Sandbox") {
                dismiss()
            }
            .buttonStyle(.borderedProminent)
            .tint(tokens.accent)
            .frame(maxWidth: .infinity)
        }
        .padding(30)
        .frame(width: 450, height: 480)
        .background(tokens.bg)
    }
}

struct CheckItem: View {
    let text: String
    let tokens: ThemeTokens

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundColor(tokens.good)
            Text(text)
                .font(.caption)
                .foregroundColor(tokens.fg3)
        }
    }
}
