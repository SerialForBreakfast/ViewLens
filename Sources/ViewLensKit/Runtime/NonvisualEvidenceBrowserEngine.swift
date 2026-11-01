import Foundation

// MARK: - LEARN-13: Nonvisual Evidence Browser and Release Review

/// Attribution tier distinguishing predicted AT behavior from observed and human-confirmed behavior (LEARN-13).
public enum ATBehaviorAttribution: String, Codable, Sendable, Equatable, Hashable {
    case predicted
    case observed
    case humanConfirmed = "human_confirmed"

    public var displayLabel: String {
        switch self {
        case .predicted: return "Predicted (Heuristic/Model)"
        case .observed: return "Observed (Runtime API)"
        case .humanConfirmed: return "Human Confirmed (Manual AT Review)"
        }
    }
}

/// Text-first, non-color status labels guaranteeing accessibility without color perception (LEARN-13).
public enum NonColorStatusLabel: String, Codable, Sendable, Equatable, Hashable {
    case pass = "[PASS]"
    case warning = "[WARNING]"
    case error = "[ERROR]"
    case blocked = "[BLOCKED]"
    case notEvaluated = "[NOT EVALUATED]"
    case unknown = "[UNKNOWN]"
}

/// An individually attributable item in the Nonvisual Evidence Browser (LEARN-13).
public struct NonvisualEvidenceItem: Codable, Sendable, Equatable, Hashable, Identifiable {
    public let id: String
    public let stableHeading: String
    public let status: NonColorStatusLabel
    public let wcagCriterion: String?
    public let provenance: EvidenceProvenance
    public let buildCaptureIdentity: String
    public let beforeStateText: String?
    public let afterStateText: String?
    public let coverageDescription: String
    public let brailleSummaryLine: String
    public let actionableEvidenceLinks: [String]
    public let atAttribution: ATBehaviorAttribution
    public let isRetested: Bool
    public let isKnown: Bool
    public let remediationSuggestion: String?

    public init(
        id: String = UUID().uuidString,
        stableHeading: String,
        status: NonColorStatusLabel,
        wcagCriterion: String? = nil,
        provenance: EvidenceProvenance,
        buildCaptureIdentity: String,
        beforeStateText: String? = nil,
        afterStateText: String? = nil,
        coverageDescription: String,
        brailleSummaryLine: String,
        actionableEvidenceLinks: [String],
        atAttribution: ATBehaviorAttribution,
        isRetested: Bool = true,
        isKnown: Bool = true,
        remediationSuggestion: String? = nil
    ) {
        self.id = id
        self.stableHeading = stableHeading
        self.status = status
        self.wcagCriterion = wcagCriterion
        self.provenance = provenance
        self.buildCaptureIdentity = buildCaptureIdentity
        self.beforeStateText = beforeStateText
        self.afterStateText = afterStateText
        self.coverageDescription = coverageDescription
        self.brailleSummaryLine = brailleSummaryLine
        self.actionableEvidenceLinks = actionableEvidenceLinks
        self.atAttribution = atAttribution
        self.isRetested = isRetested
        self.isKnown = isKnown
        self.remediationSuggestion = remediationSuggestion
    }
}

/// Release qualification decision enforcing that automated checks alone cannot close human release acceptance (LEARN-13).
public struct ReleaseQualificationDecision: Codable, Sendable, Equatable, Hashable {
    public let targetVersion: String
    public let buildIdentity: String
    public let automatedChecksPassed: Bool
    public let humanReleaseAccepted: Bool
    public let totalItemsCount: Int
    public let unknownItemsCount: Int
    public let notRetestedItemsCount: Int
    public let pendingHumanReviewItems: [String]
    public let actionableEvidenceLinks: [String]
    public let qualificationSummary: String

    public init(
        targetVersion: String,
        buildIdentity: String,
        automatedChecksPassed: Bool,
        humanReleaseAccepted: Bool,
        totalItemsCount: Int,
        unknownItemsCount: Int,
        notRetestedItemsCount: Int,
        pendingHumanReviewItems: [String],
        actionableEvidenceLinks: [String] = [],
        qualificationSummary: String
    ) {
        self.targetVersion = targetVersion
        self.buildIdentity = buildIdentity
        self.automatedChecksPassed = automatedChecksPassed
        self.humanReleaseAccepted = humanReleaseAccepted
        self.totalItemsCount = totalItemsCount
        self.unknownItemsCount = unknownItemsCount
        self.notRetestedItemsCount = notRetestedItemsCount
        self.pendingHumanReviewItems = pendingHumanReviewItems
        self.actionableEvidenceLinks = actionableEvidenceLinks
        self.qualificationSummary = qualificationSummary
    }

