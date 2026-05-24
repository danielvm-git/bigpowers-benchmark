import Foundation

public struct BenchmarkTask: Codable, Sendable, Identifiable, Hashable {
    public let id: String
    public let name: String
    public let description: String

    public init(id: String, name: String, description: String) {
        self.id = id
        self.name = name
        self.description = description
    }
}

public extension BenchmarkTask {
    static let allTasks: [BenchmarkTask] = [
        BenchmarkTask(
            id: "T01",
            name: "Bug Investigation",
            description: "Fix the memory leak and file descriptor exhaustion in the HTTP server module."
        ),
        BenchmarkTask(
            id: "T02",
            name: "Feature Slice",
            description: "Implement the OAuth2 login flow and save secure tokens to the keychain database."
        ),
        BenchmarkTask(
            id: "T03",
            name: "Refactor Challenge",
            description: "Refactor the legacy XML parsing engine into a modern, type-safe Swift Codable parser."
        ),
        BenchmarkTask(
            id: "T04",
            name: "Performance Optimization",
            description: "Optimize the image processing pipeline to reduce Largest Contentful Paint latency by 40%."
        ),
        BenchmarkTask(
            id: "T05",
            name: "API Integration",
            description: "Integrate Daytona sandboxed CLI endpoints and establish WebSocket command log streams."
        ),
    ]
}

public struct BenchmarkSuite: Identifiable, Sendable, Hashable {
    public let id: String
    public let name: String
    public let tasks: [BenchmarkTask]

    public init(id: String, name: String, tasks: [BenchmarkTask]) {
        self.id = id
        self.name = name
        self.tasks = tasks
    }

    public static let allSuites: [BenchmarkSuite] = [
        BenchmarkSuite(id: "canonical", name: "Canonical", tasks: BenchmarkTask.allTasks),
        BenchmarkSuite(id: "extended", name: "Extended", tasks: Array(BenchmarkTask.allTasks.prefix(3))),
        BenchmarkSuite(id: "sanity", name: "Sanity", tasks: [BenchmarkTask.allTasks[0]]),
    ]
}
