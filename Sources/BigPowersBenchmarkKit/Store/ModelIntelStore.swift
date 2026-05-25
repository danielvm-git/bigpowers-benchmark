import Foundation
import Observation

public struct ModelIntelProfile: Codable, Sendable, Equatable {
    public var modelId: String
    public var label: String
    public var testedProviderLabel: String?
    public var modelAlias: String?
    public var pingTransport: String?

    public var lastPingAt: Date?
    public var lastPingStatus: String?
    public var lastErrorDetail: String?
    public var lastP50: Double
    public var lastMeasuredCost: Double
    public var consecutiveLive: Int
    public var consecutiveFail: Int
    public var totalPings: Int

    public var lastBenchAt: Date?
    public var lastBenchScore: Double?
    public var lastBenchError: String?
    public var benchSuccessCount: Int
    public var benchFailCount: Int

    public var hasTools: Bool
    public var hasContext: Bool
    public var modelMatched: Bool
    public var notContentFiltered: Bool
    public var catalogIsFree: Bool
    public var catalogIsQuota: Bool

    public var isRuntimeFree: Bool
    public var smartFree: Bool
    public var benchCandidate: Bool

    public init(
        modelId: String,
        label: String,
        testedProviderLabel: String? = nil,
        modelAlias: String? = nil,
        pingTransport: String? = nil,
        lastPingAt: Date? = nil,
        lastPingStatus: String? = nil,
        lastErrorDetail: String? = nil,
        lastP50: Double = 0,
        lastMeasuredCost: Double = 0,
        consecutiveLive: Int = 0,
        consecutiveFail: Int = 0,
        totalPings: Int = 0,
        lastBenchAt: Date? = nil,
        lastBenchScore: Double? = nil,
        lastBenchError: String? = nil,
        benchSuccessCount: Int = 0,
        benchFailCount: Int = 0,
        hasTools: Bool = false,
        hasContext: Bool = false,
        modelMatched: Bool = false,
        notContentFiltered: Bool = true,
        catalogIsFree: Bool = false,
        catalogIsQuota: Bool = false,
        isRuntimeFree: Bool = false,
        smartFree: Bool = false,
        benchCandidate: Bool = false
    ) {
        self.modelId = modelId
        self.label = label
        self.testedProviderLabel = testedProviderLabel
        self.modelAlias = modelAlias
        self.pingTransport = pingTransport
        self.lastPingAt = lastPingAt
        self.lastPingStatus = lastPingStatus
        self.lastErrorDetail = lastErrorDetail
        self.lastP50 = lastP50
        self.lastMeasuredCost = lastMeasuredCost
        self.consecutiveLive = consecutiveLive
        self.consecutiveFail = consecutiveFail
        self.totalPings = totalPings
        self.lastBenchAt = lastBenchAt
        self.lastBenchScore = lastBenchScore
        self.lastBenchError = lastBenchError
        self.benchSuccessCount = benchSuccessCount
        self.benchFailCount = benchFailCount
        self.hasTools = hasTools
        self.hasContext = hasContext
        self.modelMatched = modelMatched
        self.notContentFiltered = notContentFiltered
        self.catalogIsFree = catalogIsFree
        self.catalogIsQuota = catalogIsQuota
        self.isRuntimeFree = isRuntimeFree
        self.smartFree = smartFree
        self.benchCandidate = benchCandidate
    }
}

public enum ModelIntelDerivation {
    public static func smartFree(for profile: ModelIntelProfile) -> Bool {
        if profile.lastPingStatus == ModelHealthSnapshot.statusString(.noCredit) {
            return false
        }
        if profile.isRuntimeFree {
            return true
        }
        if profile.catalogIsFree, !profile.catalogIsQuota {
            if profile.lastPingStatus == nil {
                return true
            }
            if profile.lastPingStatus == ModelHealthSnapshot.statusString(.live) {
                return profile.lastMeasuredCost == 0
            }
            return profile.lastPingStatus != ModelHealthSnapshot.statusString(.noCredit)
        }
        return false
    }

    public static func benchCandidate(for profile: ModelIntelProfile) -> Bool {
        guard profile.lastPingStatus == ModelHealthSnapshot.statusString(.live) else { return false }
        guard profile.hasTools, profile.hasContext else { return false }
        guard profile.modelMatched, profile.notContentFiltered else { return false }
        guard profile.consecutiveFail < 2 else { return false }
        guard profile.consecutiveLive >= 1 else { return false }
        return true
    }

    public static func recompute(_ profile: inout ModelIntelProfile) {
        profile.isRuntimeFree = profile.lastPingStatus == ModelHealthSnapshot.statusString(.live)
            && profile.lastMeasuredCost == 0
        profile.smartFree = smartFree(for: profile)
        profile.benchCandidate = benchCandidate(for: profile)
    }
}

@Observable
public final class ModelIntelStore: @unchecked Sendable {
    public static let defaultCacheURL: URL = {
        let appSupport = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first ?? FileManager.default.homeDirectoryForCurrentUser
        let bundleID = Bundle.main.bundleIdentifier ?? "BigPowersBenchmark"
        return appSupport
            .appendingPathComponent(bundleID)
            .appendingPathComponent("model-intel.json")
    }()

