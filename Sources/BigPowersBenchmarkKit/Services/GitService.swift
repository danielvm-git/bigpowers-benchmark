import Foundation

public protocol GitServiceProtocol: Sendable {
    func commit(message: String, in directory: URL) throws
    func push(in directory: URL) throws
    func isGitRepo(at directory: URL) -> Bool
}

public final class GitService: GitServiceProtocol, Sendable {
    public init() {}

    public func commit(message: String, in directory: URL) throws {
        try run(["git", "-C", directory.path, "add", "-A"], in: directory)
        try run(["git", "-C", directory.path, "commit", "-m", message], in: directory)
    }

    public func push(in directory: URL) throws {
        try run(["git", "-C", directory.path, "push"], in: directory)
    }

    public func isGitRepo(at directory: URL) -> Bool {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/git")
        process.arguments = ["-C", directory.path, "rev-parse", "--is-inside-work-tree"]
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        try? process.run()
        process.waitUntilExit()
        return process.terminationStatus == 0
    }

    private func run(_ args: [String], in directory: URL) throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/git")
        process.arguments = Array(args.dropFirst())
        process.currentDirectoryURL = directory
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        try process.run()
        process.waitUntilExit()
        guard process.terminationStatus == 0 else {
            throw GitError.nonZeroExit(Int(process.terminationStatus))
        }
    }
}

public enum GitError: Error {
    case nonZeroExit(Int)
}
