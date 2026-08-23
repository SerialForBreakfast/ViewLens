import Testing
import Foundation
import CoreGraphics
@testable import ViewLensKit

@Suite("W3C WAI & WCAG 2.2 Accessibility Engine Tests")
struct AccessibilityAuditorTests {

    @Test("WCAG relative luminance calculation")
    func testRelativeLuminance() {
        // Pure black luminance is 0.0
        let blackLum = ContrastEvaluator.relativeLuminance(r: 0.0, g: 0.0, b: 0.0)
        #expect(blackLum == 0.0)

        // Pure white luminance is 1.0
        let whiteLum = ContrastEvaluator.relativeLuminance(r: 1.0, g: 1.0, b: 1.0)
        #expect(abs(whiteLum - 1.0) < 0.001)
    }

    @Test("WCAG contrast ratio on standard color pairs")
    func testContrastRatio() {
        // Black on White: 21:1
        let bwResult = ContrastEvaluator.evaluate(
            fgR: 0.0, fgG: 0.0, fgB: 0.0,
            bgR: 1.0, bgG: 1.0, bgB: 1.0
        )
        #expect(bwResult.ratio == 21.0)
        #expect(bwResult.passesAA == true)
        #expect(bwResult.passesAAA == true)

        // Identical colors: 1.0:1
        let sameResult = ContrastEvaluator.evaluate(
            fgR: 1.0, fgG: 1.0, fgB: 1.0,
            bgR: 1.0, bgG: 1.0, bgB: 1.0
        )
        #expect(sameResult.ratio == 1.0)
        #expect(sameResult.passesAA == false)

        // Mid-gray (#777777 = 0.467) on White (#FFFFFF) is ~4.48:1 (fails 4.5:1 AA)
        let midGrayResult = ContrastEvaluator.evaluate(
            fgR: 0.467, fgG: 0.467, fgB: 0.467,
            bgR: 1.0, bgG: 1.0, bgB: 1.0
        )
        #expect(midGrayResult.ratio < 4.5)
        #expect(midGrayResult.passesAA == false)
        #expect(midGrayResult.passesAALargeText == true)
    }

    @Test("Audits compliant template successfully")
    @MainActor
    func testAuditCompliantTemplate() async {
        let report = await AccessibilityAuditor.auditTemplate(named: "LoginForm", targetLevel: "AA")
        #expect(report.passed == true)
        #expect(report.overallComplianceScore == 100)
        #expect(report.criteria.count >= 4)
        #expect(report.complete == true)
        #expect(report.criteria.contains { $0.criterion == "WCAG 4.1.2" && $0.passed })
        #expect(report.criteria.contains { $0.criterion == "WCAG 2.5.8" && $0.passed })
        #expect(report.criteria.first { $0.criterion == "WCAG 1.4.4 / 1.4.10" }?.details.contains("AX1, AX3, and AX5") == true)
    }

    @Test("A 24pt target passes WCAG 2.5.8 AA but fails WCAG 2.5.5 AAA")
    @MainActor
    func testAuditDefectiveTemplate() async {
        let aaReport = await AccessibilityAuditor.auditTemplate(named: "Sub44ptButtonBug", targetLevel: "AA")
        #expect(aaReport.criteria.first { $0.criterion == "WCAG 2.5.8" }?.passed == true)

        let aaaReport = await AccessibilityAuditor.auditTemplate(named: "Sub44ptButtonBug", targetLevel: "AAA")
        #expect(aaaReport.passed == false)
        #expect(aaaReport.criteria.first { $0.criterion == "WCAG 2.5.5" }?.passed == false)
        #expect(aaaReport.issues.contains { $0.kind == .tappableTargetTooSmall && $0.wcagLevel == "AAA" })
    }

    @Test("WCAG 2.5.8 applies the spacing exception to isolated undersized targets")
    func testTargetSizeSpacingException() {
        let imageSize = CGSize(width: 300, height: 600)
        let isolated = DetectedElement(
            type: "button",
            confidence: 1,
            boundingBox: BoundingBox(x: 0.45, y: 0.45, width: 20.0 / 300.0, height: 20.0 / 600.0)
        )
        #expect(WCAGRules.targetSizeIssues(
            elements: [isolated],
            imageSize: imageSize,
            scale: 1,
            targetLevel: .aa
        ).isEmpty)

        let adjacent = DetectedElement(
            type: "button",
            confidence: 1,
            boundingBox: BoundingBox(x: 0.50, y: 0.45, width: 20.0 / 300.0, height: 20.0 / 600.0)
        )
        #expect(WCAGRules.targetSizeIssues(
            elements: [isolated, adjacent],
            imageSize: imageSize,
            scale: 1,
            targetLevel: .aa
        ).count == 2)
    }

    @Test("Dynamic Type layout failures are emitted as dynamicTypeOverflow")
    func testDynamicTypeOverflowRule() {
        let baseline = [DetectedElement(
            type: "primaryButton",
            confidence: 1,
            boundingBox: BoundingBox(x: 0.1, y: 0.7, width: 0.8, height: 0.1)
        )]
        let clipped = ViewLensIssue(
            kind: .clippedElement,
            severity: .warning,
            description: "Button reaches viewport edge."
        )
        let issues = WCAGRules.reflowIssues(
            baselineElements: baseline,
            enlargedElements: [],
            enlargedLayoutIssues: [clipped],
            stage: "AX5 (312%)"
        )
        #expect(issues.contains { $0.kind == .dynamicTypeOverflow })
        #expect(issues.allSatisfy { $0.wcagCriterion == "WCAG 1.4.4 / 1.4.10" })
    }

    @Test("WCAG 4.1.2 reports missing name, role, and required value")
    func testNameRoleValueRule() {
        let issues = WCAGRules.nameRoleValueIssues(snapshots: [
            AccessibilityElementSnapshot(identifier: "CustomControl", label: nil, role: nil, value: nil, requiresValue: true)
        ])
        #expect(issues.count == 3)
        #expect(issues.contains { $0.kind == .missingAccessibilityLabel })
        #expect(issues.contains { $0.kind == .missingAccessibilityTrait })
        #expect(issues.allSatisfy { $0.wcagCriterion == "WCAG 4.1.2" && $0.wcagLevel == "A" })
    }
}
