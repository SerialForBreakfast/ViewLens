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
        public let frame: CGRect

        public init(
            viewClass: String,
            identifier: String?,
            isAmbiguous: Bool,
            hasAccessibilityLabel: Bool,
            frame: CGRect
        ) {
            self.viewClass = viewClass
            self.identifier = identifier
            self.isAmbiguous = isAmbiguous
            self.hasAccessibilityLabel = hasAccessibilityLabel
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

        if isAmbiguous || (!hasA11y && view.isUserInteractionEnabled) {
            results.append(IntrospectionFinding(
                viewClass: String(describing: type(of: view)),
                identifier: view.accessibilityIdentifier,
                isAmbiguous: isAmbiguous,
                hasAccessibilityLabel: hasA11y,
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
                    remediation: RemediationAdvice(
                        description: "Provide an accessible description.",
                        codeSnippet: "view.accessibilityLabel = \"Description\""
                    )
                ))
            }
        }

        return issues
    }
}
#endif
