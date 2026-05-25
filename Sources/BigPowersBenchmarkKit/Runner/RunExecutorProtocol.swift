import Foundation

public protocol RunExecutorProtocol: Sendable {
    func run(task: BenchmarkTask, model: String, catalogModelId: String?) -> AsyncStream<RunEvent>
}

public extension RunExecutorProtocol {
    func run(task: BenchmarkTask, model: String) -> AsyncStream<RunEvent> {
        run(task: task, model: model, catalogModelId: nil)
    }
}