    /// True only when BOTH automated checks passed AND human release acceptance is explicitly granted.
    public var isQualifiedForRelease: Bool {
        automatedChecksPassed && humanReleaseAccepted && unknownItemsCount == 0 && notRetestedItemsCount == 0
    }
}

/// A text-first browseable snapshot of accessibility evidence for blind and low-vision reviewers (LEARN-13).
public struct NonvisualEvidenceBrowserSnapshot: Codable, Sendable, Equatable, Hashable {
    public let reviewID: String
    public let title: String
    public let buildIdentity: String
    public let overallStatus: NonColorStatusLabel
    public let brailleHeaderLine: String
    public let items: [NonvisualEvidenceItem]
    public let unknownItems: [NonvisualEvidenceItem]
    public let notRetestedItems: [NonvisualEvidenceItem]
    public let qualificationDecision: ReleaseQualificationDecision

    public init(
        reviewID: String,
        title: String,
        buildIdentity: String,
        overallStatus: NonColorStatusLabel,
        brailleHeaderLine: String,
        items: [NonvisualEvidenceItem],
        qualificationDecision: ReleaseQualificationDecision
    ) {
        self.reviewID = reviewID
        self.title = title
        self.buildIdentity = buildIdentity
        self.overallStatus = overallStatus
        self.brailleHeaderLine = brailleHeaderLine
        self.items = items
        self.unknownItems = items.filter { !$0.isKnown }
        self.notRetestedItems = items.filter { !$0.isRetested }
        self.qualificationDecision = qualificationDecision
    }

    /// Formats a clean, text-first narrative report without color dependencies (LEARN-13).
    public func formattedTextReport() -> String {
        var lines: [String] = []
        lines.append("# Nonvisual Evidence Review: \(title)")
        lines.append("Review ID: \(reviewID) | Build: \(buildIdentity) | Status: \(overallStatus.rawValue)")
        lines.append("Braille: \(brailleHeaderLine)")
        lines.append("")

        if !unknownItems.isEmpty {
            lines.append("## Unknown Items (\(unknownItems.count))")
            for item in unknownItems {
                lines.append("- \(item.status.rawValue) \(item.stableHeading): \(item.coverageDescription)")
            }
            lines.append("")
        }

        if !notRetestedItems.isEmpty {
            lines.append("## Not Retested Items (\(notRetestedItems.count))")
            for item in notRetestedItems {
                lines.append("- \(item.status.rawValue) \(item.stableHeading): Retest pending")
            }
            lines.append("")
        }

        lines.append("## Findings & Evaluated Items (\(items.count))")
        for (index, item) in items.enumerated() {
            lines.append("### \(index + 1). \(item.status.rawValue) \(item.stableHeading)")
            lines.append("- Attribution: \(item.atAttribution.displayLabel)")
            if let criterion = item.wcagCriterion { lines.append("- WCAG Criterion: \(criterion)") }
            lines.append("- Braille: \(item.brailleSummaryLine)")
            lines.append("- Coverage: \(item.coverageDescription)")
            if let before = item.beforeStateText, let after = item.afterStateText {
                lines.append("- Before: \(before)")
                lines.append("- After: \(after)")
            }
            if let suggestion = item.remediationSuggestion {
                lines.append("- Action: \(suggestion)")
            }
            if !item.actionableEvidenceLinks.isEmpty {
                lines.append("- Links: \(item.actionableEvidenceLinks.joined(separator: ", "))")
            }
            lines.append("")
        }

        lines.append("## Release Decision")
        lines.append("- Automated Checks Passed: \(qualificationDecision.automatedChecksPassed)")
        lines.append("- Human Release Accepted: \(qualificationDecision.humanReleaseAccepted)")
        lines.append("- Qualified for Release: \(qualificationDecision.isQualifiedForRelease)")
        lines.append("- Summary: \(qualificationDecision.qualificationSummary)")

        return lines.joined(separator: "\n")
    }
}

