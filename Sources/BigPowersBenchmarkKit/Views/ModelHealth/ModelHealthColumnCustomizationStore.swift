import Foundation
import Observation
import SwiftUI

@Observable
@MainActor
public final class ModelHealthColumnCustomizationStore {
    public var live = TableColumnCustomization<ModelHealthTableRow>()
    public var history = TableColumnCustomization<ModelHealthTableRow>()

    private static let liveKey = "modelHealth.columnCustomization.live"
    private static let historyKey = "modelHealth.columnCustomization.history"

    public init() {
        loadFromDefaults()
    }

    public func loadFromDefaults() {
        if let data = UserDefaults.standard.data(forKey: Self.liveKey),
           let decoded = try? JSONDecoder().decode(
               TableColumnCustomization<ModelHealthTableRow>.self,
               from: data
           ) {
            live = decoded
        }
        if let data = UserDefaults.standard.data(forKey: Self.historyKey),
           let decoded = try? JSONDecoder().decode(
               TableColumnCustomization<ModelHealthTableRow>.self,
               from: data
           ) {
            history = decoded
        }
    }

    public func persistLive() {
        guard let data = try? JSONEncoder().encode(live) else { return }
        UserDefaults.standard.set(data, forKey: Self.liveKey)
    }

    public func persistHistory() {
        guard let data = try? JSONEncoder().encode(history) else { return }
        UserDefaults.standard.set(data, forKey: Self.historyKey)
    }
}

enum ModelHealthColumnLayout {
    enum ColumnID {
        static let rank = "rank"
        static let model = "model"
        static let latency = "latency"
        static let bench = "bench"
        static let rsp = "rsp"
        static let match = "match"
        static let clear = "clear"
        static let tools = "tools"
        static let free = "free"
        static let ctx = "ctx"
        static let cost = "cost"
        static let reason = "reason"
    }
}
