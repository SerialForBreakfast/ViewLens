import Foundation
import CoreGraphics

/// Native accessibility traits modeled after UIAccessibilityTraits and NSAccessibility roles.
public enum NativeAccessibilityTrait: String, Codable, Sendable, Equatable, Hashable, CaseIterable {
    case isButton = "button"
    case isHeader = "header"
    case isImage = "image"
    case isSelected = "selected"
    case isStaticText = "text"
    case isLink = "link"
    case isSearchField = "searchField"
    case isKeyboardKey = "keyboardKey"
    case notEnabled = "notEnabled"
    case isSummaryElement = "summary"
    case isAdjustable = "adjustable"
    case allowsDirectInteraction = "directInteraction"
    case playsSound = "playsSound"
}

/// A node representing native accessibility API attributes and structure.
public struct NativeAccessibilityNode: Codable, Sendable, Equatable, Hashable, Identifiable {
    public let id: NonvisualID
    public let label: String?
    public let value: String?
    public let hint: String?
    public let traits: Set<NativeAccessibilityTrait>
    public let customActions: [String]
    public let frame: BoundingBox?
    public let headingLevel: Int?
    public let isAccessibilityElement: Bool
    public let children: [NonvisualID]
    public let provenance: EvidenceProvenance
    /// Explicit accessibility activation point (e.g. `accessibilityActivationPoint`), in the same
    /// normalized coordinate space as `frame`. Only set when instrumented from a real accessibility
    /// override; `nil` means no override was reported, not that one is absent, so callers must not
    /// infer a value (e.g. the frame's center) when this is `nil`.
    public let activationPoint: CGPoint?

    public init(
        id: NonvisualID,
        label: String? = nil,
        value: String? = nil,
        hint: String? = nil,
        traits: Set<NativeAccessibilityTrait> = [],
        customActions: [String] = [],
        frame: BoundingBox? = nil,
        headingLevel: Int? = nil,
        isAccessibilityElement: Bool = true,
        children: [NonvisualID] = [],
        provenance: EvidenceProvenance,
        activationPoint: CGPoint? = nil
    ) {
        self.id = id
        self.label = label
        self.value = value
        self.hint = hint
        self.traits = traits
        self.customActions = customActions.sorted()
        self.frame = frame
        self.headingLevel = headingLevel
        self.isAccessibilityElement = isAccessibilityElement
        self.children = children.sorted()
        self.provenance = provenance
        self.activationPoint = activationPoint
    }
}

/// VoiceOver rotor category classifications.
public enum RotorItemKind: String, Codable, Sendable, Equatable, Hashable, CaseIterable {
    case heading = "Headings"
    case interactiveControl = "Interactive Controls"
    case formField = "Form Fields"
    case link = "Links"
    case landmark = "Landmarks"
    case finding = "Findings"
}

/// An individual item indexed in the VoiceOver rotor.
public struct RotorItem: Codable, Sendable, Equatable, Hashable, Identifiable {
    public var id: String { "\(kind.rawValue):\(elementID.rawValue)" }
    public let kind: RotorItemKind
    public let label: String
    public let elementID: NonvisualID
    public let details: String?

    public init(
        kind: RotorItemKind,
        label: String,
        elementID: NonvisualID,
        details: String? = nil
    ) {
        self.kind = kind
        self.label = label
        self.elementID = elementID
        self.details = details
    }
}

/// A comprehensive inventory of all rotor-accessible items on the screen.
public struct RotorInventory: Codable, Sendable, Equatable {
    public let items: [RotorItem]

    public init(items: [RotorItem] = []) {
        self.items = items
    }

    public func items(for kind: RotorItemKind) -> [RotorItem] {
        items.filter { $0.kind == kind }
    }

    public var headings: [RotorItem] { items(for: .heading) }
    public var interactiveControls: [RotorItem] { items(for: .interactiveControl) }
    public var landmarks: [RotorItem] { items(for: .landmark) }
    public var findings: [RotorItem] { items(for: .finding) }
}

/// A step in a predicted VoiceOver traversal sequence.
public struct VoiceOverTranscriptEntry: Codable, Sendable, Equatable, Identifiable {
    public var id: Int { step }
    public let step: Int
    public let elementID: NonvisualID
    public let speechText: String
    public let brailleText: String
    public let traits: [String]
    public let hint: String?

    public init(
        step: Int,
        elementID: NonvisualID,
        speechText: String,
        brailleText: String,
        traits: [String] = [],
        hint: String? = nil
    ) {
        self.step = step
        self.elementID = elementID
        self.speechText = speechText
        self.brailleText = brailleText
        self.traits = traits
        self.hint = hint
    }
}

/// Predicted VoiceOver transcript simulating accessibility speech synthesis order and output.
public struct VoiceOverTranscript: Codable, Sendable, Equatable {
    public static let heuristicDisclaimer = "API-derived heuristic VoiceOver prediction; does not replace real VoiceOver manual verification."

    public let screenID: NonvisualID
    public let entries: [VoiceOverTranscriptEntry]
    public let disclaimer: String

    public init(
        screenID: NonvisualID,
        entries: [VoiceOverTranscriptEntry],
        disclaimer: String = Self.heuristicDisclaimer
    ) {
        self.screenID = screenID
        self.entries = entries
        self.disclaimer = disclaimer
    }

