// swiftlint:disable file_length
// swiftlint:disable function_parameter_count
import Foundation

public struct ModelInfo: Codable, Identifiable, Sendable, Hashable {
    public let id: String
    public let name: String
    public let provider: String
    public let contextWindow: Int
    public let tier: Tier
    public let capabilities: [Capability]
    public let pricing: ModelPricing
    public let pingTransport: PingTransport
    public let resolvedModelId: String?

    public init(
        id: String,
        name: String,
        provider: String,
        contextWindow: Int,
        tier: Tier,
        capabilities: [Capability],
        pricing: ModelPricing,
        pingTransport: PingTransport = .openRouter,
        resolvedModelId: String? = nil
    ) {
        // swiftlint:disable:previous function_parameter_count
        self.id = id
        self.name = name
        self.provider = provider
        self.contextWindow = contextWindow
        self.tier = tier
        self.capabilities = capabilities
        self.pricing = pricing
        self.pingTransport = pingTransport
        self.resolvedModelId = resolvedModelId
    }

    public var apiModelId: String {
        resolvedModelId ?? id
    }

    enum CodingKeys: String, CodingKey {
        case id, name, provider, contextWindow, tier, capabilities, pricing
        case pingTransport, resolvedModelId
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        provider = try container.decode(String.self, forKey: .provider)
        contextWindow = try container.decode(Int.self, forKey: .contextWindow)
        tier = try container.decode(Tier.self, forKey: .tier)
        capabilities = try container.decode([Capability].self, forKey: .capabilities)
        pricing = try container.decode(ModelPricing.self, forKey: .pricing)
        pingTransport = try container.decodeIfPresent(PingTransport.self, forKey: .pingTransport) ?? .openRouter
        resolvedModelId = try container.decodeIfPresent(String.self, forKey: .resolvedModelId)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encode(provider, forKey: .provider)
        try container.encode(contextWindow, forKey: .contextWindow)
        try container.encode(tier, forKey: .tier)
        try container.encode(capabilities, forKey: .capabilities)
        try container.encode(pricing, forKey: .pricing)
        try container.encode(pingTransport, forKey: .pingTransport)
        try container.encodeIfPresent(resolvedModelId, forKey: .resolvedModelId)
    }

    public var formattedContextWindow: String {
        ModelInfoFormatting.contextWindow(contextWindow)
    }

    public var isFreeModel: Bool {
        id.contains(":free") || (pricing.inputPer1k == 0 && pricing.outputPer1k == 0)
    }

    /// Subscription-quota models (CLI channels) — not OpenRouter-style free tier.
    public var isQuotaModel: Bool {
        switch pingTransport {
        case .openRouter:
            false
        case .nousResearch, .claudeCLI, .geminiCLI, .openCode:
            !isFreeModel
        }
    }
}

public enum Capability: String, Codable, CaseIterable, Sendable, Hashable {
    case tools
    case vision
    case reasoning
    case streaming
}

public enum Tier: String, Codable, CaseIterable, Sendable, Hashable {
    case light
    case standard
    case deep
}

public struct ModelPricing: Codable, Sendable, Hashable {
    public let inputPer1k: Double
    public let outputPer1k: Double

    public init(inputPer1k: Double, outputPer1k: Double) {
        self.inputPer1k = inputPer1k
        self.outputPer1k = outputPer1k
    }

    public var formatted: String {
        String(format: "$%.2f / $%.2f", inputPer1k, outputPer1k)
    }
}

public enum BenchmarkSuitability: Sendable, Equatable {
    case recommended
    case limited
    case notSuitable
}

public struct BenchRankScore: Sendable, Comparable, Equatable {
    public let total: Double
    public let suitability: BenchmarkSuitability

    public init(total: Double, suitability: BenchmarkSuitability) {
        self.total = total
        self.suitability = suitability
    }

    public static func < (lhs: BenchRankScore, rhs: BenchRankScore) -> Bool {
        lhs.total < rhs.total
    }

