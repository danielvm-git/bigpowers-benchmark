import Foundation
import Observation

public enum ExecutionMode: String, Codable, Sendable, CaseIterable {
    case host
    case daytona

    public var displayName: String {
        switch self {
        case .host: "Host (local)"
        case .daytona: "Daytona (remote)"
        }
    }
}

@Observable
public final class HostRunConfig: @unchecked Sendable {
    private let userDefaults: UserDefaults
    private let fileManager: FileManager

    public var executionMode: ExecutionMode {
        get {
            guard let raw = userDefaults.string(forKey: Keys.executionMode),
                  let mode = ExecutionMode(rawValue: raw)
            else {
                return .host
            }
            return mode
        }
        set { userDefaults.set(newValue.rawValue, forKey: Keys.executionMode) }
    }

    public var bigpowersRepo: String {
        get {
            userDefaults.string(forKey: Keys.bigpowersRepo)
                ?? fileManager.homeDirectoryForCurrentUser
                .appendingPathComponent("Developer/bigpowers").path
        }
        set { userDefaults.set(newValue, forKey: Keys.bigpowersRepo) }
    }

    public var bigpowersRef: String {
        get { userDefaults.string(forKey: Keys.bigpowersRef) ?? "HEAD" }
        set { userDefaults.set(newValue, forKey: Keys.bigpowersRef) }
    }

    public var sandboxPath: String {
        get {
            // First, return stored value if it exists and points to a valid location
            if let stored = userDefaults.string(forKey: Keys.sandboxPath),
               fileManager.fileExists(atPath: stored) {
                return stored
            }

            // Clear any invalid stored path
            userDefaults.removeObject(forKey: Keys.sandboxPath)

            // Try multiple locations in order of preference
            let homeDir = fileManager.homeDirectoryForCurrentUser.path
            let candidates = [
                (homeDir as NSString).appendingPathComponent("Developer/bigpowers-benchmark/SANDBOX"),
                (homeDir as NSString).appendingPathComponent("Developer/bigpowers-benchmark-old/SANDBOX"),
            ]

            for candidate in candidates where fileManager.fileExists(atPath: candidate) {
                return candidate
            }

            // Fallback to the traditional location (even if it doesn't exist yet)
            return candidates.last ?? (homeDir as NSString)
                .appendingPathComponent("Developer/bigpowers-benchmark-old/SANDBOX")
        }
        set { userDefaults.set(newValue, forKey: Keys.sandboxPath) }
    }

    public var worktreeRoot: String {
        get { userDefaults.string(forKey: Keys.worktreeRoot) ?? "/tmp/bp_bench_runs" }
        set { userDefaults.set(newValue, forKey: Keys.worktreeRoot) }
    }

    public var scoreScriptPath: String {
        get {
            if let custom = userDefaults.string(forKey: Keys.scoreScriptPath), !custom.isEmpty {
                return custom
            }
            return HostRunConfig.defaultScoreScriptPath()
        }
        set { userDefaults.set(newValue, forKey: Keys.scoreScriptPath) }
    }

    public static func defaultScoreScriptPath() -> String {
        let cwd = FileManager.default.currentDirectoryPath
        let candidate = (cwd as NSString).appendingPathComponent("scripts/score_run.sh")
        if FileManager.default.fileExists(atPath: candidate) {
            return candidate
        }
        return "/usr/local/bin/score_run.sh"
    }

    public init(userDefaults: UserDefaults = .standard, fileManager: FileManager = .default) {
        self.userDefaults = userDefaults
        self.fileManager = fileManager
    }

    private enum Keys {
        static let executionMode = "bigpowers.executionMode"
        static let bigpowersRepo = "bigpowers.host.bigpowersRepo"
        static let bigpowersRef = "bigpowers.host.bigpowersRef"
        static let sandboxPath = "bigpowers.host.sandboxPath"
        static let worktreeRoot = "bigpowers.host.worktreeRoot"
        static let scoreScriptPath = "bigpowers.host.scoreScriptPath"
    }
}
