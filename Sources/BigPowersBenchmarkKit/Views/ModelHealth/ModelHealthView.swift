// swiftlint:disable file_length cyclomatic_complexity type_body_length
import SwiftUI

public struct ModelHealthView: View {
    @Environment(BenchmarkStore.self) private var store
    @Environment(ThemeManager.self) private var themeManager
    @Environment(ProviderStore.self) private var providerStore
    @Environment(HostRunConfig.self) private var hostRunConfig
    @Environment(ModelHealthHistoryStore.self) private var historyStore
    @Environment(ModelHealthViewModel.self) private var viewModel
    @Environment(ModelRegistry.self) private var registry
    @Environment(ModelHealthColumnCustomizationStore.self) private var columnStore
    @Environment(ModelIntelStore.self) private var intelStore
    @Environment(\.openSettings) private var openSettings

    @State private var registryError: String?
    @State private var isLoadingRegistry = false
    @State private var isRefreshingCatalog = false
    @State private var showMissingKeyAlert = false

    public init() {}

    public var body: some View {
        let tokens = themeManager.resolvedTheme.tokens
        VStack(alignment: .leading, spacing: 20) {
            header(tokens: tokens)
            controlsStrip(tokens: tokens)
            configStrip(tokens: tokens)
            leaderboardSection(tokens: tokens)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .padding(30)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(tokens.bg)
        .task {
            try? providerStore.load()
            sanitizeProviderSelection()
            await loadRegistryIfNeeded()
        }
        .onAppear {
            sanitizeProviderSelection()
            Task { await loadRegistryIfNeeded() }
        }
        .alert("OpenRouter API Key Required", isPresented: $showMissingKeyAlert) {
            Button("Open Settings") { openSettings() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text(
                "Set OPENROUTER_API_KEY in your shell or project .env, or add a key under Settings → Providers, then tap Ping All."
            )
        }
    }

    private func header(tokens: ThemeTokens) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Model Health & Leaderboard")
                .font(.largeTitle)
                .fontWeight(.bold)
                .foregroundColor(tokens.fg)
            Text("Monitor LLM provider statuses, latency, and capability ranks.")
                .foregroundColor(tokens.fg3)
        }
    }

    private func controlsStrip(tokens: ThemeTokens) -> some View {
        HStack(spacing: 12) {
            Menu {
                ForEach(ModelPingScope.allCases, id: \.self) { scope in
                    Button {
                        viewModel.pingScope = scope
                    } label: {
                        if viewModel.pingScope == scope {
                            Label(scope.label, systemImage: "checkmark")
                        } else {
                            Text(scope.label)
                        }
                    }
                }
            } label: {
                Label(
                    viewModel.isPinging ? "Pinging…" : "Ping \(viewModel.pingScope.label)",
                    systemImage: "play.fill"
                )
            } primaryAction: {
                Task { await runPingAll() }
            }
            .menuStyle(.borderlessButton)
            .buttonStyle(.borderedProminent)
            .tint(tokens.accent)
            .disabled(viewModel.isPinging)
            .accessibilityLabel("Ping models")

            if viewModel.isPinging {
                Button {
                    viewModel.stopPing()
                } label: {
                    Label("Stop", systemImage: "stop.fill")
                }
                .buttonStyle(.bordered)
                .tint(tokens.bad)
                .accessibilityLabel("Stop ping batch")
            }

            if openRouterAPIKey() == nil {
                Button("Add API Key") {
                    openSettings()
                }
                .accessibilityLabel("Open Settings to add OpenRouter API key")
            }

            providerFilter(tokens: tokens)
            if canRefreshCatalog {
                refreshCatalogButton(tokens: tokens)
            }
            tierFilter(tokens: tokens)

            Spacer()

            statusInfo(tokens: tokens)

            Toggle("Reasoning", isOn: Bindable(viewModel).showReasoningColumn)
                .toggleStyle(.checkbox)
                .accessibilityLabel("Show reasoning tokens column")
        }
    }

