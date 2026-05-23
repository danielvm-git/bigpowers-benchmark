import SwiftUI

public struct ContentView: View {
    @Environment(BenchmarkStore.self) private var store
    @Environment(ThemeManager.self) private var themeManager

    @State private var selectedScreen: Screen? = .dashboard
    @State private var columnVisibility: NavigationSplitViewVisibility = .all
    @State private var showOnboarding = false

    public init() {}

    public var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            List(Screen.allCases, id: \.self, selection: $selectedScreen) { screen in
                Label(screen.title, systemImage: screen.systemImage)
                    .accessibilityLabel(screen.title)
            }
            .navigationSplitViewColumnWidth(min: 60, ideal: 240)
        } detail: {
            if let screen = selectedScreen {
                Text(screen.title)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ContentUnavailableView("Select a screen", systemImage: "sidebar.left")
            }
        }
        .toolbar {
            ToolbarItem(placement: .navigation) {
                Button {
                    withAnimation {
                        columnVisibility = columnVisibility == .all ? .detailOnly : .all
                    }
                } label: {
                    Label("Toggle Sidebar", systemImage: "sidebar.left")
                }
                .accessibilityLabel("Toggle Sidebar")
            }

            ToolbarItemGroup(placement: .principal) {
                Circle()
                    .fill(store.currentRun != nil ? Color.green : Color.gray.opacity(0.4))
                    .frame(width: 8, height: 8)
                    .accessibilityLabel(store.currentRun != nil ? "Run in progress" : "Idle")

                if let last = store.runs.last {
                    Text(last.timestamp, style: .relative)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .accessibilityLabel("Last run \(last.timestamp.formatted(.relative(presentation: .named)))")
                } else {
                    Text("No runs yet")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .accessibilityLabel("No runs yet")
                }
            }

            ToolbarItemGroup(placement: .primaryAction) {
                Button {
                    let all = Theme.allCases.filter { $0 != .auto }
                    let idx = all.firstIndex(of: themeManager.current) ?? 0
                    themeManager.current = all[(idx + 1) % all.count]
                } label: {
                    Label("Cycle Theme", systemImage: "paintpalette")
                }
                .accessibilityLabel("Cycle Theme")

                Button {
                    if let screen = Screen.allCases.first(where: { $0 == .settings }) {
                        selectedScreen = screen
                    }
                } label: {
                    Label("Settings", systemImage: "gearshape")
                }
                .accessibilityLabel("Settings")
            }
        }
        .sheet(isPresented: $showOnboarding) {
            OnboardingSheet()
        }
        .onAppear {
            showOnboarding = !store.isRunsDirectoryGitRepo
        }
        .onChange(of: store.isRunsDirectoryGitRepo) { _, isRepo in
            if isRepo { showOnboarding = false }
        }
    }
}
