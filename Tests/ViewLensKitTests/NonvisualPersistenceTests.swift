import Testing
import Foundation
import CoreGraphics
@testable import ViewLensKit

@Suite("Nonvisual Persistence & Stable-ID Tests (NV-1.2)")
struct NonvisualPersistenceTests {

    @Test("NonvisualScreenModel encodes and decodes deterministically preserving stable IDs")
    func testNonvisualScreenModelRoundTrip() throws {
        let screenID = NonvisualID("screen:login-001")
        let regionID = NonvisualID("screen:login-001:region:main")
        let el1ID = NonvisualID("screen:login-001:element:0000")
        let el2ID = NonvisualID("screen:login-001:element:0001")
        let finding1ID = NonvisualID("screen:login-001:finding:0000")

        let element1 = NonvisualElement(
            id: el1ID,
            visualIndex: 0,
            type: "primaryButton",
            visibleLabel: "Sign In",
            bounds: BoundingBox(x: 0.1, y: 0.8, width: 0.8, height: 0.05),
            regionID: regionID,
            findingIDs: [finding1ID],
            isInteractive: true,
            visualEvidence: EvidenceProvenance(kind: .measured, source: "test"),
            semanticEvidence: EvidenceProvenance(kind: .derived, source: "test")
        )

        let element2 = NonvisualElement(
            id: el2ID,
            visualIndex: 1,
            type: "textField",
            visibleLabel: "Username",
            bounds: BoundingBox(x: 0.1, y: 0.4, width: 0.8, height: 0.05),
            regionID: regionID,
            findingIDs: [],
            isInteractive: true,
            visualEvidence: EvidenceProvenance(kind: .measured, source: "test"),
            semanticEvidence: EvidenceProvenance(kind: .derived, source: "test")
        )

        let region = NonvisualRegion(
            id: regionID,
            label: "Login Card",
            role: "container",
            elementIDs: [el1ID, el2ID],
            evidence: EvidenceProvenance(kind: .derived, source: "test")
        )

        let model = NonvisualScreenModel(
            id: screenID,
            title: "Login Screen",
            sourceMode: .rendered,
            regions: [region],
            elements: [element1, element2]
        )

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(model)

        let decoder = JSONDecoder()
        let decoded = try decoder.decode(NonvisualScreenModel.self, from: data)

        #expect(decoded.id == screenID)
        #expect(decoded.title == "Login Screen")
        #expect(decoded.sourceMode == .rendered)
        #expect(decoded.regions.count == 1)
        #expect(decoded.regions[0].id == regionID)
        #expect(decoded.elements.count == 2)
        #expect(decoded.elements[0].id == el1ID)
        #expect(decoded.elements[0].findingIDs == [finding1ID])
        #expect(decoded.elements[1].id == el2ID)
    }

    @Test("NonvisualScreenBuilder assigns stable element and finding cross-references")
    func testNonvisualScreenBuilderStableCrossReferences() {
        let report = AuditReport(
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

        let screenID = NonvisualID("screen:test-review-01")
        let nonvisual = NonvisualScreenBuilder.fromAuditReport(report, screenID: screenID, title: "Login Form")

        #expect(nonvisual.elements.count == 2)
        #expect(nonvisual.elements[0].id.rawValue == "screen:test-review-01:element:0000")
        #expect(nonvisual.elements[0].findingIDs.count == 1)
        #expect(nonvisual.elements[0].findingIDs[0].rawValue == "screen:test-review-01:finding:0000")
        #expect(nonvisual.elements[1].id.rawValue == "screen:test-review-01:element:0001")
        #expect(nonvisual.elements[1].findingIDs.isEmpty)
    }
}
