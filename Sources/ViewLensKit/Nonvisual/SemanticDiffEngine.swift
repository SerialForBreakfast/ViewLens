import Foundation

/// Classification of semantic changes between two nonvisual screen models.
public enum SemanticChangeKind: String, Codable, Sendable, Equatable, Hashable, CaseIterable {
    case addedElement = "added_element"
    case removedElement = "removed_element"
    case labelModified = "label_modified"
    case roleModified = "role_modified"
    case valueModified = "value_modified"
    case traitModified = "trait_modified"
    case focusOrderShifted = "focus_order_shifted"
    case findingResolved = "finding_resolved"
    case findingIntroduced = "finding_introduced"
}

/// Impact level of a semantic change on assistive technology users.
public enum SemanticDeltaImpact: String, Codable, Sendable, Equatable, Hashable, CaseIterable {
    case blocking = "Blocking Accessibility"
    case material = "Material Semantic"
    case cosmetic = "Minor Refinement"
}

/// An individual semantic change between two screens.
public struct SemanticChange: Codable, Sendable, Equatable, Hashable, Identifiable {
    public let id: NonvisualID
    public let elementID: NonvisualID
    public let kind: SemanticChangeKind
    public let impact: SemanticDeltaImpact
    public let description: String
    public let beforeValue: String?
    public let afterValue: String?
    public let remediationSnippet: String?

    public init(
        id: NonvisualID,
        elementID: NonvisualID,
        kind: SemanticChangeKind,
        impact: SemanticDeltaImpact,
        description: String,
        beforeValue: String? = nil,
        afterValue: String? = nil,
        remediationSnippet: String? = nil
    ) {
        self.id = id
        self.elementID = elementID
        self.kind = kind
        self.impact = impact
        self.description = description
        self.beforeValue = beforeValue
        self.afterValue = afterValue
        self.remediationSnippet = remediationSnippet
    }
}

/// A comprehensive semantic diff between two NonvisualScreenModels.
public struct SemanticScreenDiff: Codable, Sendable, Equatable {
    public let beforeScreenID: NonvisualID
    public let afterScreenID: NonvisualID
    public let changes: [SemanticChange]
    public let resolvedFindings: [SemanticMismatch]
    public let introducedFindings: [SemanticMismatch]

    public init(
        beforeScreenID: NonvisualID,
        afterScreenID: NonvisualID,
        changes: [SemanticChange] = [],
        resolvedFindings: [SemanticMismatch] = [],
        introducedFindings: [SemanticMismatch] = []
    ) {
        self.beforeScreenID = beforeScreenID
        self.afterScreenID = afterScreenID
        self.changes = changes
        self.resolvedFindings = resolvedFindings
        self.introducedFindings = introducedFindings
    }

    public var blockingChanges: [SemanticChange] {
        changes.filter { $0.impact == .blocking }
    }

    public var materialChanges: [SemanticChange] {
        changes.filter { $0.impact == .material }
    }

    public var passed: Bool {
        blockingChanges.isEmpty && introducedFindings.isEmpty
    }

    public func formattedSummary(profile: NonvisualPresentationProfile = .speech) -> String {
        var lines: [String] = []

        let resolvedCount = resolvedFindings.count
        let introCount = introducedFindings.count
        let blockingCount = blockingChanges.count

        switch profile {
        case .speech:
            lines.append("Semantic diff: \(changes.count) total change\(changes.count == 1 ? "" : "s").")
            if resolvedCount > 0 {
                lines.append("\(resolvedCount) accessibility issue\(resolvedCount == 1 ? "" : "s") resolved.")
            }
            if introCount > 0 {
                lines.append("Warning: \(introCount) new issue\(introCount == 1 ? "" : "s") introduced.")
            }
            if blockingCount > 0 {
                lines.append("\(blockingCount) blocking change\(blockingCount == 1 ? "" : "s") require review.")
            } else {
                lines.append("No blocking accessibility regressions detected.")
            }
            return lines.joined(separator: " ")

        case .braille:
            lines.append("DIF [\(changes.count) changes, +\(resolvedCount) fix, -\(introCount) reg]")
            for c in changes.prefix(8) {
                lines.append("[\(c.kind.rawValue.prefix(3).uppercased())] \(c.description)")
            }
            return lines.joined(separator: "\n")

        case .developer:
            lines.append("=== Semantic Screen Diff (\(beforeScreenID.rawValue) -> \(afterScreenID.rawValue)) ===")
            lines.append("Status: \(passed ? "PASSED (No Regressions)" : "FAILED (Regressions Found)")")
            lines.append("Resolved: \(resolvedCount) | Introduced: \(introCount) | Blocking: \(blockingCount)")
            lines.append("")
            for c in changes {
                let fix = c.remediationSnippet.map { " | fix: `\($0)`" } ?? ""
                lines.append("[\(c.impact.rawValue)] \(c.elementID.rawValue): \(c.description)\(fix)")
            }
            return lines.joined(separator: "\n")
        }
    }
}

/// Deterministic semantic diff engine comparing nonvisual structures independent of pixel differences.
public enum SemanticDiffEngine {

