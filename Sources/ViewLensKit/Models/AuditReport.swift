import Foundation
import CoreGraphics

/// Identifies whether the audit was performed on a static screenshot or a live rendered view template.
public enum AuditSourceMode: String, Codable, Sendable {
    /// Static image file (simulator capture or screenshot)
    case screenshot
    /// Programmatically rendered SwiftUI or UIKit view
    case rendered
}

public struct AuditDimensions: Codable, Sendable, Equatable, Hashable {
    public let width: Double
    public let height: Double
    public let scale: Double

    public init(width: Double, height: Double, scale: Double) {
        self.width = width
        self.height = height
        self.scale = scale
    }
}

public struct AuditSummary: Codable, Sendable, Equatable, Hashable {
    public let totalElements: Int
    public let totalIssues: Int
    public let errorCount: Int
    public let warningCount: Int
    public let worstIssue: String?

    public init(
        totalElements: Int,
        totalIssues: Int,
        errorCount: Int,
        warningCount: Int,
        worstIssue: String?
    ) {
        self.totalElements = totalElements
        self.totalIssues = totalIssues
        self.errorCount = errorCount
        self.warningCount = warningCount
        self.worstIssue = worstIssue
    }
}

/// The unified diagnostic report returned by ViewLens CLI and MCP tools.
public struct AuditReport: Codable, Sendable, Equatable, Hashable {
    public let sourceMode: AuditSourceMode
    public let image: String?
    public let target: String?
    public let device: String?
    public let dimensions: AuditDimensions?
    public let elements: [DetectedElement]
    public let issues: [ViewLensIssue]
    public let passed: Bool
    public let summary: AuditSummary

    public init(
        sourceMode: AuditSourceMode,
        image: String? = nil,
        target: String? = nil,
        device: String? = nil,
        dimensions: AuditDimensions? = nil,
        elements: [DetectedElement],
        issues: [ViewLensIssue]
    ) {
        self.sourceMode = sourceMode
        self.image = image
        self.target = target
        self.device = device
        self.dimensions = dimensions
        self.elements = elements
        self.issues = issues

        let errors = issues.filter { $0.severity == .error }
        let warnings = issues.filter { $0.severity == .warning }
        self.passed = errors.isEmpty

        let worst = errors.first?.description ?? warnings.first?.description
        self.summary = AuditSummary(
            totalElements: elements.count,
            totalIssues: issues.count,
            errorCount: errors.count,
            warningCount: warnings.count,
            worstIssue: worst
        )
    }
}
