import Foundation

public struct LogLine: Codable, Sendable {
    public let t: String
    public let kind: LogKind
    public let text: String

    public init(t: String, kind: LogKind, text: String) {
        self.t = t
        self.kind = kind
        self.text = text
    }
}

public enum LogKind: String, Codable, Sendable {
    case info, ok, warn, err, cmd
}

public enum RunEvent: Sendable {
    case logLine(LogLine)
    case phase(BenchmarkPhase)
    case completed(BenchRow)
    case failed(Error)
}

public enum BenchmarkPhase: String, Sendable {
    case resettingWorkspace
    case runningOpencode
    case grading
    case persisting
}

public enum RunnerError: Error, Sendable {
    case timeout(phase: BenchmarkPhase)
    case sandboxUnreachable
    case opencodeNonZeroExit(code: Int, stderr: String?)
    case gradingScriptMissing
    case gradingOutputInvalid
    case unsupportedHostTransport(String)
    case unknownCatalogModel(String)
}

extension RunnerError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case let .timeout(phase):
            "Timed out during \(phase.rawValue)"
        case .sandboxUnreachable:
            "Sandbox is unreachable"
        case let .opencodeNonZeroExit(code, stderr):
            if let stderr, !stderr.isEmpty {
                "opencode exited with code \(code): \(stderr)"
            } else {
                "opencode exited with code \(code)"
            }
        case .gradingScriptMissing:
            "Grading script (score_run.sh) not found in sandbox"
        case .gradingOutputInvalid:
            "Grading script output could not be parsed"
        case let .unsupportedHostTransport(label):
            "Host mode requires an OpenCode or OpenRouter model, not \(label)"
        case let .unknownCatalogModel(id):
            "Unknown model \"\(id)\" — select a model from the bench candidate list"
        }
    }
}
