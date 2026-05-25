import Foundation

public enum StaticModelCatalogs {
    /// CLI models bill against subscription quota — not OpenRouter-style free tier.
    private static let quotaPricing = ModelPricing(inputPer1k: 1, outputPer1k: 1)
    private static let freePricing = ModelPricing(inputPer1k: 0, outputPer1k: 0)
    private static let cliCapabilities: [Capability] = [.tools, .streaming]
    private static let cliContextWindow = 128_000

    private static let defaultNousResearch: [ModelInfo] = [
        portalModel(id: "anthropic/claude-opus-4.7", name: "Claude Opus 4.7"),
        portalModel(id: "anthropic/claude-opus-4.6", name: "Claude Opus 4.6"),
        portalModel(id: "anthropic/claude-sonnet-4.6", name: "Claude Sonnet 4.6"),
        portalModel(id: "moonshotai/kimi-k2.6", name: "Kimi K2.6"),
        portalModel(id: "qwen/qwen3.6-plus", name: "Qwen 3.6 Plus"),
        portalModel(id: "anthropic/claude-haiku-4.5", name: "Claude Haiku 4.5"),
        portalModel(id: "openai/gpt-5.5", name: "GPT-5.5"),
        portalModel(id: "openai/gpt-5.5-pro", name: "GPT-5.5 Pro"),
        portalModel(id: "openai/gpt-5.4-mini", name: "GPT-5.4 Mini"),
        portalModel(id: "openai/gpt-5.4-nano", name: "GPT-5.4 Nano"),
        portalModel(id: "openai/gpt-5.3-codex", name: "GPT-5.3 Codex"),
        portalModel(id: "xiaomi/mimo-v2.5-pro", name: "Xiaomi Mimo v2.5 Pro"),
        portalModel(id: "tencent/hy3-preview", name: "Tencent HY3 Preview"),
        portalModel(id: "google/gemini-3-pro-preview", name: "Gemini 3 Pro Preview"),
        portalModel(id: "google/gemini-3-flash-preview", name: "Gemini 3 Flash Preview"),
        portalModel(id: "google/gemini-3.1-pro-preview", name: "Gemini 3.1 Pro Preview"),
        portalModel(id: "google/gemini-3.1-flash-lite-preview", name: "Gemini 3.1 Flash Lite Preview"),
        portalModel(id: "qwen/qwen3.6-35b-a3b", name: "Qwen 3.6 35B A3B"),
        portalModel(id: "stepfun/step-3.5-flash", name: "StepFun Step 3.5 Flash"),
        portalModel(id: "minimax/minimax-m2.7", name: "MiniMax M2.7"),
        portalModel(id: "z-ai/glm-5.1", name: "Z.ai GLM 5.1"),
        portalModel(id: "x-ai/grok-4.3", name: "Grok 4.3"),
        portalModel(id: "nvidia/nemotron-3-super-120b-a12b", name: "Nemotron 3 Super 120B"),
        portalModel(id: "deepseek/deepseek-v4-pro", name: "DeepSeek V4 Pro"),
    ]

    private static let defaultOpenCode: [ModelInfo] = [
        opencodeModel(id: "opencode/big-pickle", name: "OpenCode Zen Big Pickle"),
        opencodeModel(
            id: "opencode/deepseek-v4-flash-free",
            name: "OpenCode Zen DeepSeek V4 Flash (Free)",
            free: true
        ),
        opencodeModel(
            id: "opencode/nemotron-3-super-free",
            name: "OpenCode Zen Nemotron 3 Super (Free)",
            free: true
        ),
    ]

    public nonisolated(unsafe) static var nousResearch: [ModelInfo] = defaultNousResearch

    private static let defaultClaudeCLI: [ModelInfo] = [
        claudeCLIModel(modelArg: "haiku", name: "Claude CLI (Haiku)"),
        claudeCLIModel(modelArg: "opus", name: "Claude CLI (Opus)"),
        claudeCLIModel(modelArg: "sonnet", name: "Claude CLI (Sonnet)"),
    ]

