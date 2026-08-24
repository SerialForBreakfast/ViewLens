import Foundation

/// Deterministic spatial and semantic analysis for the shared nonvisual screen model.
public enum NonvisualAnalyzer {
    public static func deriveSpatialRelationships(
        screenID: NonvisualID,
        elements: [NonvisualElement],
        alignmentTolerance: Double = 0.03,
        maximumPerElement: Int = 10
    ) -> [SpatialRelationship] {
        let candidates = elements.filter { $0.bounds != nil }.sorted { $0.id < $1.id }
        var output: [SpatialRelationship] = []

        for subject in candidates {
            guard let subjectBounds = subject.bounds else { continue }
            var relationships: [SpatialRelationship] = []

            if isOutside(subjectBounds) {
                relationships.append(makeRelationship(
                    subject: subject,
                    kind: .outside,
                    objectID: screenID,
                    description: "\(displayName(subject)) is outside the screen bounds."
                ))
            } else if isPartiallyOutside(subjectBounds) {
                relationships.append(makeRelationship(
                    subject: subject,
                    kind: .partiallyOutside,
                    objectID: screenID,
                    description: "\(displayName(subject)) is partially outside the screen bounds."
                ))
            }

            let others = candidates.filter { $0.id != subject.id }
            if let nearest = nearestVertical(subjectBounds, others: others, direction: .above) {
                relationships.append(makeRelationship(
                    subject: subject,
                    kind: .below,
                    object: nearest.element,
                    distance: nearest.distance
                ))
            }
            if let nearest = nearestVertical(subjectBounds, others: others, direction: .below) {
                relationships.append(makeRelationship(
                    subject: subject,
                    kind: .above,
                    object: nearest.element,
                    distance: nearest.distance
                ))
            }
            if let nearest = nearestHorizontal(subjectBounds, others: others, direction: .leading) {
                relationships.append(makeRelationship(
                    subject: subject,
                    kind: .trailing,
                    object: nearest.element,
                    distance: nearest.distance
                ))
            }
            if let nearest = nearestHorizontal(subjectBounds, others: others, direction: .trailing) {
                relationships.append(makeRelationship(
                    subject: subject,
                    kind: .leading,
                    object: nearest.element,
                    distance: nearest.distance
                ))
            }

            for other in others {
                guard let otherBounds = other.bounds else { continue }
                if contains(subjectBounds, otherBounds) {
                    relationships.append(makeRelationship(subject: subject, kind: .contains, object: other))
                } else if contains(otherBounds, subjectBounds) {
                    relationships.append(makeRelationship(subject: subject, kind: .containedBy, object: other))
                } else if subjectBounds.iou(with: otherBounds) > 0 {
                    relationships.append(makeRelationship(subject: subject, kind: .overlaps, object: other))
                }
            }

            if let aligned = others
                .compactMap({ element -> (NonvisualElement, Double)? in
                    guard let bounds = element.bounds else { return nil }
                    let delta = abs(subjectBounds.midY - bounds.midY)
                    return delta <= alignmentTolerance ? (element, delta) : nil
                })
                .sorted(by: candidateSort)
                .first {
                relationships.append(makeRelationship(
                    subject: subject,
                    kind: .alignedHorizontally,
                    object: aligned.0,
                    distance: aligned.1
                ))
            }

            if let aligned = others
                .compactMap({ element -> (NonvisualElement, Double)? in
                    guard let bounds = element.bounds else { return nil }
                    let delta = abs(subjectBounds.midX - bounds.midX)
                    return delta <= alignmentTolerance ? (element, delta) : nil
                })
                .sorted(by: candidateSort)
                .first {
                relationships.append(makeRelationship(
                    subject: subject,
                    kind: .alignedVertically,
                    object: aligned.0,
                    distance: aligned.1
                ))
            }

            let unique = Dictionary(grouping: relationships, by: \.id).compactMap { $0.value.first }
            output.append(contentsOf: unique.sorted { $0.id < $1.id }.prefix(max(1, maximumPerElement)))
        }
        return output.sorted { $0.id < $1.id }
    }

