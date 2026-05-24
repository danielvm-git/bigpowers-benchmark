@testable import BigPowersBenchmarkKit
import Foundation
import Testing

@Suite("HostRunConfig")
struct HostRunConfigTests {
    @Test("defaults to host execution mode")
    func defaultMode() throws {
        let defaults = try #require(UserDefaults(suiteName: "HostRunConfigTests-\(UUID().uuidString)"))
        let config = HostRunConfig(userDefaults: defaults)

        #expect(config.executionMode == .host)
        #expect(config.bigpowersRef == "HEAD")
        #expect(config.worktreeRoot == "/tmp/bp_bench_runs")
    }

    @Test("sandboxPath resolves to valid SANDBOX directory with task baselines")
    func sandboxPathPointsToValidDirectory() throws {
        let defaults = try #require(UserDefaults(suiteName: "HostRunConfigTests-\(UUID().uuidString)"))
        let config = HostRunConfig(userDefaults: defaults)

        let sandboxURL = URL(fileURLWithPath: config.sandboxPath)
        let t01Baseline = sandboxURL.appendingPathComponent("T01/baseline/src/limiter.js")

        #expect(
            FileManager.default.fileExists(atPath: t01Baseline.path),
            "SANDBOX task T01 baseline not found at expected path: \(t01Baseline.path)"
        )
    }
}
