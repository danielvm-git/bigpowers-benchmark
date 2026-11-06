import Foundation

public enum HarnessEvent: Sendable {
    case line(String)
    case record(ABRunRecord)
    case completed(exitCode: Int32, report: ABReport?)
    case failed(Error)
}

public enum HarnessError: Error, Sendable {
    case timeout
    case reportUnreadable(String)
}

extension HarnessError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .timeout:
            "The A/B harness exceeded its wall-clock timeout"
        case let .reportUnreadable(path):
            "Could not read the A/B report at \(path)"
        }
    }
}

/// Streams one `run-ab-eval.sh` invocation and decodes the live records and final report.
public struct HarnessRunner: Sendable {
    private let shell: ShellCommandRunning
    private let timeout: TimeInterval

    public init(shell: ShellCommandRunning = ShellCommandRunner(), timeout: TimeInterval = 3600) {
        self.shell = shell
        self.timeout = timeout
    }

    public func run(_ command: HarnessCommand) -> AsyncStream<HarnessEvent> {
        let source = shell.streamOutput(
            executable: "/bin/bash",
            arguments: command.processArguments,
            workingDirectory: command.runnerRoot
        )
        return AsyncStream { continuation in
            let work = Task {
                var exitCode: Int32 = -1
                for await event in source {
                    switch event {
                    case let .line(line):
                        continuation.yield(.line(line))
                        if let record = Self.decodeRecord(line) {
                            continuation.yield(.record(record))
                        }
                    case let .completed(code):
                        exitCode = code
                    }
                }
                let report = command.jsonOut.flatMap(Self.loadReport)
                continuation.yield(.completed(exitCode: exitCode, report: report))
                continuation.finish()
            }
            let deadline = Task {
                try? await Task.sleep(for: .seconds(timeout))
                guard !Task.isCancelled else { return }
                continuation.yield(.failed(HarnessError.timeout))
                continuation.finish()
                work.cancel()
            }
            continuation.onTermination = { _ in
                work.cancel()
                deadline.cancel()
            }
        }
    }

    static func decodeRecord(_ line: String) -> ABRunRecord? {
        guard let data = line.data(using: .utf8),
              let record = try? JSONDecoder().decode(ABRunRecord.self, from: data)
        else { return nil }
        return record
    }

    static func loadReport(_ url: URL) -> ABReport? {
        guard let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(ABReport.self, from: data)
    }
}
