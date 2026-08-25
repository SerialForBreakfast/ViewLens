import Foundation

/// Specific token mismatch between Figma design variables and SwiftUI code.
public struct TokenMismatch: Sendable, Codable, Equatable {
    public let token: String
    public let expectedFigma: String
    public let actualSwiftUI: String
    public let remediationSnippet: String?

    public init(
        token: String,
        expectedFigma: String,
        actualSwiftUI: String,
        remediationSnippet: String? = nil
    ) {
        self.token = token
        self.expectedFigma = expectedFigma
        self.actualSwiftUI = actualSwiftUI
        self.remediationSnippet = remediationSnippet
    }
}

/// Coordinate alignment delta between a Figma component and a detected native element.
public struct GeometryDelta: Sendable, Codable, Equatable {
    public let elementName: String
    public let deltaX: Double
    public let deltaY: Double
    public let deltaWidth: Double
    public let deltaHeight: Double
    public let iou: Double

    public init(
        elementName: String,
        deltaX: Double,
        deltaY: Double,
        deltaWidth: Double,
        deltaHeight: Double,
        iou: Double
    ) {
        self.elementName = elementName
        self.deltaX = deltaX
        self.deltaY = deltaY
        self.deltaWidth = deltaWidth
        self.deltaHeight = deltaHeight
        self.iou = iou
    }
}

/// Comprehensive Design-to-Code verification report comparing Figma reference designs with native code.
public struct DesignDiffReport: Sendable, Codable, Equatable {
    public let referenceSource: String
    public let candidateTemplate: String
    public let visualDiff: VisualDiffResult
    public let tokenMismatches: [TokenMismatch]
    public let geometryDeltas: [GeometryDelta]
    public let accessibilityReport: AccessibilityReport?
    public let passed: Bool
    public let timestamp: Date

    public init(
        referenceSource: String,
        candidateTemplate: String,
        visualDiff: VisualDiffResult,
        tokenMismatches: [TokenMismatch] = [],
        geometryDeltas: [GeometryDelta] = [],
        accessibilityReport: AccessibilityReport? = nil,
        passed: Bool,
        timestamp: Date = Date()
    ) {
        self.referenceSource = referenceSource
        self.candidateTemplate = candidateTemplate
        self.visualDiff = visualDiff
        self.tokenMismatches = tokenMismatches
        self.geometryDeltas = geometryDeltas
        self.accessibilityReport = accessibilityReport
        self.passed = passed
        self.timestamp = timestamp
    }

    /// Formats a clean GitHub markdown summary of the design verification.
    public func formattedMarkdown() -> String {
        var md = """
        ## 🎨 ViewLens Design-to-Code Verification Report

        **Reference Design:** `\(referenceSource)`  
        **Rendered Template:** `\(candidateTemplate)`  
        **Overall Status:** \(passed ? "✅ PASS (Design Faithful)" : "❌ FAIL (Design Drift Detected)")

        ### 🔍 Visual & Structural Similarity Metrics

        | Metric | Value | Threshold | Status |
        |---|---|---|---|
        | **SSIM Index** | `\(String(format: "%.4f", visualDiff.ssimScore))` | $\\ge 0.9800$ | \(visualDiff.ssimScore >= 0.98 ? "✅ Pass" : "❌ Fail") |
        | **Pixel Mismatch** | `\(String(format: "%.2f", visualDiff.mismatchPercentage))%` | $\\le 5.00\\%$ | \(visualDiff.mismatchPercentage <= 5.0 ? "✅ Pass" : "❌ Fail") |
        | **Differing Pixels** | `\(visualDiff.differingPixelsCount)` / `\(visualDiff.totalPixelsCount)` | - | - |

        """

        if !tokenMismatches.isEmpty {
            md += "\n### 🏷️ Design Token & Spacing Discrepancies\n\n"
            md += "| Token | Expected (Figma) | Actual (SwiftUI) | Suggested Fix |\n"
            md += "|---|---|---|---|\n"
            for t in tokenMismatches {
                let fix = t.remediationSnippet.map { "`\($0)`" } ?? "-"
                md += "| `\(t.token)` | `\(t.expectedFigma)` | `\(t.actualSwiftUI)` | \(fix) |\n"
            }
        }

        if let a11y = accessibilityReport {
            md += "\n### ♿ Accessibility & HIG Matrix\n\n"
            md += "- **WCAG Compliance Score:** `\(a11y.overallComplianceScore)%` (\(a11y.passed ? "✅ Passed" : "❌ Failed"))\n"
            md += "- **Detected A11y Issues:** `\(a11y.issues.count)`\n"
        }

        return md
    }

