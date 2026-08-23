import Foundation
import ArgumentParser
import ViewLensKit
import CoreGraphics
import ImageIO

public struct AccessibilityCommand: AsyncParsableCommand {
    public static let configuration = CommandConfiguration(
        commandName: "accessibility",
        abstract: "Performs comprehensive W3C WAI & WCAG 2.2 mobile accessibility audit on a SwiftUI template or screenshot."
    )

    @Option(name: .shortAndLong, help: "Name of registered SwiftUI view template (e.g. 'LoginForm', 'CheckoutView').")
    public var template: String?

    @Option(name: .shortAndLong, help: "Path to a screenshot image file (PNG/JPEG).")
    public var image: String?

    @Option(name: .long, help: "Target WCAG compliance level ('A', 'AA', or 'AAA').")
    public var level: String = "AA"

    @Flag(name: .long, help: "Output full JSON result for machine consumption.")
    public var json: Bool = false

    @Flag(name: .long, help: "Output formatted GitHub markdown report.")
    public var markdown: Bool = false

    public init() {}

    public func validate() throws {
        guard (template == nil) != (image == nil) else {
            throw ValidationError("Specify exactly one of --template or --image.")
        }
        guard WCAGConformanceLevel(input: level) != nil else {
            throw ValidationError("Invalid --level '\(level)'. Expected A, AA, or AAA.")
        }
    }

    public func run() async throws {
        let report: AccessibilityReport

        if let templateName = template {
            report = await AccessibilityAuditor.auditTemplate(named: templateName, targetLevel: level)
        } else if let imagePath = image {
            guard let source = CGImageSourceCreateWithURL(URL(fileURLWithPath: imagePath) as CFURL, nil),
                  let cgImage = CGImageSourceCreateImageAtIndex(source, 0, nil) else {
                print("❌ Error: Failed to load image at \(imagePath)")
                throw ExitCode.failure
            }
            report = await AccessibilityAuditor.auditScreenshot(image: cgImage, imageName: (imagePath as NSString).lastPathComponent, targetLevel: level)
        } else { throw ExitCode.failure }

        if json {
            print(JSONFormatter.encode(report))
        } else if markdown {
            print(report.formattedMarkdown())
        } else {
            printTerminalSummary(report: report)
        }

        if !report.passed {
            throw ExitCode.failure
        }
    }

    private func printTerminalSummary(report: AccessibilityReport) {
        print("════════════════════════════════════════════════════════════════════════")
        print("♿ ViewLens W3C / WCAG 2.2 Accessibility Audit: \(report.target)")
        print("🎯 Target Level: WCAG 2.2 Level \(report.targetLevel) | Score: \(report.overallComplianceScore)%")
        print("────────────────────────────────────────────────────────────────────────")

        for c in report.criteria {
            let status = c.passed ? "✅ PASS" : "❌ FAIL"
            print("  \(status) [\(c.criterion) \(c.level)] \(c.name)")
            print("         \(c.details)")
        }

        print("────────────────────────────────────────────────────────────────────────")
        if !report.complete {
            print("Overall Result: ⚪ INCOMPLETE — one or more required criteria were not evaluated")
        } else if report.passed {
            print("Overall Result: ✅ 100% WCAG \(report.targetLevel) COMPLIANT")
        } else {
            print("Overall Result: ❌ NON-COMPLIANT (\(report.issues.count) issue(s) detected)")
            for (idx, issue) in report.issues.enumerated() {
                let badge = issue.severity == .error ? "🔴" : "🟠"
                let wcag = issue.wcagCriterion.map { " [\($0)]" } ?? ""
                print("  \(idx + 1). \(badge)\(wcag) \(issue.description)")
                if let code = issue.remediation?.codeSnippet {
                    print("     Fix: \(code.replacingOccurrences(of: "\n", with: " "))")
                }
            }
        }
        print("════════════════════════════════════════════════════════════════════════")
    }
}
