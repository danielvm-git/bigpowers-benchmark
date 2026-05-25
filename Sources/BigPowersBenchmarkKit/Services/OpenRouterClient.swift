import Foundation

public enum OpenRouterClientError: Error, Sendable, Equatable {
    case missingAPIKey
    case invalidResponse
    case httpError(statusCode: Int, message: String)
    case timedOut
}

public struct OpenRouterChatCompletion: Sendable {
    public let id: String
    public let model: String
    public let finishReason: String?
    public let promptTokens: Int
    public let completionTokens: Int
    public let reasoningTokens: Int
    public let cachedTokens: Int
    public let cost: Double
    public let upstreamCost: Double?
    public let routingStrategy: String?
    public let attemptCount: Int
}

public struct OpenRouterGenerationMetadata: Sendable {
    public let latency: Double?
    public let generationTime: Double?
    public let providerName: String?
}

public protocol OpenRouterClientProtocol: Sendable {
    func fetchModels(apiKey: String) async throws -> [ModelInfo]
    func ping(
        modelId: String,
        apiKey: String,
        maxTokens: Int,
        timeoutMs: Int
    ) async throws -> (completion: OpenRouterChatCompletion, latencyMs: Double)
    func fetchGeneration(id: String, apiKey: String) async throws -> OpenRouterGenerationMetadata
}

public final class OpenRouterClient: OpenRouterClientProtocol, @unchecked Sendable {
    public static let defaultModelsURL = URL(string: "https://openrouter.ai/api/v1/models")!
    public static let defaultChatURL = URL(string: "https://openrouter.ai/api/v1/chat/completions")!
    public static let defaultGenerationURL = URL(string: "https://openrouter.ai/api/v1/generation")!

    private let session: URLSession
    private let modelsURL: URL
    private let chatURL: URL
    private let generationURL: URL
    private let logger = AppLogger.modelHealth

    public init(
        session: URLSession = .shared,
        modelsURL: URL = OpenRouterClient.defaultModelsURL,
        chatURL: URL = OpenRouterClient.defaultChatURL,
        generationURL: URL = OpenRouterClient.defaultGenerationURL
    ) {
        self.session = session
        self.modelsURL = modelsURL
        self.chatURL = chatURL
        self.generationURL = generationURL
    }

    public func fetchModels(apiKey: String) async throws -> [ModelInfo] {
        guard !apiKey.isEmpty else { throw OpenRouterClientError.missingAPIKey }

        var request = URLRequest(url: modelsURL)
        request.httpMethod = "GET"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")

        let (data, response) = try await session.data(for: request)
        try validateHTTPResponse(response, data: data, apiKey: apiKey)

        let decoded = try JSONDecoder().decode(OpenRouterModelsResponse.self, from: data)
        return decoded.data.map { OpenRouterModelMapper.map($0) }
    }