    public static func compute(
        info: ModelInfo,
        pingResult: ModelHealthPingResult,
        maxP50: Double
    ) -> BenchRankScore {
        guard case .live = pingResult.status else {
            return BenchRankScore(total: 0, suitability: .notSuitable)
        }

        let hasTools = info.capabilities.contains(.tools)
        let hasContext = info.contextWindow >= 32000
        let speedScore = maxP50 > 0 ? (1 - pingResult.p50 / maxP50) * 800 : 0
        let toolsScore = hasTools ? 600.0 : 0
        let freeScore = ModelHealthFreeTier.isFree(catalog: info, pingResult: pingResult) ? 400.0 : 0
        let contextScore = hasContext ? 200.0 : 0
        let suitability: BenchmarkSuitability = (hasTools && hasContext) ? .recommended : .limited

        return BenchRankScore(
            total: speedScore + toolsScore + freeScore + contextScore,
            suitability: suitability
        )
    }

    public static func sortResults(
        _ results: [ModelHealthPingResult],
        registry: [ModelInfo]
    ) -> [ModelHealthPingResult] {
        let maxP50 = results.map(\.p50).max() ?? 1
        return results.sorted { lhs, rhs in
            let infoL = registry.first { $0.id == lhs.id }
            let infoR = registry.first { $0.id == rhs.id }
            let scoreL = infoL.map {
                compute(info: $0, pingResult: lhs, maxP50: maxP50)
            } ?? BenchRankScore(total: 0, suitability: .notSuitable)
            let scoreR = infoR.map {
                compute(info: $0, pingResult: rhs, maxP50: maxP50)
            } ?? BenchRankScore(total: 0, suitability: .notSuitable)

            return compareRankedRows(
                lhsLabel: lhs.label,
                lhsP50: lhs.p50,
                lhsCost: lhs.cost,
                lhsResponded: lhs.responded,
                lhsModelMatched: lhs.modelMatched,
                lhsNotContentFiltered: lhs.notContentFiltered,
                lhsIsFree: ModelHealthFreeTier.isFree(catalog: infoL, pingResult: lhs),
                lhsHasContext: (infoL?.contextWindow ?? 0) >= 32000,
                lhsHasTools: infoL?.capabilities.contains(.tools) ?? false,
                lhsSuitability: scoreL.suitability,
                rhsLabel: rhs.label,
                rhsP50: rhs.p50,
                rhsCost: rhs.cost,
                rhsResponded: rhs.responded,
                rhsModelMatched: rhs.modelMatched,
                rhsNotContentFiltered: rhs.notContentFiltered,
                rhsIsFree: ModelHealthFreeTier.isFree(catalog: infoR, pingResult: rhs),
                rhsHasContext: (infoR?.contextWindow ?? 0) >= 32000,
                rhsHasTools: infoR?.capabilities.contains(.tools) ?? false,
                rhsSuitability: scoreR.suitability
            )
        }
    }

    public static func signalPassCount(info: ModelInfo, pingResult: ModelHealthPingResult) -> Int {
        var count = 0
        if pingResult.responded { count += 1 }
        if pingResult.modelMatched { count += 1 }
        if pingResult.notContentFiltered { count += 1 }
        if info.capabilities.contains(.tools) { count += 1 }
        if ModelHealthFreeTier.isFree(catalog: info, pingResult: pingResult) { count += 1 }
        if info.contextWindow >= 32000 { count += 1 }
        return count
    }

    public static func signalPassCount(row: SnapshotRow) -> Int {
        var count = 0
        if row.responded { count += 1 }
        if row.modelMatched { count += 1 }
        if row.notContentFiltered { count += 1 }
        if row.hasTools { count += 1 }
        if row.isFree { count += 1 }
        if row.hasContext { count += 1 }
        return count
    }

    public static func sortSnapshotRows(_ rows: [SnapshotRow]) -> [SnapshotRow] {
        rows.sorted { lhs, rhs in
            compareRankedRows(
                lhsLabel: lhs.label,
                lhsP50: lhs.p50,
                lhsCost: lhs.cost,
                lhsResponded: lhs.responded,
                lhsModelMatched: lhs.modelMatched,
                lhsNotContentFiltered: lhs.notContentFiltered,
                lhsIsFree: lhs.isFree,
                lhsHasContext: lhs.hasContext,
                lhsHasTools: lhs.hasTools,
                lhsSuitability: ModelHealthSnapshot.suitability(from: lhs.suitability),
                rhsLabel: rhs.label,
                rhsP50: rhs.p50,
                rhsCost: rhs.cost,
                rhsResponded: rhs.responded,
                rhsModelMatched: rhs.modelMatched,
                rhsNotContentFiltered: rhs.notContentFiltered,
                rhsIsFree: rhs.isFree,
                rhsHasContext: rhs.hasContext,
                rhsHasTools: rhs.hasTools,
                rhsSuitability: ModelHealthSnapshot.suitability(from: rhs.suitability)
            )
        }
    }

