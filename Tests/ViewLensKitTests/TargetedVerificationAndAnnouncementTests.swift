import Testing
import Foundation
@testable import ViewLensKit

@Suite("Targeted Verification, Announcement Analyzer, and Matrix Permutations Tests (NV-4.5, NV-4.8, NV-5.7)")
struct TargetedVerificationAndAnnouncementTests {

    @Test("AnnouncementAnalyzer detects rapid bursts, duplicate consecutive messages, and empty messages")
    func testAnnouncementAnalyzer() {
        let msg1 = AccessibilityAnnouncementRecord(timestamp: 10.0, message: "Screen loaded")
        let msg2 = AccessibilityAnnouncementRecord(timestamp: 10.1, message: "Screen loaded") // Duplicate & rapid burst
        let msg3 = AccessibilityAnnouncementRecord(timestamp: 10.2, message: "") // Empty message
        let msg4 = AccessibilityAnnouncementRecord(timestamp: 11.5, message: "Review complete: 0 findings")

        let result = AnnouncementAnalyzer.analyze(announcements: [msg1, msg2, msg3, msg4], minimumIntervalSeconds: 0.5)

        #expect(!result.passed)
        #expect(result.totalAnnouncements == 4)
        #expect(result.defects.contains { $0.kind == .duplicateConsecutive })
        #expect(result.defects.contains { $0.kind == .emptyMessage })
        #expect(result.throttledAnnouncements.count == 2)
        #expect(result.throttledAnnouncements[0].message == "Screen loaded")
        #expect(result.throttledAnnouncements[1].message == "Review complete: 0 findings")
    }

    @Test("TargetedVerifier categorizes resolved vs introduced findings and computes score deltas")
    func testTargetedVerifier() {
        let issueOld = ViewLensIssue(
            kind: .tappableTargetTooSmall,
            severity: .error,
            description: "Button height 28pt is smaller than 44pt minimum",
            identifier: "btn_login"
        )
        let issueRemaining = ViewLensIssue(
            kind: .contrastRisk,
            severity: .warning,
            description: "Contrast ratio 3.2:1 is below 4.5:1",
            identifier: "subtitle"
        )
        let issueIntroduced = ViewLensIssue(
            kind: .clippedElement,
            severity: .error,
            description: "Label clipped by bottom edge",
            identifier: "footer"
        )

        let beforeReport = AuditReport(
            sourceMode: .rendered,
            elements: [],
            issues: [issueOld, issueRemaining]
        )

        let afterReportResolved = AuditReport(
            sourceMode: .rendered,
            elements: [],
            issues: [issueRemaining]
        )

        let resultResolved = TargetedVerifier.verify(
            componentName: "LoginForm",
            beforeReport: beforeReport,
            afterReport: afterReportResolved
        )

        #expect(resultResolved.status == .partiallyResolved)
        #expect(resultResolved.resolvedIssues.count == 1)
        #expect(resultResolved.remainingIssues.count == 1)
        #expect(resultResolved.introducedIssues.isEmpty)
        #expect(resultResolved.scoreAfter > resultResolved.scoreBefore)

        let speech = resultResolved.formattedSummary(profile: .speech)
        #expect(speech.contains("1 issue(s) resolved"))

        let afterReportRegressed = AuditReport(
            sourceMode: .rendered,
            elements: [],
            issues: [issueOld, issueRemaining, issueIntroduced]
        )

        let resultRegressed = TargetedVerifier.verify(
            componentName: "LoginForm",
            beforeReport: beforeReport,
            afterReport: afterReportRegressed
        )

        #expect(resultRegressed.status == .regressed)
        #expect(resultRegressed.introducedIssues.count == 1)
        #expect(!resultRegressed.passed)
    }

    #if canImport(SwiftUI)
    @Test("AccessibilityMatrixRunner generates standard environmental variants")
    func testAccessibilityMatrixRunnerVariants() {
        let variants = AccessibilityMatrixRunner.standardVariants()
        #expect(variants.count >= 4)
        #expect(variants.contains { $0.dynamicTypeSize == .accessibility5 })
        #expect(variants.contains { $0.colorScheme == .dark })
        #expect(variants.contains { $0.increaseContrast })
        #expect(variants.contains { $0.isRightToLeft })

        let report = AccessibilityMatrixReport(
            componentName: "HeaderView",
            results: variants.map { AccessibilityMatrixVariantResult(variant: $0, issues: [], passed: true) }
        )
        #expect(report.allPassed)
        #expect(report.passingVariants == variants.count)
        #expect(report.formattedSpeech().contains("All accessibility variants passed"))
    }
    #endif
}
