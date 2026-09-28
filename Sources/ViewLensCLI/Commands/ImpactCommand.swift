import ArgumentParser
import Foundation
import ViewLensKit

public struct ImpactCommand: ParsableCommand {
    public static let configuration = CommandConfiguration(
        commandName: "impact",
        abstract: "Maps changed Swift or resource files to affected root views and recommended audit permutations."
    )

    @Option(name: .long, help: "Owning workspace or Swift package root.")
    var workspace: String

    @Option(name: .long, parsing: .upToNextOption, help: "Changed files, absolute or relative to --workspace.")
    var changedFiles: [String]

    @Flag(name: .long, help: "Exit with failure when impact evidence is unavailable.")
    var strict = false

    public init() {}

    public func validate() throws {
        guard !changedFiles.isEmpty else { throw ValidationError("Provide at least one --changed-files path.") }
    }

    public func run() throws {
        let report = ChangeImpactAnalyzer.analyze(workspaceRoot: workspace, changedFiles: changedFiles)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        print(String(decoding: try encoder.encode(report), as: UTF8.self))
        if strict && report.completeness == .unavailable { throw ExitCode.failure }
    }
}

