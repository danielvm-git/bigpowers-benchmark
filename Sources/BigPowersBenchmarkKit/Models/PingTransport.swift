import Foundation

public enum PingTransport: String, Codable, Sendable, Hashable, CaseIterable {
    case openRouter
    case nousResearch
    case claudeCLI
    case geminiCLI
    case openCode

    public var channelDisplayName: String {
        switch self {
        case .openRouter: "OpenRouter"
        case .nousResearch: "Nous Portal"
        case .claudeCLI: "Claude CLI"
        case .geminiCLI: "Gemini CLI"
        case .openCode: "OpenCode Zen"
        }
    }
}
