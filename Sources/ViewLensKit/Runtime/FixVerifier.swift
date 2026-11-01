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

/// Certainty level when matching a baseline finding to a post-fix observation (LEARN-03).
public enum FindingMatchCertainty: String, Codable, Sendable, Equatable, Hashable {
    case exact
    case positional
    case ambiguous
    case unmatched
    case notRetested = "not_retested"
}

/// Verification outcome for an individual finding comparison (LEARN-03).
public enum FindingVerificationOutcome: String, Codable, Sendable, Equatable, Hashable {
    case resolved
    case remaining
    case introduced
    case uncertain
    case notRetested = "not_retested"
}

/// Stable identity for an audit finding combining rule, target, element/source anchor, and matrix/scenario context (LEARN-03).
public struct IdentifiedFinding: Codable, Sendable, Equatable, Hashable {
    public let ruleID: String
    public let target: String
    public let elementAnchor: String?
    public let sourceAnchor: String?
    public let matrixContext: String
    public let scenarioContext: String
    public let provenance: EvidenceProvenance
    /// Preserves the caller's original string representation when parsed from a legacy/canonical string.
    public let rawRepresentation: String?

    public init(
        ruleID: String,
        target: String,
        elementAnchor: String? = nil,
        sourceAnchor: String? = nil,
        matrixContext: String = "default",
        scenarioContext: String = "default",
        provenance: EvidenceProvenance = EvidenceProvenance(kind: .measured, source: "audit", confidence: 1.0),
        rawRepresentation: String? = nil
    ) {
        self.ruleID = ruleID
        self.target = target
        self.elementAnchor = elementAnchor?.isEmpty == true ? nil : elementAnchor
        self.sourceAnchor = sourceAnchor?.isEmpty == true ? nil : sourceAnchor
        self.matrixContext = matrixContext.isEmpty ? "default" : matrixContext
        self.scenarioContext = scenarioContext.isEmpty ? "default" : scenarioContext
        self.provenance = provenance
        self.rawRepresentation = rawRepresentation
    }

    /// Primary stable anchor (prefers explicit element identifier/anchor, then source anchor).
    public var effectiveAnchor: String? {
        elementAnchor ?? sourceAnchor
    }

    /// Whether the anchor is only positional (`index:N`) rather than a stable semantic/source identifier.
    public var hasPositionalOnlyAnchor: Bool {
        guard let anchor = effectiveAnchor else { return false }
        return anchor.hasPrefix("index:")
    }

    /// Canonical string representation `target|matrixContext|scenarioContext|ruleID|anchor`.
    public var canonicalID: String {
        let anchor = effectiveAnchor ?? "unanchored"
        return "\(target)|\(matrixContext)|\(scenarioContext)|\(ruleID)|\(anchor)"
    }

    /// Key used in summary arrays (`rawRepresentation` if supplied by legacy string API and unambiguous, else `canonicalID`).
    public var displayKey: String {
        rawRepresentation ?? canonicalID
    }

    /// Parses either a canonical `target|matrix|scenario|rule|anchor` string, `matrix|rule|anchor`, or a legacy bare `ruleID`.
    public static func parse(_ raw: String, defaultTarget: String) -> IdentifiedFinding {
        let parts = raw.split(separator: "|", omittingEmptySubsequences: false).map(String.init)
        if parts.count == 5 {
            let anchor = (parts[4].isEmpty || parts[4] == "unanchored") ? nil : parts[4]
            return IdentifiedFinding(
                ruleID: parts[3],
                target: parts[0].isEmpty ? defaultTarget : parts[0],
                elementAnchor: anchor,
                matrixContext: parts[1].isEmpty ? "default" : parts[1],
                scenarioContext: parts[2].isEmpty ? "default" : parts[2],
                rawRepresentation: raw
            )
        } else if parts.count == 3 {
            let anchor = (parts[2].isEmpty || parts[2] == "unanchored") ? nil : parts[2]
            return IdentifiedFinding(
                ruleID: parts[1],
                target: defaultTarget,
                elementAnchor: anchor,
                matrixContext: parts[0].isEmpty ? "default" : parts[0],
                scenarioContext: "default",
                rawRepresentation: raw
            )
        } else {
            return IdentifiedFinding(
                ruleID: raw,
                target: defaultTarget,
                elementAnchor: nil,
                matrixContext: "default",
                scenarioContext: "default",
                rawRepresentation: raw
            )
        }
    }
}

