import Foundation
import Testing
@testable import ViewLensKit

@Suite("Nonvisual Authoring Evidence Tests")
struct NonvisualScreenModelTests {
    @Test("Seeded fixture exposes visual-semantic, state, and order defects")
    func seededFixtureMismatches() throws {
        let fixture = try loadFixture()
        let mismatches = NonvisualAnalyzer.detectSemanticMismatches(
            elements: fixture.elements,
            navigationSequences: fixture.navigationSequences
        )
        let kinds = Set(mismatches.map(\.kind))

        #expect(kinds.contains(.missingVisualCounterpart))
        #expect(kinds.contains(.missingSemanticCounterpart))
        #expect(kinds.contains(.visibleLabelNameConflict))
        #expect(kinds.contains(.missingValueOrState))
        #expect(kinds.contains(.readingOrderDivergence))
        #expect(kinds.contains(.focusOrderDivergence))
    }

    @Test("Relational geometry is deterministic, bounded, and describes clipping")
    func deterministicRelationalGeometry() throws {
        let fixture = try loadFixture()
        let first = NonvisualAnalyzer.deriveSpatialRelationships(
            screenID: fixture.id,
            elements: fixture.elements,
            maximumPerElement: 8
        )
        let second = NonvisualAnalyzer.deriveSpatialRelationships(
            screenID: fixture.id,
            elements: fixture.elements,
            maximumPerElement: 8
        )

        #expect(first == second)
        #expect(first.count <= fixture.elements.count * 8)
        #expect(first.contains { $0.subjectID == NonvisualID("element:password") && $0.kind == .below && $0.objectID == NonvisualID("element:email") })
        #expect(first.contains { $0.subjectID == NonvisualID("element:clipped") && $0.kind == .partiallyOutside })
        #expect(first.allSatisfy { $0.evidence.kind == .derived })
    }

    @Test("Screenshot adapter preserves stable references and cannot assert semantics")
    func screenshotAdapterDoesNotInferSemantics() throws {
        let report = AuditReport(
            sourceMode: .screenshot,
            image: "/tmp/login.png",
            dimensions: AuditDimensions(width: 390, height: 844, scale: 3),
            elements: [
                DetectedElement(
                    type: "primaryButton",
                    confidence: 0.91,
                    boundingBox: BoundingBox(x: 0.1, y: 0.8, width: 0.8, height: 0.08)
                )
            ],
            issues: [
                ViewLensIssue(
                    kind: .tappableTargetTooSmall,
                    severity: .error,
                    description: "Target is too small.",
                    elementIndex: 0
                )
            ]
        )
        let elementID = NonvisualID("element:login-submit")
        let findingID = NonvisualID("finding:small-submit")
        let model = NonvisualScreenBuilder.fromAuditReport(
            report,
            screenID: NonvisualID("screen:login"),
            title: "Login",
            stableElementIDs: [0: elementID],
            stableFindingIDs: [0: findingID]
        )

        let element = try #require(model.elements.first)
        #expect(element.id == elementID)
        #expect(element.findingIDs == [findingID])
        #expect(element.visualEvidence.kind == .inferred)
        #expect(element.semanticEvidence.kind == .unavailable)
        #expect(model.mismatches.isEmpty)
        #expect(model.navigationSequences.first?.evidence.kind == .unavailable)
    }

    @Test("Nonvisual model round trips with scalar stable identifiers")
    func stableSerializationRoundTrip() throws {
        let fixture = try loadFixture()
        let data = try JSONEncoder().encode(fixture)
        let decoded = try JSONDecoder().decode(NonvisualScreenModel.self, from: data)

        #expect(decoded == fixture)
        let object = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
        #expect(object["id"] as? String == "screen:checkout")
    }

    @Test("Unavailable semantic evidence never creates a semantic failure")
    func unavailableSemanticsAreNotFailures() {
        let element = NonvisualElement(
            id: NonvisualID("element:detected-button"),
            type: "primaryButton",
            bounds: BoundingBox(x: 0.1, y: 0.8, width: 0.8, height: 0.08),
            isInteractive: true,
            requiresAction: true,
            visualEvidence: EvidenceProvenance(kind: .inferred, source: "fixture.detector", confidence: 0.8),
            semanticEvidence: .unavailable(
                source: "fixture.semantic_tree",
                detail: "Screenshot-only evidence."
            )
        )

        #expect(NonvisualAnalyzer.detectSemanticMismatches(elements: [element]).isEmpty)
    }

    private func loadFixture() throws -> NonvisualScreenModel {
        let root = try #require(Bundle.module.resourceURL)
        let url = root.appendingPathComponent("Fixtures/Nonvisual/problem-screen-evidence.json")
        return try JSONDecoder().decode(NonvisualScreenModel.self, from: Data(contentsOf: url))
    }
}
