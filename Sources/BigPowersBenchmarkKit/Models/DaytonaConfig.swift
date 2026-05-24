import Foundation
import Observation

@Observable
public final class DaytonaConfig: @unchecked Sendable {
    private let keychainService: KeychainServiceProtocol
    private let userDefaults: UserDefaults

    public var baseURL: String {
        get { userDefaults.string(forKey: Keys.baseURL) ?? "" }
        set {
            userDefaults.set(newValue, forKey: Keys.baseURL)
            validateURL(newValue)
        }
    }

    public private(set) var baseURLError: String?

    public var apiKey: String {
        get { keychainService.load(account: Accounts.daytona) ?? "" }
        set { try? keychainService.save(newValue, account: Accounts.daytona) }
    }

    public var taskRepoURL: String {
        get { userDefaults.string(forKey: Keys.taskRepoURL) ?? "" }
        set { userDefaults.set(newValue, forKey: Keys.taskRepoURL) }
    }

    public var terminalShellPath: String {
        get { userDefaults.string(forKey: Keys.terminalShellPath) ?? "/bin/zsh" }
        set { userDefaults.set(newValue, forKey: Keys.terminalShellPath) }
    }

    public var terminalFontSize: Double {
        get {
            let val = userDefaults.double(forKey: Keys.terminalFontSize)
            return val > 0 ? val : 13.0
        }
        set { userDefaults.set(newValue, forKey: Keys.terminalFontSize) }
    }

    public var terminalOptionAsMeta: Bool {
        get {
            userDefaults.object(forKey: Keys.terminalOptionAsMeta) == nil ? true : userDefaults
                .bool(forKey: Keys.terminalOptionAsMeta)
        }
        set { userDefaults.set(newValue, forKey: Keys.terminalOptionAsMeta) }
    }

    public var terminalUseBrightColors: Bool {
        get {
            userDefaults.object(forKey: Keys.terminalUseBrightColors) == nil ? true : userDefaults
                .bool(forKey: Keys.terminalUseBrightColors)
        }
        set { userDefaults.set(newValue, forKey: Keys.terminalUseBrightColors) }
    }

    public init(
        keychainService: KeychainServiceProtocol = KeychainService(),
        userDefaults: UserDefaults = .standard
    ) {
        self.keychainService = keychainService
        self.userDefaults = userDefaults
        validateURL(baseURL)
    }

    private func validateURL(_ string: String) {
        if string.isEmpty {
            baseURLError = nil
            return
        }

        if let url = URL(string: string), url.scheme != nil, url.host != nil {
            baseURLError = nil
        } else {
            baseURLError = "Invalid URL format"
        }
    }

    private enum Keys {
        static let baseURL = "bigpowers.daytona.baseURL"
        static let taskRepoURL = "bigpowers.taskRepoURL"
        static let terminalShellPath = "bigpowers.terminal.shellPath"
        static let terminalFontSize = "bigpowers.terminal.fontSize"
        static let terminalOptionAsMeta = "bigpowers.terminal.optionAsMeta"
        static let terminalUseBrightColors = "bigpowers.terminal.useBrightColors"
    }

    private enum Accounts {
        static let daytona = "bigpowers.benchmark.daytona"
    }
}
