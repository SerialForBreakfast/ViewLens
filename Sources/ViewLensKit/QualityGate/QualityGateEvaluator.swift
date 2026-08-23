import Foundation

/// Result of evaluating an audit against a specific Git Hook / CI Gate policy.
public struct GateEvaluationResult: Sendable, Codable {
    public let gateName: String
    public let passed: Bool
    public let failureReason: String?
    public let totalPermutations: Int
    public let totalFilteredIssues: Int
    public let errorCount: Int
    public let warningCount: Int

    public init(
        gateName: String,
        passed: Bool,
        failureReason: String? = nil,
        totalPermutations: Int,
        totalFilteredIssues: Int,
        errorCount: Int,
        warningCount: Int
    ) {
        self.gateName = gateName
        self.passed = passed
        self.failureReason = failureReason
        self.totalPermutations = totalPermutations
        self.totalFilteredIssues = totalFilteredIssues
        self.errorCount = errorCount
        self.warningCount = warningCount
    }
}

/// Evaluates MatrixAuditReports against declarative GateConfig rules and severity thresholds.
public struct QualityGateEvaluator: Sendable {
    public static func evaluate(
        gateName: String,
        config: GateConfig,
        matrixReport: MatrixAuditReport
    ) -> GateEvaluationResult {
        var totalErrors = 0
        var totalWarnings = 0
        var totalFilteredIssues = 0

        for (_, report) in matrixReport.permutations {
            for issue in report.issues {
                guard isIssueRelevantToPurposes(issue, purposes: config.purposes) else {
                    continue
                }

                totalFilteredIssues += 1
                if issue.severity == .error {
                    totalErrors += 1
                } else if issue.severity == .warning {
                    totalWarnings += 1
                }
            }
        }

        let passed: Bool
        let failureReason: String?

        switch config.failOn {
        case .error:
            passed = (totalErrors == 0)
            failureReason = passed ? nil : "\(totalErrors) error-level HIG violation(s) detected."
        case .warning:
            passed = (totalErrors == 0 && totalWarnings == 0)
            failureReason = passed ? nil : "\(totalErrors) error(s) and \(totalWarnings) warning(s) detected under strict policy."
        case .none:
            passed = true
            failureReason = nil
        }

        return GateEvaluationResult(
            gateName: gateName,
            passed: passed,
            failureReason: failureReason,
            totalPermutations: matrixReport.summary.totalPermutations,
            totalFilteredIssues: totalFilteredIssues,
            errorCount: totalErrors,
            warningCount: totalWarnings
        )
    }

    private static func isIssueRelevantToPurposes(_ issue: ViewLensIssue, purposes: [AuditPurpose]) -> Bool {
        if purposes.isEmpty { return true }

        for purpose in purposes {
            switch purpose {
            case .touchTargets:
                if issue.kind == .tappableTargetTooSmall { return true }
            case .clipping:
                if issue.kind == .clippedElement || issue.kind == .textTruncated { return true }
            case .accessibility:
                if issue.kind == .missingAccessibilityLabel { return true }
            case .autolayout:
                if issue.kind == .ambiguousAutoLayout { return true }
            case .darkMode:
                return true
            }
        }

        return false
    }
}
