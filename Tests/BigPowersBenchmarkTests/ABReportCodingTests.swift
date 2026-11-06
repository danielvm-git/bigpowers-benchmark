@testable import BigPowersBenchmarkKit
import Foundation
import Testing

@Suite("ABReport Coding")
struct ABReportCodingTests {
    @Test("decodes summary, delta and records")
    func decodesReport() throws {
        let json = """
        {"generated_at":"2026-11-04T00:00:00Z","bigpowers_sha":"abc","runner_sha":"def",
         "adapter":"pi-docker","model":"m","k":3,"tasks":["ab-11"],"arms":["vanilla","bigpowers"],
         "arms_summary":{"vanilla":{"runs":3,"pass_rate":0.9,"mean_cost_usd":0.0074},
                         "bigpowers":{"runs":3,"pass_rate":0.8,"mean_cost_usd":0.0146}},
         "delta":{"pass_rate":-0.1,"ci95":[-0.3,0.1],"cost_usd":0.0072,"score":-0.01},
         "decision":{"verdict":"reject","reasons":["cost"],"preregistration_sha":"xyz"},
         "records":[{"task":"ab-11","arm":"vanilla","run":1,"pass":true}]}
        """
        let report = try JSONDecoder().decode(ABReport.self, from: Data(json.utf8))
        #expect(report.bigpowersSHA == "abc")
        #expect(report.runnerSHA == "def")
        #expect(report.runsPerTask == 3)
        #expect(report.arms == ["vanilla", "bigpowers"])
        #expect(report.armsSummary["vanilla"]?.passRate == 0.9)
        #expect(report.delta?.passRate == -0.1)
        #expect(report.delta?.ci95 == [-0.3, 0.1])
        #expect(report.decision?.verdict == "reject")
        #expect(report.records?.count == 1)
        #expect(report.records?.first?.pass == true)
    }
}
