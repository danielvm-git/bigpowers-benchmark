import Foundation

public enum LogSanitizer {
    public static func sanitize(_ text: String) -> String {
        var result = text
        let patterns = [
            "Bearer\\s+[A-Za-z0-9._\\-]+",
            "Authorization:\\s*\\S+",
            "api[_-]?key[=:]\\s*\\S+",
        ]
        for pattern in patterns {
            guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) else {
                continue
            }
            let range = NSRange(result.startIndex ..< result.endIndex, in: result)
            let replacement = if pattern.hasPrefix("Bearer") {
                "Bearer [REDACTED]"
            } else if pattern.hasPrefix("Authorization") {
                "Authorization: [REDACTED]"
            } else {
                "api_key=[REDACTED]"
            }
            result = regex.stringByReplacingMatches(in: result, range: range, withTemplate: replacement)
        }
        return result
    }
}