    private func providerFilter(tokens: ThemeTokens) -> some View {
        Menu {
            Button("All Providers") { viewModel.selectProvider(nil) }
            Divider()
            ForEach(subscriptionProviders, id: \.rawValue) { provider in
                Button(provider.displayName) { viewModel.selectProvider(provider.rawValue) }
            }
        } label: {
            Label(
                viewModel.selectedProvider.map(ModelHealthSubscriptionProvider.displayName(for:)) ?? "Provider",
                systemImage: "line.3.horizontal.decrease.circle"
            )
        }
        .accessibilityLabel("Filter by provider")
        .foregroundColor(tokens.fg2)
    }

    private var canRefreshCatalog: Bool {
        viewModel.selectedProvider != nil
    }

    private func refreshCatalogButton(tokens: ThemeTokens) -> some View {
        Button {
            Task { await refreshCatalog() }
        } label: {
            Label("Refresh Catalog", systemImage: "arrow.clockwise")
        }
        .buttonStyle(.bordered)
        .disabled(isRefreshingCatalog || viewModel.isPinging)
        .accessibilityLabel("Refresh model catalog for selected provider")
        .foregroundColor(tokens.fg2)
    }

    private func tierFilter(tokens: ThemeTokens) -> some View {
        Menu {
            Button("All Tiers") { viewModel.selectedTier = nil }
            Divider()
            ForEach(Tier.allCases, id: \.self) { tier in
                Button(tier.rawValue.capitalized) { viewModel.selectedTier = tier }
            }
        } label: {
            Label(viewModel.selectedTier?.rawValue.capitalized ?? "Tier", systemImage: "slider.horizontal.3")
        }
        .accessibilityLabel("Filter by tier")
        .foregroundColor(tokens.fg2)
    }

    private func statusInfo(tokens: ThemeTokens) -> some View {
        HStack(spacing: 16) {
            if viewModel.isPinging {
                Text("Pinging \(viewModel.pingCompletedCount)/\(viewModel.pingTotalCount)…")
                    .font(.caption)
                    .foregroundColor(tokens.accent)
            } else if let lastPing = viewModel.lastPingDate {
                Text("Last ping: \(relativeTime(since: lastPing))")
                    .font(.caption)
                    .foregroundColor(tokens.fg3)
            } else {
                Text("Last ping: never")
                    .font(.caption)
                    .foregroundColor(tokens.fg3)
            }

            Text(
                "\(viewModel.filteredRows(from: registry.models).count) shown · \(viewModel.responsiveCount) responded · \(viewModel.timeoutCount) timeout · \(viewModel.mismatchCount) mismatch · \(viewModel.noCreditCount) no credit · \(intelStore.smartFreeCount) smart free · \(intelStore.benchCandidateCount) bench"
            )
            .font(.caption)
            .foregroundColor(tokens.fg3)

            if let registryError {
                Text(registryError)
                    .font(.caption)
                    .foregroundColor(tokens.bad)
            } else if isRefreshingCatalog {
                Text("Refreshing catalog…")
                    .font(.caption)
                    .foregroundColor(tokens.fg4)
            } else if isLoadingRegistry {
                Text("Loading registry…")
                    .font(.caption)
                    .foregroundColor(tokens.fg4)
            }
        }
    }

    private func configStrip(tokens: ThemeTokens) -> some View {
        HStack(spacing: 20) {
            LabeledContent("Token Count") {
                TextField("10", value: Bindable(viewModel).maxTokens, format: .number)
                    .frame(width: 70)
                    .textFieldStyle(.roundedBorder)
                    .accessibilityLabel("Token count")
            }

            LabeledContent("Parallelism") {
                TextField("4", value: Bindable(viewModel).parallelism, format: .number)
                    .frame(width: 70)
                    .textFieldStyle(.roundedBorder)
                    .accessibilityLabel("Parallelism")
            }

            LabeledContent("Timeout (ms)") {
                TextField("30000", value: Bindable(viewModel).timeoutMs, format: .number)
                    .frame(width: 90)
                    .textFieldStyle(.roundedBorder)
                    .accessibilityLabel("Timeout in milliseconds")
            }
        }
        .font(.caption)
        .foregroundColor(tokens.fg2)
    }

    private func leaderboardSection(tokens: ThemeTokens) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Latency Leaderboard")
                .font(.headline)
                .foregroundColor(tokens.fg)