    public func ping(
        modelId: String,
        apiKey: String,
        maxTokens: Int,
        timeoutMs: Int
    ) async throws -> (completion: OpenRouterChatCompletion, latencyMs: Double) {
        guard !apiKey.isEmpty else { throw OpenRouterClientError.missingAPIKey }

        var request = URLRequest(url: chatURL)
        request.httpMethod = "POST"
        request.timeoutInterval = Double(timeoutMs) / 1000
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("bigpowers-benchmark", forHTTPHeaderField: "HTTP-Referer")
        request.setValue("enabled", forHTTPHeaderField: "X-OpenRouter-Experimental-Metadata")

        let body: [String: Any] = [
            "model": modelId,
            "messages": [
                ["role": "user", "content": "Reply with just the word: pong"],
            ],
            "max_tokens": maxTokens,
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let start = Date()
        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch let error as URLError where error.code == .timedOut {
            throw OpenRouterClientError.timedOut
        } catch {
            if (error as? URLError)?.code == .timedOut {
                throw OpenRouterClientError.timedOut
            }
            throw error
        }
        let latencyMs = Date().timeIntervalSince(start) * 1000

        try validateHTTPResponse(response, data: data, apiKey: apiKey)

        let decoded = try JSONDecoder().decode(OpenRouterChatResponse.self, from: data)
        let completion = OpenRouterModelMapper.mapChatCompletion(decoded)
        return (completion, latencyMs)
    }

    public func fetchGeneration(id: String, apiKey: String) async throws -> OpenRouterGenerationMetadata {
        guard !apiKey.isEmpty else { throw OpenRouterClientError.missingAPIKey }

        var components = URLComponents(url: generationURL, resolvingAgainstBaseURL: false)
        components?.queryItems = [URLQueryItem(name: "id", value: id)]
        guard let url = components?.url else { throw OpenRouterClientError.invalidResponse }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")

        let (data, response) = try await session.data(for: request)
        try validateHTTPResponse(response, data: data, apiKey: apiKey)

        let decoded = try JSONDecoder().decode(OpenRouterGenerationResponse.self, from: data)
        return OpenRouterGenerationMetadata(
            latency: decoded.data.latency,
            generationTime: decoded.data.generationTime,
            providerName: decoded.data.providerName
        )
    }

    private func validateHTTPResponse(_ response: URLResponse, data: Data, apiKey: String) throws {
        guard let http = response as? HTTPURLResponse else {
            throw OpenRouterClientError.invalidResponse
        }
        guard (200 ... 299).contains(http.statusCode) else {
            let message = Self.errorMessage(from: data, apiKey: apiKey)
            throw OpenRouterClientError.httpError(statusCode: http.statusCode, message: message)
        }
    }

    static func errorMessage(from data: Data, apiKey: String) -> String {
        if let json = try? JSONDecoder().decode(OpenRouterErrorEnvelope.self, from: data) {
            return sanitize(json.error.message, apiKey: apiKey)
        }
        let raw = String(data: data, encoding: .utf8) ?? "Unknown error"
        return sanitize(raw, apiKey: apiKey)
    }

    static func sanitize(_ text: String, apiKey: String) -> String {
        var result = LogSanitizer.sanitize(text)
        if !apiKey.isEmpty {
            result = result.replacingOccurrences(of: apiKey, with: "[REDACTED]")
        }
        return result
    }
}

private struct OpenRouterModelsResponse: Decodable {
    let data: [OpenRouterModelDTO]
}

private struct OpenRouterModelDTO: Decodable {
    let id: String
    let name: String
    let contextLength: Int?
    let architecture: OpenRouterArchitectureDTO?
    let pricing: OpenRouterPricingDTO?
    let supportedParameters: [String]?

    enum CodingKeys: String, CodingKey {
        case id, name, architecture, pricing
        case contextLength = "context_length"
        case supportedParameters = "supported_parameters"
    }
}

private struct OpenRouterArchitectureDTO: Decodable {
    let inputModalities: [String]?
    let outputModalities: [String]?

    enum CodingKeys: String, CodingKey {
        case inputModalities = "input_modalities"
        case outputModalities = "output_modalities"
    }
}

private struct OpenRouterPricingDTO: Decodable {
    let prompt: String?
    let completion: String?
}

private struct OpenRouterChatResponse: Decodable {
    let id: String
    let model: String
    let choices: [OpenRouterChatChoiceDTO]?
    let usage: OpenRouterUsageDTO?
    let openrouterMetadata: OpenRouterMetadataDTO?

    enum CodingKeys: String, CodingKey {
        case id, model, choices, usage
        case openrouterMetadata = "openrouter_metadata"
    }
}

private struct OpenRouterChatChoiceDTO: Decodable {
    let finishReason: String?

    enum CodingKeys: String, CodingKey {
        case finishReason = "finish_reason"
    }
}

private struct OpenRouterUsageDTO: Decodable {
    let promptTokens: Int?
    let completionTokens: Int?
    let cost: Double?
    let promptTokensDetails: OpenRouterPromptTokenDetailsDTO?
    let completionTokensDetails: OpenRouterCompletionTokenDetailsDTO?
    let costDetails: OpenRouterCostDetailsDTO?