    public static func detectSemanticMismatches(
        elements: [NonvisualElement],
        navigationSequences: [NavigationSequence] = []
    ) -> [SemanticMismatch] {
        var mismatches: [SemanticMismatch] = []

        for element in elements.sorted(by: { $0.id < $1.id }) {
            let visualIsKnown = element.visualEvidence.kind == .measured
            let semanticsAreKnown = element.semanticEvidence.kind == .measured
            let hasVisual = element.bounds != nil
            let hasSemantics = element.semantics != nil

            if visualIsKnown, !hasVisual, hasSemantics {
                mismatches.append(mismatch(
                    .missingVisualCounterpart,
                    element: element,
                    description: "\(displayName(element)) is exposed semantically but has no measured visual counterpart."
                ))
            }
            if semanticsAreKnown, hasVisual, !hasSemantics {
                mismatches.append(mismatch(
                    .missingSemanticCounterpart,
                    element: element,
                    description: "\(displayName(element)) is visually present but absent from the measured accessibility hierarchy."
                ))
                continue
            }
            guard semanticsAreKnown, let semantics = element.semantics else { continue }

            if element.isInteractive, isBlank(semantics.accessibleName) {
                mismatches.append(mismatch(
                    .missingAccessibleName,
                    element: element,
                    description: "\(displayName(element)) has no programmatically determinable accessible name."
                ))
            }
            if element.isInteractive, isBlank(semantics.role) {
                mismatches.append(mismatch(
                    .missingRole,
                    element: element,
                    description: "\(displayName(element)) has no programmatically determinable role."
                ))
            }
            if element.requiresValueOrState, isBlank(semantics.value), semantics.states.isEmpty {
                mismatches.append(mismatch(
                    .missingValueOrState,
                    element: element,
                    description: "\(displayName(element)) does not expose its current value or state."
                ))
            }
            if element.requiresAction, semantics.actions.isEmpty {
                mismatches.append(mismatch(
                    .missingAction,
                    element: element,
                    description: "\(displayName(element)) does not expose a supported accessibility action."
                ))
            }
            if let visible = normalized(element.visibleLabel),
               let accessible = normalized(semantics.accessibleName),
               visible != accessible {
                mismatches.append(mismatch(
                    .visibleLabelNameConflict,
                    element: element,
                    description: "Visible label ‘\(element.visibleLabel ?? "")’ differs from accessible name ‘\(semantics.accessibleName ?? "")’."
                ))
            }
        }

        let duplicateGroups = Dictionary(grouping: elements.compactMap { element -> (String, NonvisualElement)? in
            guard element.semanticEvidence.kind == .measured,
                  let identifier = normalized(element.semantics?.runtimeIdentifier) else { return nil }
            return (identifier, element)
        }, by: { $0.0 })
        for (identifier, duplicates) in duplicateGroups where duplicates.count > 1 {
            let ids = duplicates.map { $0.1.id }.sorted()
            mismatches.append(SemanticMismatch(
                id: NonvisualID("mismatch:duplicate_exposure:\(identifier)"),
                kind: .duplicateExposure,
                severity: .error,
                elementIDs: ids,
                description: "Accessibility identifier ‘\(identifier)’ is exposed by \(ids.count) elements.",
                evidence: derivedSemanticEvidence
            ))
        }

        if let reading = knownSequence(.readingOrder, in: navigationSequences),
           let voiceOver = knownSequence(.predictedVoiceOver, in: navigationSequences),
           sharedOrder(reading.elementIDs, voiceOver.elementIDs) != sharedOrder(voiceOver.elementIDs, reading.elementIDs) {
            let ids = Array(Set(reading.elementIDs).intersection(voiceOver.elementIDs)).sorted()
            mismatches.append(SemanticMismatch(
                id: NonvisualID("mismatch:reading_order_divergence"),
                kind: .readingOrderDivergence,
                severity: .error,
                elementIDs: ids,
                description: "Measured reading order differs from the predicted VoiceOver traversal order.",
                evidence: derivedSemanticEvidence
            ))
        }

        if let reading = knownSequence(.readingOrder, in: navigationSequences),
           let focus = knownSequence(.keyboardFocus, in: navigationSequences),
           sharedOrder(reading.elementIDs, focus.elementIDs) != sharedOrder(focus.elementIDs, reading.elementIDs) {
            let ids = Array(Set(reading.elementIDs).intersection(focus.elementIDs)).sorted()
            mismatches.append(SemanticMismatch(
                id: NonvisualID("mismatch:focus_order_divergence"),
                kind: .focusOrderDivergence,
                severity: .warning,
                elementIDs: ids,
                description: "Measured reading order differs from keyboard focus order.",
                evidence: derivedSemanticEvidence
            ))
        }

        return mismatches.sorted { $0.id < $1.id }
    }

    private enum VerticalDirection { case above, below }
    private enum HorizontalDirection { case leading, trailing }

    private static let derivedGeometryEvidence = EvidenceProvenance(
        kind: .derived,
        source: "viewlens.relational_geometry"
    )
    private static let derivedSemanticEvidence = EvidenceProvenance(
        kind: .derived,
        source: "viewlens.semantic_mismatch"
    )

    private static func nearestVertical(
        _ subject: BoundingBox,
        others: [NonvisualElement],
        direction: VerticalDirection
    ) -> (element: NonvisualElement, distance: Double)? {
        others.compactMap { element in
            guard let bounds = element.bounds else { return nil }
            let overlapsHorizontally = min(subject.maxX, bounds.maxX) > max(subject.minX, bounds.minX)
            guard overlapsHorizontally else { return nil }
            switch direction {
            case .above where bounds.maxY <= subject.minY:
                return (element, subject.minY - bounds.maxY)
            case .below where bounds.minY >= subject.maxY:
                return (element, bounds.minY - subject.maxY)
            default:
                return nil
            }
        }.sorted(by: candidateSort).first
    }

