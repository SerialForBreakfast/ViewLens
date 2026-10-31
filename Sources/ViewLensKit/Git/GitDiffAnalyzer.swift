import Foundation

/// Analyzes git staging area to identify modified SwiftUI and UIKit files for targeted pre-commit audits.
public struct GitDiffAnalyzer: Sendable {
    public enum ChangeDiscoveryError: Error, LocalizedError {
        case missingBaseReference
        case gitFailed
        public var errorDescription: String? {
            switch self {
            case .missingBaseReference: "Set VIEWLENS_BASE_REF to the comparison base for CI gates."
            case .gitFailed: "Git change discovery failed. Check the workspace and comparison reference."
            }
        }
    }

    public static func getChangedFiles(workspaceRoot: String, gate: String) throws -> [String] {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/git")
        var arguments = ["-C", workspaceRoot, "diff", "--name-only", "-z"]
        if gate == "pre-commit" { arguments.append("--cached") }
        else if let base = ProcessInfo.processInfo.environment["VIEWLENS_BASE_REF"], !base.isEmpty {
            arguments.append("\(base)...HEAD")
        } else if gate == "pre-push" {
            arguments.append("@{upstream}...HEAD")
        } else { throw ChangeDiscoveryError.missingBaseReference }
        process.arguments = arguments
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice
        do {
            try process.run()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            process.waitUntilExit()
            guard process.terminationStatus == 0 else { throw ChangeDiscoveryError.gitFailed }
            return String(decoding: data, as: UTF8.self).split(separator: "\0").map(String.init).sorted()
        } catch { throw ChangeDiscoveryError.gitFailed }
    }

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