            let rows = viewModel.filteredRows(from: registry.models)
            Group {
                if rows.isEmpty, viewModel.isPinging {
                    HStack(spacing: 8) {
                        ProgressView()
                            .controlSize(.small)
                        Text("Waiting for first results…")
                            .font(.caption)
                            .foregroundColor(tokens.fg3)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if rows.isEmpty {
                    ThemedInlineEmpty(
                        icon: "network",
                        title: "No ping data yet",
                        tokens: tokens
                    )
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    let maxP50 = rows.map(\.p50).max() ?? 1
                    let tableRows = rows.enumerated().map { index, row in
                        ModelHealthTableRow.from(
                            result: row,
                            rank: index + 1,
                            registry: registry.models,
                            maxP50: maxP50
                        )
                    }
                    let resultByID = Dictionary(uniqueKeysWithValues: rows.map { ($0.id, $0) })
                    ModelHealthLeaderboardTable(
                        rows: tableRows,
                        maxP50: maxP50,
                        tokens: tokens,
                        mode: viewModel.showReasoningColumn ? .liveReason : .liveCost,
                        columnCustomization: Bindable(columnStore).live
                    ) { tableRow in
                        if let result = resultByID[tableRow.id] {
                            modelColumn(row: result, tokens: tokens)
                        }
                    }
                    .onChange(of: columnStore.live) { _, _ in
                        columnStore.persistLive()
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(tokens.surface)
        .cornerRadius(12)
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(tokens.border, lineWidth: 1))
    }

    @ViewBuilder
    private func modelColumn(row: ModelHealthPingResult, tokens: ThemeTokens) -> some View {
        let model = registry.models.first { $0.id == row.id }
        let alias = row.modelAlias ?? model?.apiModelId
        let providerLabel = row.testedProviderLabel ?? model?.pingTransport.channelDisplayName
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                Text(row.label)
                    .fontWeight(.medium)
                    .foregroundColor(tokens.fg)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
                if let alias, !alias.isEmpty {
                    Text(alias)
                        .font(.caption)
                        .fontDesign(.monospaced)
                        .foregroundColor(tokens.fg3)
                        .lineLimit(1)
                        .help("Ping alias: \(alias)")
                }
                if case let .mismatch(actual) = row.status {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(tokens.warn)
                        .help("Responded as: \(actual)")
                }
                if row.finishReason != nil, row.finishReason != "stop" {
                    FinishReasonBadge(reason: row.finishReason!, tokens: tokens)
                }
            }

            HStack(spacing: 6) {
                if let providerLabel {
                    ProviderBadge(label: providerLabel, tokens: tokens)
                }
                if let model {
                    Text("ctx: \(model.formattedContextWindow)")
                        .font(.caption2)
                        .foregroundColor(tokens.fg3)
                    ForEach(model.capabilities, id: \.self) { capability in
                        CapabilityChip(capability: capability, tokens: tokens)
                    }
                }
                if let detail = row.status.statusDetail {
                    Text(detail)
                        .font(.caption2)
                        .foregroundColor(tokens.bad)
                        .lineLimit(1)
                        .help(detail)
                }
                if let strategy = row.routingStrategy, !strategy.isEmpty {
                    RoutingChip(strategy: strategy, tokens: tokens)
                }
                if row.attemptCount > 1 {
                    Circle()
                        .fill(tokens.warn)
                        .frame(width: 6, height: 6)
                        .help("Served on attempt \(row.attemptCount)")
                }
            }

            if let benchSubtitle = benchSubtitle(for: row.id) {
                Text(benchSubtitle)
                    .font(.caption2)
                    .foregroundColor(tokens.fg4)
            }
        }
    }

    private var subscriptionProviders: [ModelHealthSubscriptionProvider] {
        ModelHealthSubscriptionProvider.available(
            providerStore: providerStore,
            dotEnvPaths: credentialDotEnvPaths()
        )
    }

    private func sanitizeProviderSelection() {
        guard let selected = viewModel.selectedProvider else { return }
        let available = Set(subscriptionProviders.map(\.rawValue))
        if !available.contains(selected) {
            viewModel.selectProvider(nil)
        }
    }

    private func loadRegistryIfNeeded(force: Bool = false) async {
        if !force, !registry.models.isEmpty { return }
        isLoadingRegistry = true
        registryError = nil
        defer { isLoadingRegistry = false }

        guard let apiKey = openRouterAPIKey(), !apiKey.isEmpty else {
            registryError = "OpenRouter API key not configured — set OPENROUTER_API_KEY, .env, or Settings → Providers"
            return
        }

        do {
            _ = try await registry.loadModels(apiKey: apiKey)
            intelStore.seed(from: registry.models)
        } catch let error as ModelRegistryError {
            switch error {
            case .missingAPIKey:
                registryError = "OpenRouter API key not configured — set OPENROUTER_API_KEY, .env, or Settings → Providers"
            case let .fetchFailed(message):
                registryError = message
            }
        } catch {
            registryError = error.localizedDescription
        }
    }

    private func refreshCatalog() async {
        guard let selected = viewModel.selectedProvider else { return }
        isRefreshingCatalog = true
        registryError = nil
        defer { isRefreshingCatalog = false }

        let service = CatalogRefreshService()
        let fetchedAt = Date()
        var nousModels = StaticModelCatalogs.nousResearch
        var openCodeModels = StaticModelCatalogs.openCode
        var claudeModels = StaticModelCatalogs.claudeCLI
        var geminiModels = StaticModelCatalogs.geminiCLI

        do {
            switch selected {
            case ModelHealthSubscriptionProvider.openrouter.rawValue:
                guard let apiKey = openRouterAPIKey(), !apiKey.isEmpty else {
                    registryError = "OpenRouter API key not configured — set OPENROUTER_API_KEY, .env, or Settings → Providers"
                    return
                }
                _ = try await registry.loadModels(apiKey: apiKey, forceRefresh: true)
                return
            case ModelHealthSubscriptionProvider.nousresearchDirect.rawValue:
                guard let apiKey = NousPortalCredentialStore.resolveAgentKey(), !apiKey.isEmpty else {
                    registryError = "Nous key missing — run: hermes login"
                    return
                }
                nousModels = try await service.refreshNous(apiKey: apiKey, timeoutMs: viewModel.timeoutMs)
            case ModelHealthSubscriptionProvider.opencode.rawValue:
                openCodeModels = try await service.refreshOpenCode(timeoutMs: viewModel.timeoutMs)
            case ModelHealthSubscriptionProvider.claudecli.rawValue:
                claudeModels = try await service.refreshClaudeCLI(timeoutMs: viewModel.timeoutMs)
            case ModelHealthSubscriptionProvider.geminicli.rawValue:
                geminiModels = try await service.refreshGeminiCLI(timeoutMs: viewModel.timeoutMs)
            default:
                return
            }

            let cache = StaticCatalogCache(
                fetchedAt: fetchedAt,
                nousResearch: nousModels,
                openCode: openCodeModels,
                claudeCLI: claudeModels,
                geminiCLI: geminiModels
            )
            try cache.save()
            StaticModelCatalogs.applyCache(cache)
            registry.remergeStaticCatalog()
        } catch let error as CatalogRefreshError {
            switch error {
            case let .missingCredentials(message):
                registryError = message
            case .invalidResponse:
                registryError = "Invalid catalog response"
            case let .httpError(statusCode: code, message: message):
                registryError = "HTTP \(code): \(message)"
            case .timedOut:
                registryError = "Catalog fetch timed out"
            case let .cliFailed(message):
                registryError = message
            }
        } catch let error as ModelRegistryError {
            switch error {
            case .missingAPIKey:
                registryError = "OpenRouter API key not configured — set OPENROUTER_API_KEY, .env, or Settings → Providers"
            case let .fetchFailed(message):
                registryError = message
            }
        } catch {
            registryError = error.localizedDescription
        }
    }

    private func runPingAll() async {
        guard let apiKey = openRouterAPIKey(), !apiKey.isEmpty else {
            registryError = "OpenRouter API key not configured — set OPENROUTER_API_KEY, .env, or Settings → Providers"
            showMissingKeyAlert = true
            return
        }
        registryError = nil
        if registry.models.isEmpty {
            await loadRegistryIfNeeded(force: true)
        }
        guard !registry.models.isEmpty else {
            registryError = registryError ?? "No models loaded from OpenRouter"
            return
        }
        let targetCount = viewModel.pingTargets(from: registry.models).count
        guard targetCount > 0 else {
            registryError = "No models match the current ping scope and filters"
            return
        }
        viewModel.startPingAll(models: registry.models, apiKey: apiKey) {
            let snapshot = ModelHealthSnapshot.make(
                from: viewModel.rows,
                registry: registry.models,
                scope: viewModel.pingScope
            )
            try? historyStore.save(snapshot)
            try? intelStore.ingest(snapshot: snapshot, registry: registry.models)
        }
    }

    private func openRouterAPIKey() -> String? {
        ProviderCredentialResolver.resolve(
            providerId: "openrouter",
            dotEnvPaths: credentialDotEnvPaths()
        )?.value
    }

    private func credentialDotEnvPaths() -> [URL] {
        let projectRoot = URL(fileURLWithPath: hostRunConfig.sandboxPath, isDirectory: true)
            .deletingLastPathComponent()
        return ProviderCredentialResolver.defaultDotEnvPaths(projectRoot: projectRoot)
    }

    private func benchSubtitle(for modelId: String) -> String? {
        let runs = store.runs.filter { $0.modelId == modelId }
        guard !runs.isEmpty else { return nil }
        let avgScore = runs.map(\.overallScore).reduce(0, +) / Double(runs.count)
        let latest = runs.max(by: { $0.timestamp < $1.timestamp })?.timestamp
        let age = latest.map { relativeTime(since: $0) } ?? "unknown"
        return "Last bench: \(age) · avg \(String(format: "%.0f", avgScore))"
    }

    private func relativeTime(since date: Date) -> String {
        let seconds = Int(Date().timeIntervalSince(date))
        if seconds < 60 { return "\(seconds)s ago" }
        if seconds < 3600 { return "\(seconds / 60)m ago" }
        if seconds < 86400 { return "\(seconds / 3600)h ago" }
        return "\(seconds / 86400)d ago"
    }
}

private struct ProviderBadge: View {
    let label: String
    let tokens: ThemeTokens

