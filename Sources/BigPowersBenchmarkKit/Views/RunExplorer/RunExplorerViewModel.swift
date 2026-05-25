import Foundation
import Observation

@Observable @MainActor
public final class RunExplorerViewModel {
    public var query: String = ""
    public var selectedModel: String?
    public var selectedRef: String?
    public var selectedTask: String?

    public var selectedRunIDs: Set<BenchRow.ID> = []

    private let store: BenchmarkStore

    public init(store: BenchmarkStore) {
        self.store = store
    }

    public var sortOrder = [KeyPathComparator(\BenchRow.timestamp, order: .reverse)]

    public var filteredRuns: [BenchRow] {
        var runs = store.runs

        if !query.isEmpty {
            runs = runs.filter {
                $0.modelId.localizedCaseInsensitiveContains(query) ||
                    $0.taskId.localizedCaseInsensitiveContains(query) ||
                    $0.bigpowersRef.localizedCaseInsensitiveContains(query)
            }
        }

        if let selectedModel {
            runs = runs.filter { $0.modelId == selectedModel }
        }

        if let selectedRef {
            runs = runs.filter { $0.bigpowersRef == selectedRef }
        }

        if let selectedTask {
            runs = runs.filter { $0.taskId == selectedTask }
        }

        return runs.sorted(using: sortOrder)
    }

    public var availableModels: [String] {
        Array(Set(store.runs.map(\.modelId))).sorted()
    }

    public var availableRefs: [String] {
        Array(Set(store.runs.map(\.bigpowersRef))).sorted()
    }

    public var availableTasks: [String] {
        Array(Set(store.runs.map(\.taskId))).sorted()
    }
}
