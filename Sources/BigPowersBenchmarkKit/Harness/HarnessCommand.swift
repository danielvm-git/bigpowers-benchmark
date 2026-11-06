import Foundation

/// Builds the argv for `scripts/run-ab-eval.sh`. No shell string is assembled here.
public struct HarnessCommand: Sendable, Hashable {
    public let runnerRoot: URL
    public let subjectRoot: URL
    public let tasks: [String]
    public let arms: [String]
    public let runsPerTask: Int
    public let adapter: String
    public let outDir: URL
    public let jsonOut: URL?

    public init(
        runnerRoot: URL,
        subjectRoot: URL,
        tasks: [String],
        arms: [String] = ["vanilla", "bigpowers"],
        runsPerTask: Int = 1,
        adapter: String = "pi-docker",
        outDir: URL,
        jsonOut: URL? = nil
    ) {
        self.runnerRoot = runnerRoot
        self.subjectRoot = subjectRoot
        self.tasks = tasks
        self.arms = arms
        self.runsPerTask = runsPerTask
        self.adapter = adapter
        self.outDir = outDir
        self.jsonOut = jsonOut
    }

    public var scriptURL: URL {
        runnerRoot.appendingPathComponent("scripts/run-ab-eval.sh")
    }

    /// Arguments after the script path.
    public var arguments: [String] {
        var args = [
            "--bigpowers-root", subjectRoot.path,
            "--tasks", tasks.joined(separator: ","),
            "--arms", arms.joined(separator: ","),
            "--k", String(runsPerTask),
            "--adapter", adapter,
            "--out", outDir.path,
        ]
        if let jsonOut {
            args += ["--json-out", jsonOut.path]
        }
        return args
    }

    public var processArguments: [String] {
        [scriptURL.path] + arguments
    }
}