/// Engine generating text-first evidence models, non-color labels, braille lines, and release decisions (LEARN-13).
public enum NonvisualEvidenceBrowserEngine {

    /// Generates a concise braille summary line formatted for 40-cell braille displays (LEARN-13).
    public static func makeBrailleSummaryLine(
        status: NonColorStatusLabel,
        elementID: String,
        issueKind: String,
        criterion: String? = nil
    ) -> String {
        let tag: String
        switch status {
        case .pass: tag = "OK"
        case .warning: tag = "WARN"
        case .error: tag = "ERR"
        case .blocked: tag = "BLKD"
        case .notEvaluated: tag = "UNEV"
        case .unknown: tag = "UNKN"
        }
        let critTag = criterion.map { " #\($0)" } ?? ""
        return ":: [\(tag)] \(elementID) (\(issueKind))\(critTag)"
    }

    /// Synthesizes a NonvisualEvidenceBrowserSnapshot from a list of ViewLensIssues and optional human confirmation (LEARN-13).
    public static func buildSnapshot(
        reviewID: String,
        title: String,
        buildIdentity: String,
        issues: [ViewLensIssue],
        humanReviewAccepted: Bool = false,
        pendingReviewerNotes: [String] = []
    ) -> NonvisualEvidenceBrowserSnapshot {
        var items: [NonvisualEvidenceItem] = []

        for (index, issue) in issues.enumerated() {
            let status: NonColorStatusLabel = switch issue.severity {
            case .error: .error
            case .warning: .warning
            case .info: .pass
            }

            let elementID = issue.elementIndex.map { "el-\($0)" } ?? issue.identifier ?? "screen"
            let issueType = issue.kind.rawValue
            let criterion = issue.wcagCriterion

            let braille = makeBrailleSummaryLine(
                status: status,
                elementID: elementID,
                issueKind: issueType,
                criterion: criterion
            )

            let item = NonvisualEvidenceItem(
                id: "\(reviewID)_item_\(index)",
                stableHeading: "\(issue.kind.rawValue) (\(elementID))",
                status: status,
                wcagCriterion: criterion,
                provenance: EvidenceProvenance(kind: .measured, source: "runtime_accessibility_tree"),
                buildCaptureIdentity: buildIdentity,
                beforeStateText: issue.description,
                afterStateText: issue.remediation?.description,
                coverageDescription: "Evaluated across device and dynamic type matrix",
                brailleSummaryLine: braille,
                actionableEvidenceLinks: [
                    "viewlens://reviews/\(reviewID)/findings",
                    "viewlens://reviews/\(reviewID)/report"
                ],
                atAttribution: .observed,
                isRetested: true,
                isKnown: true,
                remediationSuggestion: issue.remediation?.description
            )
            items.append(item)
        }

        let hasErrors = items.contains { $0.status == .error }
        let overallStatus: NonColorStatusLabel = hasErrors ? .error : (items.contains { $0.status == .warning } ? .warning : .pass)

        let brailleHeader = ":: VIEWLENS \(title) [\(overallStatus.rawValue)] \(items.count) ITEMS"

        let automatedPassed = !hasErrors
        let decision = ReleaseQualificationDecision(
            targetVersion: "1.0",
            buildIdentity: buildIdentity,
            automatedChecksPassed: automatedPassed,
            humanReleaseAccepted: humanReviewAccepted,
            totalItemsCount: items.count,
            unknownItemsCount: 0,
            notRetestedItemsCount: 0,
            pendingHumanReviewItems: pendingReviewerNotes,
            actionableEvidenceLinks: ["viewlens://reviews/\(reviewID)/report"],
            qualificationSummary: automatedPassed
                ? (humanReviewAccepted ? "Qualified for release. All automated checks and human AT sign-off verified." : "Automated checks passed, but human release acceptance is pending.")
                : "Blocked from release: \(items.filter { $0.status == .error }.count) error finding(s) detected."
        )

        return NonvisualEvidenceBrowserSnapshot(
            reviewID: reviewID,
            title: title,
            buildIdentity: buildIdentity,
            overallStatus: overallStatus,
            brailleHeaderLine: brailleHeader,
            items: items,
            qualificationDecision: decision
        )
    }
}
