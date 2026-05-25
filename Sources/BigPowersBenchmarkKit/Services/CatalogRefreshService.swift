// swiftlint:disable type_body_length
import Foundation

public enum CatalogRefreshError: Error, Sendable, Equatable {
    case missingCredentials(String)
    case invalidResponse
    case httpError(statusCode: Int, message: String)
    case timedOut
    case cliFailed(String)
}

public protocol CatalogRefreshServiceProtocol: Sendable {
    func refreshNous(apiKey: String, timeoutMs: Int) async throws -> [ModelInfo]
    func refreshOpenCode(timeoutMs: Int) async throws -> [ModelInfo]
    func refreshClaudeCLI(timeoutMs: Int) async throws -> [ModelInfo]
    func refreshGeminiCLI(timeoutMs: Int) async throws -> [ModelInfo]
}

public struct CatalogRefreshService: CatalogRefreshServiceProtocol {
    public static let defaultModelsURL = URL(string: "https://inference-api.nousresearch.com/v1/models")!
    public static let defaultNousManifestURL = NousCuratedCatalog.defaultManifestURL
    public static let defaultAnthropicModelsURL = URL(string: "https://api.anthropic.com/v1/models")!
    public static let defaultModelsDevURL = URL(string: "https://models.dev/api.json")!

    private static let anthropicOAuthBetas = [
        "interleaved-thinking-2025-05-14",
        "fine-grained-tool-streaming-2025-05-14",
        "claude-code-20250219",
        "oauth-2025-04-20",
    ]

    private static let geminiCLICuratedModelIds = [
        "gemini-3.1-pro-preview",
        "gemini-3-pro-preview",
        "gemini-3-flash-preview",
    ]

    private static let googleHiddenModelIds: Set<String> = [
        "gemma-4-31b-it",
        "gemma-4-26b-it",
        "gemma-4-26b-a4b-it",
        "gemma-3-1b",
        "gemma-3-1b-it",
        "gemma-3-2b",
        "gemma-3-2b-it",
        "gemma-3-4b",
        "gemma-3-4b-it",
        "gemma-3-12b",
        "gemma-3-12b-it",
        "gemma-3-27b",
        "gemma-3-27b-it",
        "gemini-1.5-flash",
        "gemini-1.5-pro",
        "gemini-1.5-flash-8b",
        "gemini-2.0-flash",
        "gemini-2.0-flash-lite",
    ]

    private let session: URLSession
    private let modelsURL: URL
    private let nousManifestURL: URL
    private let anthropicModelsURL: URL
    private let modelsDevURL: URL
    private let processRunner: CLIProcessRunning
    private let anthropicTokenProvider: @Sendable () -> String?

    public init(
        session: URLSession = .shared,
        modelsURL: URL = CatalogRefreshService.defaultModelsURL,
        nousManifestURL: URL = CatalogRefreshService.defaultNousManifestURL,
        anthropicModelsURL: URL = CatalogRefreshService.defaultAnthropicModelsURL,
        modelsDevURL: URL = CatalogRefreshService.defaultModelsDevURL,
        processRunner: CLIProcessRunning = AsyncShellProcessRunner(),
        anthropicTokenProvider: @escaping @Sendable () -> String? = { ClaudeCodeCredentialStore.resolveToken() }
    ) {
        self.session = session
        self.modelsURL = modelsURL
        self.nousManifestURL = nousManifestURL
        self.anthropicModelsURL = anthropicModelsURL
        self.modelsDevURL = modelsDevURL
        self.processRunner = processRunner
        self.anthropicTokenProvider = anthropicTokenProvider
    }

    public func refreshNous(apiKey: String, timeoutMs: Int = 30000) async throws -> [ModelInfo] {
        guard !apiKey.isEmpty else {
            throw CatalogRefreshError.missingCredentials("Nous key missing — run: hermes login")
        }

        let curatedIds = try await fetchCuratedNousModelIds(timeoutMs: timeoutMs)
        let liveById = try await fetchNousLiveModelMetadata(apiKey: apiKey, timeoutMs: timeoutMs)

        return curatedIds.compactMap { modelId in
            guard !modelId.lowercased().contains("hermes") else { return nil }
            let live = liveById[modelId]
            let trimmedName = live?.name?.trimmingCharacters(in: .whitespacesAndNewlines)
            let displayName = (trimmedName?.isEmpty == false) ? trimmedName! : Self.displayName(fromModelId: modelId)
            let context = live?.contextLength ?? 128_000
            return StaticModelCatalogs.portalModel(
                id: modelId,
                name: displayName,
                contextWindow: context
            )
        }
    }

    func fetchCuratedNousModelIds(timeoutMs: Int) async throws -> [String] {
        var request = URLRequest(url: nousManifestURL)
        request.httpMethod = "GET"
        request.timeoutInterval = Double(timeoutMs) / 1000
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        do {
            let (data, response) = try await session.data(for: request)
            if let http = response as? HTTPURLResponse,
               (200 ... 299).contains(http.statusCode),
               let ids = NousCuratedCatalog.parseManifestModelIds(from: data) {
                return ids
            }
        } catch let error as URLError where error.code == .timedOut {
            throw CatalogRefreshError.timedOut
        } catch {
            if (error as? URLError)?.code == .timedOut {
                throw CatalogRefreshError.timedOut
            }
        }

        return NousCuratedCatalog.fallbackModelIds()
    }

