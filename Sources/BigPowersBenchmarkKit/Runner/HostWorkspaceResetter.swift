import Foundation

public enum HostWorkspaceError: Error, Sendable, LocalizedError {
    case sandboxTaskMissing(taskId: String, path: String)
    case bigpowersRepoMissing(path: String)
    case claudeMdMissing(ref: String)
    case claudeMdInvalid
    case archiveFailed(ref: String, detail: String)

    public var errorDescription: String? {
        switch self {
        case let .sandboxTaskMissing(taskId, path):
            "SANDBOX task \(taskId) not found at \(path)"
        case let .bigpowersRepoMissing(path):
            "Bigpowers git repo not found at \(path)"
        case let .claudeMdMissing(ref):
            "CLAUDE.md not found at ref \(ref) in bigpowers repo"
        case .claudeMdInvalid:
            "Injected CLAUDE.md is missing '## Session Start' section"
        case let .archiveFailed(ref, detail):
            "git archive failed for ref \(ref): \(detail)"
        }
    }
}

public struct HostWorkspaceResetter: Sendable {
    private let shell: ShellCommandRunning

    public init(shell: ShellCommandRunning = ShellCommandRunner()) {
        self.shell = shell
    }

    public func reset(
        taskId: String,
        runId: String,
        config: HostRunConfig
    ) throws -> URL {
        let worktreePath = URL(fileURLWithPath: config.worktreeRoot)
            .appendingPathComponent(runId, isDirectory: true)

        let fileManager = FileManager.default
        if fileManager.fileExists(atPath: worktreePath.path) {
            try fileManager.removeItem(at: worktreePath)
        }
        try fileManager.createDirectory(at: worktreePath, withIntermediateDirectories: true)

        let taskRoot = URL(fileURLWithPath: config.sandboxPath).appendingPathComponent(taskId)
        let baselineSrc = taskRoot.appendingPathComponent("baseline/src")
        guard fileManager.fileExists(atPath: baselineSrc.path) else {
            throw HostWorkspaceError.sandboxTaskMissing(taskId: taskId, path: taskRoot.path)
        }

        let destSrc = worktreePath.appendingPathComponent("src")
        try fileManager.createDirectory(at: destSrc, withIntermediateDirectories: true)
        let baselineContents = try fileManager.contentsOfDirectory(at: baselineSrc, includingPropertiesForKeys: nil)
        for item in baselineContents {
            let destination = destSrc.appendingPathComponent(item.lastPathComponent)
            try fileManager.copyItem(at: item, to: destination)
        }

        let testJs = taskRoot.appendingPathComponent("test.js")
        if fileManager.fileExists(atPath: testJs.path) {
            try fileManager.copyItem(at: testJs, to: worktreePath.appendingPathComponent("test.js"))
        }

        let taskMd = taskRoot.appendingPathComponent("TASK.md")
        if fileManager.fileExists(atPath: taskMd.path) {
            try fileManager.copyItem(at: taskMd, to: worktreePath.appendingPathComponent("README.md"))
        }

        let bigpowersRepo = URL(fileURLWithPath: config.bigpowersRepo)
        guard fileManager.fileExists(atPath: bigpowersRepo.appendingPathComponent(".git").path) else {
            throw HostWorkspaceError.bigpowersRepoMissing(path: bigpowersRepo.path)
        }

        try extractArchive(
            repo: bigpowersRepo,
            ref: config.bigpowersRef,
            paths: ["CLAUDE.md", ".claude", "skills"],
            into: worktreePath
        )

        let claudePath = worktreePath.appendingPathComponent("CLAUDE.md")
        guard fileManager.fileExists(atPath: claudePath.path) else {
            throw HostWorkspaceError.claudeMdMissing(ref: config.bigpowersRef)
        }
        let claudeContents = try String(contentsOf: claudePath, encoding: .utf8)
        guard claudeContents.contains("## Session Start") else {
            throw HostWorkspaceError.claudeMdInvalid
        }

        _ = try shell.run(
            executable: "/usr/bin/git",
            arguments: ["init"],
            workingDirectory: worktreePath
        )

        let methodology = """
        TASK=\(taskId)
        RUN_ID=\(runId)
        BIGPOWERS_REF=\(config.bigpowersRef)
        TIMESTAMP=\(ISO8601DateFormatter().string(from: Date()))
        """
        try methodology.write(
            to: worktreePath.appendingPathComponent(".methodology"),
            atomically: true,
            encoding: .utf8
        )

        return worktreePath
    }

    private func extractArchive(
        repo: URL,
        ref: String,
        paths: [String],
        into destination: URL
    ) throws {
        for path in paths {
            let command = "git -C '\(repo.path)' archive '\(ref)' -- '\(path)' | tar -x -m -C '\(destination.path)'"
            let result = try shell.run(
                executable: "/bin/bash",
                arguments: ["-c", command],
                workingDirectory: destination
            )
            if path == "CLAUDE.md", result.exitCode != 0 {
                throw HostWorkspaceError.archiveFailed(ref: ref, detail: result.stderr)
            }
        }

        guard FileManager.default.fileExists(atPath: destination.appendingPathComponent("CLAUDE.md").path) else {
            throw HostWorkspaceError.claudeMdMissing(ref: ref)
        }
    }
}
