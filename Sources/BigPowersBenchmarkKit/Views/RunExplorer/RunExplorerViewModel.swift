import Foundation
import Observation

@Observable @MainActor
public final class RunExplorerViewModel {
    public var query: String = ""
    public var selectedRunIDs: Set<BenchRow.ID> = []

    private let store: BenchmarkStore

    public init(store: BenchmarkStore) {
        self.store = store
    }

    public var filteredRuns: [BenchRow] {
        if query.isEmpty {
            store.runs
        } else {
            store.runs.filter {
                $0.modelId.localizedCaseInsensitiveContains(query) ||
                    $0.taskId.localizedCaseInsensitiveContains(query)
            }
        }
    }
}