/// Detailed per-finding comparison record explaining matching certainty and outcome (LEARN-03).
public struct FindingComparisonRecord: Codable, Sendable, Equatable, Hashable {
    public let findingID: String
    public let ruleID: String
    public let target: String
    public let matrixContext: String
    public let scenarioContext: String
    public let baselineAnchor: String?
    public let currentAnchor: String?
    public let outcome: FindingVerificationOutcome
    public let certainty: FindingMatchCertainty
    public let reason: String

    public init(
        findingID: String,
        ruleID: String,
        target: String,
        matrixContext: String = "default",
        scenarioContext: String = "default",
        baselineAnchor: String? = nil,
        currentAnchor: String? = nil,
        outcome: FindingVerificationOutcome,
        certainty: FindingMatchCertainty,
        reason: String
    ) {
        self.findingID = findingID
        self.ruleID = ruleID
        self.target = target
        self.matrixContext = matrixContext
        self.scenarioContext = scenarioContext
        self.baselineAnchor = baselineAnchor
        self.currentAnchor = currentAnchor
        self.outcome = outcome
        self.certainty = certainty
        self.reason = reason
    }
}

/// Comprehensive report comparing before/after findings to prove fix effectiveness without regressions (MCP-17.7, MCP-17.8, LEARN-02, LEARN-03, LEARN-04).
public struct FixVerificationReport: Codable, Sendable, Equatable {
    public let template: String
    public let resolvedIssues: [String]
    public let remainingIssues: [String]
    public let introducedIssues: [String]
    public let notRetested: [String]
    public let uncertainFindings: [String]
    public let comparisons: [FindingComparisonRecord]
    public let eligibility: EvidenceEligibilityDecision
    public let sourceChangesVerified: Bool
    public let chainReceipt: SourceVerificationChainReceipt?
    public let hasRegressions: Bool
    public let passed: Bool

    public init(
        template: String,
        resolvedIssues: [String],
        remainingIssues: [String],
        introducedIssues: [String],
        notRetested: [String] = [],
        uncertainFindings: [String] = [],
        comparisons: [FindingComparisonRecord] = [],
        eligibility: EvidenceEligibilityDecision? = nil,
        sourceChangesVerified: Bool = false,
        chainReceipt: SourceVerificationChainReceipt? = nil
    ) {
        self.template = template
        self.resolvedIssues = resolvedIssues
        self.remainingIssues = remainingIssues
        self.introducedIssues = introducedIssues
        self.notRetested = notRetested
        self.uncertainFindings = uncertainFindings
        self.comparisons = comparisons

        let resolvedEligibility = eligibility ?? EvidenceEligibilityDecision(
            consumer: .fixVerification,
            status: .eligible,
            isEligible: true,
            canPass: true
        )
        self.eligibility = resolvedEligibility
        self.chainReceipt = chainReceipt
        self.sourceChangesVerified = chainReceipt?.sourceChangesVerified ?? sourceChangesVerified
        self.hasRegressions = !introducedIssues.isEmpty
        self.passed = remainingIssues.isEmpty
            && introducedIssues.isEmpty
            && notRetested.isEmpty
            && uncertainFindings.isEmpty
            && resolvedEligibility.canPass
    }
}

/// Engine executing closed-loop verification of agent-applied source code changes (MCP-17.6 - MCP-17.8, LEARN-02, LEARN-03).
public enum FixVerifier {

