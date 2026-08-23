import Foundation
import ArgumentParser
import ViewLensKit
import CoreGraphics
import ImageIO

public struct DesignDiffCommand: AsyncParsableCommand {
    public static let configuration = CommandConfiguration(
        commandName: "design-diff",
        abstract: "Performs Design-to-Code verification comparing a Figma reference design against native SwiftUI code."
    )

    @Option(name: .shortAndLong, help: "Path to the reference design image (PNG/JPEG) from Figma or design baseline.")
    public var reference: String

    @Option(name: .shortAndLong, help: "Name of registered SwiftUI view template (e.g. 'LoginForm', 'CheckoutView').")
    public var template: String

    @Option(name: .shortAndLong, help: "Device profile to simulate (e.g. 'iPhone16Pro', 'iPhoneSE', 'iPadPro11').")
    public var device: String = "iPhone16Pro"

    @Option(name: .long, help: "Minimum SSIM threshold to pass (default 0.98).")
    public var threshold: Double = 0.98

    @Option(name: .long, help: "Optional path to write visual diff heatmap image.")
    public var heatmap: String?

    @Flag(name: .long, help: "Output structured JSON report.")
    public var json: Bool = false

    @Flag(name: .long, help: "Output formatted GitHub markdown report.")
    public var markdown: Bool = false

    public init() {}

    public func run() async throws {
        guard let source = CGImageSourceCreateWithURL(URL(fileURLWithPath: reference) as CFURL, nil),
              let refImage = CGImageSourceCreateImageAtIndex(source, 0, nil) else {
            print("❌ Error: Failed to load reference image at '\(reference)'")
            throw ExitCode.failure
        }

        let profile = DeviceProfile.named(device) ?? .iPhone16Pro

        let report = await DesignVerifier.verify(
            referenceImage: refImage,
            referenceSource: (reference as NSString).lastPathComponent,
            templateName: template,
            device: profile,
            thresholdSSIM: threshold,
            includeAccessibility: true,
            heatmapOutputPath: heatmap
        )

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

    private func printTerminalSummary(report: DesignDiffReport) {
        print("════════════════════════════════════════════════════════════════════════")
        print("🎨 ViewLens Design-to-Code Verification")
        print("📐 Reference: \(report.referenceSource) | Template: \(report.candidateTemplate)")
        print("────────────────────────────────────────────────────────────────────────")
        let ssimIcon = report.visualDiff.passed ? "✅ PASS" : "❌ FAIL"
        print("  \(ssimIcon) Structural Similarity (SSIM): \(String(format: "%.4f", report.visualDiff.ssimScore)) (Threshold: 0.9800)")
        print("         Pixel Mismatch: \(String(format: "%.2f", report.visualDiff.mismatchPercentage))% (\(report.visualDiff.differingPixelsCount) differing pixels)")

        if let a11y = report.accessibilityReport {
            let a11yIcon = a11y.passed ? "✅ PASS" : "❌ FAIL"
            print("  \(a11yIcon) WCAG 2.2 Accessibility Score: \(a11y.overallComplianceScore)% (\(a11y.issues.count) issue(s))")
        }

        print("────────────────────────────────────────────────────────────────────────")
        if report.passed {
            print("Overall Result: ✅ 100% DESIGN FAITHFUL & ACCESSIBLE")
        } else {
            print("Overall Result: ❌ DESIGN DRIFT OR HIG/WCAG VIOLATION DETECTED")
        }
        print("════════════════════════════════════════════════════════════════════════")
    }
}
