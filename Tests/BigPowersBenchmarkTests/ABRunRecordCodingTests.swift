@testable import BigPowersBenchmarkKit
import Foundation
import Testing

@Suite("ABRunRecord Coding")
struct ABRunRecordCodingTests {
    @Test("decodes a live record with snake_case keys")
    func decodesLiveRecord() throws {
        let json = """
        {"task":"ab-11","arm":"bigpowers","run":3,"pass":true,"score":0.9444,
         "bugs_opened":1,"bug_details":["brand"],"tampered":false,
         "protected_lines_added":2,"diff_lines":40,"duration_s":91.2,
         "agent_exit":0,"agent_error":false,"timed_out":false,
         "cost_usd":0.0146,"input_tokens":512593,"output_tokens":14844,
         "turns":20,"bigpowers_sha":"abc123","model":"opencode-go/deepseek-v4.1-flash",
         "vsm":{"lead_time_s":1},"waste":{"test_runs":8}}
        """
        let record = try JSONDecoder().decode(ABRunRecord.self, from: Data(json.utf8))
        #expect(record.task == "ab-11")
        #expect(record.arm == "bigpowers")
        #expect(record.run == 3)
        #expect(record.pass)
        #expect(record.score == 0.9444)
        #expect(record.bugsOpened == 1)
        #expect(record.bugDetails == ["brand"])
        #expect(record.tampered == false)
        #expect(record.protectedLinesAdded == 2)
        #expect(record.diffLines == 40)
        #expect(record.durationS == 91.2)
        #expect(record.agentExit == 0)
        #expect(record.agentError == false)
        #expect(record.timedOut == false)
        #expect(record.costUSD == 0.0146)
        #expect(record.inputTokens == 512_593)
        #expect(record.outputTokens == 14844)
        #expect(record.turns == 20)
        #expect(record.bigpowersSHA == "abc123")
        #expect(record.model == "opencode-go/deepseek-v4.1-flash")
        #expect(record.id == "ab-11-bigpowers-3")
    }

    @Test("missing optional fields decode as nil or zero")
    func decodesMinimalRecord() throws {
        let json = #"{"task":"t-01","arm":"vanilla","run":1,"pass":false}"#
        let record = try JSONDecoder().decode(ABRunRecord.self, from: Data(json.utf8))
        #expect(record.score == nil)
        #expect(record.bugsOpened == 0)
        #expect(record.costUSD == nil)
        #expect(record.timedOut == nil)
    }
}