    var body: some View {
        let color = Self.color(for: label, tokens: tokens)
        Text(label)
            .font(.caption2)
            .fontWeight(.medium)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(color.opacity(0.15))
            .foregroundColor(color)
            .clipShape(Capsule())
            .help("Tested via \(label)")
    }

    private static func color(for label: String, tokens: ThemeTokens) -> Color {
        switch label {
        case "OpenRouter": Color(hex: "#7C3AED")
        case "Nous Portal": Color(hex: "#F97316")
        case "OpenCode Zen": Color(hex: "#3B82F6")
        case "Claude CLI": Color(hex: "#D97706")
        case "Gemini CLI": Color(hex: "#1A73E8")
        default: tokens.fg3
        }
    }
}

private struct CapabilityChip: View {
    let capability: Capability
    let tokens: ThemeTokens

    var body: some View {
        Text(label)
            .font(.caption2)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(tokens.surface2)
            .foregroundColor(tokens.fg3)
            .clipShape(Capsule())
    }

    private var label: String {
        switch capability {
        case .tools: "Tools"
        case .vision: "Vision"
        case .reasoning: "Reasoning"
        case .streaming: "Stream"
        }
    }
}

private struct RoutingChip: View {
    let strategy: String
    let tokens: ThemeTokens

    var body: some View {
        Text(strategy)
            .font(.caption2)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(tokens.accent.opacity(0.15))
            .foregroundColor(tokens.accent)
            .clipShape(Capsule())
    }
}

private struct FinishReasonBadge: View {
    let reason: String
    let tokens: ThemeTokens

    var body: some View {
        Text(reason)
            .font(.caption2)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(color.opacity(0.15))
            .foregroundColor(color)
            .clipShape(Capsule())
    }

    private var color: Color {
        switch reason {
        case "content_filter", "error": tokens.bad
        case "length": tokens.warn
        default: tokens.fg3
        }
    }
}
