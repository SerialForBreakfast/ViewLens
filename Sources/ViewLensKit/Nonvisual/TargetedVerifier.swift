import Foundation

/// Status of a targeted fix verification run.
public enum TargetedVerificationStatus: String, Codable, Sendable, Equatable, Hashable {
    case fullyResolved = "fully_resolved"
    case partiallyResolved = "partially_resolved"
    case regressed = "regressed"
    case unaltered = "unaltered"
}

/// Comprehensive outcome of running targeted verification on a modified component.
public struct TargetedVerificationResult: Codable, Sendable, Equatable {
    public let componentName: String
    public let status: TargetedVerificationStatus
    public let resolvedIssues: [ViewLensIssue]
    public let remainingIssues: [ViewLensIssue]
    public let introducedIssues: [ViewLensIssue]
    public let notEvaluatedIssues: [ViewLensIssue]
    public let scoreBefore: Int
    public let scoreAfter: Int

    public init(
        componentName: String,
        status: TargetedVerificationStatus,
        resolvedIssues: [ViewLensIssue] = [],
        remainingIssues: [ViewLensIssue] = [],
        introducedIssues: [ViewLensIssue] = [],
        notEvaluatedIssues: [ViewLensIssue] = [],
        scoreBefore: Int,
        scoreAfter: Int
    ) {
        self.componentName = componentName
        self.status = status
        self.resolvedIssues = resolvedIssues
        self.remainingIssues = remainingIssues
        self.introducedIssues = introducedIssues
        self.notEvaluatedIssues = notEvaluatedIssues
        self.scoreBefore = scoreBefore
        self.scoreAfter = scoreAfter
    }

    public var passed: Bool {
        status == .fullyResolved && introducedIssues.isEmpty
    }

    public func formattedSummary(profile: NonvisualPresentationProfile = .speech) -> String {
        switch profile {
        case .speech:
            var speech = "Verification for '\(componentName)': "
            switch status {
            case .fullyResolved:
                speech += "All \(resolvedIssues.count) accessibility issue(s) fully resolved! Score increased from \(scoreBefore) to \(scoreAfter)."
            case .partiallyResolved:
                speech += "\(resolvedIssues.count) issue(s) resolved, \(remainingIssues.count) remaining. Score \(scoreBefore) -> \(scoreAfter)."
            case .regressed:
                speech += "Warning: \(introducedIssues.count) new issue(s) introduced! Score decreased from \(scoreBefore) to \(scoreAfter)."
            case .unaltered:
                speech += "No change in issue status. Score remains \(scoreAfter)."
            }
            return speech

        case .braille:
            return "VER [\(componentName): \(status.rawValue.uppercased()) | Res: +\(resolvedIssues.count), Rem: \(remainingIssues.count), Reg: -\(introducedIssues.count)]"

        case .developer:
            var lines: [String] = [
                "=== Targeted Fix Verification: \(componentName) ===",
                "Status: \(status.rawValue) (Score: \(scoreBefore) -> \(scoreAfter))",
                "Resolved Issues (\(resolvedIssues.count)):",
            ]
            for r in resolvedIssues {
                lines.append("  ✓ [\(r.kind.rawValue)] \(r.description)")
            }
            if !remainingIssues.isEmpty {
                lines.append("Remaining Issues (\(remainingIssues.count)):")
                for rem in remainingIssues {
                    lines.append("  • [\(rem.kind.rawValue)] \(rem.description)")
                }
            }
            if !introducedIssues.isEmpty {
                lines.append("Introduced Regressions (\(introducedIssues.count)):")
                for intro in introducedIssues {
                    lines.append("  ✗ [\(intro.kind.rawValue)] \(intro.description)")
                }
            }
            return lines.joined(separator: "\n")
        }
    }
}

/// Verification engine that compares before/after audit reports to validate accessibility patches.
public enum TargetedVerifier {

    public static func verify(
        componentName: String,
        beforeReport: AuditReport,
        afterReport: AuditReport
    ) -> TargetedVerificationResult {
        let beforeIssues = beforeReport.issues
        let afterIssues = afterReport.issues

        let beforeKeys = Set(beforeIssues.map(issueKey(_:)))
        let afterKeys = Set(afterIssues.map(issueKey(_:)))

        let resolved = beforeIssues.filter { !afterKeys.contains(issueKey($0)) }
        let introduced = afterIssues.filter { !beforeKeys.contains(issueKey($0)) }
        let remaining = afterIssues.filter { beforeKeys.contains(issueKey($0)) }

        let scoreBefore = calculateScore(issues: beforeIssues)
        let scoreAfter = calculateScore(issues: afterIssues)

        let status: TargetedVerificationStatus
        if !introduced.isEmpty {
            status = .regressed
        } else if beforeIssues.isEmpty && afterIssues.isEmpty {
            status = .fullyResolved
        } else if remaining.isEmpty && !resolved.isEmpty {
            status = .fullyResolved
        } else if !resolved.isEmpty && !remaining.isEmpty {
            status = .partiallyResolved
        } else {
            status = .unaltered
        }

        return TargetedVerificationResult(
            componentName: componentName,
            status: status,
            resolvedIssues: resolved,
            remainingIssues: remaining,
            introducedIssues: introduced,
            notEvaluatedIssues: [],
            scoreBefore: scoreBefore,
            scoreAfter: scoreAfter
        )
    }

    private static func issueKey(_ issue: ViewLensIssue) -> String {
        "\(issue.kind.rawValue):\(issue.identifier ?? ""):\(issue.elementIndex ?? -1):\(issue.description)"
    }

    private static func calculateScore(issues: [ViewLensIssue]) -> Int {
        var score = 100
        for issue in issues {
            switch issue.severity {
            case .error: score -= 15
            case .warning: score -= 5
            case .info: score -= 1
            }
        }
        return max(0, min(100, score))
    }
}
