import Foundation

/// Categorization of UI defects, accessibility failures, and HIG violations.
public enum ViewLensIssueKind: String, Codable, Sendable, Equatable, Hashable {
    /// Interactive touch target smaller than Apple HIG 44x44pt requirement (WCAG 2.5.5 / 2.5.8)
    case tappableTargetTooSmall
    /// Element boundary clipped by screen or safe area edges (Apple HIG mobile layout)
    case clippedElement
    /// Cross-element bounding box collision/occlusion (IoU > 0.30)
    case overlappingElements
    /// Over 50% of element lies outside visible canvas (Apple HIG mobile layout)
    case offScreen
    /// Auto Layout engine reports ambiguous layout (UIView.hasAmbiguousLayout == true)
    case ambiguousAutoLayout
    /// Element missing accessibility label or description (WCAG 1.1.1 / 4.1.2)
    case missingAccessibilityLabel
    /// Element missing accessibility trait (e.g. .isButton, .isHeader) (WCAG 4.1.2)
    case missingAccessibilityTrait
    /// Text truncated by bounding constraints
    case textTruncated
    /// Inadequate color contrast between text/icon and background (WCAG 1.4.3 / 1.4.11)
    case contrastRisk
    /// Layout clipping or loss of content when enlarged under Dynamic Type AX1-AX5 (WCAG 1.4.4 / 1.4.10)
    case dynamicTypeOverflow
    /// Custom layout or design rule violation
    case customRuleViolation
}

public enum ViewLensSeverity: String, Codable, Sendable, Equatable, Hashable {
    case error
    case warning
    case info

    public var displayName: String {
        switch self {
        case .error: return "Critical"
        case .warning: return "Warning"
        case .info: return "Info"
        }
    }
}

/// Actionable remediation advice for the AI agent or developer.
public struct RemediationAdvice: Codable, Sendable, Equatable, Hashable {
    public let description: String
    public let codeSnippet: String?
    public let location: String?

    public init(description: String, codeSnippet: String? = nil, location: String? = nil) {
        self.description = description
        self.codeSnippet = codeSnippet
        self.location = location
    }
}

/// Represents a detected UI defect, HIG violation, or WCAG accessibility non-compliance issue.
public struct ViewLensIssue: Codable, Sendable, Equatable, Hashable {
    public let kind: ViewLensIssueKind
    public let severity: ViewLensSeverity
    public let description: String
    public let confidence: Float?
    public let elementIndex: Int?
    public let identifier: String?
    public let wcagCriterion: String?
    public let wcagLevel: String?
    public let remediation: RemediationAdvice?

    public init(
        kind: ViewLensIssueKind,
        severity: ViewLensSeverity,
        description: String,
        confidence: Float? = nil,
        elementIndex: Int? = nil,
        identifier: String? = nil,
        wcagCriterion: String? = nil,
        wcagLevel: String? = nil,
        remediation: RemediationAdvice? = nil
    ) {
        self.kind = kind
        self.severity = severity
        self.description = description
        self.confidence = confidence
        self.elementIndex = elementIndex
        self.identifier = identifier
        self.wcagCriterion = wcagCriterion
        self.wcagLevel = wcagLevel
        self.remediation = remediation
    }
}
