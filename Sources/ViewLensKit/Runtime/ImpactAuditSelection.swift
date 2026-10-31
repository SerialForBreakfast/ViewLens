import Foundation

/// Shared selection policy for gates, MCP verification, and the desktop dashboard.
public struct ImpactAuditSelection: Codable, Sendable, Equatable {
    public let impact: ChangeImpactReport
    public let templates: [String]
    public let unregisteredRoots: [String]
    public let usesFallback: Bool
    public let explanation: String

    public var coverageAvailable: Bool {
        impact.completeness == .complete && unregisteredRoots.isEmpty && !templates.isEmpty
    }

    public static func select(workspaceRoot: String, changedFiles: [String], availableTemplates: [String]) -> Self {
        let impact = ChangeImpactAnalyzer.analyze(workspaceRoot: workspaceRoot, changedFiles: changedFiles)
        let available = Set(availableTemplates)
        let roots = Set(impact.affectedRootViews.map(\.symbol))
        let missing = roots.subtracting(available).sorted()
        // Partial discovery and unresolved changes require broad coverage of the known registry.
        let fallback = impact.completeness != .complete || roots.isEmpty || !missing.isEmpty
        let templates = (fallback ? available : roots.intersection(available)).sorted()
        return Self(
            impact: impact, templates: templates, unregisteredRoots: missing, usesFallback: fallback,
            explanation: fallback
                ? "Impact coverage is incomplete. Audit all registered templates; affected unregistered views remain not retested."
                : "Audit registered affected root views selected by the source and resource dependency graph."
        )
    }
}