    public static func diff(before: NonvisualScreenModel, after: NonvisualScreenModel) -> SemanticScreenDiff {
        var changes: [SemanticChange] = []

        let beforeElementMap = Dictionary(uniqueKeysWithValues: before.elements.map { ($0.id, $0) })
        let afterElementMap = Dictionary(uniqueKeysWithValues: after.elements.map { ($0.id, $0) })

        // 1. Detect Added Elements
        for (id, afterEl) in afterElementMap where beforeElementMap[id] == nil {
            let label = afterEl.semantics?.accessibleName ?? afterEl.visibleLabel ?? afterEl.type
            changes.append(SemanticChange(
                id: NonvisualID("change:added:\(id.rawValue)"),
                elementID: id,
                kind: .addedElement,
                impact: .material,
                description: "Added \(afterEl.type) '\(label)'",
                afterValue: label
            ))
        }

        // 2. Detect Removed Elements
        for (id, beforeEl) in beforeElementMap where afterElementMap[id] == nil {
            let label = beforeEl.semantics?.accessibleName ?? beforeEl.visibleLabel ?? beforeEl.type
            changes.append(SemanticChange(
                id: NonvisualID("change:removed:\(id.rawValue)"),
                elementID: id,
                kind: .removedElement,
                impact: .material,
                description: "Removed \(beforeEl.type) '\(label)'",
                beforeValue: label
            ))
        }

        // 3. Detect Modified Elements
        for (id, beforeEl) in beforeElementMap {
            guard let afterEl = afterElementMap[id] else { continue }

            // Label changes
            let beforeLabel = beforeEl.semantics?.accessibleName ?? beforeEl.visibleLabel
            let afterLabel = afterEl.semantics?.accessibleName ?? afterEl.visibleLabel
            if beforeLabel != afterLabel {
                let desc = "Label changed from '\(beforeLabel ?? "none")' to '\(afterLabel ?? "none")'"
                let isMissing = afterLabel == nil || afterLabel?.isEmpty == true
                changes.append(SemanticChange(
                    id: NonvisualID("change:label:\(id.rawValue)"),
                    elementID: id,
                    kind: .labelModified,
                    impact: isMissing && afterEl.isInteractive ? .blocking : .material,
                    description: desc,
                    beforeValue: beforeLabel,
                    afterValue: afterLabel,
                    remediationSnippet: isMissing ? ".accessibilityLabel(\"\(beforeLabel ?? "Action")\")" : nil
                ))
            }

            // Role changes
            let beforeRole = beforeEl.semantics?.role ?? beforeEl.type
            let afterRole = afterEl.semantics?.role ?? afterEl.type
            if beforeRole != afterRole {
                changes.append(SemanticChange(
                    id: NonvisualID("change:role:\(id.rawValue)"),
                    elementID: id,
                    kind: .roleModified,
                    impact: .material,
                    description: "Role changed from '\(beforeRole)' to '\(afterRole)'",
                    beforeValue: beforeRole,
                    afterValue: afterRole,
                    remediationSnippet: ".accessibilityAddTraits(.\(afterRole))"
                ))
            }

            // Value changes
            let beforeVal = beforeEl.semantics?.value
            let afterVal = afterEl.semantics?.value
            if beforeVal != afterVal {
                changes.append(SemanticChange(
                    id: NonvisualID("change:value:\(id.rawValue)"),
                    elementID: id,
                    kind: .valueModified,
                    impact: .cosmetic,
                    description: "Value changed from '\(beforeVal ?? "empty")' to '\(afterVal ?? "empty")'",
                    beforeValue: beforeVal,
                    afterValue: afterVal
                ))
            }
        }

        // 4. Resolved vs Introduced Findings
        let beforeMismatchMap = Dictionary(uniqueKeysWithValues: before.mismatches.map { ($0.id, $0) })
        let afterMismatchMap = Dictionary(uniqueKeysWithValues: after.mismatches.map { ($0.id, $0) })

        let resolved = before.mismatches.filter { afterMismatchMap[$0.id] == nil }
        let introduced = after.mismatches.filter { beforeMismatchMap[$0.id] == nil }

        for res in resolved {
            changes.append(SemanticChange(
                id: NonvisualID("change:resolved:\(res.id.rawValue)"),
                elementID: res.elementIDs.first ?? NonvisualID("screen"),
                kind: .findingResolved,
                impact: .material,
                description: "Resolved issue: \(res.description)"
            ))
        }

        for intro in introduced {
            changes.append(SemanticChange(
                id: NonvisualID("change:introduced:\(intro.id.rawValue)"),
                elementID: intro.elementIDs.first ?? NonvisualID("screen"),
                kind: .findingIntroduced,
                impact: intro.severity == .error ? .blocking : .material,
                description: "Introduced issue: \(intro.description)"
            ))
        }

        return SemanticScreenDiff(
            beforeScreenID: before.id,
            afterScreenID: after.id,
            changes: changes,
            resolvedFindings: resolved,
            introducedFindings: introduced
        )
    }
}