    public var textualDiff: TextualDesignDiff {
        TextualDesignDiff.from(report: self)
    }
}

public enum TextualDiffImpactCategory: String, Codable, Sendable, CaseIterable {
    case accessibilityImpact = "Accessibility Impact"
    case semanticImpact = "Semantic Impact"
    case layoutImpact = "Layout Impact"
    case cosmeticShift = "Cosmetic Shift"
}

public struct TextualDiffImpact: Codable, Sendable, Equatable, Identifiable {
    public var id: String { "\(category.rawValue):\(title)" }
    public let category: TextualDiffImpactCategory
    public let title: String
    public let detail: String
    public let severity: ViewLensSeverity
    public let remediationSnippet: String?

    public init(
        category: TextualDiffImpactCategory,
        title: String,
        detail: String,
        severity: ViewLensSeverity = .warning,
        remediationSnippet: String? = nil
    ) {
        self.category = category
        self.title = title
        self.detail = detail
        self.severity = severity
        self.remediationSnippet = remediationSnippet
    }
}

public struct TextualDesignDiff: Codable, Sendable, Equatable {
    public let impacts: [TextualDiffImpact]

    public var accessibilityImpacts: [TextualDiffImpact] {
        impacts.filter { $0.category == .accessibilityImpact }
    }

    public var semanticImpacts: [TextualDiffImpact] {
        impacts.filter { $0.category == .semanticImpact }
    }

    public var layoutImpacts: [TextualDiffImpact] {
        impacts.filter { $0.category == .layoutImpact }
    }

    public var cosmeticShifts: [TextualDiffImpact] {
        impacts.filter { $0.category == .cosmeticShift }
    }

    public init(impacts: [TextualDiffImpact]) {
        self.impacts = impacts
    }

    public static func from(report: DesignDiffReport) -> TextualDesignDiff {
        var impacts: [TextualDiffImpact] = []

        // 1. Accessibility Impacts
        if let a11y = report.accessibilityReport {
            for issue in a11y.issues {
                let title = issue.wcagCriterion.map { "[\($0)] \(issue.description)" } ?? issue.description
                impacts.append(TextualDiffImpact(
                    category: .accessibilityImpact,
                    title: title,
                    detail: issue.description,
                    severity: issue.severity,
                    remediationSnippet: issue.remediation?.codeSnippet
                ))
            }
        }

        // 2. Token Mismatches -> Semantic Impacts
        for token in report.tokenMismatches {
            impacts.append(TextualDiffImpact(
                category: .semanticImpact,
                title: "Token Mismatch: \(token.token)",
                detail: "Expected Figma '\(token.expectedFigma)', found SwiftUI '\(token.actualSwiftUI)'",
                severity: .warning,
                remediationSnippet: token.remediationSnippet
            ))
        }

        // 3. Geometry Deltas -> Layout Impacts
        for geo in report.geometryDeltas {
            let desc = "Offset Δ(\(String(format: "%.1f", geo.deltaX)), \(String(format: "%.1f", geo.deltaY))) pt, Size Δ(\(String(format: "%.1f", geo.deltaWidth)), \(String(format: "%.1f", geo.deltaHeight))) pt (IoU: \(String(format: "%.2f", geo.iou)))"
            impacts.append(TextualDiffImpact(
                category: .layoutImpact,
                title: "Layout Shift: \(geo.elementName)",
                detail: desc,
                severity: geo.iou < 0.70 ? .error : .warning
            ))
        }

        // 4. Visual Pixel Diff -> Cosmetic Shifts
        if report.visualDiff.mismatchPercentage > 0 {
            impacts.append(TextualDiffImpact(
                category: .cosmeticShift,
                title: "Perceptual Diff (SSIM \(String(format: "%.4f", report.visualDiff.ssimScore)))",
                detail: "\(String(format: "%.2f", report.visualDiff.mismatchPercentage))% pixel delta (\(report.visualDiff.differingPixelsCount) differing pixels)",
                severity: report.visualDiff.passed ? .info : .warning
            ))
        }

        return TextualDesignDiff(impacts: impacts)
    }
}
