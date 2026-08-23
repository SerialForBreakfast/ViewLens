import Foundation

/// Generates GitHub-flavored Markdown reports for CI/CD Pull Request summaries.
public struct PRSummaryGenerator: Sendable {
    public static func generateMarkdown(
        gateName: String,
        config: GateConfig,
        matrixReport: MatrixAuditReport,
        evaluation: GateEvaluationResult
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

        lines.append("---")
        lines.append("*Generated automatically by [ViewLens](https://github.com/SerialForBreakfast/ViewLens) Pure Swift Agent Engine.*")

        return lines.joined(separator: "\n")
    }
}
