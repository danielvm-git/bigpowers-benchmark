@testable import BigPowersBenchmarkKit
import Foundation
import Testing

@Suite("HarnessCommand")
struct HarnessCommandTests {
    private let runner = URL(fileURLWithPath: "/tmp/runner", isDirectory: true)
    private let subject = URL(fileURLWithPath: "/tmp/subject", isDirectory: true)
    private let out = URL(fileURLWithPath: "/tmp/out", isDirectory: true)
    private let json = URL(fileURLWithPath: "/tmp/out/AB.json")

    @Test("builds argv without shell interpolation")
    func buildsArguments() {
        let command = HarnessCommand(
            runnerRoot: runner,
            subjectRoot: subject,
            tasks: ["ab-11", "ab-13"],
            arms: ["vanilla", "bigpowers"],
            runsPerTask: 10,
            adapter: "pi-docker",
            outDir: out,
            jsonOut: json
        )
        #expect(command.scriptURL.path == "/tmp/runner/scripts/run-ab-eval.sh")
        #expect(command.arguments == [
            "--bigpowers-root", "/tmp/subject",
            "--tasks", "ab-11,ab-13",
            "--arms", "vanilla,bigpowers",
            "--k", "10",
            "--adapter", "pi-docker",
            "--out", "/tmp/out",
            "--json-out", "/tmp/out/AB.json",
        ])
        #expect(command.processArguments.first == "/tmp/runner/scripts/run-ab-eval.sh")
    }

    @Test("omits json-out when not requested")
    func omitsJSONOut() {
        let command = HarnessCommand(
            runnerRoot: runner,
            subjectRoot: subject,
            tasks: ["ab-11"],
            outDir: out
        )
        #expect(!command.arguments.contains("--json-out"))
    }
}
