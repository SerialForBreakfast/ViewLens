import Foundation

public enum NonvisualPresentationProfile: String, Codable, Sendable, Equatable, Hashable {
    case speech
    case braille
    case developer
}

public enum NonvisualStatementCategory: String, Codable, Sendable, Equatable, Hashable {
    case purpose
    case overview
    case region
    case finding
    case completeness
    case recommendation
    case element
    case relationship
    case navigation
}

/// A single independently attributable assertion in a nonvisual presentation.
public struct NonvisualStatement: Codable, Sendable, Equatable, Hashable {
    public let id: NonvisualID
    public let category: NonvisualStatementCategory
    public let text: String
    public let relatedIDs: [NonvisualID]
    public let evidence: EvidenceProvenance

    public init(
        id: NonvisualID,
        category: NonvisualStatementCategory,
        text: String,
        relatedIDs: [NonvisualID] = [],
        evidence: EvidenceProvenance
    ) {
        self.id = id
        self.category = category
        self.text = text
        self.relatedIDs = relatedIDs.sorted()
        self.evidence = evidence
    }
}

public enum NonvisualEvidenceStatus: String, Codable, Sendable, Equatable, Hashable {
    case complete
    case partial
    case unavailable
}

public struct NonvisualEvidenceCompleteness: Codable, Sendable, Equatable, Hashable {
    public let visual: NonvisualEvidenceStatus
    public let semantics: NonvisualEvidenceStatus
    public let navigation: NonvisualEvidenceStatus

    public init(
        visual: NonvisualEvidenceStatus,
        semantics: NonvisualEvidenceStatus,
        navigation: NonvisualEvidenceStatus
    ) {
        self.visual = visual
        self.semantics = semantics
        self.navigation = navigation
    }
}

public struct NonvisualScreenSummary: Codable, Sendable, Equatable, Hashable {
    public let screenID: NonvisualID
    public let title: String
    public let regionCount: Int
    public let elementCount: Int
    public let interactiveElementCount: Int
    public let blockingFindingIDs: [NonvisualID]
    public let completeness: NonvisualEvidenceCompleteness
    public let recommendedTargetID: NonvisualID?
    public let statements: [NonvisualStatement]

    public init(
        screenID: NonvisualID,
        title: String,
        regionCount: Int,
        elementCount: Int,
        interactiveElementCount: Int,
        blockingFindingIDs: [NonvisualID],
        completeness: NonvisualEvidenceCompleteness,
        recommendedTargetID: NonvisualID?,
        statements: [NonvisualStatement]
    ) {
        self.screenID = screenID
        self.title = title
        self.regionCount = regionCount
        self.elementCount = elementCount
        self.interactiveElementCount = interactiveElementCount
        self.blockingFindingIDs = blockingFindingIDs
        self.completeness = completeness
        self.recommendedTargetID = recommendedTargetID
        self.statements = statements
    }
}