    /// Compares baseline findings against post-fix findings using stable per-finding identity, matrix context, and evidence eligibility.
    public static func verifyFindings(
        changeSet: ChangeSet,
        baselineFindings: [IdentifiedFinding],
        currentFindings: [IdentifiedFinding],
        retestedContexts: Set<String>? = nil,
        eligibility: EvidenceEligibilityDecision? = nil
    ) -> FixVerificationReport {
        // Evaluate evidence eligibility from supplied decision or finding provenances.
        let effectiveEligibility: EvidenceEligibilityDecision
        if let eligibility {
            effectiveEligibility = eligibility
        } else {
            var required: [String: EvidenceProvenance] = [:]
            for (idx, f) in baselineFindings.enumerated() {
                required["baseline.\(idx)"] = f.provenance
            }
            for (idx, f) in currentFindings.enumerated() {
                required["current.\(idx)"] = f.provenance
            }
            if required.isEmpty {
                required["verificationRun"] = EvidenceProvenance(kind: .measured, source: "fixVerifier", confidence: 1.0)
            }
            effectiveEligibility = EvidenceEligibilityPolicy.evaluate(
                consumer: .fixVerification,
                requiredEvidence: required
            )
        }

        // If evidence is not eligible to pass (e.g. synthetic, unavailable, stale, or mismatched capture),
        // no baseline finding may be claimed as resolved.
        if !effectiveEligibility.canPass {
            let reason = effectiveEligibility.reasons.isEmpty
                ? "Verification evidence is \(effectiveEligibility.status.rawValue); baseline findings remain notRetested."
                : effectiveEligibility.reasons.joined(separator: " ")
            let comparisons = baselineFindings.map { base in
                FindingComparisonRecord(
                    findingID: base.displayKey,
                    ruleID: base.ruleID,
                    target: base.target,
                    matrixContext: base.matrixContext,
                    scenarioContext: base.scenarioContext,
                    baselineAnchor: base.effectiveAnchor,
                    currentAnchor: nil,
                    outcome: .notRetested,
                    certainty: .notRetested,
                    reason: reason
                )
            }
            return FixVerificationReport(
                template: changeSet.targetTemplate,
                resolvedIssues: [],
                remainingIssues: [],
                introducedIssues: currentFindings.map(\.displayKey).sorted(),
                notRetested: baselineFindings.map(\.displayKey).sorted(),
                uncertainFindings: [],
                comparisons: comparisons,
                eligibility: effectiveEligibility
            )
        }

        struct GroupKey: Hashable, Comparable {
            let target: String
            let matrixContext: String
            let scenarioContext: String
            let ruleID: String

            static func < (lhs: GroupKey, rhs: GroupKey) -> Bool {
                if lhs.target != rhs.target { return lhs.target < rhs.target }
                if lhs.matrixContext != rhs.matrixContext { return lhs.matrixContext < rhs.matrixContext }
                if lhs.scenarioContext != rhs.scenarioContext { return lhs.scenarioContext < rhs.scenarioContext }
                return lhs.ruleID < rhs.ruleID
            }
        }

        var baselineByGroup: [GroupKey: [IdentifiedFinding]] = [:]
        for finding in baselineFindings {
            let key = GroupKey(
                target: finding.target,
                matrixContext: finding.matrixContext,
                scenarioContext: finding.scenarioContext,
                ruleID: finding.ruleID
            )
            baselineByGroup[key, default: []].append(finding)
        }

        var currentByGroup: [GroupKey: [IdentifiedFinding]] = [:]
        for finding in currentFindings {
            let key = GroupKey(
                target: finding.target,
                matrixContext: finding.matrixContext,
                scenarioContext: finding.scenarioContext,
                ruleID: finding.ruleID
            )
            currentByGroup[key, default: []].append(finding)
        }

        let allKeys = Set(baselineByGroup.keys).union(currentByGroup.keys).sorted()

        var resolvedIssues: [String] = []
        var remainingIssues: [String] = []
        var introducedIssues: [String] = []
        var notRetested: [String] = []
        var uncertainFindings: [String] = []
        var comparisons: [FindingComparisonRecord] = []

        for key in allKeys {
            let baseList = baselineByGroup[key] ?? []
            let currList = currentByGroup[key] ?? []

            // Check whether this matrix/scenario context was retested when retestedContexts is specified.
            let isContextRetested: Bool
            if let retestedContexts {
                isContextRetested = retestedContexts.contains(key.matrixContext)
                    || retestedContexts.contains("\(key.target)|\(key.matrixContext)")
                    || retestedContexts.contains("\(key.target)|\(key.matrixContext)|\(key.scenarioContext)")
            } else {
                isContextRetested = true
            }

            if !isContextRetested {
                for base in baseList {
                    let id = base.displayKey
                    notRetested.append(id)
                    comparisons.append(FindingComparisonRecord(
                        findingID: id,
                        ruleID: key.ruleID,
                        target: key.target,
                        matrixContext: key.matrixContext,
                        scenarioContext: key.scenarioContext,
                        baselineAnchor: base.effectiveAnchor,
                        currentAnchor: nil,
                        outcome: .notRetested,
                        certainty: .notRetested,
                        reason: "Matrix/scenario context '\(key.matrixContext)' was not retested during verification."
                    ))
                }
                continue
            }

            // Detect duplicate unanchored or duplicate identical-anchor findings in baseline or current.
            var matchedBaseIndices = Set<Int>()
            var matchedCurrIndices = Set<Int>()

            // Step 1: Match by exact non-nil anchor when unique across both baseline and current in this group.
            var baseAnchorIndices: [String: [Int]] = [:]
            for (idx, f) in baseList.enumerated() {
                if let anchor = f.effectiveAnchor {
                    baseAnchorIndices[anchor, default: []].append(idx)
                }
            }
            var currAnchorIndices: [String: [Int]] = [:]
            for (idx, f) in currList.enumerated() {
                if let anchor = f.effectiveAnchor {
                    currAnchorIndices[anchor, default: []].append(idx)
                }
            }

            for (anchor, bIndices) in baseAnchorIndices.sorted(by: { $0.key < $1.key }) {
                guard let cIndices = currAnchorIndices[anchor] else { continue }
                if bIndices.count == 1 && cIndices.count == 1 {
                    let bIdx = bIndices[0]
                    let cIdx = cIndices[0]
                    matchedBaseIndices.insert(bIdx)
                    matchedCurrIndices.insert(cIdx)

                    let base = baseList[bIdx]
                    let certainty: FindingMatchCertainty = base.hasPositionalOnlyAnchor ? .positional : .exact
                    let id = base.displayKey
                    remainingIssues.append(id)
                    comparisons.append(FindingComparisonRecord(
                        findingID: id,
                        ruleID: key.ruleID,
                        target: key.target,
                        matrixContext: key.matrixContext,
                        scenarioContext: key.scenarioContext,
                        baselineAnchor: anchor,
                        currentAnchor: anchor,
                        outcome: .remaining,
                        certainty: certainty,
                        reason: "Finding persisted on \(certainty == .positional ? "positional" : "stable") anchor '\(anchor)' in context '\(key.matrixContext)'."
                    ))
                }
            }

            let unmatchedBase = baseList.enumerated().filter { !matchedBaseIndices.contains($0.offset) }.map(\.element)
            let unmatchedCurr = currList.enumerated().filter { !matchedCurrIndices.contains($0.offset) }.map(\.element)

            if unmatchedBase.isEmpty && unmatchedCurr.isEmpty {
                continue
            }

            // Step 2: Handle single unanchored baseline + single unanchored current (legacy bare rule ID comparison).
            if unmatchedBase.count == 1 && unmatchedCurr.count == 1
                && unmatchedBase[0].effectiveAnchor == nil && unmatchedCurr[0].effectiveAnchor == nil
                && baseList.count == 1 && currList.count == 1 {
                let base = unmatchedBase[0]
                let id = base.displayKey
                remainingIssues.append(id)
                comparisons.append(FindingComparisonRecord(
                    findingID: id,
                    ruleID: key.ruleID,
                    target: key.target,
                    matrixContext: key.matrixContext,
                    scenarioContext: key.scenarioContext,
                    baselineAnchor: nil,
                    currentAnchor: nil,
                    outcome: .remaining,
                    certainty: .positional,
                    reason: "Unanchored finding for rule '\(key.ruleID)' persisted in context '\(key.matrixContext)'."
                ))
                continue
            }

            // Step 3: If both unmatchedBase and unmatchedCurr are non-empty, we have either:
            // - Renamed or moved elements (e.g. baseline anchor 'login_btn' vs current anchor 'sign_in_btn', or 'index:0' vs 'index:2')
            // - Duplicate rule kinds on multiple controls without disambiguating anchors
            if !unmatchedBase.isEmpty && !unmatchedCurr.isEmpty {
                let currAnchorsDesc = unmatchedCurr.map { $0.effectiveAnchor ?? "unanchored" }.joined(separator: ", ")
                for base in unmatchedBase {
                    let id = base.displayKey
                    let baseAnchorDesc = base.effectiveAnchor ?? "unanchored"
                    notRetested.append(id)
                    uncertainFindings.append(id)
                    comparisons.append(FindingComparisonRecord(
                        findingID: id,
                        ruleID: key.ruleID,
                        target: key.target,
                        matrixContext: key.matrixContext,
                        scenarioContext: key.scenarioContext,
                        baselineAnchor: base.effectiveAnchor,
                        currentAnchor: unmatchedCurr.first?.effectiveAnchor,
                        outcome: .uncertain,
                        certainty: .ambiguous,
                        reason: "Ambiguous match for rule '\(key.ruleID)' in context '\(key.matrixContext)': baseline anchor '\(baseAnchorDesc)' could not be deterministically paired against current anchor(s) [\(currAnchorsDesc)] (possible renamed/moved element or duplicate control). Retained as notRetested."
                    ))
                }
                for curr in unmatchedCurr {
                    let id = curr.displayKey
                    if !uncertainFindings.contains(id) {
                        uncertainFindings.append(id)
                    }
                }
                continue
            }

            // Step 4: Only unmatchedBase is non-empty (unmatchedCurr is empty).
            if !unmatchedBase.isEmpty && unmatchedCurr.isEmpty {
                // If baseline had multiple unanchored findings in the same group and some were matched or ambiguous, check if all were cleared.
                for base in unmatchedBase {
                    let id = base.displayKey
                    resolvedIssues.append(id)
                    comparisons.append(FindingComparisonRecord(
                        findingID: id,
                        ruleID: key.ruleID,
                        target: key.target,
                        matrixContext: key.matrixContext,
                        scenarioContext: key.scenarioContext,
                        baselineAnchor: base.effectiveAnchor,
                        currentAnchor: nil,
                        outcome: .resolved,
                        certainty: base.effectiveAnchor != nil ? .exact : .positional,
                        reason: "Finding \(base.effectiveAnchor.map { "on anchor '\($0)' " } ?? "")for rule '\(key.ruleID)' in context '\(key.matrixContext)' was absent after retest."
                    ))
                }
                continue
            }

            // Step 5: Only unmatchedCurr is non-empty (unmatchedBase is empty) -> newly introduced findings!
            if unmatchedBase.isEmpty && !unmatchedCurr.isEmpty {
                for curr in unmatchedCurr {
                    let id = curr.displayKey
                    introducedIssues.append(id)
                    comparisons.append(FindingComparisonRecord(
                        findingID: id,
                        ruleID: key.ruleID,
                        target: key.target,
                        matrixContext: key.matrixContext,
                        scenarioContext: key.scenarioContext,
                        baselineAnchor: nil,
                        currentAnchor: curr.effectiveAnchor,
                        outcome: .introduced,
                        certainty: .unmatched,
                        reason: "New finding \(curr.effectiveAnchor.map { "on anchor '\($0)' " } ?? "")for rule '\(key.ruleID)' in context '\(key.matrixContext)' was introduced after change."
                    ))
                }
            }
        }

        return FixVerificationReport(
            template: changeSet.targetTemplate,
            resolvedIssues: resolvedIssues.sorted(),
            remainingIssues: remainingIssues.sorted(),
            introducedIssues: introducedIssues.sorted(),
            notRetested: notRetested.sorted(),
            uncertainFindings: uncertainFindings.sorted(),
            comparisons: comparisons,
            eligibility: effectiveEligibility
        )
    }

