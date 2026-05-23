@testable import BigPowersBenchmarkKit
import Foundation
import Testing

@Suite("BenchmarkStore")
struct BenchmarkStoreTests {
    private func makeRow(taskId: String = "T01") -> BenchRow {
        BenchRow(
            id: UUID(),
            schemaVersion: 1,
            timestamp: Date(timeIntervalSince1970: 1_716_480_000),
            bigpowersRef: "v1.0.0",
            modelId: "test/model",
            taskId: taskId,
            codePass: 1,
            artifactScore: 2,
            conventionScore: 2,
            duration: 5,
            cost: 0.001,
            workspace: "/tmp/test"
        )
    }

    @Test("save writes a decodable JSON shard to runsURL")
    func save() throws {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let store = BenchmarkStore(runsURL: tempDir)
        let row = makeRow()
        try store.saveBenchRow(row)

        let contents = try FileManager.default.contentsOfDirectory(at: tempDir, includingPropertiesForKeys: nil)
        #expect(contents.count == 1)

        let file = try #require(contents.first)
        #expect(file.lastPathComponent.hasPrefix("run_"))
        #expect(file.lastPathComponent.hasSuffix("_T01.json"))

        let data = try Data(contentsOf: file)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode(BenchRow.self, from: data)
        #expect(decoded.id == row.id)
        #expect(decoded.taskId == row.taskId)
    }

    @Test("loadAllRuns decodes all JSON shards in runsURL")
    func roundTrip() throws {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let store = BenchmarkStore(runsURL: tempDir)
        let row1 = makeRow(taskId: "T01")
        let row2 = makeRow(taskId: "T02")
        try store.saveBenchRow(row1)
        try store.saveBenchRow(row2)

        try store.loadAllRuns()

        #expect(store.runs.count == 2)
        let ids = Set(store.runs.map(\.id))
        #expect(ids.contains(row1.id))
        #expect(ids.contains(row2.id))
    }

    @Test("loadAllRuns surfaces failed shards in loadErrors instead of dropping them")
    func testLoadErrors() throws {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let badFile = tempDir.appendingPathComponent("run_bad.json")
        try "not valid json".write(to: badFile, atomically: true, encoding: .utf8)

        let store = BenchmarkStore(runsURL: tempDir)
        try store.loadAllRuns()

        #expect(store.runs.isEmpty)
        #expect(store.loadErrors[badFile.standardizedFileURL] != nil)
    }

    @Test("directory watcher triggers loadAllRuns when a new shard is written externally")
    func directoryWatcher() async throws {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let store = BenchmarkStore(runsURL: tempDir)
        await store.startWatching()
        defer { Task { await store.startWatching() } } // restarts watcher, which calls stopWatching() internally

        let row = makeRow()
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(row)
        let file = tempDir.appendingPathComponent("run_ext_T01.json")

        // Sleep inside the body so confirm() is called before the body returns;
        // confirmation() only checks count AFTER the body exits.
        try await confirmation("watcher reloads runs after external write", expectedCount: 1) { confirm in
            var token: NSObjectProtocol?
            token = NotificationCenter.default.addObserver(
                forName: BenchmarkStore.runsDidChangeNotification,
                object: store,
                queue: .main
            ) { _ in
                confirm()
                token.map { NotificationCenter.default.removeObserver($0) }
            }
            try data.write(to: file)
            // 200 ms debounce + dispatch headroom; 1000 ms budget for slow CI hosts.
            try await Task.sleep(for: .milliseconds(1000))
        }

        #expect(store.runs.count == 1)
    }

    @Test("auto-commit calls GitService.commit after saveBenchRow when autoCommit is true")
    func testAutoCommit() throws {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let mockGit = MockGitService()
        let store = BenchmarkStore(runsURL: tempDir, gitService: mockGit)
        store.autoCommit = true

        let row = makeRow()
        try store.saveBenchRow(row)

        #expect(mockGit.commitCallCount == 1)
    }

    @Test("saveBenchRow propagates GitError.timedOut when commit times out")
    func timedOutPropagates() throws {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let mockGit = MockGitService()
        mockGit.commitError = GitError.timedOut
        let store = BenchmarkStore(runsURL: tempDir, gitService: mockGit)
        store.autoCommit = true

        #expect(throws: GitError.timedOut) {
            try store.saveBenchRow(makeRow())
        }
    }

    @Test("checkGitRepoStatus updates isRunsDirectoryGitRepo from mock result")
    func checkGitRepoStatusAsync() async throws {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let mockGit = MockGitService()
        mockGit.isGitRepoResult = false
        let store = BenchmarkStore(runsURL: tempDir, gitService: mockGit)

        store.checkGitRepoStatus()
        try await Task.sleep(for: .milliseconds(200))

        #expect(store.isRunsDirectoryGitRepo == false)
    }

    @Test("isGitRepo returns false for a directory that is not a git repo")
    func gitRepoCheck() throws {
        let notARepo = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: notARepo, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: notARepo) }

        let service = GitService()
        #expect(service.isGitRepo(at: notARepo) == false)
    }

    @Test("isGitRepo is immune to GIT_DIR inherited from a git hook environment")
    func gitRepoDirEnvIsolation() throws {
        let notARepo = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: notARepo, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: notARepo) }

        // Simulate what git injects into the environment before running pre-push hooks.
        // Process.environment is not set here, so any unguarded subprocess would inherit
        // the C env and see GIT_DIR — exactly the regression this guards against.
        setenv("GIT_DIR", notARepo.path, 1)
        defer { unsetenv("GIT_DIR") }

        let service = GitService()
        #expect(service.isGitRepo(at: notARepo) == false)
    }
}