    public func formattedTranscript(profile: NonvisualPresentationProfile = .speech) -> String {
        guard !entries.isEmpty else {
            return "No accessible elements detected on screen."
        }

        switch profile {
        case .speech:
            return entries.map { "\($0.step). \($0.speechText)" }.joined(separator: "\n")
        case .braille:
            return entries.map { "\($0.step). \($0.brailleText)" }.joined(separator: "\n")
        case .developer:
            return entries.map { entry in
                let traitsDesc = entry.traits.isEmpty ? "none" : entry.traits.joined(separator: ",")
                return "[\(entry.step)] \(entry.elementID.rawValue) | \(entry.speechText) | traits=[\(traitsDesc)]"
            }.joined(separator: "\n")
        }
    }
}

/// Predicts VoiceOver speech narration, rotor structures, and focus behavior from a NonvisualScreenModel.
public enum VoiceOverPredictor {

    public static func predictTranscript(from model: NonvisualScreenModel) -> VoiceOverTranscript {
        var entries: [VoiceOverTranscriptEntry] = []
        var step = 1

        // Use reading_order navigation sequence if available, or sort elements top-to-bottom
        let sequenceElementIDs: [NonvisualID]
        if let readingSequence = model.navigationSequences.first(where: { $0.kind == .readingOrder && $0.evidence.kind != .unavailable }) {
            sequenceElementIDs = readingSequence.elementIDs
        } else {
            sequenceElementIDs = model.elements
                .sorted { (lhs, rhs) -> Bool in
                    guard let lb = lhs.bounds, let rb = rhs.bounds else { return lhs.id < rhs.id }
                    if abs(lb.y - rb.y) > 0.05 { return lb.y < rb.y }
                    return lb.x < rb.x
                }
                .map(\.id)
        }

        for elementID in sequenceElementIDs {
            guard let element = model.elements.first(where: { $0.id == elementID }) else { continue }
            let entry = predictEntry(for: element, step: step)
            entries.append(entry)
            step += 1
        }

        return VoiceOverTranscript(screenID: model.id, entries: entries)
    }

    public static func extractRotorInventory(from model: NonvisualScreenModel) -> RotorInventory {
        var items: [RotorItem] = []

        // 1. Regions as Landmarks
        for region in model.regions {
            items.append(RotorItem(
                kind: .landmark,
                label: region.label,
                elementID: region.id,
                details: "Region with \(region.elementIDs.count) element(s)"
            ))
        }

        // 2. Elements by Role & Semantics
        for el in model.elements {
            let name = el.semantics?.accessibleName ?? el.visibleLabel ?? el.type

            if el.semantics?.isHeading == true || el.type == "heading" {
                items.append(RotorItem(
                    kind: .heading,
                    label: name,
                    elementID: el.id,
                    details: el.semantics?.role ?? "Heading"
                ))
            }

            if el.isInteractive || el.type == "button" || el.semantics?.role == "button" {
                items.append(RotorItem(
                    kind: .interactiveControl,
                    label: name,
                    elementID: el.id,
                    details: el.type
                ))
            }

            if el.type == "textField" || el.type == "secureTextField" || el.type == "slider" || el.type == "toggle" {
                items.append(RotorItem(
                    kind: .formField,
                    label: name,
                    elementID: el.id,
                    details: el.semantics?.value ?? el.type
                ))
            }

            if el.type == "link" {
                items.append(RotorItem(
                    kind: .link,
                    label: name,
                    elementID: el.id,
                    details: "Link"
                ))
            }
        }

        // 3. Findings as Finding Rotor
        for mismatch in model.mismatches {
            items.append(RotorItem(
                kind: .finding,
                label: mismatch.description,
                elementID: mismatch.id,
                details: mismatch.kind.rawValue
            ))
        }

        return RotorInventory(items: items)
    }

    private static func predictEntry(for element: NonvisualElement, step: Int) -> VoiceOverTranscriptEntry {
        let name = element.semantics?.accessibleName ?? element.visibleLabel ?? "Unlabeled \(element.type)"
        var speechParts: [String] = [name]
        var brailleParts: [String] = [name]
        var traits: [String] = []

        if let role = element.semantics?.role, !role.isEmpty {
            speechParts.append(role)
            brailleParts.append(role.prefix(3).uppercased())
            traits.append(role)
        } else if element.isInteractive {
            speechParts.append("button")
            brailleParts.append("BTN")
            traits.append("button")
        }

        if let value = element.semantics?.value, !value.isEmpty {
            speechParts.append(value)
            brailleParts.append(value)
        }

        if element.semantics?.isHeading == true {
            speechParts.append("heading")
            brailleParts.append("HDG")
            traits.append("heading")
        }

        for state in element.semantics?.states ?? [] {
            speechParts.append(state)
            brailleParts.append(state)
            traits.append(state)
        }

        let hint = element.semantics?.hint
        if let hint, !hint.isEmpty {
            speechParts.append(". \(hint)")
        }

        return VoiceOverTranscriptEntry(
            step: step,
            elementID: element.id,
            speechText: speechParts.joined(separator: ", "),
            brailleText: brailleParts.joined(separator: " "),
            traits: traits,
            hint: hint
        )
    }
}
