import Foundation

/// One line of the A/B harness output (`ab-live.jsonl` or `ab-runs-*.jsonl`).
/// Unknown keys (vsm, waste) are ignored; the app only needs the outcome and cost signals.
public struct ABRunRecord: Codable, Identifiable, Sendable, Hashable {
    public var id: String {
        "\(task)-\(arm)-\(run)"
    }

    public let task: String
    public let arm: String
    public let run: Int
    public let pass: Bool
    public let score: Double?
    public let bugsOpened: Int
    public let bugDetails: [String]?
    public let tampered: Bool
    public let protectedLinesAdded: Int
    public let diffLines: Int
    public let durationS: Double
    public let agentExit: Int?
    public let agentError: Bool
    public let timedOut: Bool?
    public let costUSD: Double?
    public let inputTokens: Int?
    public let outputTokens: Int?
    public let turns: Int?
    public let bigpowersSHA: String?
    public let model: String?

    enum CodingKeys: String, CodingKey {
        case task, arm, run, pass, score
        case bugsOpened = "bugs_opened"
        case bugDetails = "bug_details"
        case tampered
        case protectedLinesAdded = "protected_lines_added"
        case diffLines = "diff_lines"
        case durationS = "duration_s"
        case agentExit = "agent_exit"
        case agentError = "agent_error"
        case timedOut = "timed_out"
        case costUSD = "cost_usd"
        case inputTokens = "input_tokens"
        case outputTokens = "output_tokens"
        case turns
        case bigpowersSHA = "bigpowers_sha"
        case model
    }

    public init(
        task: String,
        arm: String,
        run: Int,
        pass: Bool,
        score: Double? = nil,
        bugsOpened: Int = 0,
        bugDetails: [String]? = nil,
        tampered: Bool = false,
        protectedLinesAdded: Int = 0,
        diffLines: Int = 0,
        durationS: Double = 0,
        agentExit: Int? = nil,
        agentError: Bool = false,
        timedOut: Bool? = nil,
        costUSD: Double? = nil,
        inputTokens: Int? = nil,
        outputTokens: Int? = nil,
        turns: Int? = nil,
        bigpowersSHA: String? = nil,
        model: String? = nil
    ) {
        self.task = task
        self.arm = arm
        self.run = run
        self.pass = pass
        self.score = score
        self.bugsOpened = bugsOpened
        self.bugDetails = bugDetails
        self.tampered = tampered
        self.protectedLinesAdded = protectedLinesAdded
        self.diffLines = diffLines
        self.durationS = durationS
        self.agentExit = agentExit
        self.agentError = agentError
        self.timedOut = timedOut
        self.costUSD = costUSD
        self.inputTokens = inputTokens
        self.outputTokens = outputTokens
        self.turns = turns
        self.bigpowersSHA = bigpowersSHA
        self.model = model
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        task = try container.decode(String.self, forKey: .task)
        arm = try container.decode(String.self, forKey: .arm)
        run = try container.decodeIfPresent(Int.self, forKey: .run) ?? 0
        pass = try container.decode(Bool.self, forKey: .pass)
        score = try container.decodeIfPresent(Double.self, forKey: .score)
        bugsOpened = try container.decodeIfPresent(Int.self, forKey: .bugsOpened) ?? 0
        bugDetails = try container.decodeIfPresent([String].self, forKey: .bugDetails)
        tampered = try container.decodeIfPresent(Bool.self, forKey: .tampered) ?? false
        protectedLinesAdded = try container.decodeIfPresent(Int.self, forKey: .protectedLinesAdded) ?? 0
        diffLines = try container.decodeIfPresent(Int.self, forKey: .diffLines) ?? 0
        durationS = try container.decodeIfPresent(Double.self, forKey: .durationS) ?? 0
        agentExit = try container.decodeIfPresent(Int.self, forKey: .agentExit)
        agentError = try container.decodeIfPresent(Bool.self, forKey: .agentError) ?? false
        timedOut = try container.decodeIfPresent(Bool.self, forKey: .timedOut)
        costUSD = try container.decodeIfPresent(Double.self, forKey: .costUSD)
        inputTokens = try container.decodeIfPresent(Int.self, forKey: .inputTokens)
        outputTokens = try container.decodeIfPresent(Int.self, forKey: .outputTokens)
        turns = try container.decodeIfPresent(Int.self, forKey: .turns)
        bigpowersSHA = try container.decodeIfPresent(String.self, forKey: .bigpowersSHA)
        model = try container.decodeIfPresent(String.self, forKey: .model)
    }
}
