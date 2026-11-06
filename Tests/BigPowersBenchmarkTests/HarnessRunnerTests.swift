@testable import BigPowersBenchmarkKit
import Foundation
import Testing

private struct FakeShell: ShellCommandRunning {
    let events: [ShellOutputEvent]

    func run(executable _: String, arguments _: [String], workingDirectory _: URL?) throws -> ShellCommandResult {
        ShellCommandResult(stdout: "", stderr: "", exitCode: 0)
    }

    func streamLines(executable _: String, arguments _: [String], workingDirectory _: URL?) -> AsyncStream<String> {
        AsyncStream { continuation in
            for event in events {
                if case let .line(text) = event { continuation.yield(text) }
            }
            continuation.finish()
        }
    }

    func streamOutput(
        executable _: String,
        arguments _: [String],
        workingDirectory _: URL?
    ) -> AsyncStream<ShellOutputEvent> {
        AsyncStream { continuation in
            for event in events {
                continuation.yield(event)
            }
            continuation.finish()
        }
    }
}

@Suite("HarnessRunner")
struct HarnessRunnerTests {
    @Test("streams records and decodes the final report")
    func streamsRecordsAndReport() async throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("harness-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let json = root.appendingPathComponent("AB.json")
        try #"{"tasks":["ab-11"],"arms":["vanilla"],"arms_summary":{},"records":[]}"#
            .write(to: json, atomically: true, encoding: .utf8)

        let line = #"{"task":"ab-11","arm":"vanilla","run":1,"pass":true,"cost_usd":0.01}"#
        let shell = FakeShell(events: [.line("noise"), .line(line), .completed(exitCode: 0)])
        let command = HarnessCommand(
            runnerRoot: root,
            subjectRoot: root,
            tasks: ["ab-11"],
            arms: ["vanilla"],
            outDir: root,
            jsonOut: json
        )

        var records: [ABRunRecord] = []
        var completed: (exitCode: Int32, report: ABReport?)?
        for await event in HarnessRunner(shell: shell, timeout: 5).run(command) {
            switch event {
            case let .record(record):
                records.append(record)
            case let .completed(exitCode, report):
                completed = (exitCode, report)
            case .line, .failed:
                break
            }
        }

        #expect(records.count == 1)
        #expect(records.first?.pass == true)
        #expect(completed?.exitCode == 0)
        #expect(completed?.report?.tasks == ["ab-11"])
    }

    @Test("a malformed line is ignored, not fatal")
    func ignoresMalformedLine() async throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("harness-bad-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let shell = FakeShell(events: [.line("not json"), .completed(exitCode: 2)])
        let command = HarnessCommand(
            runnerRoot: root,
            subjectRoot: root,
            tasks: ["ab-11"],
            arms: ["vanilla"],
            outDir: root
        )
        var recordCount = 0
        var exitCode: Int32 = -1
        for await event in HarnessRunner(shell: shell, timeout: 5).run(command) {
            if case .record = event { recordCount += 1 }
            if case let .completed(code, _) = event { exitCode = code }
        }
        #expect(recordCount == 0)
        #expect(exitCode == 2)
    }
}
