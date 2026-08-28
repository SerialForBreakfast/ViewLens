import Foundation

/// Generates GitHub-flavored Markdown reports for CI/CD Pull Request summaries.
public struct PRSummaryGenerator: Sendable {
    public static func generateMarkdown(
        gateName: String,
        config: GateConfig,
        matrixReport: MatrixAuditReport,
        evaluation: GateEvaluationResult,
        environmentParity: [String: String]? = nil
    ) -> String {
        var lines: [String] = []

        let badge = evaluation.passed ? "✅ PASSED" : "❌ FAILED"
        lines.append("# 🔍 ViewLens UI Quality Gate: \(badge)")
        lines.append("")
        lines.append("**Gate**: `\(gateName)` | **Policy**: `fail_on: \(config.failOn.rawValue)` | **Template**: `\(matrixReport.template)`")
        lines.append("")

        if let reason = evaluation.failureReason {
            lines.append("> ⚠️ **Quality Gate Alert**: \(reason)")
            lines.append("")
        }

        // Matrix Permutations Table
        lines.append("### 📐 Device & Appearance Matrix (\(matrixReport.summary.totalPermutations) Permutations)")
        lines.append("")
        lines.append("| Matrix Variant | Target Device | Dimensions | Status | Issues |")
        lines.append("|---|---|---|---|---|")

        for (key, report) in matrixReport.permutations.sorted(by: { $0.key < $1.key }) {
            let statusIcon = report.passed ? "✅ Pass" : "❌ Fail"
            let dimStr = report.dimensions.map { "\(Int($0.width))×\(Int($0.height))px @\(Int($0.scale))x" } ?? "N/A"
            let deviceStr = report.device ?? "Default"
            let issueCountStr = report.issues.isEmpty ? "0" : "**\(report.issues.count)**"
            lines.append("| `\(key)` | \(deviceStr) | \(dimStr) | \(statusIcon) | \(issueCountStr) |")
        }
        lines.append("")

        // Issues and Suggested Remediation Details
        var allIssuesWithVariant: [(variant: String, issue: ViewLensIssue)] = []
        for (key, report) in matrixReport.permutations.sorted(by: { $0.key < $1.key }) {
            for issue in report.issues {
                allIssuesWithVariant.append((variant: key, issue: issue))
            }
        }

        if !allIssuesWithVariant.isEmpty {
            lines.append("### 🛠️ Detected Defects & Suggested SwiftUI Fixes")
            lines.append("")
            lines.append("<details open>")
            lines.append("<summary><b>View \(allIssuesWithVariant.count) Detected Issue(s)</b></summary>")
            lines.append("")

            for item in allIssuesWithVariant {
                let severityIcon = item.issue.severity == .error ? "🔴 Error" : "🟠 Warning"
                lines.append("#### [\(severityIcon)] `\(item.issue.kind.rawValue)` on `\(item.variant)`")
                lines.append("- **Description**: \(item.issue.description)")
                if let remediation = item.issue.remediation {
                    lines.append("- **Guidance**: \(remediation.description)")
                    if let code = remediation.codeSnippet {
                        lines.append("```swift")
                        lines.append(code)
                        lines.append("```")
                    }
                }
                lines.append("")
            }

            lines.append("</details>")
            lines.append("")
        } else {
            lines.append("✨ **All HIG checks passed across all device and Dynamic Type permutations.**")
            lines.append("")
        }

        if let fixVerification = evaluation.fixVerification {
            lines.append("### \u{1F501} Fix Verification")
            lines.append("")
            lines.append("| | Count |")
            lines.append("|---|---|")
            lines.append("| \u{2705} Resolved | \(fixVerification.resolvedIssues.count) |")
            lines.append("| \u{26A0}\u{FE0F} Remaining | \(fixVerification.remainingIssues.count) |")
            lines.append("| \u{1F6A8} Introduced (regressions) | \(fixVerification.introducedIssues.count) |")
            lines.append("| \u{23ED}\u{FE0F} Not retested | \(fixVerification.notRetested.count) |")
            lines.append("")

            if let sourceRecords = evaluation.sourceRecords, !sourceRecords.isEmpty {
                let available = sourceRecords.filter { $0.confidence != .unavailable }
                let unavailableCount = sourceRecords.count - available.count

                if !available.isEmpty {
                    lines.append("**Source-linked evidence:**")
                    for record in available {
                        let location = record.filePath.map { path in "\(path)\(record.line.map { ":\($0)" } ?? "")" } ?? "unavailable"
                        lines.append("- `\(record.elementID)` \u{2192} `\(location)` (confidence: \(record.confidence.rawValue))")
                    }
                    lines.append("")
                }
                // Uninstrumented targets are never given a fabricated file/line — surfaced only
                // as a count, matching SourceProvenanceEngine's own honesty guarantee.
                if unavailableCount > 0 {
                    lines.append("*\(unavailableCount) finding(s) had no available source location.*")
                    lines.append("")
                }
            }
        }

        if let environmentParity, !environmentParity.isEmpty {
            lines.append("### \u{1F5A5}\u{FE0F} Environment Parity")
            lines.append("")
            lines.append("| Property | Value |")
            lines.append("|---|---|")
            for (key, value) in environmentParity.sorted(by: { $0.key < $1.key }) {
                lines.append("| \(key) | \(value) |")
            }
            lines.append("")
        }

        lines.append("---")
        lines.append("*Generated automatically by [ViewLens](https://github.com/SerialForBreakfast/ViewLens) Pure Swift Agent Engine.*")

        return lines.joined(separator: "\n")
    }
}
