import Foundation
import Observation

@Observable
public final class ProviderStore {
    public var providers: [Provider] = []
    private let fileURL: URL

    public init(fileURL: URL? = nil) {
        if let fileURL {
            self.fileURL = fileURL
        } else {
            guard let appSupport = FileManager.default.urls(
                for: .applicationSupportDirectory,
                in: .userDomainMask
            ).first else {
                fatalError("Application Support directory unavailable")
            }
            let bundleID = Bundle.main.bundleIdentifier ?? "BigPowersBenchmark"
            let dir = appSupport.appendingPathComponent(bundleID)
            self.fileURL = dir.appendingPathComponent("providers.json")
        }
    }

    public func load() throws {
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            providers = defaultProviders()
            return
        }

        let data = try Data(contentsOf: fileURL)
        providers = try JSONDecoder().decode([Provider].self, from: data)
    }

    public func save() throws {
        let dir = fileURL.deletingLastPathComponent()
        if !FileManager.default.fileExists(atPath: dir.path) {
            try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        }

        let data = try JSONEncoder().encode(providers)
        try data.write(to: fileURL)
    }

    private func defaultProviders() -> [Provider] {
        [
            Provider(id: "openrouter", name: "OpenRouter", baseURL: "https://openrouter.ai/api/v1"),
            Provider(id: "anthropic", name: "Anthropic", baseURL: "https://api.anthropic.com"),
            Provider(id: "openai", name: "OpenAI", baseURL: "https://api.openai.com/v1"),
            Provider(
                id: "google",
                name: "Google Vertex/AI Studio",
                baseURL: "https://generativelanguage.googleapis.com"
            ),
            Provider(
                id: "nousresearch-direct",
                name: "Nous Portal",
                baseURL: "https://inference-api.nousresearch.com/v1"
            ),
        ]
    }
}
