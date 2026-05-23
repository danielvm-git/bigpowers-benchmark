import Foundation

public final class MockGitService: GitServiceProtocol, @unchecked Sendable {
    public private(set) var commitCallCount = 0
    public private(set) var pushCallCount = 0
    public var isGitRepoResult = true
    public var commitError: Error?

    public init() {}

    public func commit(message _: String, in _: URL) throws {
        if let error = commitError { throw error }
        commitCallCount += 1
    }

    public func push(in _: URL) throws {
        pushCallCount += 1
    }

    public func isGitRepo(at _: URL) -> Bool {
        isGitRepoResult
    }
}
