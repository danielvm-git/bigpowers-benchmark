import Foundation

public enum ModelHealthErrorClassifier {
    private static let noCreditPatterns: [String] = [
        "no credit",
        "no credits",
        "insufficient credit",
        "insufficient credits",
        "insufficient balance",
        "insufficient funds",
        "payment required",
        "out of credit",
        "quota exceeded",
        "billing",
        "purchase credits",
    ]

    public static func isNoCredit(statusCode: Int? = nil, message: String) -> Bool {
        if statusCode == 402 { return true }
        let normalized = message.lowercased()
        return noCreditPatterns.contains { normalized.contains($0) }
    }

    public static func pingStatus(statusCode: Int? = nil, message: String) -> ModelHealthPingStatus {
        if isNoCredit(statusCode: statusCode, message: message) {
            return .noCredit
        }
        return .error(message)
    }
}
