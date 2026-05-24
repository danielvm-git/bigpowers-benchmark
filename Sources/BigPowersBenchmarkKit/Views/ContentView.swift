import SwiftUI

public struct ContentView: View {
    @Environment(BenchmarkStore.self) private var store
    @Environment(ThemeManager.self) private var themeManager

    @State private var selectedScreen: Screen? = .dashboard
    @State private var columnVisibility: NavigationSplitViewVisibility = .all
    @State private var showOnboarding = false

    public init() {}

    public var body: some View {
        let tokens = themeManager.resolvedTheme.tokens
        NavigationSplitView(columnVisibility: $columnVisibility) {
            List(Screen.allCases, id: \.self, selection: $selectedScreen) { screen in
                Label(screen.title, systemImage: screen.systemImage)
                    .accessibilityLabel(screen.title)
            }
            .navigationSplitViewColumnWidth(min: 60, ideal: 240)
            .listStyle(.sidebar)
        } detail: {
            if let screen = selectedScreen {
                switch screen {
                case .dashboard:
                    DashboardView()
                case .missionControl:
                    MissionControlView()
                case .runExplorer:
                    RunExplorerView()
                case .skillInsights:
                    SkillInsightsView()
                case .modelHealth:
                    ModelHealthView()
                case .taskLibrary:
                    TaskLibraryView()
                case .settings:
                    SettingsView()
                case .analytics:
                    AnalyticsView()
                }
            } else {
                ThemedEmptyState(
                    icon: "sidebar.left",
                    title: "Select a Screen",
                    subtitle: "Choose a section from the sidebar to get started.",
                    tokens: tokens
                )
                .background(tokens.bg)
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

            ToolbarItemGroup(placement: .primaryAction) {
                Button {
                    cycleTheme()
                } label: {
                    Label("Cycle Theme", systemImage: "paintpalette")
                }
                .accessibilityLabel("Cycle Theme")

                Button {
                    selectedScreen = .settings
                } label: {
                    Label("Settings", systemImage: "gearshape")
                }
                .accessibilityLabel("Settings")
            }
        }
        .background(tokens.bg)
        .sheet(isPresented: $showOnboarding) {
            OnboardingSheet()
        }
        .onAppear {
            store.checkGitRepoStatus()
        }
        .onChange(of: store.isRunsDirectoryGitRepo) { _, isRepo in
            showOnboarding = !isRepo
        }
    }

    private func cycleTheme() {
        let all = Theme.allCases.filter { $0 != .auto }
        if let idx = all.firstIndex(of: themeManager.current) {
            themeManager.current = all[(idx + 1) % all.count]
        } else {
            themeManager.current = all.first ?? .dark
        }
    }
}
