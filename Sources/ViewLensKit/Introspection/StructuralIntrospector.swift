import Foundation
import CoreGraphics

#if canImport(UIKit)
import UIKit

public struct StructuralIntrospector: Sendable {
    public struct IntrospectionFinding: Codable, Sendable, Equatable, Hashable {
        public let viewClass: String
        public let identifier: String?
        public let isAmbiguous: Bool
        public let hasAccessibilityLabel: Bool
        public let hasAccessibilityRole: Bool
        public let hasAccessibilityValue: Bool
        public let requiresAccessibilityValue: Bool
        public let frame: CGRect

        public init(
            viewClass: String,
            identifier: String?,
            isAmbiguous: Bool,
            hasAccessibilityLabel: Bool,
            hasAccessibilityRole: Bool = true,
            hasAccessibilityValue: Bool = true,
            requiresAccessibilityValue: Bool = false,
            frame: CGRect
        ) {
            self.viewClass = viewClass
            self.identifier = identifier
            self.isAmbiguous = isAmbiguous
            self.hasAccessibilityLabel = hasAccessibilityLabel
            self.hasAccessibilityRole = hasAccessibilityRole
            self.hasAccessibilityValue = hasAccessibilityValue
            self.requiresAccessibilityValue = requiresAccessibilityValue
            self.frame = frame
        }
    }

    /// Recursively inspects a root view hierarchy for Auto Layout ambiguity and accessibility metadata.
    /// Note: The view MUST be attached to a UIWindow and have executed layoutIfNeeded() prior to calling.
    @MainActor
    public static func inspect(view: UIView) -> [IntrospectionFinding] {
        var findings: [IntrospectionFinding] = []
        inspectRecursive(view: view, results: &findings)
        return findings
    }

    @MainActor
    private static func inspectRecursive(view: UIView, results: inout [IntrospectionFinding]) {
        let isAmbiguous = view.hasAmbiguousLayout
        let label = view.accessibilityLabel
        let hasA11y = label != nil && !label!.isEmpty
        let hasRole = !view.accessibilityTraits.isEmpty || view is UIControl
        let requiresValue = view is UISwitch || view is UISlider || view is UIStepper || view is UITextField
        let value = view.accessibilityValue
        let hasValue = value?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false

        if isAmbiguous || (view.isUserInteractionEnabled && (!hasA11y || !hasRole || (requiresValue && !hasValue))) {
            results.append(IntrospectionFinding(
                viewClass: String(describing: type(of: view)),
                identifier: view.accessibilityIdentifier,
                isAmbiguous: isAmbiguous,
                hasAccessibilityLabel: hasA11y,
                hasAccessibilityRole: hasRole,
                hasAccessibilityValue: hasValue,
                requiresAccessibilityValue: requiresValue,
                frame: view.frame
            ))
        }

        for subview in view.subviews {
            inspectRecursive(view: subview, results: &results)
        }
    }

    /// Maps introspection findings into standard ViewLensIssue structures.
    public static func toIssues(findings: [IntrospectionFinding]) -> [ViewLensIssue] {
        var issues: [ViewLensIssue] = []

        for finding in findings {
            if finding.isAmbiguous {
                let idText = finding.identifier.map { " (id: '\($0)')" } ?? ""
                issues.append(ViewLensIssue(
                    kind: .ambiguousAutoLayout,
                    severity: .error,
                    description: "Auto Layout engine reports ambiguous layout on \(finding.viewClass)\(idText). Constraints are contradictory or under-specified.",
                    identifier: finding.identifier,
                    remediation: RemediationAdvice(
                        description: "Add missing positioning or sizing constraints to resolve layout ambiguity.",
                        codeSnippet: "NSLayoutConstraint.activate([ ... ])"
                    )
                ))
            }

            if !finding.hasAccessibilityLabel {
                let idText = finding.identifier.map { " (id: '\($0)')" } ?? ""
                issues.append(ViewLensIssue(
                    kind: .missingAccessibilityLabel,
                    severity: .warning,
                    description: "Interactive view \(finding.viewClass)\(idText) lacks an accessibility label for VoiceOver.",
                    identifier: finding.identifier,
                    wcagCriterion: "WCAG 4.1.2",
                    wcagLevel: "A",
                    remediation: RemediationAdvice(
                        description: "Provide an accessible description.",
                        codeSnippet: "view.accessibilityLabel = \"Description\""
                    )
                ))
            }

            if !finding.hasAccessibilityRole {
                let idText = finding.identifier.map { " (id: '\($0)')" } ?? ""
                issues.append(ViewLensIssue(
                    kind: .missingAccessibilityTrait,
                    severity: .error,
                    description: "Interactive view \(finding.viewClass)\(idText) lacks a programmatically determinable accessibility role.",
                    identifier: finding.identifier,
                    wcagCriterion: "WCAG 4.1.2",
                    wcagLevel: "A",
                    remediation: RemediationAdvice(
                        description: "Expose the control's semantic role.",
                        codeSnippet: "view.accessibilityTraits.insert(.button)"
                    )
                ))
            }

            if finding.requiresAccessibilityValue && !finding.hasAccessibilityValue {
                let idText = finding.identifier.map { " (id: '\($0)')" } ?? ""
                issues.append(ViewLensIssue(
                    kind: .missingAccessibilityTrait,
                    severity: .error,
                    description: "Stateful view \(finding.viewClass)\(idText) lacks a programmatically determinable accessibility value.",
                    identifier: finding.identifier,
                    wcagCriterion: "WCAG 4.1.2",
                    wcagLevel: "A",
                    remediation: RemediationAdvice(
                        description: "Expose the current state or value.",
                        codeSnippet: "view.accessibilityValue = \"Current value\""
                    )
                ))
            }
        }

        return issues
    }
}
#endif
