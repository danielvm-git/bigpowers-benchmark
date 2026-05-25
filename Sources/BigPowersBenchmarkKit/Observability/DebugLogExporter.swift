import Foundation

public enum DebugLogExporter {
    public static func lastLines(from url: URL, count: Int) -> String {
        guard count > 0,
              let data = try? Data(contentsOf: url),
              let text = String(data: data, encoding: .utf8),
              !text.isEmpty
        else {
            return ""
        }
        let lines = text.split(separator: "\n", omittingEmptySubsequences: true)
        return lines.suffix(count).joined(separator: "\n")
    }

    public static func exportLogFile(from sourceURL: URL, to destinationURL: URL) throws {
        if FileManager.default.fileExists(atPath: destinationURL.path) {
            try FileManager.default.removeItem(at: destinationURL)
        }
        try FileManager.default.copyItem(at: sourceURL, to: destinationURL)
    }
}
