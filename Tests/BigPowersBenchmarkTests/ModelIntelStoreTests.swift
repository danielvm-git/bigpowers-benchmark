@testable import BigPowersBenchmarkKit
import Foundation
import Testing

@Suite("ModelHealthErrorClassifier")
struct ModelHealthErrorClassifierTests {
    @Test("HTTP 402 maps to noCredit")
    func http402() {
        #expect(ModelHealthErrorClassifier.isNoCredit(statusCode: 402, message: "Payment required"))
        #expect(ModelHealthErrorClassifier.pingStatus(statusCode: 402, message: "Payment required") == .noCredit)
    }

    @Test("message patterns map to noCredit")
    func messagePatterns() {
        #expect(ModelHealthErrorClassifier.isNoCredit(message: "You have no credits remaining"))
        #expect(ModelHealthErrorClassifier.isNoCredit(message: "Insufficient balance for request"))
        #expect(ModelHealthErrorClassifier.pingStatus(message: "quota exceeded") == .noCredit)
    }

    @Test("generic errors stay error status")
    func genericError() {
        if case let .error(message) = ModelHealthErrorClassifier.pingStatus(message: "503 Unavailable") {
            #expect(message == "503 Unavailable")
        } else {
            Issue.record("Expected generic error")
        }
    }
}

@Suite("ModelIntelDerivation")
struct ModelIntelDerivationTests {
    private func profile(
        lastPingStatus: String? = nil,
        lastMeasuredCost: Double = 0,
        catalogIsFree: Bool = false,
        catalogIsQuota: Bool = false,
        hasTools: Bool = true,
        hasContext: Bool = true,
        modelMatched: Bool = true,
        consecutiveLive: Int = 0,
        consecutiveFail: Int = 0
    ) -> ModelIntelProfile {
        var profile = ModelIntelProfile(
            modelId: "test/model",
            label: "Test Model",
            lastPingStatus: lastPingStatus,
            lastMeasuredCost: lastMeasuredCost,
            consecutiveLive: consecutiveLive,
            consecutiveFail: consecutiveFail,
            hasTools: hasTools,
            hasContext: hasContext,
            modelMatched: modelMatched,
            catalogIsFree: catalogIsFree,
            catalogIsQuota: catalogIsQuota
        )
        ModelIntelDerivation.recompute(&profile)
        return profile
    }

    @Test("noCredit excludes smartFree")
    func noCreditNotSmartFree() {
        let profile = profile(
            lastPingStatus: ModelHealthSnapshot.statusString(.noCredit),
            catalogIsFree: true
        )
        #expect(!profile.smartFree)
        #expect(!profile.benchCandidate)
    }

    @Test("runtime free quota model is smartFree")
    func runtimeFreeQuotaModel() {
        let profile = profile(
            lastPingStatus: ModelHealthSnapshot.statusString(.live),
            lastMeasuredCost: 0,
            catalogIsQuota: true
        )
        #expect(profile.isRuntimeFree)
        #expect(profile.smartFree)
    }

    @Test("live ping with tools and context is bench candidate")
    func benchCandidate() {
        let profile = profile(
            lastPingStatus: ModelHealthSnapshot.statusString(.live),
            consecutiveLive: 1,
            consecutiveFail: 0
        )
        #expect(profile.benchCandidate)
    }

    @Test("catalog free without ping stays smartFree")
    func catalogFreeUntested() {
        let profile = profile(catalogIsFree: true, catalogIsQuota: false)
        #expect(profile.smartFree)
    }
}

@Suite("ModelIntelStore")
struct ModelIntelStoreTests {
    @Test("ingest snapshot updates smartFree and benchCandidate")
    func ingestSnapshot() throws {
        let cacheURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathComponent("model-intel.json")
        let store = ModelIntelStore(cacheURL: cacheURL)

        let model = ModelInfo(
            id: "opencode:opencode/big-pickle",
            name: "OpenCode Zen Big Pickle",
            provider: "opencode",
            contextWindow: 128_000,
            tier: .deep,
            capabilities: [.tools, .streaming],
            pricing: ModelPricing(inputPer1k: 1, outputPer1k: 1),
            pingTransport: .openCode,
            resolvedModelId: "opencode/big-pickle"
        )

        let ping = ModelHealthPingResult(
            id: model.id,
            label: model.name,
            status: .live,
            testedProviderLabel: "OpenCode Zen",
            modelAlias: "opencode/big-pickle",
            latencySamples: [120],
            cost: 0
        )

        let snapshot = ModelHealthSnapshot.make(
            from: [ping],
            registry: [model],
            scope: .smartFree
        )

        try store.ingest(snapshot: snapshot, registry: [model])

        let profile = store.profile(for: model.id)
        #expect(profile?.smartFree == true)
        #expect(profile?.benchCandidate == true)
        #expect(profile?.isRuntimeFree == true)
    }

    @Test("smartFreeModels falls back to catalog free when intel is empty")
    func smartFreeFallback() {
        let store = ModelIntelStore(
            cacheURL: FileManager.default.temporaryDirectory
                .appendingPathComponent(UUID().uuidString)
                .appendingPathComponent("model-intel.json")
        )
        let free = ModelInfo(
            id: "meta-llama/llama-3.3-70b-instruct:free",
            name: "Llama Free",
            provider: "meta-llama",
            contextWindow: 128_000,
            tier: .deep,
            capabilities: [.streaming],
            pricing: ModelPricing(inputPer1k: 0, outputPer1k: 0)
        )
        let quota = StaticModelCatalogs.openCode[0]

        let targets = store.smartFreeModels(from: [free, quota])
        #expect(targets.count == 1)
        #expect(targets[0].id == free.id)
    }
}

@Suite("ModelInfo quota helpers")
struct ModelInfoQuotaTests {
    @Test("isQuotaModel flags CLI subscription models")
    func quotaModel() throws {
        #expect(StaticModelCatalogs.claudeCLI[0].isQuotaModel)
        #expect(try !(#require(StaticModelCatalogs.openCode.first { $0.id.contains("free") }?.isQuotaModel)))
    }
}

@Suite("BenchFailureRow")
struct BenchFailureRowTests {
    @Test("describe extracts runner error phase")
    func describeRunnerError() {
        let described = BenchFailureRow.describe(error: RunnerError.timeout(phase: .grading))
        #expect(described.kind == "timeout")
        #expect(described.phase == "grading")
    }
}
