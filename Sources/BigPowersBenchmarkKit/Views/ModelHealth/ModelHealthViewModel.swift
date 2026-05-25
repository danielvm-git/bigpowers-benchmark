// swiftlint:disable file_length type_body_length
import Foundation
import Observation

public enum ModelPingScope: String, CaseIterable, Sendable {
    case smartFree
    case benchCandidates
    case free
    case filtered
    case provider
    case all

    public var label: String {
        switch self {
        case .smartFree: "Smart Free"
        case .benchCandidates: "Bench Candidates"
        case .free: "Free Models (Catalog)"
        case .filtered: "Filtered"
        case .provider: "By Provider"
        case .all: "All Registry"
        }
    }
}

@Observable
@MainActor
public final class ModelHealthViewModel {
    public var rows: [ModelHealthPingResult] = []
    public var isPinging = false
    public var lastPingDate: Date?
    public var pingCompletedCount = 0
    public var pingTotalCount = 0

    public var maxTokens: Int = 10
    public var parallelism: Int = 4
    public var timeoutMs: Int = 30000
    public var sampleCount: Int = 3

    public var selectedProvider: String?
    public var selectedTier: Tier?
    public var pingScope: ModelPingScope = .smartFree

    public var showReasoningColumn = false
    public var disabledCLITransports: Set<PingTransport> = []

    private let client: OpenRouterClientProtocol
    private let nousResearchClient: NousResearchClientProtocol
    private let cliPingClient: CLIPingClientProtocol
    private let intelStore: ModelIntelStore
    private let logger = AppLogger.modelHealth
    @ObservationIgnored private var pingTask: Task<Void, Never>?

    public init(
        client: OpenRouterClientProtocol = OpenRouterClient(),
        nousResearchClient: NousResearchClientProtocol = NousResearchClient(),
        cliPingClient: CLIPingClientProtocol = CLIPingClient(),
        intelStore: ModelIntelStore = ModelIntelStore()
    ) {
        self.client = client
        self.nousResearchClient = nousResearchClient
        self.cliPingClient = cliPingClient
        self.intelStore = intelStore
    }

    public var responsiveCount: Int {
        rows.filter(\.responded).count
    }

    public var timeoutCount: Int {
        rows.filter {
            if case .timeout = $0.status { true } else { false }
        }.count
    }

    public var mismatchCount: Int {
        rows.filter {
            if case .mismatch = $0.status { true } else { false }
        }.count
    }

    public var contentFilterCount: Int {
        rows.filter { $0.status == .contentFilter }.count
    }

    public var noCreditCount: Int {
        rows.filter { $0.status == .noCredit }.count
    }

    public func filteredRows(from models: [ModelInfo]) -> [ModelHealthPingResult] {
        let modelIDs = Set(filteredModels(from: models).map(\.id))
        return rows.filter { modelIDs.contains($0.id) }
    }

    public func filteredModels(from models: [ModelInfo]) -> [ModelInfo] {
        models.filter { model in
            let providerMatch = selectedProvider.map { providerId in
                if let subscription = ModelHealthSubscriptionProvider(rawValue: providerId) {
                    return subscription.matches(model)
                }
                return model.provider == providerId
            } ?? true
            let tierMatch = selectedTier.map { model.tier == $0 } ?? true
            return providerMatch && tierMatch
        }
    }

    public func selectProvider(_ id: String?) {
        selectedProvider = id
        if id != nil, pingScope == .smartFree || pingScope == .free || pingScope == .all {
            pingScope = .provider
        } else if id == nil, pingScope == .provider {
            pingScope = .smartFree
        }
    }

    public func pingTargets(from models: [ModelInfo]) -> [ModelInfo] {
        let blocked = disabledCLITransports
        let filtered: [ModelInfo] = switch pingScope {
        case .all:
            models
        case .filtered, .provider:
            filteredModels(from: models)
        case .free:
            filteredModels(from: models).filter(\.isFreeModel)
        case .smartFree:
            intelStore.smartFreeModels(from: filteredModels(from: models))
        case .benchCandidates:
            intelStore.benchCandidateModels(from: filteredModels(from: models))
        }
        return filtered.filter { model in
            if blocked.contains(model.pingTransport) { return false }
            switch model.pingTransport {
            case .claudeCLI: return Self.isCLIOnPath("claude")
            case .geminiCLI: return Self.isCLIOnPath("gemini")
            default: return true
            }
        }
    }

