import SwiftUI

public struct SettingsView: View {
    @Environment(DaytonaConfig.self) private var daytonaConfig
    @Environment(ProviderStore.self) private var providerStore
    @Environment(ThemeManager.self) private var themeManager
    @Environment(BenchmarkStore.self) private var benchmarkStore

    @State private var connectionStatus: String?

    public init() {}

    public var body: some View {
        let tokens = themeManager.resolvedTheme.tokens
        Form {
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

            Section("Task Repository") {
                TextField("Repo URL", text: Bindable(daytonaConfig).taskRepoURL)
                    .textFieldStyle(.roundedBorder)
            }

            Section("Providers") {
                List {
                    ForEach(providerStore.providers) { provider in
                        HStack {
                            Toggle("", isOn: Binding(
                                get: { provider.enabled },
                                set: { newValue in
                                    if let index = providerStore.providers.firstIndex(where: { $0.id == provider.id }) {
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

                            StatusBadge(status: provider.apiKeyStatus(keychain: KeychainService()))
                        }
                    }
                }
                .frame(minHeight: 200)
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
