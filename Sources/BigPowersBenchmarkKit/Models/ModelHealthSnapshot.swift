import Foundation

public struct ModelHealthSnapshot: Codable, Identifiable, Sendable, Equatable {
    public let id: UUID
    public let timestamp: Date
    public let scope: String
    public let rows: [SnapshotRow]

    public init(id: UUID = UUID(), timestamp: Date, scope: String, rows: [SnapshotRow]) {
        self.id = id
        self.timestamp = timestamp
        self.scope = scope
        self.rows = rows
    }

    public static func make(
        from rows: [ModelHealthPingResult],
        registry: [ModelInfo],
        scope: ModelPingScope,
        timestamp: Date = Date()
    ) -> ModelHealthSnapshot {
        let maxP50 = rows.map(\.p50).max() ?? 1
        let snapshotRows = rows.map { result in
            let info = registry.first { $0.id == result.id }
            let suitability = info.map {
                BenchRankScore.compute(info: $0, pingResult: result, maxP50: maxP50).suitability
            } ?? .notSuitable
            return SnapshotRow(
                modelId: result.id,
                label: result.label,
                p50: result.p50,
                status: ModelHealthSnapshot.statusString(result.status),
                suitability: ModelHealthSnapshot.suitabilityString(suitability),
                responded: result.responded,
                modelMatched: result.modelMatched,
                notContentFiltered: result.notContentFiltered,
                isFree: ModelHealthFreeTier.isFree(
                    catalog: info,
                    pingResult: result
                ),
                hasTools: info?.capabilities.contains(.tools) ?? false,
                hasContext: (info?.contextWindow ?? 0) >= 32000,
                cost: result.cost,
                errorDetail: ModelHealthSnapshot.errorDetail(result.status),
                testedProviderLabel: result.testedProviderLabel,
                modelAlias: result.modelAlias,
                pingTransport: info?.pingTransport.rawValue
            )
        }
        return ModelHealthSnapshot(
            timestamp: timestamp,
            scope: scope.rawValue,
            rows: snapshotRows
        )
    }

    public static func statusString(_ status: ModelHealthPingStatus) -> String {
        switch status {
        case .live: "live"
        case .stale: "stale"
        case .timeout: "timeout"
        case .contentFilter: "contentFilter"
        case .mismatch: "mismatch"
        case .noCredit: "noCredit"
        case .error: "error"
        }
    }

    public static func errorDetail(_ status: ModelHealthPingStatus) -> String? {
        switch status {
        case let .error(message): message
        case .noCredit: "No credit"
        case .timeout: "Timeout"
        case .contentFilter: "Content filtered"
        case let .mismatch(actual): "Responded as \(actual)"
        case .live, .stale: nil
        }
    }

    public static func suitabilityString(_ suitability: BenchmarkSuitability) -> String {
        switch suitability {
        case .recommended: "recommended"
        case .limited: "limited"
        case .notSuitable: "notSuitable"
        }
    }

    public static func suitability(from string: String) -> BenchmarkSuitability {
        switch string {
        case "recommended": .recommended
        case "limited": .limited
        default: .notSuitable
        }
    }
}

public struct SnapshotRow: Codable, Sendable, Equatable, Identifiable {
    public var id: String {
        modelId
    }

    public let modelId: String
    public let label: String
    public let p50: Double
    public let status: String
    public let suitability: String
    public let responded: Bool
    public let modelMatched: Bool
    public let notContentFiltered: Bool
    public let isFree: Bool
    public let hasTools: Bool
    public let hasContext: Bool
    public let cost: Double
    public let errorDetail: String?
    public let testedProviderLabel: String?
    public let modelAlias: String?
    public let pingTransport: String?

    public init(
        modelId: String,
        label: String,
        p50: Double,
        status: String,
        suitability: String,
        responded: Bool,
        modelMatched: Bool,
        notContentFiltered: Bool,
        isFree: Bool,
        hasTools: Bool,
        hasContext: Bool,
        cost: Double,
        errorDetail: String? = nil,
        testedProviderLabel: String? = nil,
        modelAlias: String? = nil,
        pingTransport: String? = nil
    ) {
        self.modelId = modelId
        self.label = label
        self.p50 = p50
        self.status = status
        self.suitability = suitability
        self.responded = responded
        self.modelMatched = modelMatched
        self.notContentFiltered = notContentFiltered
        self.isFree = isFree
        self.hasTools = hasTools
        self.hasContext = hasContext
        self.cost = cost
        self.errorDetail = errorDetail
        self.testedProviderLabel = testedProviderLabel
        self.modelAlias = modelAlias
        self.pingTransport = pingTransport
    }

    enum CodingKeys: String, CodingKey {
        case modelId, label, p50, status, suitability
        case responded, modelMatched, notContentFiltered
        case isFree, hasTools, hasContext, cost
        case errorDetail, testedProviderLabel, modelAlias, pingTransport
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        modelId = try container.decode(String.self, forKey: .modelId)
        label = try container.decode(String.self, forKey: .label)
        p50 = try container.decode(Double.self, forKey: .p50)
        status = try container.decode(String.self, forKey: .status)
        suitability = try container.decode(String.self, forKey: .suitability)
        isFree = try container.decode(Bool.self, forKey: .isFree)
        hasTools = try container.decode(Bool.self, forKey: .hasTools)
        hasContext = try container.decode(Bool.self, forKey: .hasContext)
        cost = try container.decode(Double.self, forKey: .cost)
        errorDetail = try container.decodeIfPresent(String.self, forKey: .errorDetail)
        testedProviderLabel = try container.decodeIfPresent(String.self, forKey: .testedProviderLabel)
        modelAlias = try container.decodeIfPresent(String.self, forKey: .modelAlias)
        pingTransport = try container.decodeIfPresent(String.self, forKey: .pingTransport)

        if let responded = try container.decodeIfPresent(Bool.self, forKey: .responded),
           let modelMatched = try container.decodeIfPresent(Bool.self, forKey: .modelMatched),
           let notContentFiltered = try container.decodeIfPresent(Bool.self, forKey: .notContentFiltered) {
            self.responded = responded
            self.modelMatched = modelMatched
            self.notContentFiltered = notContentFiltered
        } else {
            responded = p50 > 0 || ["live", "mismatch", "contentFilter"].contains(status)
            modelMatched = status == "live" || status == "contentFilter"
            notContentFiltered = status != "contentFilter"
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(modelId, forKey: .modelId)
        try container.encode(label, forKey: .label)
        try container.encode(p50, forKey: .p50)
        try container.encode(status, forKey: .status)
        try container.encode(suitability, forKey: .suitability)
        try container.encode(responded, forKey: .responded)
        try container.encode(modelMatched, forKey: .modelMatched)
        try container.encode(notContentFiltered, forKey: .notContentFiltered)
        try container.encode(isFree, forKey: .isFree)
        try container.encode(hasTools, forKey: .hasTools)
        try container.encode(hasContext, forKey: .hasContext)
        try container.encode(cost, forKey: .cost)
        try container.encodeIfPresent(errorDetail, forKey: .errorDetail)
        try container.encodeIfPresent(testedProviderLabel, forKey: .testedProviderLabel)
        try container.encodeIfPresent(modelAlias, forKey: .modelAlias)
        try container.encodeIfPresent(pingTransport, forKey: .pingTransport)
    }
}
