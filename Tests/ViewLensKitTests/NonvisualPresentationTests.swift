import Foundation
import Testing
@testable import ViewLensKit

@Suite("Nonvisual Presentation and Schema Tests")
struct NonvisualPresentationTests {
    @Test("Summary is deterministic, bounded, actionable, and fully attributed")
    func summaryContract() throws {
        let model = try analyzedFixture()
        let first = NonvisualSummaryComposer.compose(model, maximumBlockingFindings: 3)
        let second = NonvisualSummaryComposer.compose(model, maximumBlockingFindings: 3)

        #expect(first == second)
        #expect(first.regionCount == 1)
        #expect(first.elementCount == 7)
        #expect(first.interactiveElementCount == 6)
        #expect(first.blockingFindingIDs.count == 3)
        #expect(first.recommendedTargetID == NonvisualID("element:pay"))
        #expect(first.completeness == NonvisualEvidenceCompleteness(
            visual: .complete,
            semantics: .complete,
            navigation: .complete
        ))
        #expect(first.statements.allSatisfy { !$0.evidence.source.isEmpty })
        #expect(first.statements.filter { $0.evidence.kind == .inferred }.allSatisfy { $0.evidence.confidence != nil })
    }

    @Test("Speech and braille presentations match stable narratives")
    func goldenNarratives() throws {
        let summary = NonvisualSummaryComposer.compose(try analyzedFixture())
        let speechGolden = try golden("speech-summary.txt")
        let brailleGolden = try golden("braille-summary.txt")
        let developerGolden = try golden("developer-summary.txt")
        #expect(NonvisualPresentationRenderer.render(summary, profile: .speech) == speechGolden)
        #expect(NonvisualPresentationRenderer.render(summary, profile: .braille) == brailleGolden)
        #expect(NonvisualPresentationRenderer.render(summary, profile: .developer) == developerGolden)
    }

    @Test("Developer detail exposes provenance and expansion remains bounded")
    func developerAndExpansion() throws {
        let model = try analyzedFixture()
        let summary = NonvisualSummaryComposer.compose(model)
        let developer = NonvisualPresentationRenderer.render(summary, profile: .developer, maximumStatements: 2)
        let lines = developer.split(separator: "\n")
        #expect(lines.count == 2)
        #expect(developer.contains("evidence="))
        #expect(developer.contains("related="))

        let expansion = try #require(NonvisualPresentationRenderer.renderElement(
            NonvisualID("element:password"),
            in: model,
            profile: .speech,
            maximumRelationships: 2
        ))
        #expect(expansion.contains("Secret code"))
        #expect(expansion.components(separatedBy: ". ").count <= 4)
    }

    @Test("Screenshot summary reports unavailable semantics without claiming a pass")
    func unavailableEvidenceNarrative() {
        let report = AuditReport(
            sourceMode: .screenshot,
            image: "/tmp/screen.png",
            dimensions: AuditDimensions(width: 390, height: 844, scale: 3),
            elements: [DetectedElement(
                type: "primaryButton",
                confidence: 0.9,
                boundingBox: BoundingBox(x: 0.1, y: 0.8, width: 0.8, height: 0.08)
            )],
            issues: []
        )
        let model = NonvisualScreenBuilder.fromAuditReport(
            report,
            screenID: NonvisualID("screen:screenshot"),
            title: "Screenshot"
        )
        let rendered = NonvisualPresentationRenderer.render(
            NonvisualSummaryComposer.compose(model),
            profile: .speech
        ).lowercased()

        #expect(rendered.contains("semantics unavailable"))
        #expect(!rendered.contains("semantics passed"))
        #expect(!rendered.contains("no accessibility issues"))
    }

    @Test("Validator identifies malformed evidence, duplicates, and unresolved references")
    func malformedValidation() throws {
        let fixture = try loadFixture()
        let malformedElement = NonvisualElement(
            id: fixture.elements[0].id,
            type: "button",
            regionID: NonvisualID("region:missing"),
            visualEvidence: EvidenceProvenance(kind: .inferred, source: ""),
            semanticEvidence: .unavailable(source: "fixture", detail: "Missing")
        )
        let malformed = NonvisualScreenModel(
            id: fixture.id,
            sourceMode: .runtime,
            regions: fixture.regions,
            elements: fixture.elements + [malformedElement]
        )
        let codes = Set(NonvisualModelValidator.validate(malformed).map(\.code))

        #expect(codes.contains(.duplicateIdentifier))
        #expect(codes.contains(.unresolvedReference))
        #expect(codes.contains(.invalidEvidence))
    }

    @Test("Preview schema migrates and unknown schema versions fail explicitly")
    func schemaMigration() throws {
        let data = try fixtureData()
        var object = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
        object["elements"] = Array(try #require(object["elements"] as? [[String: Any]]).reversed())
        object["schemaVersion"] = "0.9"
        let preview = try JSONSerialization.data(withJSONObject: object)
        let migrated = try NonvisualSchemaMigrator.decodeAndMigrate(preview)
        #expect(migrated.schemaVersion == NonvisualScreenModel.currentSchemaVersion)
        #expect(migrated.elements.map(\.id) == migrated.elements.map(\.id).sorted())

        object["schemaVersion"] = "99"
        let unknown = try JSONSerialization.data(withJSONObject: object)
        #expect(throws: NonvisualSchemaError.unsupportedSchemaVersion("99")) {
            try NonvisualSchemaMigrator.decodeAndMigrate(unknown)
        }
    }

    private func analyzedFixture() throws -> NonvisualScreenModel {
        let fixture = try loadFixture()
        return NonvisualScreenModel(
            id: fixture.id,
            title: fixture.title,
            sourceMode: fixture.sourceMode,
            regions: fixture.regions,
            elements: fixture.elements,
            relationships: NonvisualAnalyzer.deriveSpatialRelationships(
                screenID: fixture.id,
                elements: fixture.elements
            ),
            navigationSequences: fixture.navigationSequences,
            mismatches: NonvisualAnalyzer.detectSemanticMismatches(
                elements: fixture.elements,
                navigationSequences: fixture.navigationSequences
            )
        )
    }

    private func loadFixture() throws -> NonvisualScreenModel {
        try JSONDecoder().decode(NonvisualScreenModel.self, from: fixtureData())
    }

    private func fixtureData() throws -> Data {
        let root = try #require(Bundle.module.resourceURL)
        let url = root.appendingPathComponent("Fixtures/Nonvisual/problem-screen-evidence.json")
        return try Data(contentsOf: url)
    }

    private func golden(_ name: String) throws -> String {
        let root = try #require(Bundle.module.resourceURL)
        let url = root.appendingPathComponent("Fixtures/Nonvisual/\(name)")
        return try String(contentsOf: url, encoding: .utf8).trimmingCharacters(in: .newlines)
    }
}
