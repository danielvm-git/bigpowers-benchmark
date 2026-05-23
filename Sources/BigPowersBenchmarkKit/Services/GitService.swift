import Foundation

public protocol GitServiceProtocol: Sendable {
    func commit(message: String, in directory: URL) throws
    func push(in directory: URL) throws
    func isGitRepo(at directory: URL) -> Bool
}

public final class GitService: GitServiceProtocol, Sendable {
    private static let processTimeout: TimeInterval = 30

    public init() {}

    public func commit(message: String, in directory: URL) throws {
        try run(["add", "-A"], in: directory)
        try run(["commit", "-m", message], in: directory)
    }

    public func push(in directory: URL) throws {
        try run(["push"], in: directory)
    }

    public func isGitRepo(at directory: URL) -> Bool {
        let process = makeProcess(args: ["rev-parse", "--is-inside-work-tree"], in: directory)
        guard (try? process.run()) != nil else { return false }
        scheduleTermination(of: process, after: Self.processTimeout)
        process.waitUntilExit()
        return process.terminationStatus == 0 && process.terminationReason == .exit
    }

    private func run(_ args: [String], in directory: URL) throws {
        let process = makeProcess(args: args, in: directory)
        try process.run()
        scheduleTermination(of: process, after: Self.processTimeout)
        process.waitUntilExit()
        if process.terminationReason == .uncaughtSignal { throw GitError.timedOut }
        guard process.terminationStatus == 0 else {
            throw GitError.nonZeroExit(Int(process.terminationStatus))
        }
    }

    private func makeProcess(args: [String], in directory: URL) -> Process {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/git")
        process.arguments = args
        process.currentDirectoryURL = directory
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        return process
    }

    private func scheduleTermination(of process: Process, after timeout: TimeInterval) {
        let timer = DispatchSource.makeTimerSource(queue: DispatchQueue.global())
        timer.schedule(deadline: .now() + timeout)
        timer.setEventHandler { process.terminate() }
        process.terminationHandler = { _ in timer.cancel() }
        timer.resume()
    }
}

public enum GitError: Error {
    case nonZeroExit(Int)
    case timedOut
}
