import SwiftUI

public struct ModelHealthHistoryView: View {
    @Environment(ModelHealthHistoryStore.self) private var historyStore
    @Environment(ThemeManager.self) private var themeManager
    @Environment(ModelHealthColumnCustomizationStore.self) private var columnStore

    @State private var selectedSnapshotID: UUID?

    public init() {}

    public var body: some View {
        let tokens = themeManager.resolvedTheme.tokens
        NavigationSplitView {
            List(selection: $selectedSnapshotID) {
                ForEach(historyStore.snapshots) { snapshot in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(snapshot.timestamp, style: .date)
                            .font(.headline)
                            .foregroundColor(tokens.fg)
                        Text(snapshot.timestamp, style: .time)
                            .font(.caption)
                            .foregroundColor(tokens.fg3)
                        Text(
                            "\(snapshot.scope.capitalized) · \(snapshot.rows.count) models · \(liveCount(snapshot)) live"
                        )
                        .font(.caption2)
                        .foregroundColor(tokens.fg4)
                    }
                    .tag(snapshot.id)
                }
            }
            .navigationTitle("Health History")
            .frame(minWidth: 240)
        } detail: {
            if let snapshot = selectedSnapshot {
                snapshotDetail(snapshot, tokens: tokens)
            } else {
                ThemedEmptyState(
                    icon: "clock.arrow.circlepath",
                    title: "Select a snapshot",
                    subtitle: "Choose a ping batch from the sidebar to view historical results.",
                    tokens: tokens
                )
                .background(tokens.bg)
            }
        }
        .background(tokens.bg)
        .task {
            try? historyStore.loadAll()
            if selectedSnapshotID == nil {
                selectedSnapshotID = historyStore.snapshots.first?.id
            }
        }
    }

    private var selectedSnapshot: ModelHealthSnapshot? {
        guard let selectedSnapshotID else { return nil }
        return historyStore.snapshots.first { $0.id == selectedSnapshotID }
    }

    private func liveCount(_ snapshot: ModelHealthSnapshot) -> Int {
        snapshot.rows.filter { $0.status == "live" }.count
    }

    private func snapshotDetail(_ snapshot: ModelHealthSnapshot, tokens: ThemeTokens) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Snapshot")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .foregroundColor(tokens.fg)
                Text("\(snapshot.timestamp.formatted(date: .abbreviated, time: .standard)) · \(snapshot.scope)")
                    .foregroundColor(tokens.fg3)
            }

            let sorted = BenchRankScore.sortSnapshotRows(snapshot.rows)
            let maxP50 = sorted.map(\.p50).max() ?? 1
            let tableRows = sorted.map { ModelHealthTableRow.from(snapshotRow: $0) }
            ModelHealthLeaderboardTable(
                rows: tableRows,
                maxP50: maxP50,
                tokens: tokens,
                mode: .history,
                columnCustomization: Bindable(columnStore).history
            ) { row in
                Text(row.label)
                    .foregroundColor(tokens.fg)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .onChange(of: columnStore.history) { _, _ in
                columnStore.persistHistory()
            }
        }
        .padding(30)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(tokens.bg)
    }
}
