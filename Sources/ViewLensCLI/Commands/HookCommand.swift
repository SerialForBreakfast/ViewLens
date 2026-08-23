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

    @MainActor
    func run() async throws {
        let configURL = config.map { URL(fileURLWithPath: ($0 as NSString).expandingTildeInPath) }
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
        if let explicitTemplate = template {
            targetTemplates = [explicitTemplate]
        } else if gateConfig.autoDetectStagedViews {
            let staged = GitDiffAnalyzer.getStagedFiles()
            let available = TemplateRegistry.shared.availableTemplates
            let matched = GitDiffAnalyzer.matchModifiedTemplates(stagedFiles: staged, availableTemplates: available)
            if !matched.isEmpty {
                targetTemplates = matched
                print("🔍 Detected \(matched.count) modified template(s) in git staging: \(matched.joined(separator: ", "))")
            }
        }

        if targetTemplates.isEmpty {
            targetTemplates = ["LoginForm"] // Default baseline audit
        }

        var allPassed = true
        var combinedEvaluations: [GateEvaluationResult] = []

        print("════════════════════════════════════════════════════════════════════════")
        print("🛡️  ViewLens Git Quality Gate: [\(gate.uppercased())]")
        print("📋 Policy: fail_on = \(gateConfig.failOn.rawValue) | Purposes: \(gateConfig.purposes.map { $0.rawValue }.joined(separator: ", "))")
        print("────────────────────────────────────────────────────────────────────────")

        for tmpl in targetTemplates {
            guard TemplateRegistry.shared.template(named: tmpl) != nil else {
                print("⚠️ Template '\(tmpl)' not found in registry. Skipping.")
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
            if let outPath = gateConfig.outputMarkdown {
                let md = PRSummaryGenerator.generateMarkdown(
                    gateName: gate,
                    config: gateConfig,
                    matrixReport: matrixReport,
                    evaluation: eval
                )
                let outURL = URL(fileURLWithPath: (outPath as NSString).expandingTildeInPath)
                try? md.write(to: outURL, atomically: true, encoding: .utf8)
                print("      📝 Wrote PR Markdown Report to: \(outPath)")
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

        print("────────────────────────────────────────────────────────────────────────")
        let finalStatus = allPassed ? "✅ GATE PASSED (Commit Allowed)" : "❌ GATE FAILED (Commit Blocked)"
        print("Final Status: \(finalStatus)")
        print("════════════════════════════════════════════════════════════════════════")

        if !allPassed && gateConfig.failOn != .none {
            Darwin.exit(1)
        }
    }
}
#endif
