import Foundation

public struct TableFormatter: Sendable {
    public static func format(report: AuditReport) -> String {
        var lines: [String] = []

        lines.append("════════════════════════════════════════════════════════════════════════")
        let title = report.image ?? report.target ?? "ViewLens UI Audit Report"
        lines.append("🔍 ViewLens Audit: \(title)")
        if let dims = report.dimensions {
            lines.append("📐 Dimensions: \(Int(dims.width))x\(Int(dims.height))px (@\(Int(dims.scale))x)")
        }
        lines.append("────────────────────────────────────────────────────────────────────────")

        // Elements Table
        lines.append("\n📦 Detected UI Elements (\(report.elements.count)):")
        if report.elements.isEmpty {
            lines.append("  (No UI elements detected)")
        } else {
            lines.append(String(format: "  %-4@ %-18@ %-12@ %-30@", "#", "Type", "Confidence", "Bounding Box [x, y, w, h]"))
            lines.append("  " + String(repeating: "─", count: 66))

            for (idx, elem) in report.elements.enumerated() {
                let box = elem.boundingBox
                let boxStr = String(format: "[%.2f, %.2f, %.2f, %.2f]", box.x, box.y, box.width, box.height)
                let confStr = String(format: "%.1f%%", elem.confidence * 100)
                lines.append(String(format: "  %-4d %-18@ %-12@ %-30@", idx, elem.type, confStr, boxStr))
            }
        }

        // Issues Section
        lines.append("\n⚠️ Layout & HIG Violations (\(report.issues.count)):")
        if report.issues.isEmpty {
            lines.append("  ✅ All checks passed! Layout is fully HIG compliant.")
        } else {
            for (idx, issue) in report.issues.enumerated() {
                let icon = issue.severity == .error ? "❌" : (issue.severity == .warning ? "⚠️" : "ℹ️")
                lines.append("  [\(idx + 1)] \(icon) \(issue.kind.rawValue.uppercased()): \(issue.description)")
                if let rem = issue.remediation {
                    lines.append("      💡 Remediation: \(rem.description)")
                    if let snippet = rem.codeSnippet {
                        lines.append("         Code: \(snippet)")
                    }
                }
            }
        }

        lines.append("────────────────────────────────────────────────────────────────────────")
        let statusStr = report.passed ? "✅ PASSED" : "❌ FAILED"
        lines.append("Result: \(statusStr) (\(report.summary.errorCount) errors, \(report.summary.warningCount) warnings)")
        lines.append("════════════════════════════════════════════════════════════════════════")

        return lines.joined(separator: "\n")
    }
}
