import Testing
import Foundation
@testable import ViewLensKit

@Suite("Nonvisual MCP Resources Tests (NV-1.2 / NV-3.1)")
struct NonvisualMCPResourceTests {

    @Test("MCPResourceStore serves nonvisual-summary and semantic-outline resources")
    func testNonvisualResourceReads() async throws {
        let store = MCPResourceStore()
        let reviewID = "rev-nonvis-test-01"

        let auditReport = AuditReport(
            sourceMode: .rendered,
            target: "LoginForm",
            elements: [
                DetectedElement(type: "primaryButton", confidence: 0.95, boundingBox: BoundingBox(x: 0.1, y: 0.8, width: 0.8, height: 0.05)),
                DetectedElement(type: "textField", confidence: 0.92, boundingBox: BoundingBox(x: 0.1, y: 0.4, width: 0.8, height: 0.05))
            ],
            issues: [
                ViewLensIssue(
                    kind: .tappableTargetTooSmall,
                    severity: .error,
                    description: "Target too small",
                    elementIndex: 0,
                    wcagCriterion: "2.5.5",
                    wcagLevel: "AAA"
                )
            ]
        )

        let reportData = try JSONDecoder().decode(JSONValue.self, from: JSONEncoder().encode(auditReport))

        let envelope = MCPEvidenceEnvelope(
            reviewID: reviewID,
            sourceMode: "rendered",
            target: .init(type: "template", identifier: "LoginForm"),
            completeness: .init(status: .complete, evaluated: ["2.5.5"]),
            findings: [.object(["type": .string("primaryButton"), "id": .string("finding-001")])],
            artifacts: [],
            durationMs: 12,
            warnings: [],
            recoveryActions: [],
            data: reportData
        )

        await store.record(envelope)

        // 1. Read nonvisual-summary
        let summaryContent = try await store.read(uri: "viewlens://reviews/\(reviewID)/nonvisual-summary")
        #expect(summaryContent.mimeType == "application/json")
        #expect(summaryContent.text != nil)
        #expect(summaryContent.text?.contains("screen:\(reviewID)") == true)

        // 2. Read semantic-outline
        let outlineContent = try await store.read(uri: "viewlens://reviews/\(reviewID)/semantic-outline")
        #expect(outlineContent.mimeType == "application/json")
        #expect(outlineContent.text != nil)
        #expect(outlineContent.text?.contains("primaryButton") == true)

        // 3. Read navigation
        let navContent = try await store.read(uri: "viewlens://reviews/\(reviewID)/navigation")
        #expect(navContent.mimeType == "application/json")

        // 4. Read visual-diff-narrative
        let narrativeContent = try await store.read(uri: "viewlens://reviews/\(reviewID)/visual-diff-narrative")
        #expect(narrativeContent.mimeType == "text/plain")
        #expect(narrativeContent.text != nil)
    }

    @Test("MCPResourceStore lists nonvisual resource templates")
    func testNonvisualTemplates() {
        let templates = MCPResourceStore.templates
        let uriTemplates = templates.map(\.uriTemplate)

        #expect(uriTemplates.contains("viewlens://reviews/{reviewId}/nonvisual-summary"))
        #expect(uriTemplates.contains("viewlens://reviews/{reviewId}/semantic-outline"))
        #expect(uriTemplates.contains("viewlens://reviews/{reviewId}/navigation"))
        #expect(uriTemplates.contains("viewlens://reviews/{reviewId}/visual-diff-narrative"))
    }
}
