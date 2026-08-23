import Foundation
import ArgumentParser
import ViewLensKit

#if canImport(SwiftUI)
import SwiftUI

struct RenderCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "render",
        abstract: "Renders and audits a SwiftUI/UIKit template across a matrix of device profiles and traits in sub-second time without simulators."
    )

    @Option(name: .long, help: "Name of registered template (e.g. LoginForm, ProfileCard, SettingsList, Sub44ptButtonBug)")
    var template: String = "LoginForm"

    @Option(name: .long, help: "Comma-separated list of device profiles (e.g. iPhoneSE,iPhone16Pro,iPadPro11)")
    var devices: String = "iPhoneSE,iPhone16Pro"

    @Option(name: .long, help: "Comma-separated list of Dynamic Type sizes (e.g. large,accessibility3)")
    var dt: String = "large,accessibility3"

    @Option(name: .long, help: "Comma-separated list of color schemes (e.g. light,dark)")
    var scheme: String = "light,dark"

    @Option(name: .long, help: "Explicit path to CoreML model")
    var model: String?

    @Option(name: .long, help: "Output format: table or json")
    var format: OutputFormat = .table

    @Option(name: .long, help: "Directory to save annotated matrix screenshots")
    var overlayDir: String?

    @Flag(name: .long, help: "List all registered templates")
    var listTemplates: Bool = false

    @Flag(name: .long, help: "Exit code 1 if any layout issues are detected (CI gate)")
    var strict: Bool = false

    @MainActor
    func run() async throws {
        if listTemplates {
            let available = TemplateRegistry.shared.availableTemplates
            print("📦 Available ViewLens Templates (\(available.count)):")
            for name in available {
                print("  - \(name)")
            }
            return
        }

        guard let targetView = TemplateRegistry.shared.template(named: template) else {
            let available = TemplateRegistry.shared.availableTemplates.joined(separator: ", ")
            fputs(JSONFormatter.errorJSON(
                message: "Template '\(template)' not found.",
                detail: "Available templates: \(available)",
                nextCommand: "viewlens render --list-templates"
            ), stderr)
            Darwin.exit(2)
        }

        // Parse matrix dimensions
        let deviceList = devices.split(separator: ",").compactMap { str -> DeviceProfile? in
            DeviceProfile.named(String(str))
        }
        let dtList = dt.split(separator: ",").map { String($0) }
        let schemeList = scheme.split(separator: ",").map { String($0) }

        let permutations = MatrixRenderer.buildPermutations(
            devices: deviceList.isEmpty ? [.iPhone16Pro] : deviceList,
            dynamicTypeSizes: dtList,
            colorSchemes: schemeList
        )

        // Resolve model (optional for pure structural / template rendering)
        var detector: YOLODetector? = nil
        if let modelURL = try? ModelLocator.resolve(customPath: model).get() {
            detector = try? YOLODetector(modelURL: modelURL)
        }

        let outURL = overlayDir.map { URL(fileURLWithPath: ($0 as NSString).expandingTildeInPath) }

        let matrixReport = try await MatrixRenderer.auditMatrix(
            templateName: template,
            view: targetView,
            permutations: permutations,
            detector: detector,
            outputDirectory: outURL
        )

        if format == .json {
            print(JSONFormatter.encode(matrixReport))
        } else {
            print("════════════════════════════════════════════════════════════════════════")
            print("🎨 ViewLens Matrix Audit: \(template)")
            print("📐 Total Permutations: \(matrixReport.summary.totalPermutations) (\(matrixReport.summary.passedCount) passed, \(matrixReport.summary.failedCount) failed)")
            print("────────────────────────────────────────────────────────────────────────")

            for (key, report) in matrixReport.permutations.sorted(by: { $0.key < $1.key }) {
                let icon = report.passed ? "✅" : "❌"
                let issuesCount = report.issues.count
                print("  \(icon) [\(key)]: \(report.passed ? "HIG Compliant" : "\(issuesCount) issue(s)")")
                for issue in report.issues {
                    print("      ⚠️ \(issue.kind.rawValue): \(issue.description)")
                    if let code = issue.remediation?.codeSnippet {
                        print("         Fix: \(code)")
                    }
                }
            }

            print("────────────────────────────────────────────────────────────────────────")
            let statusStr = matrixReport.passed ? "✅ MATRIX PASSED" : "❌ MATRIX FAILED"
            print("Overall Result: \(statusStr)")
            if let worst = matrixReport.summary.worstIssue {
                print("Worst Issue:    \(worst)")
            }
            if let out = overlayDir {
                print("Annotated PNGs: \(out)")
            }
            print("════════════════════════════════════════════════════════════════════════")
        }

        if strict && !matrixReport.passed {
            Darwin.exit(1)
        }
    }
}
#endif
