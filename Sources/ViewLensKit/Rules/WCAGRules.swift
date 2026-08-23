import Foundation
import CoreGraphics

/// WCAG 2.2 conformance levels in increasing order of strictness.
public enum WCAGConformanceLevel: String, Codable, Sendable, CaseIterable, Comparable {
    case a = "A"
    case aa = "AA"
    case aaa = "AAA"

    public init?(input: String) {
        self.init(rawValue: input.trimmingCharacters(in: .whitespacesAndNewlines).uppercased())
    }

    private var rank: Int {
        switch self {
        case .a: 0
        case .aa: 1
        case .aaa: 2
        }
    }

    public static func < (lhs: Self, rhs: Self) -> Bool { lhs.rank < rhs.rank }

    public func includes(_ criterionLevel: Self) -> Bool { self >= criterionLevel }
}

/// A programmatic accessibility-tree observation used for WCAG 4.1.2 checks.
public struct AccessibilityElementSnapshot: Codable, Sendable, Equatable, Hashable {
    public let identifier: String?
    public let label: String?
    public let role: String?
    public let value: String?
    public let requiresValue: Bool

    public init(
        identifier: String? = nil,
        label: String?,
        role: String?,
        value: String? = nil,
        requiresValue: Bool = false
    ) {
        self.identifier = identifier
        self.label = label
        self.role = role
        self.value = value
        self.requiresValue = requiresValue
    }
}

/// Formal, deterministic WCAG 2.2 policies shared by screenshot and rendered-view audits.
public enum WCAGRules {
    public static let interactiveTypes = Set([
        "primaryButton", "secondaryButton", "button", "toggle", "textField", "tabBar"
    ])

    /// Evaluates WCAG 2.5.8 (24pt, Level AA, including spacing) or
    /// WCAG 2.5.5 (44pt, Level AAA) according to the requested conformance level.
    public static func targetSizeIssues(
        elements: [DetectedElement],
        imageSize: CGSize,
        scale: Double,
        targetLevel: WCAGConformanceLevel
    ) -> [ViewLensIssue] {
        guard targetLevel >= .aa else { return [] }

        let interactive = elements.enumerated().filter { interactiveTypes.contains($0.element.type) }
        let threshold = targetLevel == .aaa ? 44.0 : 24.0
        let criterion = targetLevel == .aaa ? "WCAG 2.5.5" : "WCAG 2.5.8"
        let level = targetLevel == .aaa ? "AAA" : "AA"

        return interactive.compactMap { index, element in
            let rect = element.boundingBox.toPixelRect(imageSize: imageSize)
            let widthPoints = rect.width / scale
            let heightPoints = rect.height / scale
            guard widthPoints < threshold || heightPoints < threshold else { return nil }

            // WCAG 2.5.8 permits an undersized target when its centered 24pt circle
            // does not intersect another target or another undersized target's circle.
            if targetLevel == .aa,
               hasMinimumSpacing(index: index, elements: interactive, imageSize: imageSize, scale: scale) {
                return nil
            }

            let dimensions = "\(Int(round(widthPoints)))×\(Int(round(heightPoints)))pt"
            let spacingNote = targetLevel == .aa ? " and does not satisfy the spacing exception" : ""
            return ViewLensIssue(
                kind: .tappableTargetTooSmall,
                severity: .error,
                description: "\(element.type) target is \(dimensions), below the \(Int(threshold))×\(Int(threshold))pt requirement\(spacingNote).",
                confidence: element.confidence,
                elementIndex: index,
                wcagCriterion: criterion,
                wcagLevel: level,
                remediation: RemediationAdvice(
                    description: "Increase the activation area without necessarily changing the visible control.",
                    codeSnippet: ".frame(minWidth: \(Int(threshold)), minHeight: \(Int(threshold)))\n.contentShape(Rectangle())"
                )
            )
        }
    }

