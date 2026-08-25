import Testing
import Foundation
@testable import ViewLensKit

@Suite("Textual Design Diff Tests (NV-2.7)")
struct TextualDesignDiffTests {

    @Test("TextualDesignDiff correctly categorizes impacts from DesignDiffReport")
    func testTextualDesignDiffCategorization() {
        let visualDiff = VisualDiffResult(
            ssimScore: 0.9450,
            mismatchPercentage: 1.5,
            differingPixelsCount: 150,
            totalPixelsCount: 10000,
            passed: false,
            tolerance: 0.05
        )
        let tokens = [
            TokenMismatch(token: "cornerRadius", expectedFigma: "12", actualSwiftUI: "8", remediationSnippet: ".cornerRadius(12)")
        ]
        let deltas = [
            GeometryDelta(elementName: "LoginButton", deltaX: 0, deltaY: 8, deltaWidth: 0, deltaHeight: -10, iou: 0.85)
        ]
        let a11y = AccessibilityReport(
            target: "LoginForm",
            targetLevel: "AA",
            overallComplianceScore: 80,
            passed: false,
            criteria: [],
            issues: [
                ViewLensIssue(
                    kind: .tappableTargetTooSmall,
                    severity: .error,
                    description: "Target height is 34pt, minimum is 44pt",
                    wcagCriterion: "WCAG 2.5.8",
                    remediation: RemediationAdvice(description: "Increase height", codeSnippet: ".frame(minHeight: 44)")
                )
            ]
        )

        let report = DesignDiffReport(
            referenceSource: "login_mockup.png",
            candidateTemplate: "LoginForm",
            visualDiff: visualDiff,
            tokenMismatches: tokens,
            geometryDeltas: deltas,
            accessibilityReport: a11y,
            passed: false
        )

        let diff = report.textualDiff

        #expect(diff.accessibilityImpacts.count == 1)
        #expect(diff.accessibilityImpacts[0].title.contains("WCAG 2.5.8"))
        #expect(diff.accessibilityImpacts[0].severity == .error)

        #expect(diff.semanticImpacts.count == 1)
        #expect(diff.semanticImpacts[0].title.contains("cornerRadius"))

        #expect(diff.layoutImpacts.count == 1)
        #expect(diff.layoutImpacts[0].title.contains("LoginButton"))

        #expect(diff.cosmeticShifts.count == 1)
        #expect(diff.cosmeticShifts[0].title.contains("SSIM"))
    }
}
