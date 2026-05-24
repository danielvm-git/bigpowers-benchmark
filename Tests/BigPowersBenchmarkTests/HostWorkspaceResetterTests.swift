@testable import BigPowersBenchmarkKit
import Foundation
import Testing

@Suite("HostWorkspaceResetter")
struct HostWorkspaceResetterTests {
    @Test("copies task baseline files from sandbox to worktree")
    func copiesTaskBaselineFiles() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("host-reset-baseline-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let bigpowersRepo = root.appendingPathComponent("bigpowers", isDirectory: true)
        let sandboxRoot = root.appendingPathComponent("SANDBOX", isDirectory: true)
        let worktreeRoot = root.appendingPathComponent("worktrees", isDirectory: true)
        try FileManager.default.createDirectory(at: worktreeRoot, withIntermediateDirectories: true)

        try setupBigpowersRepo(at: bigpowersRepo)
        try setupSandboxTask(at: sandboxRoot, taskId: "T01")

        let defaults = try #require(UserDefaults(suiteName: "HostWorkspaceResetter-\(UUID().uuidString)"))
        let config = HostRunConfig(userDefaults: defaults, fileManager: .default)
        config.bigpowersRepo = bigpowersRepo.path
        config.sandboxPath = sandboxRoot.path
        config.worktreeRoot = worktreeRoot.path

        let resetter = HostWorkspaceResetter()
        let worktreeURL = try resetter.reset(taskId: "T01", runId: "test-run", config: config)

        let copiedLimiter = worktreeURL.appendingPathComponent("src/limiter.js")
        let copiedTest = worktreeURL.appendingPathComponent("test.js")
        let copiedReadme = worktreeURL.appendingPathComponent("README.md")

        #expect(
            FileManager.default.fileExists(atPath: copiedLimiter.path),
            "Task baseline file not copied to worktree"
        )
        #expect(
            FileManager.default.fileExists(atPath: copiedTest.path),
            "test.js not copied to worktree"
        )
        #expect(
            FileManager.default.fileExists(atPath: copiedReadme.path),
            "TASK.md not copied as README.md to worktree"
        )
    }

    @Test("injects CLAUDE.md content pinned to ref")
    func refPinnedClaudeMd() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("host-reset-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let bigpowersRepo = root.appendingPathComponent("bigpowers", isDirectory: true)
        let sandboxRoot = root.appendingPathComponent("SANDBOX", isDirectory: true)
        let worktreeRoot = root.appendingPathComponent("worktrees", isDirectory: true)
        try FileManager.default.createDirectory(at: worktreeRoot, withIntermediateDirectories: true)

        try setupBigpowersRepo(at: bigpowersRepo)
        try setupSandboxTask(at: sandboxRoot, taskId: "T01")

        let defaults = try #require(UserDefaults(suiteName: "HostWorkspaceResetter-\(UUID().uuidString)"))
        let config = HostRunConfig(userDefaults: defaults, fileManager: .default)
        config.bigpowersRepo = bigpowersRepo.path
        config.sandboxPath = sandboxRoot.path
        config.worktreeRoot = worktreeRoot.path
        config.bigpowersRef = "ref-v1"

        let resetter = HostWorkspaceResetter()
        let worktreeV1 = try resetter.reset(taskId: "T01", runId: "run-v1", config: config)
        let claudeV1 = try String(contentsOf: worktreeV1.appendingPathComponent("CLAUDE.md"), encoding: .utf8)

        config.bigpowersRef = "ref-v2"
        let worktreeV2 = try resetter.reset(taskId: "T01", runId: "run-v2", config: config)
        let claudeV2 = try String(contentsOf: worktreeV2.appendingPathComponent("CLAUDE.md"), encoding: .utf8)

        #expect(claudeV1.contains("VERSION_ONE"))
        #expect(claudeV2.contains("VERSION_TWO"))
        #expect(claudeV1 != claudeV2)
        #expect(FileManager.default.fileExists(atPath: worktreeV1.appendingPathComponent("test.js").path))
        #expect(FileManager.default.fileExists(atPath: worktreeV1.appendingPathComponent("src/limiter.js").path))
    }

    private func setupBigpowersRepo(at url: URL) throws {
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        try runGit(["init"], in: url)

        let claudeV1 = """
        # Bigpowers v1
        ## Session Start
        VERSION_ONE
        """
        try claudeV1.write(to: url.appendingPathComponent("CLAUDE.md"), atomically: true, encoding: .utf8)
        try runGit(["add", "CLAUDE.md"], in: url)
        try runGit(["commit", "-m", "chore: v1"], in: url)
        try runGit(["tag", "ref-v1"], in: url)

        let claudeV2 = """
        # Bigpowers v2
        ## Session Start
        VERSION_TWO
        """
        try claudeV2.write(to: url.appendingPathComponent("CLAUDE.md"), atomically: true, encoding: .utf8)
        try runGit(["add", "CLAUDE.md"], in: url)
        try runGit(["commit", "-m", "chore: v2"], in: url)
        try runGit(["tag", "ref-v2"], in: url)
    }

    private func setupSandboxTask(at sandboxRoot: URL, taskId: String) throws {
        let taskRoot = sandboxRoot.appendingPathComponent(taskId, isDirectory: true)
        let baselineSrc = taskRoot.appendingPathComponent("baseline/src", isDirectory: true)
        try FileManager.default.createDirectory(at: baselineSrc, withIntermediateDirectories: true)
        try "export default 1;\n".write(
            to: baselineSrc.appendingPathComponent("limiter.js"),
            atomically: true,
            encoding: .utf8
        )
        try "console.log('test');\n".write(
            to: taskRoot.appendingPathComponent("test.js"),
            atomically: true,
            encoding: .utf8
        )
        try "# Task\n".write(
            to: taskRoot.appendingPathComponent("TASK.md"),
            atomically: true,
            encoding: .utf8
        )
    }

    private func runGit(_ arguments: [String], in directory: URL) throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/git")
        process.arguments = arguments
        process.currentDirectoryURL = directory
        var env = ProcessInfo.processInfo.environment
        for key in ["GIT_DIR", "GIT_WORK_TREE", "GIT_INDEX_FILE", "GIT_OBJECT_DIRECTORY", "GIT_COMMON_DIR"] {
            env.removeValue(forKey: key)
        }
        env["GIT_AUTHOR_NAME"] = "test"
        env["GIT_AUTHOR_EMAIL"] = "test@test.com"
        env["GIT_COMMITTER_NAME"] = "test"
        env["GIT_COMMITTER_EMAIL"] = "test@test.com"
        process.environment = env
        try process.run()
        process.waitUntilExit()
        guard process.terminationStatus == 0 else {
            throw NSError(domain: "HostWorkspaceResetterTests", code: Int(process.terminationStatus))
        }
    }
}
