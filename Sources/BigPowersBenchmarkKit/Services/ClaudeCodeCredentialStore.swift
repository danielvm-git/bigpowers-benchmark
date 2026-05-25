import Foundation

/// Reads Anthropic credentials for Claude CLI catalog refresh.
///
/// Resolution order matches hermes-agent: env vars, then Claude Code OAuth file.
public enum ClaudeCodeCredentialStore {
    public nonisolated(unsafe) static var credentialsFileURL: URL = FileManager.default
        .homeDirectoryForCurrentUser
        .appendingPathComponent(".claude/.credentials.json")

    public static func resolveToken(
        environment: [String: String] = ProcessInfo.processInfo.environment,
        credentialsURL: URL? = nil
    ) -> String? {
        for key in ["ANTHROPIC_API_KEY", "ANTHROPIC_TOKEN"] {
            if let value = environment[key]?.trimmingCharacters(in: .whitespacesAndNewlines),
               !value.isEmpty {
                return value
            }
        }
        return readClaudeCodeOAuthToken(from: credentialsURL)
    }

    static func readClaudeCodeOAuthToken(from url: URL? = nil) -> String? {
        let fileURL = url ?? credentialsFileURL
        guard FileManager.default.fileExists(atPath: fileURL.path),
              let data = try? Data(contentsOf: fileURL),
              let json = try? JSONDecoder().decode(ClaudeCredentialsFile.self, from: data),
              let token = json.claudeAiOauth?.accessToken?.trimmingCharacters(in: .whitespacesAndNewlines),
              !token.isEmpty
        else {
            return nil
        }
        return token
    }

    static func isOAuthToken(_ token: String) -> Bool {
        if token.hasPrefix("sk-ant-api") { return false }
        if token.hasPrefix("sk-ant-") { return true }
        if token.hasPrefix("eyJ") { return true }
        if token.hasPrefix("cc-") { return true }
        return false
    }
}

private struct ClaudeCredentialsFile: Decodable {
    let claudeAiOauth: ClaudeAiOAuth?

    enum CodingKeys: String, CodingKey {
        case claudeAiOauth
    }
}

private struct ClaudeAiOAuth: Decodable {
    let accessToken: String?
}