    private static func nearestHorizontal(
        _ subject: BoundingBox,
        others: [NonvisualElement],
        direction: HorizontalDirection
    ) -> (element: NonvisualElement, distance: Double)? {
        others.compactMap { element in
            guard let bounds = element.bounds else { return nil }
            let overlapsVertically = min(subject.maxY, bounds.maxY) > max(subject.minY, bounds.minY)
            guard overlapsVertically else { return nil }
            switch direction {
            case .leading where bounds.maxX <= subject.minX:
                return (element, subject.minX - bounds.maxX)
            case .trailing where bounds.minX >= subject.maxX:
                return (element, bounds.minX - subject.maxX)
            default:
                return nil
            }
        }.sorted(by: candidateSort).first
    }

    private static func candidateSort(
        _ lhs: (NonvisualElement, Double),
        _ rhs: (NonvisualElement, Double)
    ) -> Bool {
        lhs.1 == rhs.1 ? lhs.0.id < rhs.0.id : lhs.1 < rhs.1
    }

    private static func contains(_ outer: BoundingBox, _ inner: BoundingBox) -> Bool {
        outer.minX <= inner.minX && outer.minY <= inner.minY &&
            outer.maxX >= inner.maxX && outer.maxY >= inner.maxY
    }

    private static func isOutside(_ bounds: BoundingBox) -> Bool {
        bounds.maxX <= 0 || bounds.maxY <= 0 || bounds.minX >= 1 || bounds.minY >= 1
    }

    private static func isPartiallyOutside(_ bounds: BoundingBox) -> Bool {
        bounds.minX < 0 || bounds.minY < 0 || bounds.maxX > 1 || bounds.maxY > 1
    }

    private static func makeRelationship(
        subject: NonvisualElement,
        kind: SpatialRelationshipKind,
        object: NonvisualElement,
        distance: Double? = nil
    ) -> SpatialRelationship {
        makeRelationship(
            subject: subject,
            kind: kind,
            objectID: object.id,
            distance: distance,
            description: "\(displayName(subject)) is \(relationshipPhrase(kind)) \(displayName(object))."
        )
    }

    private static func makeRelationship(
        subject: NonvisualElement,
        kind: SpatialRelationshipKind,
        objectID: NonvisualID,
        distance: Double? = nil,
        description: String
    ) -> SpatialRelationship {
        SpatialRelationship(
            id: NonvisualID("relationship:\(subject.id.rawValue):\(kind.rawValue):\(objectID.rawValue)"),
            subjectID: subject.id,
            kind: kind,
            objectID: objectID,
            distance: distance,
            description: description,
            evidence: derivedGeometryEvidence
        )
    }

    private static func relationshipPhrase(_ kind: SpatialRelationshipKind) -> String {
        switch kind {
        case .above: "above"
        case .below: "below"
        case .leading: "leading of"
        case .trailing: "trailing of"
        case .alignedHorizontally: "horizontally aligned with"
        case .alignedVertically: "vertically aligned with"
        case .contains: "containing"
        case .containedBy: "contained by"
        case .overlaps: "overlapping"
        case .partiallyOutside: "partially outside"
        case .outside: "outside"
        }
    }

    private static func mismatch(
        _ kind: SemanticMismatchKind,
        element: NonvisualElement,
        description: String
    ) -> SemanticMismatch {
        SemanticMismatch(
            id: NonvisualID("mismatch:\(kind.rawValue):\(element.id.rawValue)"),
            kind: kind,
            severity: .error,
            elementIDs: [element.id],
            description: description,
            evidence: derivedSemanticEvidence
        )
    }

    private static func displayName(_ element: NonvisualElement) -> String {
        normalized(element.semantics?.accessibleName)
            ?? normalized(element.visibleLabel)
            ?? element.type
    }

    private static func normalized(_ value: String?) -> String? {
        guard let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines),
              !trimmed.isEmpty else { return nil }
        return trimmed.folding(
            options: [.caseInsensitive, .diacriticInsensitive],
            locale: Locale(identifier: "en_US_POSIX")
        )
    }

    private static func isBlank(_ value: String?) -> Bool { normalized(value) == nil }

    private static func knownSequence(
        _ kind: NavigationSequenceKind,
        in sequences: [NavigationSequence]
    ) -> NavigationSequence? {
        sequences.first { $0.kind == kind && $0.evidence.kind != .unavailable }
    }

    private static func sharedOrder(_ primary: [NonvisualID], _ comparison: [NonvisualID]) -> [NonvisualID] {
        let comparisonSet = Set(comparison)
        return primary.filter(comparisonSet.contains)
    }
}
