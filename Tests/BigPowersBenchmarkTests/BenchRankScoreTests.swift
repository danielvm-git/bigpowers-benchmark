@testable import BigPowersBenchmarkKit
import Foundation
import Testing

@Suite("BenchRankScore")
struct BenchRankScoreTests {
    private func modelInfo(
        id: String = "openai/gpt-4o",
        contextWindow: Int = 128_000,
        capabilities: [Capability] = [.tools],
        pricing: ModelPricing = ModelPricing(inputPer1k: 0, outputPer1k: 0)
    ) -> ModelInfo {
        ModelInfo(
            id: id,
            name: "Test Model",
            provider: "openai",
            contextWindow: contextWindow,
            tier: .deep,
            capabilities: capabilities,
            pricing: pricing
        )
    }

    private func pingResult(
        id: String = "openai/gpt-4o",
        status: ModelHealthPingStatus = .live,
        latencyMs: Double = 100,
        cost: Double = 0
    ) -> ModelHealthPingResult {
        ModelHealthPingResult(
            id: id,
            label: "Test Model",
            status: status,
            latencySamples: latencyMs > 0 ? [latencyMs] : [],
            cost: cost
        )
    }

    @Test("live + tools + ctx128K is recommended")
    func recommendedSuitability() {
        let score = BenchRankScore.compute(
            info: modelInfo(),
            pingResult: pingResult(),
            maxP50: 200
        )
        #expect(score.suitability == .recommended)
        #expect(score.total > 0)
    }

    @Test("live without tools is limited")
    func limitedWithoutTools() {
        let score = BenchRankScore.compute(
            info: modelInfo(capabilities: [.streaming]),
            pingResult: pingResult(),
            maxP50: 200
        )
        #expect(score.suitability == .limited)
    }

    @Test("live with small context is limited")
    func limitedWithoutContext() {
        let score = BenchRankScore.compute(
            info: modelInfo(contextWindow: 8000),
            pingResult: pingResult(),
            maxP50: 200
        )
        #expect(score.suitability == .limited)
    }

    @Test("timeout is not suitable with zero score")
    func timeoutNotSuitable() {
        let score = BenchRankScore.compute(
            info: modelInfo(),
            pingResult: pingResult(status: .timeout, latencyMs: 0),
            maxP50: 200
        )
        #expect(score.suitability == .notSuitable)
        #expect(score.total == 0)
    }

    @Test("recommended beats limited at same speed")
    func recommendedBeatsLimited() {
        let maxP50 = 200.0
        let recommended = BenchRankScore.compute(
            info: modelInfo(),
            pingResult: pingResult(latencyMs: 100),
            maxP50: maxP50
        )
        let limited = BenchRankScore.compute(
            info: modelInfo(capabilities: [.streaming]),
            pingResult: pingResult(latencyMs: 100),
            maxP50: maxP50
        )
        #expect(recommended > limited)
    }

    @Test("faster model beats slower at same suitability")
    func fasterBeatsSlower() {
        let maxP50 = 400.0
        let fast = BenchRankScore.compute(
            info: modelInfo(),
            pingResult: pingResult(latencyMs: 100),
            maxP50: maxP50
        )
        let slow = BenchRankScore.compute(
            info: modelInfo(),
            pingResult: pingResult(latencyMs: 300),
            maxP50: maxP50
        )
        #expect(fast > slow)
    }

    @Test("free beats paid at same speed and tools")
    func freeBeatsPaid() {
        let maxP50 = 200.0
        let free = BenchRankScore.compute(
            info: modelInfo(pricing: ModelPricing(inputPer1k: 0, outputPer1k: 0)),
            pingResult: pingResult(latencyMs: 100),
            maxP50: maxP50
        )
        let paid = BenchRankScore.compute(
            info: modelInfo(pricing: ModelPricing(inputPer1k: 5, outputPer1k: 15)),
            pingResult: pingResult(latencyMs: 100, cost: 0.01),
            maxP50: maxP50
        )
        #expect(free > paid)
        #expect(free.total - paid.total == 400)
    }

    @Test("32K context beats 8K at same other signals")
    func contextBeatsSmallWindow() {
        let maxP50 = 200.0
        let largeContext = BenchRankScore.compute(
            info: modelInfo(contextWindow: 128_000),
            pingResult: pingResult(latencyMs: 100),
            maxP50: maxP50
        )
        let smallContext = BenchRankScore.compute(
            info: modelInfo(contextWindow: 8000),
            pingResult: pingResult(latencyMs: 100),
            maxP50: maxP50
        )
        #expect(largeContext > smallContext)
        #expect(largeContext.total - smallContext.total == 200)
    }

    @Test("signalPassCount counts all six signals")
    func signalPassCountAllSix() {
        let info = modelInfo()
        let live = pingResult()
        #expect(BenchRankScore.signalPassCount(info: info, pingResult: live) == 6)

        let timeout = pingResult(status: .timeout, latencyMs: 0)
        #expect(BenchRankScore.signalPassCount(info: info, pingResult: timeout) == 4)
    }
}

