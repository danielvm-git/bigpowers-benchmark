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
    case opencodeNonZeroExit(code: Int)
    case gradingScriptMissing
    case gradingOutputInvalid
}