    /// Sort key order: Bench? → Latency → Free → Ctx → Clear → Tools → Rsp → Match → cost → name.
    static func compareRankedRows(
        lhsLabel: String,
        lhsP50: Double,
        lhsCost: Double,
        lhsResponded: Bool,
        lhsModelMatched: Bool,
        lhsNotContentFiltered: Bool,
        lhsIsFree: Bool,
        lhsHasContext: Bool,
        lhsHasTools: Bool,
        lhsSuitability: BenchmarkSuitability,
        rhsLabel: String,
        rhsP50: Double,
        rhsCost: Double,
        rhsResponded: Bool,
        rhsModelMatched: Bool,
        rhsNotContentFiltered: Bool,
        rhsIsFree: Bool,
        rhsHasContext: Bool,
        rhsHasTools: Bool,
        rhsSuitability: BenchmarkSuitability
    ) -> Bool {
        let rankL = suitabilityRank(lhsSuitability)
        let rankR = suitabilityRank(rhsSuitability)
        if rankL != rankR { return rankL < rankR }

        if preferLatencyOrdered(lhsP50, rhsP50) { return true }
        if preferLatencyOrdered(rhsP50, lhsP50) { return false }

        if lhsIsFree != rhsIsFree { return lhsIsFree }
        if lhsHasContext != rhsHasContext { return lhsHasContext }
        if lhsNotContentFiltered != rhsNotContentFiltered { return lhsNotContentFiltered }
        if lhsHasTools != rhsHasTools { return lhsHasTools }
        if lhsResponded != rhsResponded { return lhsResponded }
        if lhsModelMatched != rhsModelMatched { return lhsModelMatched }

        if lhsCost != rhsCost { return lhsCost < rhsCost }

        return lhsLabel < rhsLabel
    }

    /// Rows with measured latency rank above p50 == 0 within the same Bench? tier.
    private static func preferLatencyOrdered(_ lhsP50: Double, _ rhsP50: Double) -> Bool {
        guard lhsP50 != rhsP50 else { return false }
        let lhsHas = lhsP50 > 0
        let rhsHas = rhsP50 > 0
        if lhsHas != rhsHas { return lhsHas }
        return lhsP50 < rhsP50
    }

    static func suitabilityRank(_ suitability: BenchmarkSuitability) -> Int {
        switch suitability {
        case .recommended: 0
        case .limited: 1
        case .notSuitable: 2
        }
    }
}

public enum ModelHealthPingStatus: Sendable, Equatable {
    case live
    case stale
    case timeout
    case contentFilter
    case mismatch(actual: String)
    case noCredit
    case error(String)

    public var statusDetail: String? {
        switch self {
        case let .error(message): message
        case .timeout: "Timeout"
        case .contentFilter: "Content filtered"
        case .noCredit: "No credit"
        case .live, .stale, .mismatch: nil
        }
    }
}

public struct ModelHealthPingResult: Identifiable, Sendable, Equatable {
    public let id: String
    public let label: String
    public let status: ModelHealthPingStatus
    public let respondedModelId: String?
    public let providerName: String?
    public let testedProviderLabel: String?
    public let modelAlias: String?
    public let routingStrategy: String?
    public let attemptCount: Int
    public let finishReason: String?
    public let latencySamples: [Double]
    public let serverLatency: Double?
    public let generationTime: Double?
    public let promptTokens: Int
    public let completionTokens: Int
    public let reasoningTokens: Int
    public let cachedTokens: Int
    public let cost: Double
    public let upstreamCost: Double?