    enum CodingKeys: String, CodingKey {
        case cost
        case promptTokens = "prompt_tokens"
        case completionTokens = "completion_tokens"
        case promptTokensDetails = "prompt_tokens_details"
        case completionTokensDetails = "completion_tokens_details"
        case costDetails = "cost_details"
    }
}

private struct OpenRouterPromptTokenDetailsDTO: Decodable {
    let cachedTokens: Int?

    enum CodingKeys: String, CodingKey {
        case cachedTokens = "cached_tokens"
    }
}

private struct OpenRouterCompletionTokenDetailsDTO: Decodable {
    let reasoningTokens: Int?

    enum CodingKeys: String, CodingKey {
        case reasoningTokens = "reasoning_tokens"
    }
}

private struct OpenRouterCostDetailsDTO: Decodable {
    let upstreamInferenceCost: Double?

    enum CodingKeys: String, CodingKey {
        case upstreamInferenceCost = "upstream_inference_cost"
    }
}

private struct OpenRouterMetadataDTO: Decodable {
    let strategy: String?
    let attempt: Int?
}

private struct OpenRouterGenerationResponse: Decodable {
    let data: OpenRouterGenerationDataDTO
}

private struct OpenRouterGenerationDataDTO: Decodable {
    let latency: Double?
    let generationTime: Double?
    let providerName: String?

    enum CodingKeys: String, CodingKey {
        case latency
        case generationTime = "generation_time"
        case providerName = "provider_name"
    }
}

private struct OpenRouterErrorEnvelope: Decodable {
    let error: OpenRouterErrorBody
}

private struct OpenRouterErrorBody: Decodable {
    let message: String
}

private enum OpenRouterModelMapper {
    static func map(_ dto: OpenRouterModelDTO) -> ModelInfo {
        let provider = dto.id.split(separator: "/").first.map(String.init) ?? "unknown"
        let contextWindow = dto.contextLength ?? 0
        let inputPerToken = Double(dto.pricing?.prompt ?? "0") ?? 0
        let outputPerToken = Double(dto.pricing?.completion ?? "0") ?? 0
        let pricing = ModelPricing(
            inputPer1k: inputPerToken * 1000,
            outputPer1k: outputPerToken * 1000
        )

        return ModelInfo(
            id: dto.id,
            name: dto.name,
            provider: provider,
            contextWindow: contextWindow,
            tier: tier(for: contextWindow),
            capabilities: capabilities(from: dto),
            pricing: pricing
        )
    }

    static func mapChatCompletion(_ response: OpenRouterChatResponse) -> OpenRouterChatCompletion {
        OpenRouterChatCompletion(
            id: response.id,
            model: response.model,
            finishReason: response.choices?.first?.finishReason,
            promptTokens: response.usage?.promptTokens ?? 0,
            completionTokens: response.usage?.completionTokens ?? 0,
            reasoningTokens: response.usage?.completionTokensDetails?.reasoningTokens ?? 0,
            cachedTokens: response.usage?.promptTokensDetails?.cachedTokens ?? 0,
            cost: response.usage?.cost ?? 0,
            upstreamCost: response.usage?.costDetails?.upstreamInferenceCost,
            routingStrategy: response.openrouterMetadata?.strategy,
            attemptCount: response.openrouterMetadata?.attempt ?? 1
        )
    }

    private static func tier(for contextWindow: Int) -> Tier {
        if contextWindow >= 128_000 {
            .deep
        } else if contextWindow > 0, contextWindow < 32000 {
            .light
        } else {
            .standard
        }
    }

    private static func capabilities(from dto: OpenRouterModelDTO) -> [Capability] {
        var result: [Capability] = []
        let supported = Set(dto.supportedParameters ?? [])
        let inputModalities = Set(dto.architecture?.inputModalities ?? [])
        let outputModalities = Set(dto.architecture?.outputModalities ?? [])

        if supported.contains("tools") { result.append(.tools) }
        if inputModalities.contains("image") { result.append(.vision) }
        if supported.contains("include_reasoning") || supported.contains("reasoning_effort") {
            result.append(.reasoning)
        }
        if outputModalities.contains("text") { result.append(.streaming) }
        return result
    }
}
