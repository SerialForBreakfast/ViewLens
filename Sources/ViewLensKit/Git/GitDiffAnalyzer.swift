import Foundation

/// Analyzes git staging area to identify modified SwiftUI and UIKit files for targeted pre-commit audits.
public struct GitDiffAnalyzer: Sendable {
    public static func getStagedFiles() -> [String] {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/git")
        process.arguments = ["diff", "--cached", "--name-only"]

        let pipe = Pipe()
        process.standardOutput = pipe

        do {
            try process.run()
            process.waitUntilExit()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            if let output = String(data: data, encoding: .utf8) {
                return output
                    .split(separator: "\n")
                    .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                    .filter { !$0.isEmpty }
            }
        } catch {
            return []
        }

        return []
    }

    /// Matches staged file paths against registered template names.
    public static func matchModifiedTemplates(
        stagedFiles: [String],
        availableTemplates: [String]
    ) -> [String] {
        var matched: [String] = []

        for file in stagedFiles {
            let filename = URL(fileURLWithPath: file).deletingPathExtension().lastPathComponent.lowercased()
            for template in availableTemplates {
                let lowerTemplate = template.lowercased()
                if filename.contains(lowerTemplate) || lowerTemplate.contains(filename) {
                    if !matched.contains(template) {
                        matched.append(template)
                    }
                }
            }
        }

        return matched
    }
}
