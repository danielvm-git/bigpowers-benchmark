import Foundation

public protocol GitServiceProtocol: Sendable {
    func commit(message: String, in directory: URL) throws
    func push(in directory: URL) throws
    func isGitRepo(at directory: URL) -> Bool
}

public final class GitService: GitServiceProtocol, Sendable {
    private static let gitExecutable = URL(fileURLWithPath: "/usr/bin/git")
    private let processTimeout: TimeInterval

    public init(processTimeout: TimeInterval = 30) {
        self.processTimeout = processTimeout
    }

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
        scheduleTermination(of: process, after: processTimeout)
        process.waitUntilExit()
        // timeout (uncaughtSignal) is indistinguishable from non-repo to callers; both warrant false
        return process.terminationStatus == 0 && process.terminationReason == .exit
    }

    private func run(_ args: [String], in directory: URL) throws {
        let process = makeProcess(args: args, in: directory)
        try process.run()
        scheduleTermination(of: process, after: processTimeout)
        process.waitUntilExit()
        if process.terminationReason == .uncaughtSignal { throw GitError.timedOut }
        guard process.terminationStatus == 0 else {
            throw GitError.nonZeroExit(Int(process.terminationStatus))
        }
    }

    /// Git sets GIT_DIR (and friends) when invoking hooks; strip them so subprocesses
    /// are not tricked into using the hook repo as the working repo.
    private static let gitEnvOverrideKeys = [
        "GIT_DIR", "GIT_WORK_TREE", "GIT_INDEX_FILE",
        "GIT_OBJECT_DIRECTORY", "GIT_COMMON_DIR"
    ]

    private func makeProcess(args: [String], in directory: URL) -> Process {
        let process = Process()
        process.executableURL = Self.gitExecutable
        process.arguments = args
        process.currentDirectoryURL = directory
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        var env = ProcessInfo.processInfo.environment
        for key in Self.gitEnvOverrideKeys {
            env.removeValue(forKey: key)
        }
        process.environment = env
        return process
    }

    private func scheduleTermination(of process: Process, after timeout: TimeInterval) {
        let timer = DispatchSource.makeTimerSource(queue: DispatchQueue.global())
        timer.schedule(deadline: .now() + timeout)
        timer.setEventHandler { process.terminate() }
        process.terminationHandler = { _ in timer.cancel() } // must precede resume to close PID-reuse race
        timer.resume()
    }
}

public enum GitError: Error, Equatable {
    case nonZeroExit(Int)
    case timedOut
}
