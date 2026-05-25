// swiftlint:disable type_body_length
import SwiftUI

public struct SettingsView: View {
    @Environment(DaytonaConfig.self) private var daytonaConfig
    @Environment(HostRunConfig.self) private var hostRunConfig
    @Environment(ProviderStore.self) private var providerStore
    @Environment(ThemeManager.self) private var themeManager
    @Environment(BenchmarkStore.self) private var benchmarkStore

    @State private var connectionStatus: String?
    @State private var registry = ModelRegistry()
    @State private var registrySearchText = ""
    @State private var selectedCapabilityFilter: Capability?
    @State private var registryError: String?
    @State private var isLoadingRegistry = false
    @State private var providerKeyDrafts: [String: String] = [:]
    @State private var providerKeySaveStatus: [String: String] = [:]

    private let keychain = KeychainService()

    public init() {}

    public var body: some View {
        let tokens = themeManager.resolvedTheme.tokens
        Form {
            Section("Execution") {
                Picker("Mode", selection: Bindable(hostRunConfig).executionMode) {
                    ForEach(ExecutionMode.allCases, id: \.self) { mode in
                        Text(mode.displayName).tag(mode)
                    }
                }

                if hostRunConfig.executionMode == .host {
                    TextField("Bigpowers Repo", text: Bindable(hostRunConfig).bigpowersRepo)
                        .textFieldStyle(.roundedBorder)
                    TextField("Bigpowers Ref", text: Bindable(hostRunConfig).bigpowersRef)
                        .textFieldStyle(.roundedBorder)
                    TextField("SANDBOX Path", text: Bindable(hostRunConfig).sandboxPath)
                        .textFieldStyle(.roundedBorder)
                    TextField("Worktree Root", text: Bindable(hostRunConfig).worktreeRoot)
                        .textFieldStyle(.roundedBorder)
                    TextField("Score Script", text: Bindable(hostRunConfig).scoreScriptPath)
                        .textFieldStyle(.roundedBorder)
                }
            }

            if hostRunConfig.executionMode == .daytona {
                Section("Daytona") {
                    TextField("Base URL", text: Bindable(daytonaConfig).baseURL)
                        .textFieldStyle(.roundedBorder)
                    if let error = daytonaConfig.baseURLError {
                        Text(error)
                            .font(.caption)
                            .foregroundColor(tokens.bad)
                    }

                    SecureField("API Key", text: Bindable(daytonaConfig).apiKey)
                        .textFieldStyle(.roundedBorder)

                    HStack {
                        Button("Test Connection") {
                            Task {
                                connectionStatus = "Testing..."
                                AppLogger.settings.info("Test Connection started", metadata: [
                                    "baseURL": .string(daytonaConfig.baseURL),
                                ])
                                let client = DaytonaClient(config: daytonaConfig)
                                let result = await client.pingDetailed()
                                switch result {
                                case .success:
                                    connectionStatus = "Connection successful!"
                                    AppLogger.settings.info("Test Connection succeeded")
                                case let .failure(message: message):
                                    connectionStatus = "Connection failed: \(message)"
                                    AppLogger.settings.error("Test Connection failed", metadata: [
                                        "error": .string(message),
                                    ])
                                }
                            }
                        }
                        if let status = connectionStatus {
                            Text(status)
                                .font(.caption)
                                .foregroundColor(status.contains("successful") ? tokens.good : tokens.bad)
                        }
                    }
                }
            }

            Section("Terminal Settings") {
                TextField("Shell Path", text: Bindable(daytonaConfig).terminalShellPath)
                    .textFieldStyle(.roundedBorder)

                HStack {
                    Text("Font Size: \(Int(daytonaConfig.terminalFontSize)) pt")
                    Slider(value: Bindable(daytonaConfig).terminalFontSize, in: 9 ... 24, step: 1)
                }

                Toggle("Use Option as Meta Key", isOn: Bindable(daytonaConfig).terminalOptionAsMeta)
                Toggle("Use Bright Colors", isOn: Bindable(daytonaConfig).terminalUseBrightColors)
            }

            if hostRunConfig.executionMode == .daytona {
                Section("Task Repository") {
                    TextField("Repo URL", text: Bindable(daytonaConfig).taskRepoURL)
                        .textFieldStyle(.roundedBorder)
                }
            }

            Section("Providers") {
                Text(
                    "Keys are resolved from Keychain first, then shell environment (e.g. OPENROUTER_API_KEY), then project .env. Terminals use a login shell so profile exports apply."
                )
                .font(.caption)
                .foregroundColor(tokens.fg3)

                List {
                    ForEach(providerStore.providers) { provider in
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Toggle("", isOn: Binding(
                                    get: { provider.enabled },
                                    set: { newValue in
                                        if let index = providerStore.providers
                                            .firstIndex(where: { $0.id == provider.id }) {
                                            providerStore.providers[index].enabled = newValue
                                            try? providerStore.save()
                                        }
                                    }
                                ))
                                .labelsHidden()

                                VStack(alignment: .leading) {
                                    Text(provider.name)
                                        .font(.headline)
                                        .foregroundColor(tokens.fg)
                                    Text(provider.baseURL)
                                        .font(.caption)
                                        .foregroundColor(tokens.fg3)
                                }

                                Spacer()

                                StatusBadge(status: provider.apiKeyStatus(
                                    keychain: keychain,
                                    dotEnvPaths: credentialDotEnvPaths()
                                ))
                            }

                            HStack {
                                SecureField("API Key", text: providerKeyBinding(for: provider))
                                    .textFieldStyle(.roundedBorder)
                                    .accessibilityLabel("\(provider.name) API key")

                                Button("Save") {
                                    saveProviderKey(provider)
                                }
                                .disabled((providerKeyDrafts[provider.id] ?? "").isEmpty)
                            }

                            if let status = providerKeySaveStatus[provider.id] {
                                Text(status)
                                    .font(.caption2)
                                    .foregroundColor(status.contains("saved") ? tokens.good : tokens.bad)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
                .frame(minHeight: 280)
            }

            Section("Model Registry") {
                TextField("Search models…", text: $registrySearchText)
                    .textFieldStyle(.roundedBorder)
                    .accessibilityLabel("Search models")

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack {
                        RegistryFilterChip(title: "All", isSelected: selectedCapabilityFilter == nil, tokens: tokens) {
                            selectedCapabilityFilter = nil
                        }
                        ForEach(Capability.allCases, id: \.self) { capability in
                            RegistryFilterChip(
                                title: capabilityLabel(capability),
                                isSelected: selectedCapabilityFilter == capability,
                                tokens: tokens
                            ) {
                                selectedCapabilityFilter = selectedCapabilityFilter == capability ? nil : capability
                            }
                        }
                        RegistryFilterChip(
                            title: "128K+ ctx",
                            isSelected: registrySearchText == "__128K__",
                            tokens: tokens
                        ) {
                            registrySearchText = registrySearchText == "__128K__" ? "" : "__128K__"
                        }
                    }
                }

                if isLoadingRegistry {
                    Text("Loading model registry…")
                        .font(.caption)
                        .foregroundColor(tokens.fg3)
                } else if let registryError {
                    Text(registryError)
                        .font(.caption)
                        .foregroundColor(tokens.bad)
                } else if filteredRegistryModels.isEmpty {
                    Text("No models match the current filters.")
                        .font(.caption)
                        .foregroundColor(tokens.fg3)
                } else {
                    List(filteredRegistryModels, id: \.id) { model in
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Text(model.name)
                                    .font(.headline)
                                    .foregroundColor(tokens.fg)
                                Spacer()
                                Text(model.tier.rawValue.capitalized)
                                    .font(.caption2)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(tokens.surface2)
                                    .clipShape(Capsule())
                            }

                            HStack(spacing: 8) {
                                Text(model.provider)
                                    .font(.caption)
                                    .foregroundColor(tokens.fg3)
                                Text(model.formattedContextWindow)
                                    .font(.caption.monospaced())
                                    .foregroundColor(tokens.fg2)
                                Text(model.pricing.formatted)
                                    .font(.caption)
                                    .foregroundColor(tokens.fg3)
                            }

                            HStack(spacing: 6) {
                                ForEach(model.capabilities, id: \.self) { capability in
                                    Text(capabilityLabel(capability))
                                        .font(.caption2)
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(tokens.surface2)
                                        .clipShape(Capsule())
                                }
                            }
                        }
                        .accessibilityElement(children: .combine)
                    }
                    .frame(minHeight: 220)
                }

                Button("Refresh Registry") {
                    Task { await loadRegistry(force: true) }
                }
                .disabled(isLoadingRegistry)
            }

            Section("General") {
                Picker("Theme", selection: Bindable(themeManager).current) {
                    ForEach(Theme.allCases, id: \.self) { theme in
                        Text(theme.rawValue.capitalized).tag(theme)
                    }
                }
            }

            Section("GitOps") {
                Toggle("Auto-commit results", isOn: Bindable(benchmarkStore).autoCommit)
            }

            Section {
                Text("Logs: \(AppLogger.logFileURL.path)")
                    .font(.caption2)
                    .foregroundColor(tokens.fg4)
            }
        }
        .formStyle(.grouped)
        .padding()
        .frame(width: 500, height: 600)
        .onAppear {
            try? providerStore.load()
            loadProviderKeyDrafts()
        }
        .task {
            await loadRegistry(force: false)
        }
    }

    private var filteredRegistryModels: [ModelInfo] {
        registry.models.filter { model in
            let matchesSearch: Bool
            if registrySearchText == "__128K__" {
                matchesSearch = model.contextWindow >= 128_000
            } else if registrySearchText.isEmpty {
                matchesSearch = true
            } else {
                let query = registrySearchText.lowercased()
                matchesSearch = model.name.lowercased().contains(query)
                    || model.id.lowercased().contains(query)
                    || model.provider.lowercased().contains(query)
            }

            let matchesCapability = selectedCapabilityFilter.map { model.capabilities.contains($0) } ?? true
            return matchesSearch && matchesCapability
        }
    }

    private func capabilityLabel(_ capability: Capability) -> String {
        switch capability {
        case .tools: "Tools"
        case .vision: "Vision"
        case .reasoning: "Reasoning"
        case .streaming: "Streaming"
        }
    }

    private func loadRegistry(force: Bool) async {
        if !force, !registry.models.isEmpty { return }
        isLoadingRegistry = true
        registryError = nil
        defer { isLoadingRegistry = false }

        guard let apiKey = ProviderCredentialResolver.resolve(
            providerId: "openrouter",
            keychain: keychain,
            dotEnvPaths: credentialDotEnvPaths()
        )?.value, !apiKey.isEmpty else {
            registryError = "OpenRouter API key not configured — set OPENROUTER_API_KEY or add in Providers"
            return
        }

        do {
            _ = try await registry.loadModels(apiKey: apiKey, forceRefresh: force)
        } catch let error as ModelRegistryError {
            switch error {
            case .missingAPIKey:
                registryError = "OpenRouter API key not configured"
            case let .fetchFailed(message):
                registryError = message
            }
        } catch {
            registryError = error.localizedDescription
        }
    }

    private func credentialDotEnvPaths() -> [URL] {
        let projectRoot = URL(fileURLWithPath: hostRunConfig.sandboxPath, isDirectory: true)
            .deletingLastPathComponent()
        return ProviderCredentialResolver.defaultDotEnvPaths(projectRoot: projectRoot)
    }

    private func providerKeyBinding(for provider: Provider) -> Binding<String> {
        Binding(
            get: { providerKeyDrafts[provider.id] ?? "" },
            set: { providerKeyDrafts[provider.id] = $0 }
        )
    }

    private func loadProviderKeyDrafts() {
        for provider in providerStore.providers {
            providerKeyDrafts[provider.id] = keychain.load(account: provider.keychainAccount) ?? ""
        }
    }

    private func saveProviderKey(_ provider: Provider) {
        let draft = providerKeyDrafts[provider.id] ?? ""
        guard !draft.isEmpty else {
            providerKeySaveStatus[provider.id] = "Enter an API key first"
            return
        }

        do {
            try keychain.save(draft, account: provider.keychainAccount)
            providerKeySaveStatus[provider.id] = "API key saved to Keychain"
            AppLogger.settings.info("Provider API key saved", metadata: [
                "providerId": .string(provider.id),
            ])
            if provider.id == "openrouter" {
                Task { await loadRegistry(force: true) }
            }
        } catch {
            providerKeySaveStatus[provider.id] = "Failed to save API key"
            AppLogger.settings.error("Provider API key save failed", metadata: [
                "providerId": .string(provider.id),
                "error": .string(LogSanitizer.sanitize(error.localizedDescription)),
            ])
        }
    }
}

struct StatusBadge: View {
    let status: ApiKeyStatus

    var body: some View {
        Text(status.rawValue.capitalized)
            .font(.caption2)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(backgroundColor.opacity(0.2))
            .foregroundColor(backgroundColor)
            .clipShape(Capsule())
    }

    var backgroundColor: Color {
        switch status {
        case .configured: .green
        case .notSet: .gray
        case .error: .red
        }
    }
}

private struct RegistryFilterChip: View {
    let title: String
    let isSelected: Bool
    let tokens: ThemeTokens
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.caption)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(isSelected ? tokens.accent.opacity(0.2) : tokens.surface2)
                .foregroundColor(isSelected ? tokens.accent : tokens.fg3)
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
    }
}
