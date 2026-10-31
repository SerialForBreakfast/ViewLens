import Foundation
import ArgumentParser
import ViewLensKit

#if canImport(SwiftUI)
import SwiftUI

struct HookCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "hook",
        abstract: "Executes a ViewLens Git Hook or CI Quality Gate audit (pre-commit, pre-push, pull-request)."
    )

    @Argument(help: "Gate name to evaluate: pre-commit, pre-push, pull-request, or ci")
    var gate: String = "pre-commit"

    @Option(name: .long, help: "Path to custom configuration file (.viewlens.json)")
    var config: String?

    @Option(name: .long, help: "Explicit template name to audit (overrides staged auto-detection)")
    var template: String?

    @Option(name: .long, help: "Failure threshold override: error, warning, or none")
    var failOn: String?

    @Option(name: .long, help: "Output path for markdown report")
    var outputMarkdown: String?

    @Option(name: .long, help: "Workspace root for impact analysis and Git change discovery")
    var workspace: String = FileManager.default.currentDirectoryPath

    @MainActor
    func run() async throws {
        let configURL = config.map { URL(fileURLWithPath: ($0 as NSString).expandingTildeInPath) }
            ?? URL(fileURLWithPath: workspace).appendingPathComponent(".viewlens.json")
        let masterConfig = ViewLensConfig.load(from: configURL)

        var gateConfig = masterConfig.gates[gate] ?? GateConfig()

        // Apply CLI overrides if present
        if let failStr = failOn, let threshold = FailureThreshold(rawValue: failStr.lowercased()) {
            gateConfig.failOn = threshold
        }
        if let outPath = outputMarkdown {
            gateConfig.outputMarkdown = outPath
        }

        // Determine target templates to audit
        var targetTemplates: [String] = []
        var selection: ImpactAuditSelection?
        if let explicitTemplate = template {
            targetTemplates = [explicitTemplate]
        } else if gateConfig.autoDetectStagedViews {
            let staged = try GitDiffAnalyzer.getChangedFiles(workspaceRoot: workspace, gate: gate)
            if staged.isEmpty {
                print("No changed files to audit for \(gate).")
                return
            }
            let available = TemplateRegistry.shared.availableTemplates
            let selected = ImpactAuditSelection.select(workspaceRoot: workspace, changedFiles: staged, availableTemplates: available)
            selection = selected
            targetTemplates = selected.templates
            print("Impact selection (\(selected.impact.confidence.rawValue)): \(selected.explanation)")
            print("Selected: \(targetTemplates.joined(separator: ", "))")
            if !selected.unregisteredRoots.isEmpty { print("Not retested: \(selected.unregisteredRoots.joined(separator: ", "))") }
        }

        if targetTemplates.isEmpty {
            targetTemplates = TemplateRegistry.shared.availableTemplates.sorted()
        }

        var allPassed = !targetTemplates.isEmpty && (selection?.coverageAvailable ?? true)
        var combinedEvaluations: [GateEvaluationResult] = []
        var markdownReports: [String] = []

        print("════════════════════════════════════════════════════════════════════════")
        print("🛡️  ViewLens Git Quality Gate: [\(gate.uppercased())]")
        print("📋 Policy: fail_on = \(gateConfig.failOn.rawValue) | Purposes: \(gateConfig.purposes.map { $0.rawValue }.joined(separator: ", "))")
        print("────────────────────────────────────────────────────────────────────────")

        for tmpl in targetTemplates {
            guard TemplateRegistry.shared.template(named: tmpl) != nil else {
                print("⚠️ Template '\(tmpl)' not found in registry. Not retested.")
                allPassed = false
                continue
            }

            var detector: YOLODetector? = nil
            if let modelURL = try? ModelLocator.resolve().get() {
                detector = try? YOLODetector(modelURL: modelURL)
            }

            let matrixReport = try await MatrixRenderer.auditNamedTemplate(
                templateName: tmpl,
                deviceNames: gateConfig.devices,
                dtSizes: gateConfig.dynamicTypeSizes,
                schemes: gateConfig.colorSchemes,
                detector: detector
            )

            let eval = QualityGateEvaluator.evaluate(
                gateName: gate,
                config: gateConfig,
                matrixReport: matrixReport
            )

            combinedEvaluations.append(eval)

            let icon = eval.passed ? "✅" : "❌"
            print("  \(icon) Template: \(tmpl) (\(matrixReport.summary.totalPermutations) matrix tests) -> \(eval.passed ? "PASSED" : "FAILED")")
            if let reason = eval.failureReason {
                print("      ⚠️ Reason: \(reason)")
            }

            // Write markdown report if requested
            if gateConfig.outputMarkdown != nil {
                let md = PRSummaryGenerator.generateMarkdown(
                    gateName: gate,
                    config: gateConfig,
                    matrixReport: matrixReport,
                    evaluation: eval
                )
                markdownReports.append(md)
            }

            // Write to GitHub Step Summary if environment variable exists
            if let stepSummaryPath = ProcessInfo.processInfo.environment["GITHUB_STEP_SUMMARY"] {
                let md = PRSummaryGenerator.generateMarkdown(
                    gateName: gate,
                    config: gateConfig,
                    matrixReport: matrixReport,
                    evaluation: eval
                )
                let summaryURL = URL(fileURLWithPath: stepSummaryPath)
                if let handle = try? FileHandle(forWritingTo: summaryURL) {
                    handle.seekToEndOfFile()
                    if let data = md.data(using: .utf8) {
                        handle.write(data)
                    }
                    try? handle.close()
                }
            }

            if !eval.passed {
                allPassed = false
            }
        }

        if let outPath = gateConfig.outputMarkdown {
            var introduction = "# Change impact selection\n\n"
            if let selection {
                introduction += "\(selection.explanation)\n\nConfidence: \(selection.impact.confidence.rawValue). Coverage: \(selection.impact.completeness.rawValue).\n\n"
                introduction += "Not retested: \(selection.unregisteredRoots.joined(separator: ", "))\n\n"
            }
            introduction += "Overall gate: \(allPassed ? "passed" : "failed or incomplete").\n\n"
            let outURL = URL(fileURLWithPath: (outPath as NSString).expandingTildeInPath)
            try FileManager.default.createDirectory(at: outURL.deletingLastPathComponent(), withIntermediateDirectories: true)
            try (introduction + markdownReports.joined(separator: "\n\n")).write(to: outURL, atomically: true, encoding: .utf8)
        }

        print("────────────────────────────────────────────────────────────────────────")
        let finalStatus = allPassed ? "✅ GATE PASSED (Commit Allowed)" : "❌ GATE FAILED (Commit Blocked)"
        print("Final Status: \(finalStatus)")
        print("════════════════════════════════════════════════════════════════════════")

        if let summaryPath = ProcessInfo.processInfo.environment["GITHUB_STEP_SUMMARY"],
           let handle = try? FileHandle(forWritingTo: URL(fileURLWithPath: summaryPath)) {
            defer { try? handle.close() }
            try handle.seekToEnd()
            let summary = "\n\nOverall gate: \(allPassed ? "passed" : "failed or incomplete"). \(selection?.explanation ?? "Explicit template coverage.")\n"
            try handle.write(contentsOf: Data(summary.utf8))
        }

        if !allPassed && gateConfig.failOn != .none {
            Darwin.exit(1)
        }
    }
}
#endif