public enum NonvisualSummaryComposer {
    public static func compose(
        _ model: NonvisualScreenModel,
        maximumBlockingFindings: Int = 5
    ) -> NonvisualScreenSummary {
        let title = normalized(model.title) ?? "Untitled screen"
        let findings = model.mismatches.sorted(by: findingSort)
        let blocking = Array(findings.prefix(min(max(maximumBlockingFindings, 0), 20)))
        let recommendedTarget = blocking.first?.elementIDs.first ?? model.elements.first?.id
        let completeness = NonvisualEvidenceCompleteness(
            visual: status(model.elements.map(\.visualEvidence)),
            semantics: status(model.elements.map(\.semanticEvidence)),
            navigation: status(model.navigationSequences.map(\.evidence))
        )

        var statements: [NonvisualStatement] = [
            NonvisualStatement(
                id: NonvisualID("statement:\(model.id.rawValue):purpose"),
                category: .purpose,
                text: "Purpose is not explicitly provided. Screen title: \(title).",
                relatedIDs: [model.id],
                evidence: .unavailable(
                    source: "viewlens.screen_purpose",
                    detail: "The nonvisual schema does not currently include an explicitly authored task purpose."
                )
            ),
            NonvisualStatement(
                id: NonvisualID("statement:\(model.id.rawValue):overview"),
                category: .overview,
                text: "\(title) contains \(model.regions.count) \(noun("region", model.regions.count)) and \(model.elements.count) \(noun("element", model.elements.count)); \(model.elements.filter(\.isInteractive).count) are interactive.",
                relatedIDs: [model.id],
                evidence: EvidenceProvenance(kind: .derived, source: "viewlens.screen_summary")
            )
        ]

        for region in model.regions.sorted(by: { $0.id < $1.id }) {
            let role = normalized(region.role).map { ", role \($0)" } ?? ""
            statements.append(NonvisualStatement(
                id: NonvisualID("statement:\(region.id.rawValue):region"),
                category: .region,
                text: "Region \(region.label)\(role), with \(region.elementIDs.count) \(noun("element", region.elementIDs.count)).",
                relatedIDs: [region.id] + region.elementIDs,
                evidence: region.evidence
            ))
        }

        statements.append(contentsOf: blocking.map { mismatch in
            NonvisualStatement(
                id: NonvisualID("statement:\(mismatch.id.rawValue):finding"),
                category: .finding,
                text: "\(mismatch.severity.rawValue.capitalized): \(mismatch.description)",
                relatedIDs: [mismatch.id] + mismatch.elementIDs,
                evidence: mismatch.evidence
            )
        })

        statements.append(NonvisualStatement(
            id: NonvisualID("statement:\(model.id.rawValue):completeness"),
            category: .completeness,
            text: "Evidence completeness: visual \(completeness.visual.rawValue), semantics \(completeness.semantics.rawValue), navigation \(completeness.navigation.rawValue).",
            relatedIDs: [model.id],
            evidence: EvidenceProvenance(kind: .derived, source: "viewlens.evidence_completeness")
        ))

        let recommendation: String
        if let first = blocking.first, let target = first.elementIDs.first {
            recommendation = "Next target: \(target.rawValue), to review \(first.kind.rawValue.replacingOccurrences(of: "_", with: " "))."
        } else if let target = recommendedTarget {
            recommendation = "Next target: \(target.rawValue), the first available element."
        } else {
            recommendation = "No navigation target is available."
        }
        statements.append(NonvisualStatement(
            id: NonvisualID("statement:\(model.id.rawValue):recommendation"),
            category: .recommendation,
            text: recommendation,
            relatedIDs: recommendedTarget.map { [$0] } ?? [],
            evidence: EvidenceProvenance(kind: .derived, source: "viewlens.navigation_recommendation")
        ))

        return NonvisualScreenSummary(
            screenID: model.id,
            title: title,
            regionCount: model.regions.count,
            elementCount: model.elements.count,
            interactiveElementCount: model.elements.filter(\.isInteractive).count,
            blockingFindingIDs: blocking.map(\.id),
            completeness: completeness,
            recommendedTargetID: recommendedTarget,
            statements: statements
        )
    }

    private static func status(_ evidence: [EvidenceProvenance]) -> NonvisualEvidenceStatus {
        guard !evidence.isEmpty else { return .unavailable }
        let availableCount = evidence.filter { $0.kind != .unavailable }.count
        if availableCount == 0 { return .unavailable }
        if availableCount == evidence.count { return .complete }
        return .partial
    }

    private static func findingSort(_ lhs: SemanticMismatch, _ rhs: SemanticMismatch) -> Bool {
        let left = severityRank(lhs.severity)
        let right = severityRank(rhs.severity)
        return left == right ? lhs.id < rhs.id : left < right
    }

    private static func severityRank(_ severity: ViewLensSeverity) -> Int {
        switch severity {
        case .error: 0
        case .warning: 1
        case .info: 2
        }
    }

