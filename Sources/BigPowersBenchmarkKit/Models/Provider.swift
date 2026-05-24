import Foundation

public struct Provider: Codable, Identifiable {
    public let id: String
    public let name: String
    public let baseURL: String
    public var enabled: Bool

    public init(id: String, name: String, baseURL: String, enabled: Bool = true) {
        self.id = id
        self.name = name
        self.baseURL = baseURL
        self.enabled = enabled
    }

    public func apiKeyStatus(keychain: KeychainServiceProtocol) -> ApiKeyStatus {
        if keychain.load(account: "bigpowers.benchmark.\(id)") != nil {
            .configured
        } else {
            .notSet
        }
    }
}

public enum ApiKeyStatus: String, Codable {
    case notSet
    case configured
    case error
}