    public func startPingAll(
        models: [ModelInfo],
        apiKey: String,
        onComplete: (@MainActor () -> Void)? = nil
    ) {
        pingTask?.cancel()
        pingTask = Task { @MainActor in
            await pingAll(models: models, apiKey: apiKey)
            if !Task.isCancelled {
                onComplete?()
            }
            pingTask = nil
        }
    }

    public func stopPing() {
        pingTask?.cancel()
    }

    public func pingAll(models: [ModelInfo], apiKey: String) async {
        guard !isPinging else { return }
        isPinging = true
        pingCompletedCount = 0
        defer {
            isPinging = false
            pingCompletedCount = 0
            pingTotalCount = 0
        }

        let targets = pingTargets(from: models)
        pingTotalCount = targets.count
        guard !targets.isEmpty else { return }

        rows = []
        let startedAt = Date()

        logger.info("Ping batch started", metadata: [
            "action": .string("pingStart"),
            "modelCount": .stringConvertible(targets.count),
            "parallelism": .stringConvertible(parallelism),
            "timeoutMs": .stringConvertible(timeoutMs),
        ])

        var results = Array(
            repeating: ModelHealthPingResult(id: "", label: "", status: .error("Not started")),
            count: targets.count
        )

        await withTaskGroup(of: (Int, ModelHealthPingResult).self) { group in
            var nextIndex = 0

            func enqueueNext() {
                guard nextIndex < targets.count, !Task.isCancelled else { return }
                let index = nextIndex
                nextIndex += 1
                let model = targets[index]
                group.addTask {
                    let result = await self.pingModel(model, apiKey: apiKey)
                    return (index, result)
                }
            }

            for _ in 0 ..< min(parallelism, targets.count) {
                enqueueNext()
            }

            for await (index, result) in group {
                if Task.isCancelled {
                    group.cancelAll()
                    break
                }
                results[index] = result
                pingCompletedCount += 1
                publishRows(from: results, registry: models)
                enqueueNext()
            }
        }

        if Task.isCancelled {
            for index in results.indices {
                guard results[index].id.isEmpty, index < targets.count else { continue }
                let model = targets[index]
                results[index] = cancelledResult(for: model)
            }
            publishRows(from: results, registry: models)
            logger.info("Ping batch cancelled", metadata: [
                "action": .string("pingCancelled"),
                "completed": .stringConvertible(pingCompletedCount),
            ])
            return
        }

        lastPingDate = Date()
        let durationMs = Int(Date().timeIntervalSince(startedAt) * 1000)

        logger.info("Ping batch complete", metadata: [
            "action": .string("pingComplete"),
            "responsive": .stringConvertible(responsiveCount),
            "timeout": .stringConvertible(timeoutCount),
            "mismatch": .stringConvertible(mismatchCount),
            "contentFilter": .stringConvertible(contentFilterCount),
            "durationMs": .stringConvertible(durationMs),
        ])
    }

    private func publishRows(from results: [ModelHealthPingResult], registry: [ModelInfo]) {
        rows = BenchRankScore.sortResults(results.filter { !$0.id.isEmpty }, registry: registry)
    }

    private func cancelledResult(for model: ModelInfo) -> ModelHealthPingResult {
        ModelHealthPingResult(
            id: model.id,
            label: model.name,
            status: .error("Cancelled"),
            testedProviderLabel: model.pingTransport.channelDisplayName,
            modelAlias: model.apiModelId
        )
    }

    private func pingModel(_ model: ModelInfo, apiKey: String) async -> ModelHealthPingResult {
        if Task.isCancelled {
            return cancelledResult(for: model)
        }

        switch model.pingTransport {
        case .openRouter:
            return await pingOpenRouterModel(model, apiKey: apiKey)
        case .nousResearch:
            return await pingNousResearchModel(model)
        case .claudeCLI:
            return await pingCLIModel(model, transport: .claudeCLI)
        case .geminiCLI:
            return await pingCLIModel(model, transport: .geminiCLI)
        case .openCode:
            return await pingCLIModel(model, transport: .openCode)
        }
    }

    private static func isCLIOnPath(_ executable: String) -> Bool {
        let path = ProcessInfo.processInfo.environment["PATH"] ?? "/usr/bin:/bin"
        for dir in path.split(separator: ":") {
            let fullPath = (String(dir) as NSString).appendingPathComponent(executable)
            if FileManager.default.isExecutableFile(atPath: fullPath) {
                return true
            }
        }
        return false
    }

