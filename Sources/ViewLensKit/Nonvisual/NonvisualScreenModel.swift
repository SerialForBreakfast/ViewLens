import Foundation

/// A stable, opaque identifier shared by nonvisual regions, elements, findings,
/// navigation sequences, relationships, and future source-provenance records.
public struct NonvisualID: Codable, Sendable, Equatable, Hashable, Comparable, CustomStringConvertible {
    public let rawValue: String

    public init(_ rawValue: String) {
        self.rawValue = rawValue
    }

    public var description: String { rawValue }

    public static func < (lhs: Self, rhs: Self) -> Bool {
        lhs.rawValue < rhs.rawValue
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        rawValue = try container.decode(String.self)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }
}

public enum EvidenceProvenanceKind: String, Codable, Sendable, Equatable, Hashable, CaseIterable {
    /// Directly observed from pixels, a registered semantic snapshot, or a platform API.
    case measured
    /// Deterministically calculated from measured evidence.
    case derived
    /// Model-produced evidence that must retain confidence and must not become a semantic pass.
    case inferred
    /// The requested evidence could not be obtained.
    case unavailable
}

public struct EvidenceProvenance: Codable, Sendable, Equatable, Hashable {
    public let kind: EvidenceProvenanceKind
    public let source: String
    public let confidence: Double?
    public let detail: String?

    public init(
        kind: EvidenceProvenanceKind,
        source: String,
        confidence: Double? = nil,
        detail: String? = nil
    ) {
        self.kind = kind
        self.source = source
        self.confidence = confidence.map { min(max($0, 0), 1) }
        self.detail = detail
    }

    public static func unavailable(source: String, detail: String) -> Self {
        Self(kind: .unavailable, source: source, detail: detail)
    }
}

public enum NonvisualSourceMode: String, Codable, Sendable, Equatable, Hashable {
    case screenshot
    case rendered
    case runtime
    case importedReport = "imported_report"
}

public struct NonvisualSemantics: Codable, Sendable, Equatable, Hashable {
    public let runtimeIdentifier: String?
    public let accessibleName: String?
    public let role: String?
    public let value: String?
    public let states: [String]
    public let actions: [String]
    public let hint: String?
    public let isHeading: Bool

    public init(
        runtimeIdentifier: String? = nil,
        accessibleName: String? = nil,
        role: String? = nil,
        value: String? = nil,
        states: [String] = [],
        actions: [String] = [],
        hint: String? = nil,
        isHeading: Bool = false
    ) {
        self.runtimeIdentifier = runtimeIdentifier
        self.accessibleName = accessibleName
        self.role = role
        self.value = value
        self.states = states.sorted()
        self.actions = actions.sorted()
        self.hint = hint
        self.isHeading = isHeading
    }
}

public struct NonvisualRegion: Codable, Sendable, Equatable, Hashable {
    public let id: NonvisualID
    public let label: String
    public let role: String?
    public let bounds: BoundingBox?
    public let elementIDs: [NonvisualID]
    public let evidence: EvidenceProvenance

    public init(
        id: NonvisualID,
        label: String,
        role: String? = nil,
        bounds: BoundingBox? = nil,
        elementIDs: [NonvisualID] = [],
        evidence: EvidenceProvenance
    ) {
        self.id = id
        self.label = label
        self.role = role
        self.bounds = bounds
        self.elementIDs = elementIDs
        self.evidence = evidence
    }
}

public struct NonvisualElement: Codable, Sendable, Equatable, Hashable {
    public let id: NonvisualID
    public let visualIndex: Int?
    public let type: String
    public let visibleLabel: String?
    public let bounds: BoundingBox?
    public let regionID: NonvisualID?
    public let findingIDs: [NonvisualID]
    public let semantics: NonvisualSemantics?
    public let isInteractive: Bool
    public let requiresValueOrState: Bool
    public let requiresAction: Bool
    public let visualEvidence: EvidenceProvenance
    public let semanticEvidence: EvidenceProvenance

    public init(
        id: NonvisualID,
        visualIndex: Int? = nil,
        type: String,
        visibleLabel: String? = nil,
        bounds: BoundingBox? = nil,
        regionID: NonvisualID? = nil,
        findingIDs: [NonvisualID] = [],
        semantics: NonvisualSemantics? = nil,
        isInteractive: Bool = false,
        requiresValueOrState: Bool = false,
        requiresAction: Bool = false,
        visualEvidence: EvidenceProvenance,
        semanticEvidence: EvidenceProvenance
    ) {
        self.id = id
        self.visualIndex = visualIndex
        self.type = type
        self.visibleLabel = visibleLabel
        self.bounds = bounds
        self.regionID = regionID
        self.findingIDs = findingIDs.sorted()
        self.semantics = semantics
        self.isInteractive = isInteractive
        self.requiresValueOrState = requiresValueOrState
        self.requiresAction = requiresAction
        self.visualEvidence = visualEvidence
        self.semanticEvidence = semanticEvidence
    }
}

public enum SpatialRelationshipKind: String, Codable, Sendable, Equatable, Hashable, CaseIterable {
    case above
    case below
    case leading
    case trailing
    case alignedHorizontally = "aligned_horizontally"
    case alignedVertically = "aligned_vertically"
    case contains
    case containedBy = "contained_by"
    case overlaps
    case partiallyOutside = "partially_outside"
    case outside
}

