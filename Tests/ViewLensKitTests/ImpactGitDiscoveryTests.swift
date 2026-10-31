import Foundation
import Testing
@testable import ViewLensKit

@Suite("Impact Git Discovery")
struct ImpactGitDiscoveryTests {
    @Test("Staged discovery preserves whitespace and reports invalid repositories")
    func stagedPathsAndFailures() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        #expect(throws: GitDiffAnalyzer.ChangeDiscoveryError.self) {
            try GitDiffAnalyzer.getChangedFiles(workspaceRoot: directory.path, gate: "pre-commit")
        }
        try git(["init", "-q", directory.path])
        let filename = "View with\nnewline.swift"
        try Data("struct Example: View {}".utf8).write(to: directory.appendingPathComponent(filename))
        try git(["-C", directory.path, "add", "--", filename])
        #expect(try GitDiffAnalyzer.getChangedFiles(workspaceRoot: directory.path, gate: "pre-commit") == [filename])
    }

    private func git(_ arguments: [String]) throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/git")
        process.arguments = arguments
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        try process.run()
        process.waitUntilExit()
        #expect(process.terminationStatus == 0)
    }
}