    private static let defaultPingPrompt = "Reply with just the word: pong"

    private func pingOpenRouterModel(_ model: ModelInfo, apiKey: String) async -> ModelHealthPingResult {
        var latencySamples: [Double] = []
        var lastCompletion: OpenRouterChatCompletion?
        var lastGeneration: OpenRouterGenerationMetadata?
        var lastStatus: ModelHealthPingStatus = .error("No samples")

        for _ in 0 ..< max(sampleCount, 1) {
            if Task.isCancelled {
                lastStatus = .error("Cancelled")
                break
            }
            do {
                let (completion, latencyMs) = try await client.ping(
                    modelId: model.id,
                    apiKey: apiKey,
                    maxTokens: maxTokens,
                    timeoutMs: timeoutMs
                )
                latencySamples.append(latencyMs)
                lastCompletion = completion

                if let generation = try? await client.fetchGeneration(id: completion.id, apiKey: apiKey) {
                    lastGeneration = generation
                } else {
                    logger.debug("Generation fetch failed", metadata: [
                        "action": .string("generationFetchFailed"),
                        "generationId": .string(completion.id),
                    ])
                }

                lastStatus = ModelHealthStatusResolver.resolve(
                    requestedModelId: model.id,
                    completion: completion
                )

                logger.debug("Ping response received", metadata: [
                    "action": .string("pingResponse"),
                    "modelId": .string(model.id),
                    "respondedModelId": .string(completion.model),
                    "strategy": .string(completion.routingStrategy ?? ""),
                    "attemptCount": .stringConvertible(completion.attemptCount),
                    "latencyMs": .stringConvertible(Int(latencyMs)),
                    "finishReason": .string(completion.finishReason ?? ""),
                    "costUsd": .stringConvertible(completion.cost),
                ])

                if case let .mismatch(actual) = lastStatus {
                    logger.warning("Model mismatch detected", metadata: [
                        "action": .string("modelMismatch"),
                        "requestedModel": .string(model.id),
                        "respondedModel": .string(actual),
                    ])
                }

                if lastStatus == .contentFilter {
                    logger.warning("Content filter hit", metadata: [
                        "action": .string("contentFilter"),
                        "modelId": .string(model.id),
                    ])
                }
            } catch OpenRouterClientError.timedOut {
                lastStatus = .timeout
                logger.warning("Ping timeout", metadata: [
                    "action": .string("pingTimeout"),
                    "modelId": .string(model.id),
                    "timeoutMs": .stringConvertible(timeoutMs),
                ])
                break
            } catch let OpenRouterClientError.httpError(statusCode: statusCode, message: message) {
                let sanitized = OpenRouterClient.sanitize(message, apiKey: apiKey)
                lastStatus = ModelHealthErrorClassifier.pingStatus(statusCode: statusCode, message: sanitized)
                logger.error("Ping error", metadata: [
                    "action": .string("pingError"),
                    "modelId": .string(model.id),
                    "statusCode": .stringConvertible(statusCode),
                    "error": .string(sanitized),
                ])
                break
            } catch {
                let sanitized = OpenRouterClient.sanitize(error.localizedDescription, apiKey: apiKey)
                lastStatus = .error(sanitized)
                logger.error("Ping error", metadata: [
                    "action": .string("pingError"),
                    "modelId": .string(model.id),
                    "error": .string(sanitized),
                ])
                break
            }
        }

        return ModelHealthPingResult(
            id: model.id,
            label: model.name,
            status: lastStatus,
            respondedModelId: lastCompletion?.model,
            providerName: lastGeneration?.providerName,
            testedProviderLabel: PingTransport.openRouter.channelDisplayName,
            modelAlias: model.apiModelId,
            routingStrategy: lastCompletion?.routingStrategy,
            attemptCount: lastCompletion?.attemptCount ?? 1,
            finishReason: lastCompletion?.finishReason,
            latencySamples: latencySamples,
            serverLatency: lastGeneration?.latency,
            generationTime: lastGeneration?.generationTime,
            promptTokens: lastCompletion?.promptTokens ?? 0,
            completionTokens: lastCompletion?.completionTokens ?? 0,
            reasoningTokens: lastCompletion?.reasoningTokens ?? 0,
            cachedTokens: lastCompletion?.cachedTokens ?? 0,
            cost: lastCompletion?.cost ?? 0,
            upstreamCost: lastCompletion?.upstreamCost
        )
    }

