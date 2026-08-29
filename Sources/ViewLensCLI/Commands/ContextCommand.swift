import ArgumentParser
import Foundation
import ViewLensKit

public struct ContextCommand: ParsableCommand {
    public static let configuration = CommandConfiguration(
        commandName: "context",
        abstract: "Resolves the bounded source, resource, package, and preview-scenario context for a Swift view."
    )

    @Option(name: .long, help: "Owning workspace or package root.")
    var workspace: String

    @Option(name: .long, help: "Root Swift view/type symbol to resolve.")
    var rootSymbol: String?

    @Option(name: .long, help: "Root Swift source file, absolute or relative to --workspace.")
    var sourceFile: String?

    @Option(name: .long, help: "Specific .xcworkspace, .xcodeproj, or Package.swift path.")
    var project: String?

    @Option(name: .long, help: "Owning Xcode scheme.")
    var scheme: String?

    @Option(name: .long, help: "Owning build target.")
    var target: String?

    @Option(name: .long, help: "Build configuration recorded in the context manifest.")
    var configurationName: String = "Debug"

    @Option(name: .long, help: "Named deterministic preview scenario.")
    var scenario: String?

    @Option(name: .long, help: "Package policy: locked, local_only, or allow_resolution.")
    var packagePolicy: String = PackageResolutionPolicy.locked.rawValue

    @Option(name: .long, help: "Missing resource policy: fail, request, structural_mock, or generated_mock.")
    var missingResourcePolicy: String = MissingResourcePolicy.fail.rawValue

    @Flag(name: .long, help: "Return exit code 1 unless the context is ready_for_build.")
    var strict = false

    public init() {}

    public func validate() throws {
        guard rootSymbol?.isEmpty == false || sourceFile?.isEmpty == false else {
            throw ValidationError("Provide either --root-symbol or --source-file.")
        }
        guard PackageResolutionPolicy(rawValue: packagePolicy) != nil else {
            throw ValidationError("Invalid --package-policy. Expected locked, local_only, or allow_resolution.")
        }
        guard MissingResourcePolicy(rawValue: missingResourcePolicy) != nil else {
            throw ValidationError("Invalid --missing-resource-policy. Expected fail, request, structural_mock, or generated_mock.")
        }
    }

    public func run() throws {
        let manifest = ProjectContextManifest(
            workspaceRoot: workspace,
            projectPath: project,
            scheme: scheme,
            target: target,
            configuration: configurationName,
            rootSymbol: rootSymbol,
            sourceFile: sourceFile,
            scenario: scenario,
            packagePolicy: PackageResolutionPolicy(rawValue: packagePolicy) ?? .locked,
            missingResourcePolicy: MissingResourcePolicy(rawValue: missingResourcePolicy) ?? .fail
        )
        let report = ProjectContextResolver.resolve(manifest: manifest)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        let data = try encoder.encode(report)
        print(String(decoding: data, as: UTF8.self))
        if strict && report.status != .readyForBuild {
            throw ExitCode.failure
        }
    }
}