@Suite("ModelHealthViewModel bench rank sort")
struct BenchRankSortTests {
    @Test("sortResults orders by bench latency free ctx clear tools rsp match cost name")
    func sortByExplicitCriteria() {
        let registry = [
            ModelInfo(
                id: "fast-free",
                name: "Fast Free",
                provider: "openai",
                contextWindow: 128_000,
                tier: .deep,
                capabilities: [.tools],
                pricing: ModelPricing(inputPer1k: 0, outputPer1k: 0)
            ),
            ModelInfo(
                id: "slow-free",
                name: "Slow Free",
                provider: "openai",
                contextWindow: 128_000,
                tier: .deep,
                capabilities: [.tools],
                pricing: ModelPricing(inputPer1k: 0, outputPer1k: 0)
            ),
            ModelInfo(
                id: "fast-paid",
                name: "Fast Paid",
                provider: "openai",
                contextWindow: 128_000,
                tier: .deep,
                capabilities: [.tools],
                pricing: ModelPricing(inputPer1k: 5, outputPer1k: 15)
            ),
            ModelInfo(
                id: "limited",
                name: "Limited",
                provider: "openai",
                contextWindow: 128_000,
                tier: .deep,
                capabilities: [.streaming],
                pricing: ModelPricing(inputPer1k: 0, outputPer1k: 0)
            ),
            ModelInfo(
                id: "timeout",
                name: "Timeout",
                provider: "openai",
                contextWindow: 128_000,
                tier: .deep,
                capabilities: [.tools],
                pricing: ModelPricing(inputPer1k: 0, outputPer1k: 0)
            ),
        ]

        let results = [
            ModelHealthPingResult(id: "timeout", label: "Timeout", status: .timeout),
            ModelHealthPingResult(id: "limited", label: "Limited", status: .live, latencySamples: [50]),
            ModelHealthPingResult(id: "fast-paid", label: "Fast Paid", status: .live, latencySamples: [50]),
            ModelHealthPingResult(id: "slow-free", label: "Slow Free", status: .live, latencySamples: [300]),
            ModelHealthPingResult(id: "fast-free", label: "Fast Free", status: .live, latencySamples: [100]),
        ]

        let sorted = BenchRankScore.sortResults(results, registry: registry)
        #expect(sorted.map(\.id) == ["fast-paid", "fast-free", "slow-free", "limited", "timeout"])
    }

    @Test("free beats paid at same bench suitability and latency")
    func signalsBreakTie() {
        let registry = [
            ModelInfo(
                id: "paid",
                name: "Paid",
                provider: "openai",
                contextWindow: 128_000,
                tier: .deep,
                capabilities: [.tools],
                pricing: ModelPricing(inputPer1k: 5, outputPer1k: 15)
            ),
            ModelInfo(
                id: "free",
                name: "Free",
                provider: "openai",
                contextWindow: 128_000,
                tier: .deep,
                capabilities: [.tools],
                pricing: ModelPricing(inputPer1k: 0, outputPer1k: 0)
            ),
        ]

        let results = [
            ModelHealthPingResult(id: "paid", label: "Paid", status: .live, latencySamples: [100], cost: 0.01),
            ModelHealthPingResult(id: "free", label: "Free", status: .live, latencySamples: [100], cost: 0),
        ]

        let sorted = BenchRankScore.sortResults(results, registry: registry)
        #expect(sorted.map(\.id) == ["free", "paid"])
    }

    @Test("live beats dead even with fewer registry signals")
    func liveBeatsDead() {
        let registry = [
            ModelInfo(
                id: "dead",
                name: "Dead",
                provider: "openai",
                contextWindow: 128_000,
                tier: .deep,
                capabilities: [.tools],
                pricing: ModelPricing(inputPer1k: 0, outputPer1k: 0)
            ),
            ModelInfo(
                id: "alive",
                name: "Alive",
                provider: "openai",
                contextWindow: 8000,
                tier: .deep,
                capabilities: [.streaming],
                pricing: ModelPricing(inputPer1k: 0, outputPer1k: 0)
            ),
        ]

        let results = [
            ModelHealthPingResult(id: "dead", label: "Dead", status: .timeout),
            ModelHealthPingResult(id: "alive", label: "Alive", status: .live, latencySamples: [500]),
        ]

        let sorted = BenchRankScore.sortResults(results, registry: registry)
        #expect(sorted.map(\.id) == ["alive", "dead"])
    }

    @Test("not suitable with latency ranks before not suitable without")
    func measuredLatencyBeforeZeroInNotSuitable() {
        let registry = [
            ModelInfo(
                id: "mismatch-fast",
                name: "Mismatch Fast",
                provider: "poolside",
                contextWindow: 131_000,
                tier: .deep,
                capabilities: [.tools],
                pricing: ModelPricing(inputPer1k: 0, outputPer1k: 0)
            ),
            ModelInfo(
                id: "timeout",
                name: "Timeout",
                provider: "openai",
                contextWindow: 128_000,
                tier: .deep,
                capabilities: [.tools],
                pricing: ModelPricing(inputPer1k: 0, outputPer1k: 0)
            ),
            ModelInfo(
                id: "mismatch-slow",
                name: "Mismatch Slow",
                provider: "baidu",
                contextWindow: 131_000,
                tier: .deep,
                capabilities: [.tools],
                pricing: ModelPricing(inputPer1k: 0, outputPer1k: 0)
            ),
        ]

        let results = [
            ModelHealthPingResult(id: "timeout", label: "Timeout", status: .timeout),
            ModelHealthPingResult(
                id: "mismatch-slow",
                label: "Mismatch Slow",
                status: .mismatch(actual: "other-model"),
                latencySamples: [2243]
            ),
            ModelHealthPingResult(
                id: "mismatch-fast",
                label: "Mismatch Fast",
                status: .mismatch(actual: "other-model"),
                latencySamples: [406]
            ),
        ]

        let sorted = BenchRankScore.sortResults(results, registry: registry)
        #expect(sorted.map(\.id) == ["mismatch-fast", "mismatch-slow", "timeout"])
    }
}
