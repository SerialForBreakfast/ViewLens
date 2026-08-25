import Foundation

/// A declared change set representing modified source files and target template (MCP-17.6).
public struct ChangeSet: Codable, Sendable, Equatable {
    public let changedFiles: [String]
    public let targetTemplate: String
    public let priorReviewID: String?

    public init(
        changedFiles: [String],
        targetTemplate: String,
        priorReviewID: String? = nil
    ) {
        self.changedFiles = changedFiles
        self.targetTemplate = targetTemplate
        self.priorReviewID = priorReviewID
    }
}

/// Comprehensive report comparing before/after findings to prove fix effectiveness without regressions (MCP-17.7, MCP-17.8).
public struct FixVerificationReport: Codable, Sendable, Equatable {
    public let template: String
    public let resolvedIssues: [String]
    public let remainingIssues: [String]
    public let introducedIssues: [String]
    public let notRetested: [String]
    public let hasRegressions: Bool
    public let passed: Bool

    public init(
        template: String,
        resolvedIssues: [String],
        remainingIssues: [String],
        introducedIssues: [String],
        notRetested: [String] = []
    ) {
        self.template = template
        self.resolvedIssues = resolvedIssues
        self.remainingIssues = remainingIssues
        self.introducedIssues = introducedIssues
        self.notRetested = notRetested
        self.hasRegressions = !introducedIssues.isEmpty
        self.passed = remainingIssues.isEmpty && introducedIssues.isEmpty
    }
}

/// Engine executing closed-loop verification of agent-applied source code changes (MCP-17.6 - MCP-17.8).
public enum FixVerifier {

    /// Compares baseline findings against post-fix findings to evaluate fix success and detect regressions.
    public static func verify(
        changeSet: ChangeSet,
        baselineIssues: [String],
        currentIssues: [String]
    ) -> FixVerificationReport {
        let baseSet = Set(baselineIssues)
        let currSet = Set(currentIssues)

        let resolved = baseSet.subtracting(currSet).sorted()
        let remaining = baseSet.intersection(currSet).sorted()
        let introduced = currSet.subtracting(baseSet).sorted()

        return FixVerificationReport(
            template: changeSet.targetTemplate,
            resolvedIssues: resolved,
            remainingIssues: remaining,
            introducedIssues: introduced
        )
    }
}