    public init(
        id: String,
        label: String,
        status: ModelHealthPingStatus,
        respondedModelId: String? = nil,
        providerName: String? = nil,
        testedProviderLabel: String? = nil,
        modelAlias: String? = nil,
        routingStrategy: String? = nil,
        attemptCount: Int = 1,
        finishReason: String? = nil,
        latencySamples: [Double] = [],
        serverLatency: Double? = nil,
        generationTime: Double? = nil,
        promptTokens: Int = 0,
        completionTokens: Int = 0,
        reasoningTokens: Int = 0,
        cachedTokens: Int = 0,
        cost: Double = 0,
        upstreamCost: Double? = nil
    ) {
        self.id = id
        self.label = label
        self.status = status
        self.respondedModelId = respondedModelId
        self.providerName = providerName
        self.testedProviderLabel = testedProviderLabel
        self.modelAlias = modelAlias
        self.routingStrategy = routingStrategy
        self.attemptCount = attemptCount
        self.finishReason = finishReason
        self.latencySamples = latencySamples
        self.serverLatency = serverLatency
        self.generationTime = generationTime
        self.promptTokens = promptTokens
        self.completionTokens = completionTokens
        self.reasoningTokens = reasoningTokens
        self.cachedTokens = cachedTokens
        self.cost = cost
        self.upstreamCost = upstreamCost
    }

    public var p50: Double {
        percentile(latencySamples, 0.50)
    }

    public var p95: Double {
        percentile(latencySamples, 0.95)
    }

    public var p99: Double {
        percentile(latencySamples, 0.99)
    }

    public var tokensPerSec: Double {
        guard p50 > 0 else { return 0 }
        return Double(completionTokens) / (p50 / 1000)
    }

    public var cacheHitRate: Double {
        guard promptTokens > 0 else { return 0 }
        return Double(cachedTokens) / Double(promptTokens)
    }

    /// Ping returned measurable latency (got a response).
    public var responded: Bool {
        !latencySamples.isEmpty
    }

    /// Requested model slug matched the provider response (OpenRouter routing check).
    public var modelMatched: Bool {
        switch status {
        case .live, .contentFilter: true
        case .mismatch: false
        case .timeout, .noCredit, .error, .stale: false
        }
    }

    /// Response was not blocked by a content filter.
    public var notContentFiltered: Bool {
        status != .contentFilter
    }
}

/// Whether a model counts as free for leaderboard signals — catalog tier or zero measured cost on a live ping.
public enum ModelHealthFreeTier {
    public static func isFree(catalog info: ModelInfo?, pingResult: ModelHealthPingResult) -> Bool {
        if case .noCredit = pingResult.status { return false }
        if info?.isQuotaModel == true {
            guard case .live = pingResult.status else { return false }
            return pingResult.cost == 0
        }
        if info?.isFreeModel == true { return true }
        guard case .live = pingResult.status else { return false }
        return pingResult.cost == 0
    }
}

public enum ModelInfoFormatting {
    public static func contextWindow(_ value: Int) -> String {
        if value >= 1_000_000 {
            let millions = Double(value) / 1_000_000
            if millions.truncatingRemainder(dividingBy: 1) == 0 {
                return "\(Int(millions))M"
            }
            return String(format: "%.1fM", millions)
        }
        if value >= 1000 {
            let thousands = Double(value) / 1000
            if thousands.truncatingRemainder(dividingBy: 1) == 0 {
                return "\(Int(thousands))K"
            }
            return String(format: "%.0fK", thousands)
        }
        return "\(value)"
    }
}

public func percentile(_ samples: [Double], _ percentileValue: Double) -> Double {
    guard !samples.isEmpty else { return 0 }
    let sorted = samples.sorted()
    let clamped = min(max(percentileValue, 0), 1)
    let index = Int((Double(sorted.count - 1) * clamped).rounded())
    return sorted[index]
}

public enum ModelHealthStatusResolver {
    public static func resolve(
        requestedModelId: String,
        completion: OpenRouterChatCompletion
    ) -> ModelHealthPingStatus {
        if completion.finishReason == "content_filter" {
            return .contentFilter
        }
        if !modelsMatch(requested: requestedModelId, responded: completion.model) {
            return .mismatch(actual: completion.model)
        }
        return .live
    }

    /// OpenRouter often returns versioned slugs (e.g. `claude-3-haiku-20240307` for `claude-3-haiku`).
    public static func modelsMatch(requested: String, responded: String) -> Bool {
        if requested == responded { return true }
        if responded.hasPrefix(requested + "-") { return true }
        if responded.hasPrefix(requested + ":") { return true }
        return false
    }
}
