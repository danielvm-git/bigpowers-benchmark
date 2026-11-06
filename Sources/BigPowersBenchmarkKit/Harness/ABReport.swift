import Foundation

public struct ABArmSummary: Codable, Sendable, Hashable {
    public let runs: Int?
    public let passRate: Double?
    public let meanScore: Double?
    public let meanBugsOpened: Double?
    public let tamperRate: Double?
    public let agentErrorRate: Double?
    public let meanCostUSD: Double?
    public let meanInputTokens: Double?
    public let meanOutputTokens: Double?
    public let meanTurns: Double?
    public let meanDurationS: Double?
    public let meanDiffLines: Double?

    enum CodingKeys: String, CodingKey {
        case runs
        case passRate = "pass_rate"
        case meanScore = "mean_score"
        case meanBugsOpened = "mean_bugs_opened"
        case tamperRate = "tamper_rate"
        case agentErrorRate = "agent_error_rate"
        case meanCostUSD = "mean_cost_usd"
        case meanInputTokens = "mean_input_tokens"
        case meanOutputTokens = "mean_output_tokens"
        case meanTurns = "mean_turns"
        case meanDurationS = "mean_duration_s"
        case meanDiffLines = "mean_diff_lines"
    }
}

public struct ABDelta: Codable, Sendable, Hashable {
    public let passRate: Double?
    public let ci95: [Double]?
    public let tamperRate: Double?
    public let costUSD: Double?
    public let score: Double?
    public let scoreCI95: [Double]?
    public let bugsOpened: Double?

    enum CodingKeys: String, CodingKey {
        case passRate = "pass_rate"
        case ci95
        case tamperRate = "tamper_rate"
        case costUSD = "cost_usd"
        case score
        case scoreCI95 = "score_ci95"
        case bugsOpened = "bugs_opened"
    }
}

public struct ABDecision: Codable, Sendable, Hashable {
    public let verdict: String?
    public let reasons: [String]?
    public let preregistrationSHA: String?

    enum CodingKeys: String, CodingKey {
        case verdict, reasons
        case preregistrationSHA = "preregistration_sha"
    }
}

/// The JSON sidecar written by `ab-eval.py --json-out`.
public struct ABReport: Codable, Sendable {
    public let generatedAt: String?
    public let bigpowersSHA: String?
    public let runnerSHA: String?
    public let adapter: String?
    public let model: String?
    public let runsPerTask: Int?
    public let tasks: [String]
    public let arms: [String]
    public let armsSummary: [String: ABArmSummary]
    public let delta: ABDelta?
    public let deltasVsVanilla: [String: ABDelta]?
    public let decision: ABDecision?
    public let records: [ABRunRecord]?

    enum CodingKeys: String, CodingKey {
        case generatedAt = "generated_at"
        case bigpowersSHA = "bigpowers_sha"
        case runnerSHA = "runner_sha"
        case adapter, model, tasks, arms, delta, decision, records
        case runsPerTask = "k"
        case armsSummary = "arms_summary"
        case deltasVsVanilla = "deltas_vs_vanilla"
    }
}
