import Foundation

public enum ApiKeySource: String, Sendable, Equatable {
    case keychain
    case environment
    case dotEnv
}

public struct ResolvedProviderCredential: Sendable, Equatable {
    public let value: String
    public let source: ApiKeySource

    public init(value: String, source: ApiKeySource) {
        self.value = value
        self.source = source
    }
}

public enum ProviderCredentialResolver {
    public static let environmentVariableNames: [String: String] = [
        "openrouter": "OPENROUTER_API_KEY",
        "anthropic": "ANTHROPIC_API_KEY",
        "openai": "OPENAI_API_KEY",
        "google": "GOOGLE_API_KEY",
        "nousresearch-direct": "NOUS_RESEARCH_API_KEY",
    ]

    public static func resolve(
        providerId: String,
        keychain: KeychainServiceProtocol = KeychainService(),
        dotEnvPaths: [URL] = defaultDotEnvPaths(),
        environment: [String: String] = ProcessInfo.processInfo.environment
    ) -> ResolvedProviderCredential? {
        let account = "bigpowers.benchmark.\(providerId)"
        if let key = keychain.load(account: account), !key.isEmpty {
            return ResolvedProviderCredential(value: key, source: .keychain)
        }

        if let envName = environmentVariableNames[providerId],
           let value = environment[envName],
           !value.isEmpty {
            return ResolvedProviderCredential(value: value, source: .environment)
        }

        if let envName = environmentVariableNames[providerId],
           let value = dotEnvValue(for: envName, paths: dotEnvPaths),
           !value.isEmpty {
            return ResolvedProviderCredential(value: value, source: .dotEnv)
        }

        return nil
    }

    public static func isConfigured(
        providerId: String,
        keychain: KeychainServiceProtocol = KeychainService(),
        dotEnvPaths: [URL] = defaultDotEnvPaths(),
        environment: [String: String] = ProcessInfo.processInfo.environment
    ) -> Bool {
        resolve(providerId: providerId, keychain: keychain, dotEnvPaths: dotEnvPaths, environment: environment) != nil
    }

    public static func defaultDotEnvPaths(projectRoot: URL? = nil) -> [URL] {
        var paths: [URL] = []
        if let projectRoot {
            paths.append(projectRoot.appendingPathComponent(".env"))
        }

        let home = FileManager.default.homeDirectoryForCurrentUser
        paths.append(home.appendingPathComponent("Developer/bigpowers-benchmark/.env"))
        paths.append(home.appendingPathComponent("Developer/bigpowers-benchmark-old/.env"))

        let cwd = URL(fileURLWithPath: FileManager.default.currentDirectoryPath, isDirectory: true)
        paths.append(cwd.appendingPathComponent(".env"))

        var seen = Set<String>()
        return paths.filter { url in
            let path = url.standardizedFileURL.path
            guard seen.insert(path).inserted else { return false }
            return true
        }
    }

    static func dotEnvValue(for key: String, paths: [URL]) -> String? {
        for path in paths where FileManager.default.fileExists(atPath: path.path) {
            if let value = parseDotEnv(at: path, key: key) {
                return value
            }
        }
        return nil
    }

    static func parseDotEnv(at url: URL, key: String) -> String? {
        guard let content = try? String(contentsOf: url, encoding: .utf8) else { return nil }
        for line in content.split(separator: "\n") {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.isEmpty || trimmed.hasPrefix("#") { continue }
            let parts = trimmed.split(separator: "=", maxSplits: 1).map(String.init)
            guard parts.count == 2, parts[0].trimmingCharacters(in: .whitespaces) == key else { continue }
            return parts[1]
                .trimmingCharacters(in: .whitespaces)
                .trimmingCharacters(in: CharacterSet(charactersIn: "\"'"))
        }
        return nil
    }
}
