import SwiftUI

struct InventoryRow: Identifiable {
    let id: String
    let label: String
    let provider: String
    let pingTransport: String?
    let p50: Double
    let cost: Double
    let responded: Bool
    let modelMatched: Bool
    let notContentFiltered: Bool
    let hasTools: Bool
    let isFree: Bool
    let hasContext: Bool
    let suitability: BenchmarkSuitability
    let lastPingAt: Date?
    let tier: Tier?
}

public struct HealthInventoryView: View {
    @Environment(ModelIntelStore.self) private var intelStore
    @Environment(ModelRegistry.self) private var registry
    @Environment(ThemeManager.self) private var themeManager

    @State private var selectedProvider: String?
    @State private var selectedTier: Tier?
    @State private var benchOnly = false
    @State private var searchText = ""

    public init() {}

    public var body: some View {
        let tokens = themeManager.resolvedTheme.tokens
        VStack(alignment: .leading, spacing: 20) {
            header(tokens: tokens)
            controlsStrip(tokens: tokens)
            tableSection(tokens: tokens)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .padding(30)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(tokens.bg)
    }

    private func header(tokens: ThemeTokens) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Health Inventory")
                .font(.largeTitle)
                .fontWeight(.bold)
                .foregroundColor(tokens.fg)
            Text("Latest ping result per model across all provider catalogs.")
                .foregroundColor(tokens.fg3)
        }
    }

    private func controlsStrip(tokens: ThemeTokens) -> some View {
        HStack(spacing: 12) {
            Menu {
                Button("All Providers") { selectedProvider = nil }
                Divider()
                ForEach(availableProviders, id: \.self) { provider in
                    Button(provider) { selectedProvider = provider }
                }
            } label: {
                Label(
                    selectedProvider ?? "Provider",
                    systemImage: "line.3.horizontal.decrease.circle"
                )
            }
            .foregroundColor(tokens.fg2)

            Menu {
                Button("All Tiers") { selectedTier = nil }
                Divider()
                ForEach(Tier.allCases, id: \.self) { tier in
                    Button(tier.rawValue.capitalized) { selectedTier = tier }
                }
            } label: {
                Label(
                    selectedTier?.rawValue.capitalized ?? "Tier",
                    systemImage: "slider.horizontal.3"
                )
            }
            .foregroundColor(tokens.fg2)

            Toggle("Bench candidates only", isOn: $benchOnly)
                .toggleStyle(.checkbox)

            Spacer()

            TextField("Search models", text: $searchText)
                .textFieldStyle(.roundedBorder)
                .frame(maxWidth: 220)
        }
        .font(.caption)
    }

    @ViewBuilder
    private func tableSection(tokens: ThemeTokens) -> some View {
        let rows = filteredRows
        if rows.isEmpty {
            ThemedInlineEmpty(
                icon: "checklist",
                title: "No ping data yet — run a ping batch in Model Health first.",
                tokens: tokens
            )
        } else {
            let maxP50 = rows.map(\.p50).max() ?? 1
            Table(rows) {
                TableColumn("Bench?") { row in
                    BenchSuitabilityBadge(suitability: row.suitability, tokens: tokens)
                }
                .width(min: 72, ideal: 88, max: 110)

                TableColumn("Provider") { row in
                    HealthProviderBadge(label: row.provider, tokens: tokens)
                }
                .width(min: 100, ideal: 120, max: 150)

                TableColumn("Latency") { row in
                    LatencyCell(p50: row.p50, maxP50: maxP50, tokens: tokens)
                }
                .width(min: 130, ideal: 170, max: 220)

                TableColumn("Free") { row in
                    SignalCell(pass: row.isFree, tooltip: "Free tier model", tokens: tokens)
                }
                .width(min: 44, ideal: 52, max: 60)

                TableColumn("Ctx") { row in
                    SignalCell(pass: row.hasContext, tooltip: "Context window ≥ 32K", tokens: tokens)
                }
                .width(min: 44, ideal: 52, max: 60)

                TableColumn("Clear") { row in
                    SignalCell(pass: row.notContentFiltered, tooltip: "Not content-filtered", tokens: tokens)
                }
                .width(min: 44, ideal: 52, max: 60)

                TableColumn("Tools") { row in
                    SignalCell(pass: row.hasTools, tooltip: "Tool calling supported", tokens: tokens)
                }
                .width(min: 44, ideal: 52, max: 60)

                TableColumn("Cost") { row in
                    Text(String(format: "$%.4f", row.cost))
                        .foregroundColor(tokens.fg3)
                }
                .width(min: 72, ideal: 88, max: 110)

                TableColumn("Model") { row in
                    VStack(alignment: .leading, spacing: 2) {
                        Text(row.label)
                            .foregroundColor(tokens.fg)
                            .lineLimit(2)
                        Text(relativeTime(since: row.lastPingAt))
                            .font(.caption2)
                            .foregroundColor(tokens.fg4)
                    }
                }
                .width(min: 220, ideal: 360, max: CGFloat.infinity)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private var inventoryRows: [InventoryRow] {
        let registryById = Dictionary(uniqueKeysWithValues: registry.models.map { ($0.id, $0) })
        return intelStore.profiles.values
            .filter { $0.lastPingAt != nil }
            .map { profile in
                let info = registryById[profile.modelId]
                let provider = profile.testedProviderLabel
                    ?? info.map { ModelHealthSubscriptionProvider.displayName(for: $0.provider) }
                    ?? profile.pingTransport
                    ?? info?.provider
                    ?? "Unknown"
                let responded = profile.lastPingStatus == ModelHealthSnapshot.statusString(.live)
                    || profile.consecutiveLive > 0
                let suitability: BenchmarkSuitability = if profile.benchCandidate {
                    .recommended
                } else if responded {
                    .limited
                } else {
                    .notSuitable
                }
                return InventoryRow(
                    id: profile.modelId,
                    label: profile.label,
                    provider: provider,
                    pingTransport: profile.pingTransport,
                    p50: profile.lastP50,
                    cost: profile.lastMeasuredCost,
                    responded: responded,
                    modelMatched: profile.modelMatched,
                    notContentFiltered: profile.notContentFiltered,
                    hasTools: profile.hasTools,
                    isFree: profile.catalogIsFree || profile.isRuntimeFree,
                    hasContext: profile.hasContext,
                    suitability: suitability,
                    lastPingAt: profile.lastPingAt,
                    tier: info?.tier
                )
            }
            .sorted { lhs, rhs in
                if lhs.p50 == rhs.p50 { return lhs.label < rhs.label }
                if lhs.p50 == 0 { return false }
                if rhs.p50 == 0 { return true }
                return lhs.p50 < rhs.p50
            }
    }

    private var filteredRows: [InventoryRow] {
        inventoryRows.filter { row in
            let providerMatch = selectedProvider.map { row.provider == $0 } ?? true
            let tierMatch = selectedTier.map { row.tier == $0 } ?? true
            let benchMatch = !benchOnly || row.suitability == .recommended
            let needle = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            let searchMatch = needle.isEmpty
                || row.label.lowercased().contains(needle)
                || row.id.lowercased().contains(needle)
                || row.provider.lowercased().contains(needle)
            return providerMatch && tierMatch && benchMatch && searchMatch
        }
    }

    private var availableProviders: [String] {
        Array(Set(inventoryRows.map(\.provider))).sorted()
    }

    private func relativeTime(since date: Date?) -> String {
        guard let date else { return "—" }
        let seconds = Int(Date().timeIntervalSince(date))
        if seconds < 60 { return "\(seconds)s ago" }
        if seconds < 3600 { return "\(seconds / 60)m ago" }
        if seconds < 86400 { return "\(seconds / 3600)h ago" }
        return "\(seconds / 86400)d ago"
    }
}

struct HealthProviderBadge: View {
    let label: String
    let tokens: ThemeTokens

    var body: some View {
        Text(label)
            .font(.caption2)
            .fontWeight(.medium)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(color.opacity(0.15))
            .foregroundColor(color)
            .clipShape(Capsule())
    }

    private var color: Color {
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
