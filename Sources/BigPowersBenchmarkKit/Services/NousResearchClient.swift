import Foundation

public enum NousResearchClientError: Error, Sendable, Equatable {
    case invalidResponse
    case httpError(statusCode: Int, message: String)
    case timedOut
}

public struct NousResearchPingResult: Sendable {
    public let reply: String
    public let latencyMs: Double
    public let promptTokens: Int
    public let completionTokens: Int

    public init(reply: String, latencyMs: Double, promptTokens: Int, completionTokens: Int) {
        self.reply = reply
        self.latencyMs = latencyMs
        self.promptTokens = promptTokens
        self.completionTokens = completionTokens
    }
}

public protocol NousResearchClientProtocol: Sendable {
    func ping(
        modelId: String,
        prompt: String,
        maxTokens: Int,
        timeoutMs: Int,
        apiKey: String?
    ) async throws -> NousResearchPingResult
}

public final class NousResearchClient: NousResearchClientProtocol, @unchecked Sendable {
    public static let defaultChatURL = URL(string: "https://inference-api.nousresearch.com/v1/chat/completions")!

    private let session: URLSession
    private let chatURL: URL

    public init(
        session: URLSession = .shared,
        chatURL: URL = NousResearchClient.defaultChatURL
    ) {
        self.session = session
        self.chatURL = chatURL
    }

    public func ping(
        modelId: String,
        prompt: String,
        maxTokens: Int,
        timeoutMs: Int,
        apiKey: String? = nil
    ) async throws -> NousResearchPingResult {
        var request = URLRequest(url: chatURL)
        request.httpMethod = "POST"
        request.timeoutInterval = Double(timeoutMs) / 1000
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let apiKey, !apiKey.isEmpty {
            request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        }

        let body: [String: Any] = [
            "model": modelId,
            "messages": [
                ["role": "user", "content": prompt],
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
            throw NousResearchClientError.timedOut
        } catch {
            if (error as? URLError)?.code == .timedOut {
                throw NousResearchClientError.timedOut
            }
            throw error
        }
        let latencyMs = Date().timeIntervalSince(start) * 1000

        guard let http = response as? HTTPURLResponse else {
            throw NousResearchClientError.invalidResponse
        }
        guard (200 ... 299).contains(http.statusCode) else {
            let message = Self.errorMessage(from: data)
            throw NousResearchClientError.httpError(statusCode: http.statusCode, message: message)
        }

        let decoded = try JSONDecoder().decode(NousResearchChatResponse.self, from: data)
        let reply = decoded.choices?.first?.message?.content?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return NousResearchPingResult(
            reply: reply,
            latencyMs: latencyMs,
            promptTokens: decoded.usage?.promptTokens ?? 0,
            completionTokens: decoded.usage?.completionTokens ?? 0
        )
    }

    static func errorMessage(from data: Data) -> String {
        if let json = try? JSONDecoder().decode(NousResearchErrorEnvelope.self, from: data) {
            return LogSanitizer.sanitize(json.error.message)
        }
        return LogSanitizer.sanitize(String(data: data, encoding: .utf8) ?? "Unknown error")
    }
}

private struct NousResearchChatResponse: Decodable {
    let choices: [NousResearchChoiceDTO]?
    let usage: NousResearchUsageDTO?
}

private struct NousResearchChoiceDTO: Decodable {
    let message: NousResearchMessageDTO?
}

private struct NousResearchMessageDTO: Decodable {
    let content: String?
}

private struct NousResearchUsageDTO: Decodable {
    let promptTokens: Int?
    let completionTokens: Int?

    enum CodingKeys: String, CodingKey {
        case promptTokens = "prompt_tokens"
        case completionTokens = "completion_tokens"
    }
}

private struct NousResearchErrorEnvelope: Decodable {
    let error: NousResearchErrorBody
}

private struct NousResearchErrorBody: Decodable {
    let message: String
}