    public let cacheURL: URL
    public private(set) var profiles: [String: ModelIntelProfile] = [:]

    public init(cacheURL: URL = ModelIntelStore.defaultCacheURL) {
        self.cacheURL = cacheURL
    }

    public func profile(for modelId: String) -> ModelIntelProfile? {
        profiles[modelId]
    }

    public var smartFreeCount: Int {
        profiles.values.filter(\.smartFree).count
    }

    public var benchCandidateCount: Int {
        profiles.values.filter(\.benchCandidate).count
    }

    public func loadFromDisk() throws {
        guard FileManager.default.fileExists(atPath: cacheURL.path) else {
            profiles = [:]
            return
        }
        let data = try Data(contentsOf: cacheURL)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        profiles = try decoder.decode([String: ModelIntelProfile].self, from: data)
    }

    public func saveToDisk() throws {
        let directory = cacheURL.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(profiles)
        try data.write(to: cacheURL, options: .atomic)
    }

    public func ingest(snapshot: ModelHealthSnapshot, registry: [ModelInfo]) throws {
        for row in snapshot.rows {
            let info = registry.first { $0.id == row.modelId }
            ingestSnapshotRow(row, info: info, at: snapshot.timestamp)
        }
        try saveToDisk()
    }

    public func ingest(row: BenchRow) throws {
        var profile = profiles[row.modelId] ?? baseProfile(
            modelId: row.modelId,
            label: row.modelId,
            info: nil
        )
        profile.lastBenchAt = row.timestamp
        profile.lastBenchScore = row.overallScore
        profile.lastBenchError = nil
        profile.benchSuccessCount += 1
        ModelIntelDerivation.recompute(&profile)
        profiles[row.modelId] = profile
        try saveToDisk()
    }

    public func ingest(failure: BenchFailureRow) throws {
        var profile = profiles[failure.modelId] ?? baseProfile(
            modelId: failure.modelId,
            label: failure.modelId,
            info: nil
        )
        profile.lastBenchAt = failure.timestamp
        profile.lastBenchError = failure.errorMessage
        profile.benchFailCount += 1
        ModelIntelDerivation.recompute(&profile)
        profiles[failure.modelId] = profile
        try saveToDisk()
    }

    public func seed(from registry: [ModelInfo]) {
        for info in registry where profiles[info.id] == nil {
            var profile = baseProfile(modelId: info.id, label: info.name, info: info)
            ModelIntelDerivation.recompute(&profile)
            profiles[info.id] = profile
        }
    }

    public func smartFreeModels(from registry: [ModelInfo]) -> [ModelInfo] {
        if profiles.isEmpty {
            return registry.filter { $0.isFreeModel && !$0.isQuotaModel }
        }
        let ids = Set(profiles.values.filter(\.smartFree).map(\.modelId))
        return registry.filter { ids.contains($0.id) }
    }

    public func benchCandidateModels(from registry: [ModelInfo]) -> [ModelInfo] {
        let ids = Set(profiles.values.filter(\.benchCandidate).map(\.modelId))
        return registry.filter { ids.contains($0.id) }
    }

    func ingestSnapshotRow(_ row: SnapshotRow, info: ModelInfo?, at timestamp: Date) {
        var profile = profiles[row.modelId] ?? baseProfile(
            modelId: row.modelId,
            label: row.label,
            info: info
        )
        profile.label = row.label
        profile.testedProviderLabel = row.testedProviderLabel
        profile.modelAlias = row.modelAlias
        profile.pingTransport = row.pingTransport
        profile.lastPingAt = timestamp
        profile.lastPingStatus = row.status
        profile.lastErrorDetail = row.errorDetail
        profile.lastP50 = row.p50
        profile.lastMeasuredCost = row.cost
        profile.totalPings += 1
        profile.hasTools = row.hasTools
        profile.hasContext = row.hasContext
        profile.modelMatched = row.modelMatched
        profile.notContentFiltered = row.notContentFiltered
        if let info {
            profile.catalogIsFree = info.isFreeModel
            profile.catalogIsQuota = info.isQuotaModel
        }

        if row.status == ModelHealthSnapshot.statusString(.live) {
            profile.consecutiveLive += 1
            profile.consecutiveFail = 0
        } else {
            profile.consecutiveFail += 1
            profile.consecutiveLive = 0
        }

        ModelIntelDerivation.recompute(&profile)
        profiles[row.modelId] = profile
    }

    private func baseProfile(modelId: String, label: String, info: ModelInfo?) -> ModelIntelProfile {
        ModelIntelProfile(
            modelId: modelId,
            label: label,
            testedProviderLabel: info?.pingTransport.channelDisplayName,
            modelAlias: info?.apiModelId,
            pingTransport: info?.pingTransport.rawValue,
            hasTools: info?.capabilities.contains(.tools) ?? false,
            hasContext: (info?.contextWindow ?? 0) >= 32000,
            catalogIsFree: info?.isFreeModel ?? false,
            catalogIsQuota: info?.isQuotaModel ?? false
        )
    }
}
