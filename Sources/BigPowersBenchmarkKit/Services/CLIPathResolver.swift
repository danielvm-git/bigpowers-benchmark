import Foundation

public enum CLIPathResolver {
    public static let defaultShellPath = "/bin/zsh"

    public static func loginShellPath() -> String {
        UserDefaults.standard.string(forKey: "bigpowers.terminal.shellPath") ?? defaultShellPath
    }

    /// Whether `name` is invokable from the user's login shell (Homebrew/npm globals included).
    public static func isExecutableOnPath(_ name: String, shellPath: String = loginShellPath()) -> Bool {
        if isExecutableInAugmentedPath(name) {
            return true
        }
        return checkViaLoginShell(name, shellPath: shellPath)
    }

    static func isExecutableInAugmentedPath(_ name: String) -> Bool {
        var path = ProcessInfo.processInfo.environment["PATH"] ?? "/usr/bin:/bin"
        if !path.contains("homebrew") {
            path += ":/opt/homebrew/bin:/usr/local/bin"
        }
        for dir in path.split(separator: ":") {
            let fullPath = (String(dir) as NSString).appendingPathComponent(name)
            if FileManager.default.isExecutableFile(atPath: fullPath) {
                return true
            }
        }
        return false
    }

    private static func checkViaLoginShell(_ name: String, shellPath: String) -> Bool {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: shellPath)
        process.arguments = ["-l", "-c", "command -v \(ShellQuoting.single(name)) >/dev/null 2>&1"] // swiftlint:disable:this line_length
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe
        do {
            try process.run()
            process.waitUntilExit()
            return process.terminationStatus == 0
        } catch {
            return false
        }
    }
}

enum ShellQuoting {
    static func single(_ value: String) -> String {
        "'" + value.replacingOccurrences(of: "'", with: "'\\''") + "'"
    }
}
