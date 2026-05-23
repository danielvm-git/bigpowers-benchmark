import SwiftUI

public struct MenuBarContent: View {
    @Environment(BenchmarkStore.self) private var store

    public init() {}

    public var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("BigPowers Benchmark")
                .font(.headline)
            Divider()
            Text("Runs: \(store.runs.count)")
                .font(.caption)
        }
        .padding(8)
        .frame(minWidth: 180)
    }
}