    private func pingNousResearchModel(_ model: ModelInfo) async -> ModelHealthPingResult {
        guard let agentKey = NousPortalCredentialStore.resolveAgentKey() else {
            return ModelHealthPingResult(
                id: model.id,
                label: model.name,
                status: .error("Nous key missing — run: hermes login"),
                testedProviderLabel: PingTransport.nousResearch.channelDisplayName,
                modelAlias: model.apiModelId
            )
        }

        do {
            let result = try await nousResearchClient.ping(
                modelId: model.apiModelId,
                prompt: Self.defaultPingPrompt,
                maxTokens: maxTokens,
                timeoutMs: timeoutMs,
                apiKey: agentKey
            )
            let status: ModelHealthPingStatus = result.reply.isEmpty ? .error("Empty reply") : .live
            return ModelHealthPingResult(
                id: model.id,
                label: model.name,
                status: status,
                respondedModelId: model.apiModelId,
                providerName: ModelHealthSubscriptionProvider.nousresearchDirect.displayName,
                testedProviderLabel: PingTransport.nousResearch.channelDisplayName,
                modelAlias: model.apiModelId,
                latencySamples: [result.latencyMs],
                promptTokens: result.promptTokens,
                completionTokens: result.completionTokens
            )
        } catch NousResearchClientError.timedOut {
            return pingFailureResult(for: model, transport: .nousResearch, status: .timeout)
        } catch let NousResearchClientError.httpError(statusCode: statusCode, message: message) {
            return pingFailureResult(
                for: model,
                transport: .nousResearch,
                status: ModelHealthErrorClassifier.pingStatus(statusCode: statusCode, message: message)
            )
        } catch {
            return pingFailureResult(
                for: model,
                transport: .nousResearch,
                status: .error(error.localizedDescription)
            )
        }
    }

    private func pingCLIModel(_ model: ModelInfo, transport: PingTransport) async -> ModelHealthPingResult {
        do {
            let result: (reply: String, latencyMs: Double)
            switch transport {
            case .claudeCLI:
                result = try await cliPingClient.pingClaude(
                    model: model.apiModelId,
                    prompt: Self.defaultPingPrompt,
                    timeoutMs: timeoutMs
                )
            case .geminiCLI:
                result = try await cliPingClient.pingGemini(
                    model: model.apiModelId,
                    prompt: Self.defaultPingPrompt,
                    timeoutMs: timeoutMs
                )
            case .openCode:
                result = try await cliPingClient.pingOpenCode(
                    model: model.apiModelId,
                    prompt: Self.defaultPingPrompt,
                    timeoutMs: timeoutMs
                )
            default:
                return pingFailureResult(
                    for: model,
                    transport: transport,
                    status: .error("Unsupported CLI transport")
                )
            }

            let status: ModelHealthPingStatus = result.reply.isEmpty ? .error("Empty reply") : .live
            return ModelHealthPingResult(
                id: model.id,
                label: model.name,
                status: status,
                respondedModelId: model.apiModelId,
                providerName: model.provider,
                testedProviderLabel: transport.channelDisplayName,
                modelAlias: model.apiModelId,
                latencySamples: [result.latencyMs],
                completionTokens: max(result.reply.count / 4, 1)
            )
        } catch CLIPingError.timeout {
            return pingFailureResult(for: model, transport: transport, status: .timeout)
        } catch let CLIPingError.nonZeroExit(message) {
            return pingFailureResult(
                for: model,
                transport: transport,
                status: ModelHealthErrorClassifier.pingStatus(message: message)
            )
        } catch let CLIPingError.executableNotFound(message) {
            return pingFailureResult(for: model, transport: transport, status: .error(message))
        } catch {
            return pingFailureResult(
                for: model,
                transport: transport,
                status: .error(error.localizedDescription)
            )
        }
    }

    private func pingFailureResult(
        for model: ModelInfo,
        transport: PingTransport,
        status: ModelHealthPingStatus
    ) -> ModelHealthPingResult {
        ModelHealthPingResult(
            id: model.id,
            label: model.name,
            status: status,
            testedProviderLabel: transport.channelDisplayName,
            modelAlias: model.apiModelId
        )
    }

    static func status(
        requestedModelId: String,
        completion: OpenRouterChatCompletion
    ) -> ModelHealthPingStatus {
        ModelHealthStatusResolver.resolve(requestedModelId: requestedModelId, completion: completion)
    }
}

// swiftlint:enable file_length type_body_length
