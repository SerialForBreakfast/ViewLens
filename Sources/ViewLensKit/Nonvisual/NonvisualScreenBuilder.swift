import Foundation

/// Adapts existing ViewLens audit evidence into the shared nonvisual contract.
public enum NonvisualScreenBuilder {
    public static func fromAuditReport(
        _ report: AuditReport,
        screenID: NonvisualID,
        title: String? = nil,
        stableElementIDs: [Int: NonvisualID] = [:],
        stableFindingIDs: [Int: NonvisualID] = [:]
    ) -> NonvisualScreenModel {
        let elements: [NonvisualElement] = report.elements.enumerated().map { index, detected in
            let elementID = stableElementIDs[index]
                ?? NonvisualID("\(screenID.rawValue):element:\(String(format: "%04d", index))")
            let findingIDs: [NonvisualID] = report.issues.enumerated().compactMap { issueIndex, issue in
                guard issue.elementIndex == index else { return nil }
                return stableFindingIDs[issueIndex]
                    ?? NonvisualID("\(screenID.rawValue):finding:\(String(format: "%04d", issueIndex))")
            }
            return NonvisualElement(
                id: elementID,
                visualIndex: index,
                type: detected.type,
                bounds: detected.boundingBox,
                regionID: NonvisualID("\(screenID.rawValue):region:screen"),
                findingIDs: findingIDs,
                isInteractive: WCAGRules.interactiveTypes.contains(detected.type),
                requiresValueOrState: detected.type == "toggle",
                requiresAction: WCAGRules.interactiveTypes.contains(detected.type),
                visualEvidence: EvidenceProvenance(
                    kind: .inferred,
                    source: "viewlens.visual_detector",
                    confidence: Double(detected.confidence),
                    detail: "Element type and bounds were inferred from rendered pixels."
                ),
                semanticEvidence: .unavailable(
                    source: "viewlens.accessibility_hierarchy",
                    detail: report.sourceMode == .screenshot
                        ? "A screenshot does not contain programmatic accessibility semantics."
                        : "No registered or runtime accessibility hierarchy was supplied for this audit."
                )
            )
        }
        let regionID = NonvisualID("\(screenID.rawValue):region:screen")
        let regions = [NonvisualRegion(
            id: regionID,
            label: title ?? "Screen",
            role: "screen",
            bounds: BoundingBox(x: 0, y: 0, width: 1, height: 1),
            elementIDs: elements.map(\.id),
            evidence: EvidenceProvenance(kind: .derived, source: "viewlens.audit_report")
        )]
        let navigation = [NavigationSequence(
            id: NonvisualID("\(screenID.rawValue):navigation:predicted_voiceover"),
            kind: .predictedVoiceOver,
            elementIDs: [],
            evidence: .unavailable(
                source: "viewlens.accessibility_hierarchy",
                detail: "VoiceOver traversal cannot be determined from visual detections."
            )
        )]
        let relationships = NonvisualAnalyzer.deriveSpatialRelationships(
            screenID: screenID,
            elements: elements
        )

        return NonvisualScreenModel(
            id: screenID,
            title: title,
            sourceMode: report.sourceMode == .screenshot ? .screenshot : .rendered,
            regions: regions,
            elements: elements,
            relationships: relationships,
            navigationSequences: navigation,
            mismatches: NonvisualAnalyzer.detectSemanticMismatches(
                elements: elements,
                navigationSequences: navigation
            )
        )
    }
}