    func fetchNousLiveModelMetadata(
        apiKey: String,
        timeoutMs: Int
    ) async throws -> [String: NousLiveModelMetadata] {
        var request = URLRequest(url: modelsURL)
        request.httpMethod = "GET"
        request.timeoutInterval = Double(timeoutMs) / 1000
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch let error as URLError where error.code == .timedOut {
            throw CatalogRefreshError.timedOut
        } catch {
            if (error as? URLError)?.code == .timedOut {
                throw CatalogRefreshError.timedOut
            }
            return [:]
        }

        guard let http = response as? HTTPURLResponse else {
            return [:]
        }

        guard (200 ... 299).contains(http.statusCode) else {
            let message = Self.errorMessage(from: data)
            if http.statusCode == 401 {
                throw CatalogRefreshError.missingCredentials("Session expired — run: hermes login")
            }
            throw CatalogRefreshError.httpError(statusCode: http.statusCode, message: message)
        }

        return try NousCuratedCatalog.parseLiveModelMetadata(from: data)
    }

    public func refreshOpenCode(timeoutMs: Int = 30000) async throws -> [ModelInfo] {
        let result: ShellCommandResult
        do {
            result = try await processRunner.run(
                executable: "opencode",
                arguments: ["models", "opencode"],
                timeoutMs: timeoutMs
            )
        } catch CLIPingError.timeout {
            throw CatalogRefreshError.timedOut
        } catch {
            throw CatalogRefreshError.cliFailed("opencode not installed")
        }

        guard result.exitCode == 0 else {
            let message = CLIPingClient.stripANSI(
                (result.stderr.isEmpty ? result.stdout : result.stderr)
                    .trimmingCharacters(in: .whitespacesAndNewlines)
            )
            throw CatalogRefreshError.cliFailed(message.isEmpty ? "opencode models failed" : message)
        }

        return result.stdout
            .split(whereSeparator: \.isNewline)
            .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { $0.hasPrefix("opencode/") }
            .map { slug in
                let free = slug.hasSuffix("-free")
                return StaticModelCatalogs.opencodeModel(
                    id: slug,
                    name: Self.displayName(fromOpenCodeSlug: slug),
                    free: free
                )
            }
    }

    public func refreshClaudeCLI(timeoutMs: Int = 30000) async throws -> [ModelInfo] {
        if let token = anthropicTokenProvider(), !token.isEmpty,
           let live = try await fetchAnthropicModels(token: token, timeoutMs: timeoutMs),
           !live.isEmpty {
            return live.map { StaticModelCatalogs.claudeCLIModel(modelArg: $0) }
        }

        let fallback = try await fetchModelsDevAgenticModelIds(
            providerKey: "anthropic",
            filter: { $0.hasPrefix("claude") && !$0.localizedCaseInsensitiveContains("embed") },
            timeoutMs: timeoutMs
        )
        guard !fallback.isEmpty else {
            throw CatalogRefreshError
                .cliFailed("No Claude CLI models found — log in with Claude Code or set ANTHROPIC_API_KEY")
        }
        return fallback.map { StaticModelCatalogs.claudeCLIModel(modelArg: $0) }
    }

    public func refreshGeminiCLI(timeoutMs: Int = 30000) async throws -> [ModelInfo] {
        let live = try await fetchModelsDevAgenticModelIds(
            providerKey: "google",
            filter: { $0.hasPrefix("gemini") && !Self.googleHiddenModelIds.contains($0) },
            timeoutMs: timeoutMs
        )
        let merged = Self.mergeModelIds(preferred: live, curated: Self.geminiCLICuratedModelIds)
        guard !merged.isEmpty else {
            throw CatalogRefreshError.cliFailed("No Gemini CLI models found from models.dev")
        }
        return merged.map { StaticModelCatalogs.geminiCLIModel(modelArg: $0) }
    }

    func fetchAnthropicModels(token: String, timeoutMs: Int) async throws -> [String]? {
        var request = URLRequest(url: anthropicModelsURL)
        request.httpMethod = "GET"
        request.timeoutInterval = Double(timeoutMs) / 1000
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")

        if ClaudeCodeCredentialStore.isOAuthToken(token) {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            request.setValue(Self.anthropicOAuthBetas.joined(separator: ","), forHTTPHeaderField: "anthropic-beta")
        } else {
            request.setValue(token, forHTTPHeaderField: "x-api-key")
        }

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch let error as URLError where error.code == .timedOut {
            throw CatalogRefreshError.timedOut
        } catch {
            if (error as? URLError)?.code == .timedOut {
                throw CatalogRefreshError.timedOut
            }
            return nil
        }

        guard let http = response as? HTTPURLResponse else {
            return nil
        }

        guard (200 ... 299).contains(http.statusCode) else {
            if http.statusCode == 401 {
                throw CatalogRefreshError.missingCredentials("Claude session expired — run: claude login")
            }
            return nil
        }

        let decoded = try JSONDecoder().decode(AnthropicModelsResponse.self, from: data)
        let ids = decoded.data.compactMap(\.id).filter { !$0.isEmpty }
        guard !ids.isEmpty else { return nil }
        return Self.sortClaudeModelIds(ids)
    }

