import Foundation

/// Categorization of UI defects, accessibility failures, and HIG violations.
public enum ViewLensIssueKind: String, Codable, Sendable, Equatable, Hashable {
    /// Interactive touch target smaller than Apple HIG 44x44pt requirement
    case tappableTargetTooSmall
    /// Element boundary clipped by screen or safe area edges
    case clippedElement
    /// Cross-element bounding box collision/occlusion (IoU > 0.30)
    case overlappingElements
    /// Over 50% of element lies outside visible canvas
    case offScreen
    /// Auto Layout engine reports ambiguous layout (UIView.hasAmbiguousLayout == true)
    case ambiguousAutoLayout
    /// Element missing accessibility label or traits
    case missingAccessibilityLabel
    /// Text truncated by bounding constraints
    case textTruncated
    /// Custom layout or design rule violation
    case customRuleViolation
}

public enum ViewLensSeverity: String, Codable, Sendable, Equatable, Hashable {
    case error
    case warning
    case info
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

/// Represents a detected UI defect or HIG guideline violation.
public struct ViewLensIssue: Codable, Sendable, Equatable, Hashable {
    public let kind: ViewLensIssueKind
    public let severity: ViewLensSeverity
    public let description: String
    public let confidence: Float?
    public let elementIndex: Int?
    public let identifier: String?
    public let remediation: RemediationAdvice?

    public init(
        kind: ViewLensIssueKind,
        severity: ViewLensSeverity,
        description: String,
        confidence: Float? = nil,
        elementIndex: Int? = nil,
        identifier: String? = nil,
        remediation: RemediationAdvice? = nil
    ) {
        self.kind = kind
        self.severity = severity
        self.description = description
        self.confidence = confidence
        self.elementIndex = elementIndex
        self.identifier = identifier
        self.remediation = remediation
    }
}
