import Foundation

/// Individual evaluation result for a specific WCAG Success Criterion.
public struct WCAGCriterionResult: Sendable, Codable, Equatable {
    public let criterion: String
    public let name: String
    public let level: String
    public let passed: Bool
    public let evaluated: Bool
    public let details: String
    public let remediationSnippet: String?

    public init(
        criterion: String,
        name: String,
        level: String,
        passed: Bool,
        evaluated: Bool = true,
        details: String,
        remediationSnippet: String? = nil
    ) {
        self.criterion = criterion
        self.name = name
        self.level = level
        self.passed = passed
        self.evaluated = evaluated
        self.details = details
        self.remediationSnippet = remediationSnippet
    }
}

/// Category scores kept separate from the overall criterion score so CI and agents
/// can identify the weakest accessibility dimension without parsing prose.
public struct AccessibilityMetrics: Sendable, Codable, Equatable {
    public let targetSizeCompliancePercentage: Int?
    public let contrastCompliancePercentage: Int?
    public let dynamicTypeReflowPercentage: Int?
    public let semanticsCompliancePercentage: Int?

    public init(
        targetSizeCompliancePercentage: Int? = nil,
        contrastCompliancePercentage: Int? = nil,
        dynamicTypeReflowPercentage: Int? = nil,
        semanticsCompliancePercentage: Int? = nil
    ) {
        self.targetSizeCompliancePercentage = targetSizeCompliancePercentage
        self.contrastCompliancePercentage = contrastCompliancePercentage
        self.dynamicTypeReflowPercentage = dynamicTypeReflowPercentage
        self.semanticsCompliancePercentage = semanticsCompliancePercentage
    }
}

/// Comprehensive accessibility audit report aligned with W3C WAI Mobile Accessibility & WCAG 2.1 / 2.2 standards.
public struct AccessibilityReport: Sendable, Codable, Equatable {
    public let target: String
    public let targetLevel: String // "AA" or "AAA"
    public let overallComplianceScore: Int // 0 to 100
    public let passed: Bool
    public let complete: Bool
    public let criteria: [WCAGCriterionResult]
    public let issues: [ViewLensIssue]
    public let metrics: AccessibilityMetrics
    public let timestamp: Date

    public init(
        target: String,
        targetLevel: String = "AA",
        overallComplianceScore: Int,
        passed: Bool,
        complete: Bool = true,
        criteria: [WCAGCriterionResult],
        issues: [ViewLensIssue],
        metrics: AccessibilityMetrics = AccessibilityMetrics(),
        timestamp: Date = Date()
    ) {
        self.target = target
        self.targetLevel = targetLevel
        self.overallComplianceScore = overallComplianceScore
        self.passed = passed
        self.complete = complete
        self.criteria = criteria
        self.issues = issues
        self.metrics = metrics
        self.timestamp = timestamp
    }

    /// Formats a concise GitHub markdown summary of the accessibility audit.
    public func formattedMarkdown() -> String {
        var md = """
        ## ♿ ViewLens W3C / WCAG 2.2 Accessibility Audit Report

        **Target:** `\(target)`  
        **Target Compliance Level:** `WCAG 2.2 Level \(targetLevel)`  
        **Status:** \(passed ? "✅ COMPLIANT (Score: \(overallComplianceScore)%)" : "❌ NON-COMPLIANT (Score: \(overallComplianceScore)%)")

        ### 📋 WCAG 2.2 Success Criteria Evaluation

        | Criterion | Level | Description | Status | Findings |
        |---|---|---|---|---|

        """

        for c in criteria {
            let statusBadge = !c.evaluated ? "⚪ Not evaluated" : (c.passed ? "✅ Pass" : "❌ Fail")
            md += "| **\(c.criterion)** | `\(c.level)` | \(c.name) | \(statusBadge) | \(c.details) |\n"
        }

        if !issues.isEmpty {
            md += "\n### ⚠️ Detected Non-Compliance Issues & Remediation\n\n"
            for (idx, issue) in issues.enumerated() {
                let badge = issue.severity == .error ? "🔴 [ERROR]" : "🟠 [WARNING]"
                let wcagTag = issue.wcagCriterion.map { " (\($0))" } ?? ""
                md += "\(idx + 1). \(badge)**\(issue.kind.rawValue)**\(wcagTag): \(issue.description)\n"
                if let snippet = issue.remediation?.codeSnippet {
                    md += "   ```swift\n   \(snippet)\n   ```\n"
                }
            }
        }

        return md
    }
}
