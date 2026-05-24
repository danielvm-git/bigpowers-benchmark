import Foundation

public struct Sandbox: Codable, Identifiable, Sendable, Hashable {
    public let id: String
    public let name: String
    public let state: SandboxState
    public let labels: [String: String]
    public let toolboxProxyUrl: String

    public var isRunnable: Bool {
        state == .started
    }
}

public enum SandboxState: String, Codable, Sendable {
    case creating
    case started
    case stopped
    case error
    case unknown

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let string = try container.decode(String.self)
        self = SandboxState(rawValue: string) ?? .unknown
    }
}
