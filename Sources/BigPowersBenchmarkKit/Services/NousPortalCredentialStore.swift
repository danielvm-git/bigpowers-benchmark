import Foundation

/// Reads Nous Portal credentials from hermes-agent's `~/.hermes/auth.json`.
public enum NousPortalCredentialStore {
    public nonisolated(unsafe) static var authFileURL: URL = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent(".hermes/auth.json")

    /// Returns true if the user has valid Nous credentials (non-expired token).
    public static func isConfigured(from url: URL? = nil) -> Bool {
        resolveAgentKey(from: url) != nil
    }

    public static func resolveAgentKey(from url: URL? = nil) -> String? {
        let fileURL = url ?? authFileURL
        guard FileManager.default.fileExists(atPath: fileURL.path),
              let data = try? Data(contentsOf: fileURL),
              let auth = try? JSONDecoder().decode(HermesAuthFile.self, from: data),
              let nous = auth.providers?.nous
        else {
            return nil
        }

        // Prefer a valid, non-expired agent_key
        if let agentKey = nous.agentKey, !agentKey.isEmpty {
            let expired: Bool = if let expiresAt = nous.agentKeyExpiresAt {
                parseExpiry(expiresAt).map { $0 <= Date() } ?? false
            } else {
                false
            }
            if !expired { return agentKey }
        }

        // Fall back to access_token if not expired
        if let accessToken = nous.accessToken, !accessToken.isEmpty {
            let expired: Bool = if let expiresAt = nous.expiresAt {
                parseExpiry(expiresAt).map { $0 <= Date() } ?? false
            } else {
                false
            }
            if !expired { return accessToken }
        }

        return nil
    }

    static func parseExpiry(_ string: String) -> Date? {
        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = iso.date(from: string) { return date }
        iso.formatOptions = [.withInternetDateTime]
        return iso.date(from: string)
    }
}

private struct HermesAuthFile: Decodable {
    let providers: HermesProviders?
}

private struct HermesProviders: Decodable {
    let nous: HermesNousProvider?
}

private struct HermesNousProvider: Decodable {
    let agentKey: String?
    let agentKeyExpiresAt: String?
    let accessToken: String?
    let expiresAt: String?

    enum CodingKeys: String, CodingKey {
        case agentKey = "agent_key"
        case agentKeyExpiresAt = "agent_key_expires_at"
        case accessToken = "access_token"
        case expiresAt = "expires_at"
    }
}
