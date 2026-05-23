import Foundation

public final class MockGitService: GitServiceProtocol, @unchecked Sendable {
    public private(set) var commitCallCount = 0
    public private(set) var pushCallCount = 0
    public var isGitRepoResult = true

    public init() {}

    public func commit(message _: String, in _: URL) throws {
        commitCallCount += 1
    }

    public func push(in _: URL) throws {
        pushCallCount += 1
    }

    public func isGitRepo(at _: URL) -> Bool {
        isGitRepoResult
    }
}
