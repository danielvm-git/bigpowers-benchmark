@testable import BigPowersBenchmarkKit
import Foundation
import Testing

@Suite("ShellCommandRunner")
struct ShellCommandRunnerTests {
    @Test("streamOutput yields lines before completed")
    func streamOutputYieldsLinesBeforeCompleted() async {
        let runner = ShellCommandRunner()
        let stream = runner.streamOutput(
            executable: "/bin/sh",
            arguments: ["-c", "echo line1; sleep 0.1; echo line2"],
            workingDirectory: nil
        )

        var events: [ShellOutputEvent] = []
        var completedIndex: Int?
        var lineIndices: [Int] = []

        for await event in stream {
            let index = events.count
            events.append(event)
            switch event {
            case .line:
                lineIndices.append(index)
            case .completed:
                completedIndex = index
            }
        }

        #expect(events.count >= 3)
        #expect(lineIndices.count >= 2)
        #expect(completedIndex != nil)
        if let completedIndex {
            for lineIndex in lineIndices {
                #expect(lineIndex < completedIndex)
            }
        }

        let lines = events.compactMap { event -> String? in
            if case let .line(text) = event { return text }
            return nil
        }
        #expect(lines.contains("line1"))
        #expect(lines.contains("line2"))

        if case let .completed(exitCode) = events.last {
            #expect(exitCode == 0)
        } else {
            Issue.record("Expected completed event last")
        }
    }
}