public struct SpatialRelationship: Codable, Sendable, Equatable, Hashable {
    public let id: NonvisualID
    public let subjectID: NonvisualID
    public let kind: SpatialRelationshipKind
    public let objectID: NonvisualID
    public let distance: Double?
    public let description: String
    public let evidence: EvidenceProvenance

    public init(
        id: NonvisualID,
        subjectID: NonvisualID,
        kind: SpatialRelationshipKind,
        objectID: NonvisualID,
        distance: Double? = nil,
        description: String,
        evidence: EvidenceProvenance
    ) {
        self.id = id
        self.subjectID = subjectID
        self.kind = kind
        self.objectID = objectID
        self.distance = distance
        self.description = description
        self.evidence = evidence
    }
}

public enum NavigationSequenceKind: String, Codable, Sendable, Equatable, Hashable {
    case readingOrder = "reading_order"
    case keyboardFocus = "keyboard_focus"
    case predictedVoiceOver = "predicted_voiceover"
}

public struct NavigationSequence: Codable, Sendable, Equatable, Hashable {
    public let id: NonvisualID
    public let kind: NavigationSequenceKind
    public let elementIDs: [NonvisualID]
    public let evidence: EvidenceProvenance

    public init(
        id: NonvisualID,
        kind: NavigationSequenceKind,
        elementIDs: [NonvisualID],
        evidence: EvidenceProvenance
    ) {
        self.id = id
        self.kind = kind
        self.elementIDs = elementIDs
        self.evidence = evidence
    }
}

public enum SemanticMismatchKind: String, Codable, Sendable, Equatable, Hashable, CaseIterable {
    case missingVisualCounterpart = "missing_visual_counterpart"
    case missingSemanticCounterpart = "missing_semantic_counterpart"
    case visibleLabelNameConflict = "visible_label_name_conflict"
    case missingAccessibleName = "missing_accessible_name"
    case missingRole = "missing_role"
    case missingValueOrState = "missing_value_or_state"
    case missingAction = "missing_action"
    case duplicateExposure = "duplicate_exposure"
    case incorrectGrouping = "incorrect_grouping"
    case readingOrderDivergence = "reading_order_divergence"
    case focusOrderDivergence = "focus_order_divergence"
}

public struct SemanticMismatch: Codable, Sendable, Equatable, Hashable {
    public let id: NonvisualID
    public let kind: SemanticMismatchKind
    public let severity: ViewLensSeverity
    public let elementIDs: [NonvisualID]
    public let description: String
    public let evidence: EvidenceProvenance

    public init(
        id: NonvisualID,
        kind: SemanticMismatchKind,
        severity: ViewLensSeverity,
        elementIDs: [NonvisualID],
        description: String,
        evidence: EvidenceProvenance
    ) {
        self.id = id
        self.kind = kind
        self.severity = severity
        self.elementIDs = elementIDs.sorted()
        self.description = description
        self.evidence = evidence
    }
}

public struct NonvisualScreenModel: Codable, Sendable, Equatable, Hashable {
    public static let currentSchemaVersion = "1.0"

    public let schemaVersion: String
    public let id: NonvisualID
    public let title: String?
    public let sourceMode: NonvisualSourceMode
    public let regions: [NonvisualRegion]
    public let elements: [NonvisualElement]
    public let relationships: [SpatialRelationship]
    public let navigationSequences: [NavigationSequence]
    public let mismatches: [SemanticMismatch]

    public init(
        schemaVersion: String = Self.currentSchemaVersion,
        id: NonvisualID,
        title: String? = nil,
        sourceMode: NonvisualSourceMode,
        regions: [NonvisualRegion] = [],
        elements: [NonvisualElement] = [],
        relationships: [SpatialRelationship] = [],
        navigationSequences: [NavigationSequence] = [],
        mismatches: [SemanticMismatch] = []
    ) {
        self.schemaVersion = schemaVersion
        self.id = id
        self.title = title
        self.sourceMode = sourceMode
        self.regions = regions.sorted { $0.id < $1.id }
        self.elements = elements.sorted { $0.id < $1.id }
        self.relationships = relationships.sorted { $0.id < $1.id }
        self.navigationSequences = navigationSequences.sorted { $0.id < $1.id }
        self.mismatches = mismatches.sorted { $0.id < $1.id }
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            schemaVersion: try container.decode(String.self, forKey: .schemaVersion),
            id: try container.decode(NonvisualID.self, forKey: .id),
            title: try container.decodeIfPresent(String.self, forKey: .title),
            sourceMode: try container.decode(NonvisualSourceMode.self, forKey: .sourceMode),
            regions: try container.decode([NonvisualRegion].self, forKey: .regions),
            elements: try container.decode([NonvisualElement].self, forKey: .elements),
            relationships: try container.decode([SpatialRelationship].self, forKey: .relationships),
            navigationSequences: try container.decode([NavigationSequence].self, forKey: .navigationSequences),
            mismatches: try container.decode([SemanticMismatch].self, forKey: .mismatches)
        )
    }
}
