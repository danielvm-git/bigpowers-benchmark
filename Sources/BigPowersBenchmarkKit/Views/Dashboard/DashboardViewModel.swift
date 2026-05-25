import Foundation
import Observation

public struct ModelMetric: Equatable {
    public let name: String
    public let avgScore: Double
}

public struct ModelDuration: Equatable {
    public let name: String
    public let avgDuration: Double
}

public struct ModelCost: Equatable {
    public let name: String
    public let avgCost: Double
}

public struct ModelImprovement: Equatable {
    public let model: String
    public let delta: Double
}

public struct Regression: Equatable {
    public let model: String
    public let task: String
    public let delta: Double
}

@MainActor
@Observable
public final class DashboardViewModel {
    public let store: BenchmarkStore
    public let regressionThreshold: Double

    public init(store: BenchmarkStore, regressionThreshold: Double = 0.1) {
        self.store = store
        self.regressionThreshold = regressionThreshold
    }

    public var bestModel: ModelMetric? {
        let groups = groupByModel()
        guard !groups.isEmpty else { return nil }
        return groups
            .map { ModelMetric(name: $0.key, avgScore: $0.value.avgScore) }
            .max(by: { $0.avgScore < $1.avgScore })
    }

    public var fastestModel: ModelDuration? {
        let groups = groupByModel()
        guard !groups.isEmpty else { return nil }
        return groups
            .map { ModelDuration(name: $0.key, avgDuration: $0.value.avgDuration) }
            .min(by: { $0.avgDuration < $1.avgDuration })
    }

    public var cheapestModel: ModelCost? {
        let groups = groupByModel()
        guard !groups.isEmpty else { return nil }
        return groups
            .map { ModelCost(name: $0.key, avgCost: $0.value.avgCost) }
            .min(by: { $0.avgCost < $1.avgCost })
    }

    public var mostImproved: ModelImprovement? {
        let modelRefs = modelsWithMultipleRefs()
        guard !modelRefs.isEmpty else { return nil }
        return modelRefs
            .map { ($0.key, deltaBetweenRefs($0.value)) }
            .filter { $0.1 > 0 }
            .max(by: { $0.1 < $1.1 })
            .map { ModelImprovement(model: $0.0, delta: $0.1) }
    }

    public var recentRegressions: [Regression] {
        let pairs = modelTaskPairs()
        guard !pairs.isEmpty else { return [] }
        return pairs.compactMap { model, task in
            let runs = store.runs.filter { $0.modelId == model && $0.taskId == task }
            let refs = Dictionary(grouping: runs, by: { $0.bigpowersRef })
            let refAverages = refs.mapValues { $0.map(\.overallScore).reduce(0, +) / Double($0.count) }
            let sortedRefs = refAverages.keys.sorted()
            guard sortedRefs.count >= 2 else { return nil }
            let latest = refAverages[sortedRefs.last!] ?? 0
            let previous = refAverages[sortedRefs[sortedRefs.count - 2]] ?? 0
            let delta = latest - previous
            guard delta < -regressionThreshold else { return nil }
            return Regression(model: model, task: task, delta: delta)
        }
    }

    private struct ModelAverages {
        let avgScore: Double
        let avgDuration: Double
        let avgCost: Double
    }

    private func groupByModel() -> [String: ModelAverages] {
        let groups = Dictionary(grouping: store.runs, by: { $0.modelId })
        return groups.mapValues { runs in
            let count = Double(runs.count)
            let avgScore = runs.map(\.overallScore).reduce(0, +) / count
            let avgDuration = runs.map(\.duration).reduce(0, +) / count
            let avgCost = runs.map(\.cost).reduce(0, +) / count
            return ModelAverages(avgScore: avgScore, avgDuration: avgDuration, avgCost: avgCost)
        }
    }

    private func modelsWithMultipleRefs() -> [String: [(ref: String, avgScore: Double)]] {
        let groups = Dictionary(grouping: store.runs, by: { $0.modelId })
        var result: [String: [(String, Double)]] = [:]
        for (model, runs) in groups {
            let refs = Dictionary(grouping: runs, by: { $0.bigpowersRef })
            let refAverages: [(String, Double)] = refs.map { ref, runs in
                (ref, runs.map(\.overallScore).reduce(0, +) / Double(runs.count))
            }
            guard refAverages.count >= 2 else { continue }
            result[model] = refAverages
        }
        return result
    }

    private func deltaBetweenRefs(_ refAverages: [(ref: String, avgScore: Double)]) -> Double {
        let sorted = refAverages.sorted { $0.ref < $1.ref }
        guard let first = sorted.first, let last = sorted.last else { return 0 }
        return last.avgScore - first.avgScore
    }

    private func modelTaskPairs() -> [(model: String, task: String)] {
        let pairs = Set(store.runs.map { "\($0.modelId)\0\($0.taskId)" })
        return pairs.compactMap { key in
            let parts = key.split(separator: "\0", maxSplits: 1)
            guard parts.count == 2 else { return nil }
            return (String(parts[0]), String(parts[1]))
        }
    }
}