    func fetchModelsDevAgenticModelIds(
        providerKey: String,
        filter: (String) -> Bool,
        timeoutMs: Int
    ) async throws -> [String] {
        var request = URLRequest(url: modelsDevURL)
        request.httpMethod = "GET"
        request.timeoutInterval = Double(timeoutMs) / 1000
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch let error as URLError where error.code == .timedOut {
            throw CatalogRefreshError.timedOut
        } catch {
            if (error as? URLError)?.code == .timedOut {
                throw CatalogRefreshError.timedOut
            }
            throw CatalogRefreshError.invalidResponse
        }

        guard let http = response as? HTTPURLResponse, (200 ... 299).contains(http.statusCode) else {
            throw CatalogRefreshError.invalidResponse
        }

        let decoded = try JSONDecoder().decode([String: ModelsDevProvider].self, from: data)
        guard let provider = decoded[providerKey],
              let models = provider.models
        else {
            return []
        }

        return models.compactMap { modelId, entry in
            guard entry.toolCall == true else { return nil }
            guard !Self.isModelsDevNoise(modelId) else { return nil }
            guard filter(modelId) else { return nil }
            return modelId
        }
        .sorted()
    }

    static func mergeModelIds(preferred: [String], curated: [String]) -> [String] {
        var seen = Set<String>()
        var merged: [String] = []
        for id in preferred + curated {
            let key = id.lowercased()
            guard seen.insert(key).inserted else { continue }
            merged.append(id)
        }
        return merged
    }

    static func sortClaudeModelIds(_ ids: [String]) -> [String] {
        ids.sorted { lhs, rhs in
            // swiftlint:disable:next large_tuple
            func rank(_ id: String) -> (Int, (Int, Int, String)) {
                (
                    id.contains("opus") ? 0 : 1,
                    (
                        id.contains("sonnet") ? 0 : 1,
                        id.contains("haiku") ? 0 : 1,
                        id
                    )
                )
            }
            let rankL = rank(lhs)
            let rankR = rank(rhs)
            if rankL.0 != rankR.0 { return rankL.0 < rankR.0 }
            if rankL.1.0 != rankR.1.0 { return rankL.1.0 < rankR.1.0 }
            if rankL.1.1 != rankR.1.1 { return rankL.1.1 < rankR.1.1 }
            return rankL.1.2 < rankR.1.2
        }
    }

    static func isModelsDevNoise(_ modelId: String) -> Bool {
        let pattern = #"(?i)-tts\b|embedding|live-|-(preview|exp)-\d{2,4}[-_]|(-image\b|-image-preview\b|-customtools\b)"#
        return modelId.range(of: pattern, options: .regularExpression) != nil
    }

    static func errorMessage(from data: Data) -> String {
        if let json = try? JSONDecoder().decode(NousErrorEnvelope.self, from: data) {
            return LogSanitizer.sanitize(json.error.message)
        }
        return LogSanitizer.sanitize(String(data: data, encoding: .utf8) ?? "Unknown error")
    }

    static func displayName(fromModelId id: String) -> String {
        let slug = id.split(separator: "/").last.map(String.init) ?? id
        return slug
            .split(separator: "-")
            .map { part in
                part.prefix(1).uppercased() + part.dropFirst()
            }
            .joined(separator: " ")
    }

    static func displayName(fromOpenCodeSlug slug: String) -> String {
        let modelPart = slug.hasPrefix("opencode/") ? String(slug.dropFirst("opencode/".count)) : slug
        let free = modelPart.hasSuffix("-free")
        let base = free ? String(modelPart.dropLast("-free".count)) : modelPart
        let words = base
            .split(separator: "-")
            .map { part in
                part.prefix(1).uppercased() + part.dropFirst()
            }
            .joined(separator: " ")
        return free ? "OpenCode Zen \(words) (Free)" : "OpenCode Zen \(words)"
    }
}

private struct NousErrorEnvelope: Decodable {
    let error: NousErrorBody
}

private struct NousErrorBody: Decodable {
    let message: String
}

private struct AnthropicModelsResponse: Decodable {
    let data: [AnthropicModelDTO]
}

private struct AnthropicModelDTO: Decodable {
    let id: String
}

private struct ModelsDevProvider: Decodable {
    let models: [String: ModelsDevModel]?

    enum CodingKeys: String, CodingKey {
        case models
    }
}

private struct ModelsDevModel: Decodable {
    let toolCall: Bool?

    enum CodingKeys: String, CodingKey {
        case toolCall = "tool_call"
    }
}
