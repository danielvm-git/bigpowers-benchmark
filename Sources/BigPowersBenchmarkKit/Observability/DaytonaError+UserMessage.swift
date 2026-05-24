import Foundation

public extension DaytonaError {
    var userMessage: String {
        switch self {
        case .invalidBaseURL:
            "Invalid URL format"
        case .missingApiKey:
            "Missing API key"
        case .invalidResponse:
            "Invalid response from server"
        case let .httpError(statusCode):
            "HTTP \(statusCode)"
        }
    }

    static func userMessage(for error: Error) -> String {
        if let daytonaError = error as? DaytonaError {
            return daytonaError.userMessage
        }
        return LogSanitizer.sanitize(error.localizedDescription)
    }
}