    private static func normalized(_ value: String?) -> String? {
        guard let value = value?.trimmingCharacters(in: .whitespacesAndNewlines), !value.isEmpty else { return nil }
        return value
    }

    private static func noun(_ singular: String, _ count: Int) -> String {
        count == 1 ? singular : "\(singular)s"
    }
}

public enum NonvisualPresentationRenderer {
    public static func render(
        _ summary: NonvisualScreenSummary,
        profile: NonvisualPresentationProfile,
        maximumStatements: Int = 12
    ) -> String {
        let limit = min(max(maximumStatements, 1), 50)
        let statements: [NonvisualStatement]
        switch profile {
        case .speech:
            let preferred: Set<NonvisualStatementCategory> = [.overview, .finding, .completeness, .recommendation]
            let filtered = summary.statements.filter { preferred.contains($0.category) }
            statements = Array((filtered.isEmpty ? summary.statements : filtered).prefix(limit))
        case .braille, .developer:
            statements = Array(summary.statements.prefix(limit))
        }

        switch profile {
        case .speech:
            return statements.map(\.text).joined(separator: " ")
        case .braille:
            return statements.map { "\(brailleCode($0.category)) \($0.text)" }.joined(separator: "\n")
        case .developer:
            return statements.map { statement in
                let confidence = statement.evidence.confidence.map { String(format: "%.2f", $0) } ?? "-"
                let related = statement.relatedIDs.map(\.rawValue).joined(separator: ",")
                return "[\(statement.category.rawValue)] \(statement.id.rawValue) | \(statement.text) | evidence=\(statement.evidence.kind.rawValue):\(statement.evidence.source) confidence=\(confidence) related=\(related.isEmpty ? "-" : related)"
            }.joined(separator: "\n")
        }
    }

    public static func renderElement(
        _ elementID: NonvisualID,
        in model: NonvisualScreenModel,
        profile: NonvisualPresentationProfile,
        maximumRelationships: Int = 5
    ) -> String? {
        guard let element = model.elements.first(where: { $0.id == elementID }) else { return nil }
        let name = element.semantics?.accessibleName ?? element.visibleLabel ?? element.type
        var statements = [NonvisualStatement(
            id: NonvisualID("statement:\(element.id.rawValue):element"),
            category: .element,
            text: "\(name), type \(element.type)\(element.isInteractive ? ", interactive" : "").",
            relatedIDs: [element.id],
            evidence: element.semanticEvidence.kind == .unavailable ? element.visualEvidence : element.semanticEvidence
        )]
        let maximum = min(max(maximumRelationships, 0), 20)
        statements.append(contentsOf: model.relationships
            .filter { $0.subjectID == element.id }
            .sorted { $0.id < $1.id }
            .prefix(maximum)
            .map { relationship in
                NonvisualStatement(
                    id: NonvisualID("statement:\(relationship.id.rawValue)"),
                    category: .relationship,
                    text: relationship.description,
                    relatedIDs: [relationship.subjectID, relationship.objectID],
                    evidence: relationship.evidence
                )
            })
        let summary = NonvisualScreenSummary(
            screenID: model.id,
            title: name,
            regionCount: 0,
            elementCount: 1,
            interactiveElementCount: element.isInteractive ? 1 : 0,
            blockingFindingIDs: [],
            completeness: NonvisualEvidenceCompleteness(visual: .complete, semantics: .complete, navigation: .unavailable),
            recommendedTargetID: element.id,
            statements: statements
        )
        return render(summary, profile: profile, maximumStatements: statements.count)
    }

    private static func brailleCode(_ category: NonvisualStatementCategory) -> String {
        switch category {
        case .purpose: "PUR"
        case .overview: "SCR"
        case .region: "REG"
        case .finding: "ERR"
        case .completeness: "EVD"
        case .recommendation: "NXT"
        case .element: "ELM"
        case .relationship: "REL"
        case .navigation: "NAV"
        }
    }
}
