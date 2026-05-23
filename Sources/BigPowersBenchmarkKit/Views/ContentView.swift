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

    private func cycleTheme() {
        let all = Theme.allCases.filter { $0 != .auto }
        if let idx = all.firstIndex(of: themeManager.current) {
            themeManager.current = all[(idx + 1) % all.count]
        } else {
            themeManager.current = all.first ?? .dark
        }
    }
}
