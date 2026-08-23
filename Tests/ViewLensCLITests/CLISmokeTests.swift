import Testing
import Foundation
@testable import ViewLensKit

@Suite("CLI Formatter Smoke Tests")
struct CLISmokeTests {
    @Test("JSONFormatter encodes AuditReport cleanly")
    func testJSONFormatting() {
        let box = BoundingBox(x: 0.1, y: 0.2, width: 0.8, height: 0.05)
        let element = DetectedElement(type: "primaryButton", confidence: 0.95, boundingBox: box)
        let issue = ViewLensIssue(
            kind: .tappableTargetTooSmall,
            severity: .error,
            description: "Button height is 28pt, below HIG 44pt minimum."
        )

        let report = AuditReport(
            sourceMode: .screenshot,
            image: "test_screenshot.png",
            dimensions: AuditDimensions(width: 1179, height: 2556, scale: 3.0),
            elements: [element],
            issues: [issue]
        )

        #expect(!report.passed)
        #expect(report.summary.errorCount == 1)
        #expect(report.summary.totalElements == 1)

        let json = JSONFormatter.encode(report)
        #expect(json.contains("primaryButton"))
        #expect(json.contains("tappableTargetTooSmall"))
        #expect(json.contains("\"passed\" : false"))
    }
}