    /// Compares baseline findings against post-fix findings to evaluate fix success and detect regressions.
    /// Supports both canonical finding identifiers (`target|matrix|scenario|rule|anchor`) and legacy rule strings.
    public static func verify(
        changeSet: ChangeSet,
        baselineIssues: [String],
        currentIssues: [String],
        retestedContexts: Set<String>? = nil,
        eligibility: EvidenceEligibilityDecision? = nil
    ) -> FixVerificationReport {
        let baselineFindings = baselineIssues.map { IdentifiedFinding.parse($0, defaultTarget: changeSet.targetTemplate) }
        let currentFindings = currentIssues.map { IdentifiedFinding.parse($0, defaultTarget: changeSet.targetTemplate) }
        return verifyFindings(
            changeSet: changeSet,
            baselineFindings: baselineFindings,
            currentFindings: currentFindings,
            retestedContexts: retestedContexts,
            eligibility: eligibility
        )
    }

    /// Binds fix verification to a build and capture receipt chain (LEARN-04).
    /// Sets `sourceChangesVerified = true` only when the source -> build -> capture chain and finding comparison are complete.
    public static func verifyWithReceiptChain(
        changeSet: ChangeSet,
        expectedWorkspaceRoot: String,
        expectedTarget: String,
        buildReceipt: BuildArtifactReceipt?,
        captureReceipt: BoundCaptureReceipt?,
        currentSourceDigest: String? = nil,
        missingDependencies: [String] = [],
        baselineFindings: [IdentifiedFinding],
        currentFindings: [IdentifiedFinding],
        retestedContexts: Set<String>? = nil
    ) -> FixVerificationReport {
        let resolvedContexts = retestedContexts ?? captureReceipt.map { Set($0.capturedPermutations) }
        let initialComparison = verifyFindings(
            changeSet: changeSet,
            baselineFindings: baselineFindings,
            currentFindings: currentFindings,
            retestedContexts: resolvedContexts
        )

        let findingComparisonCompleted = initialComparison.notRetested.isEmpty
            && initialComparison.uncertainFindings.isEmpty
            && initialComparison.eligibility.canPass

        let chainReceipt = BuildCaptureChainValidator.validateChain(
            expectedWorkspaceRoot: expectedWorkspaceRoot,
            expectedTarget: expectedTarget,
            buildReceipt: buildReceipt,
            captureReceipt: captureReceipt,
            currentSourceDigest: currentSourceDigest,
            missingDependencies: missingDependencies,
            findingComparisonCompleted: findingComparisonCompleted
        )

        guard chainReceipt.sourceChangesVerified else {
            let unverifiedNotRetested = Array(Set(initialComparison.notRetested + baselineFindings.map(\.displayKey) + chainReceipt.failureReasons)).sorted()
            return FixVerificationReport(
                template: changeSet.targetTemplate,
                resolvedIssues: [],
                remainingIssues: initialComparison.remainingIssues,
                introducedIssues: initialComparison.introducedIssues,
                notRetested: unverifiedNotRetested,
                uncertainFindings: initialComparison.uncertainFindings,
                comparisons: initialComparison.comparisons,
                eligibility: chainReceipt.eligibility,
                sourceChangesVerified: false,
                chainReceipt: chainReceipt
            )
        }

        return FixVerificationReport(
            template: changeSet.targetTemplate,
            resolvedIssues: initialComparison.resolvedIssues,
            remainingIssues: initialComparison.remainingIssues,
            introducedIssues: initialComparison.introducedIssues,
            notRetested: initialComparison.notRetested,
            uncertainFindings: initialComparison.uncertainFindings,
            comparisons: initialComparison.comparisons,
            eligibility: chainReceipt.eligibility,
            sourceChangesVerified: true,
            chainReceipt: chainReceipt
        )
    }
}