    /// Models available via `gemini -m` on Gemini CLI.
    private static let defaultGeminiCLI: [ModelInfo] = [
        geminiCLIModel(modelArg: "gemini-2.5-flash", name: "Gemini CLI (2.5 Flash)"),
        geminiCLIModel(modelArg: "gemini-2.5-pro", name: "Gemini CLI (2.5 Pro)"),
        geminiCLIModel(modelArg: "gemini-3-flash-preview", name: "Gemini CLI (3 Flash)"),
        geminiCLIModel(modelArg: "gemini-3.1-pro-preview", name: "Gemini CLI (3.1 Pro)"),
    ]

    public nonisolated(unsafe) static var claudeCLI: [ModelInfo] = defaultClaudeCLI

    public nonisolated(unsafe) static var geminiCLI: [ModelInfo] = defaultGeminiCLI

    /// OpenCode Zen models from `opencode models opencode` (provider/model slug).
    public nonisolated(unsafe) static var openCode: [ModelInfo] = defaultOpenCode

    public static var all: [ModelInfo] {
        nousResearch + claudeCLI + geminiCLI + openCode
    }

    public static func loadFromDisk(cacheURL: URL = StaticCatalogCache.defaultCacheURL) {
        guard let cache = StaticCatalogCache.load(from: cacheURL) else { return }
        applyCache(cache)
    }

    static var defaultNousResearchModelIds: [String] {
        defaultNousResearch.compactMap(\.resolvedModelId)
    }

    public static func applyCache(_ cache: StaticCatalogCache) {
        if !cache.nousResearch.isEmpty,
           cache.nousResearch.count <= NousCuratedCatalog.maxCachedModelCount {
            nousResearch = cache.nousResearch
        }
        if !cache.openCode.isEmpty {
            openCode = cache.openCode
        }
        if !cache.claudeCLI.isEmpty {
            claudeCLI = cache.claudeCLI
        }
        if !cache.geminiCLI.isEmpty {
            geminiCLI = cache.geminiCLI
        }
    }

    static func claudeCLIModel(modelArg: String, name: String? = nil) -> ModelInfo {
        let displayName = name ?? "Claude CLI (\(CatalogRefreshService.displayName(fromModelId: modelArg)))"
        return cliModel(
            id: "claudecli:\(modelArg)",
            name: displayName,
            modelArg: modelArg,
            transport: .claudeCLI
        )
    }

    static func geminiCLIModel(modelArg: String, name: String? = nil) -> ModelInfo {
        let displayName = name ?? "Gemini CLI (\(CatalogRefreshService.displayName(fromModelId: modelArg)))"
        return cliModel(
            id: "geminicli:\(modelArg)",
            name: displayName,
            modelArg: modelArg,
            transport: .geminiCLI
        )
    }

    static func portalModel(
        id resolvedModelId: String,
        name: String,
        contextWindow: Int = cliContextWindow
    ) -> ModelInfo {
        ModelInfo(
            id: "nousresearch-direct:\(resolvedModelId)",
            name: name,
            provider: "nousresearch-direct",
            contextWindow: contextWindow,
            tier: .deep,
            capabilities: cliCapabilities,
            pricing: quotaPricing,
            pingTransport: .nousResearch,
            resolvedModelId: resolvedModelId
        )
    }

    static func opencodeModel(id modelSlug: String, name: String, free: Bool = false) -> ModelInfo {
        ModelInfo(
            id: "opencode:\(modelSlug)",
            name: name,
            provider: "opencode",
            contextWindow: cliContextWindow,
            tier: .deep,
            capabilities: cliCapabilities,
            pricing: free ? freePricing : quotaPricing,
            pingTransport: .openCode,
            resolvedModelId: modelSlug
        )
    }

    private static func cliModel(
        id: String,
        name: String,
        modelArg: String,
        transport: PingTransport,
        provider: String? = nil
    ) -> ModelInfo {
        let providerId: String = switch transport {
        case .claudeCLI: "claudecli"
        case .geminiCLI: "geminicli"
        case .openCode: provider ?? "opencode"
        default: provider ?? "unknown"
        }

        return ModelInfo(
            id: id,
            name: name,
            provider: providerId,
            contextWindow: cliContextWindow,
            tier: .deep,
            capabilities: cliCapabilities,
            pricing: quotaPricing,
            pingTransport: transport,
            resolvedModelId: modelArg
        )
    }
}