    /// Converts enlarged-layout clipping, overlap, off-screen placement, or lost controls
    /// into explicit WCAG 1.4.4 / 1.4.10 Dynamic Type failures.
    public static func reflowIssues(
        baselineElements: [DetectedElement],
        enlargedElements: [DetectedElement],
        enlargedLayoutIssues: [ViewLensIssue],
        stage: String
    ) -> [ViewLensIssue] {
        var results = enlargedLayoutIssues
            .filter { [.clippedElement, .overlappingElements, .offScreen, .textTruncated].contains($0.kind) }
            .map { issue in
                ViewLensIssue(
                    kind: .dynamicTypeOverflow,
                    severity: .error,
                    description: "\(stage): \(issue.description)",
                    confidence: issue.confidence,
                    elementIndex: issue.elementIndex,
                    identifier: issue.identifier,
                    wcagCriterion: "WCAG 1.4.4 / 1.4.10",
                    wcagLevel: "AA",
                    remediation: RemediationAdvice(
                        description: "Allow content to wrap or scroll without losing information or functionality.",
                        codeSnippet: "ScrollView { ... }\n.fixedSize(horizontal: false, vertical: true)"
                    )
                )
            }

        let baselineInteractive = baselineElements.filter { interactiveTypes.contains($0.type) }.count
        let enlargedInteractive = enlargedElements.filter { interactiveTypes.contains($0.type) }.count
        if baselineInteractive > 0, enlargedInteractive < baselineInteractive {
            results.append(ViewLensIssue(
                kind: .dynamicTypeOverflow,
                severity: .error,
                description: "\(stage): \(baselineInteractive - enlargedInteractive) interactive control(s) are no longer detectable, indicating possible loss of content or functionality.",
                wcagCriterion: "WCAG 1.4.4 / 1.4.10",
                wcagLevel: "AA",
                remediation: RemediationAdvice(
                    description: "Use adaptive stacks, wrapping labels, and scrolling at accessibility text sizes.",
                    codeSnippet: "ViewThatFits { ... }\nScrollView { ... }"
                )
            ))
        }
        return results
    }

    /// Evaluates the programmatically exposed name, role, and value of controls.
    public static func nameRoleValueIssues(
        snapshots: [AccessibilityElementSnapshot]
    ) -> [ViewLensIssue] {
        snapshots.flatMap { snapshot -> [ViewLensIssue] in
            var issues: [ViewLensIssue] = []
            let idText = snapshot.identifier.map { " '\($0)'" } ?? ""

            if snapshot.label?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty != false {
                issues.append(ViewLensIssue(
                    kind: .missingAccessibilityLabel,
                    severity: .error,
                    description: "Interactive element\(idText) has no programmatically determinable accessible name.",
                    identifier: snapshot.identifier,
                    wcagCriterion: "WCAG 4.1.2",
                    wcagLevel: "A",
                    remediation: RemediationAdvice(
                        description: "Expose a concise accessible name.",
                        codeSnippet: ".accessibilityLabel(\"Descriptive name\")"
                    )
                ))
            }

            if snapshot.role?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty != false {
                issues.append(ViewLensIssue(
                    kind: .missingAccessibilityTrait,
                    severity: .error,
                    description: "Interactive element\(idText) has no programmatically determinable role.",
                    identifier: snapshot.identifier,
                    wcagCriterion: "WCAG 4.1.2",
                    wcagLevel: "A",
                    remediation: RemediationAdvice(
                        description: "Use a native control or expose the matching accessibility trait.",
                        codeSnippet: ".accessibilityAddTraits(.isButton)"
                    )
                ))
            }

            if snapshot.requiresValue,
               snapshot.value?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty != false {
                issues.append(ViewLensIssue(
                    kind: .missingAccessibilityTrait,
                    severity: .error,
                    description: "Stateful element\(idText) has no programmatically determinable value or state.",
                    identifier: snapshot.identifier,
                    wcagCriterion: "WCAG 4.1.2",
                    wcagLevel: "A",
                    remediation: RemediationAdvice(
                        description: "Expose the current value or state to assistive technology.",
                        codeSnippet: ".accessibilityValue(\"Current value\")"
                    )
                ))
            }
            return issues
        }
    }

    private static func hasMinimumSpacing(
        index: Int,
        elements: [(offset: Int, element: DetectedElement)],
        imageSize: CGSize,
        scale: Double
    ) -> Bool {
        guard let candidate = elements.first(where: { $0.offset == index }) else { return false }
        let candidateRect = candidate.element.boundingBox.toPixelRect(imageSize: imageSize)
        let candidateCenter = CGPoint(x: candidateRect.midX / scale, y: candidateRect.midY / scale)

        for other in elements where other.offset != index {
            let otherRectPixels = other.element.boundingBox.toPixelRect(imageSize: imageSize)
            let otherRect = CGRect(
                x: otherRectPixels.minX / scale,
                y: otherRectPixels.minY / scale,
                width: otherRectPixels.width / scale,
                height: otherRectPixels.height / scale
            )
            let otherIsUndersized = otherRect.width < 24 || otherRect.height < 24
            if otherIsUndersized {
                let dx = candidateCenter.x - otherRect.midX
                let dy = candidateCenter.y - otherRect.midY
                if hypot(dx, dy) < 24 { return false }
            } else if otherRect.insetBy(dx: -12, dy: -12).contains(candidateCenter) {
                return false
            }
        }
        return true
    }
}
