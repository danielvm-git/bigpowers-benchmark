import Foundation

public struct BenchFailureRow: Codable, Identifiable, Sendable {
    public static let filePrefix = "fail_"

    public let id: UUID
    public let schemaVersion: Int
    public let timestamp: Date
    public let modelId: String
    public let taskId: String
    public let phase: String
    public let errorKind: String
    public let errorMessage: String
    public let duration: Double
    public let workspace: String

    public init(
        id: UUID = UUID(),
        schemaVersion: Int = 1,
        timestamp: Date,
        modelId: String,
        taskId: String,
        phase: String,
        errorKind: String,
        errorMessage: String,
        duration: Double,
        workspace: String
    ) {
        self.id = id
        self.schemaVersion = schemaVersion
        self.timestamp = timestamp
        self.modelId = modelId
        self.taskId = taskId
        self.phase = phase
        self.errorKind = errorKind
        self.errorMessage = errorMessage
        self.duration = duration
        self.workspace = workspace
    }

    public struct ErrorDescription {
        public let kind: String
        public let message: String
        public let phase: String
    }

    public static func describe(error: Error) -> ErrorDescription {
        if let runnerError = error as? RunnerError {
            switch runnerError {
            case let .timeout(phase):
                return ErrorDescription(kind: "timeout", message: "timeout(\(phase.rawValue))", phase: phase.rawValue)
            case .sandboxUnreachable:
                return ErrorDescription(kind: "sandboxUnreachable", message: "Sandbox unreachable", phase: "unknown")
            case let .opencodeNonZeroExit(code, _):
                return ErrorDescription(
                    kind: "opencodeNonZeroExit",
                    message: "Opencode exit \(code)",
                    phase: "runningOpencode"
                )
            case .gradingScriptMissing:
                return ErrorDescription(
                    kind: "gradingScriptMissing",
                    message: "Grading script missing",
                    phase: "grading"
                )
            case .gradingOutputInvalid:
                return ErrorDescription(
                    kind: "gradingOutputInvalid",
                    message: "Grading output invalid",
                    phase: "grading"
                )
            case let .unsupportedHostTransport(label):
                return ErrorDescription(
                    kind: "unsupportedHostTransport",
                    message: "Unsupported transport: \(label)",
                    phase: "unknown"
                )
            case let .unknownCatalogModel(id):
                return ErrorDescription(kind: "unknownCatalogModel", message: "Unknown model: \(id)", phase: "unknown")
            }
        }
        let message = LogSanitizer.sanitize(error.localizedDescription)
        return ErrorDescription(kind: "error", message: message, phase: "unknown")
    }
}
