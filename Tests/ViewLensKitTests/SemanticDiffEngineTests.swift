import Testing
import Foundation
@testable import ViewLensKit

@Suite("Semantic Diff & Source Context Remediation Tests (NV-5)")
struct SemanticDiffEngineTests {

    @Test("SemanticDiffEngine detects additions, deletions, label shifts, and resolved findings")
    func testSemanticDiffEngine() {
        let screenID = NonvisualID("screen:settings")
        let regionID = NonvisualID("region:main")

        let region = NonvisualRegion(
            id: regionID,
            label: "Preferences",
            role: "content",
            elementIDs: [NonvisualID("el:toggle"), NonvisualID("el:btn_delete")]
        )

        // Before screen: Has unlabeled delete button that generated a mismatch
        let beforeToggle = NonvisualElement(
            id: NonvisualID("el:toggle"),
            type: "toggle",
            visibleLabel: "Dark Mode",
            regionID: regionID,
            semantics: NonvisualSemantics(accessibleName: "Dark Mode", role: "toggle", value: "On"),
            isInteractive: true
        )
        let beforeDelete = NonvisualElement(
            id: NonvisualID("el:btn_delete"),
            type: "button",
            visibleLabel: nil, // missing label!
            regionID: regionID,
            semantics: NonvisualSemantics(accessibleName: nil, role: "button"),
            isInteractive: true
        )
        let beforeMismatch = SemanticMismatch(
            id: NonvisualID("mismatch:missing_accessible_name:el:btn_delete"),
            kind: .missingAccessibleName,
            severity: .error,
            elementIDs: [NonvisualID("el:btn_delete")],
            description: "Button missing accessible name",
            evidence: EvidenceProvenance(kind: .derived, source: "test")
        )

        let beforeModel = NonvisualScreenModel(
            id: screenID,
            title: "Settings",
            sourceMode: .rendered,
            regions: [region],
            elements: [beforeToggle, beforeDelete],
            mismatches: [beforeMismatch]
        )

        // After screen: Added label to delete button and added a new help link
        let afterToggle = NonvisualElement(
            id: NonvisualID("el:toggle"),
            type: "toggle",
            visibleLabel: "Dark Mode",
            regionID: regionID,
            semantics: NonvisualSemantics(accessibleName: "Dark Mode", role: "toggle", value: "Off"), // value changed
            isInteractive: true
        )
        let afterDelete = NonvisualElement(
            id: NonvisualID("el:btn_delete"),
            type: "button",
            visibleLabel: "Delete Account",
            regionID: regionID,
            semantics: NonvisualSemantics(accessibleName: "Delete Account", role: "button"),
            isInteractive: true
        )
        let afterHelp = NonvisualElement(
            id: NonvisualID("el:link_help"),
            type: "link",
            visibleLabel: "Help & Support",
            regionID: regionID,
            semantics: NonvisualSemantics(accessibleName: "Help & Support", role: "link"),
            isInteractive: true
        )

        let afterModel = NonvisualScreenModel(
            id: screenID,
            title: "Settings",
            sourceMode: .rendered,
            regions: [region],
            elements: [afterToggle, afterDelete, afterHelp],
            mismatches: [] // issue resolved!
        )

        let diff = SemanticDiffEngine.diff(before: beforeModel, after: afterModel)

        #expect(diff.resolvedFindings.count == 1)
        #expect(diff.introducedFindings.isEmpty)
        #expect(diff.passed)

        #expect(diff.changes.contains { $0.kind == .addedElement && $0.elementID == NonvisualID("el:link_help") })
        #expect(diff.changes.contains { $0.kind == .labelModified && $0.elementID == NonvisualID("el:btn_delete") })
        #expect(diff.changes.contains { $0.kind == .valueModified && $0.elementID == NonvisualID("el:toggle") })

        let speechSummary = diff.formattedSummary(profile: .speech)
        #expect(speechSummary.contains("1 accessibility issue resolved"))
        #expect(speechSummary.contains("No blocking accessibility regressions"))
    }
}
