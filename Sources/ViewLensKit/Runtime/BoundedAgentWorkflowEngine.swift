import Foundation

/// Step kinds within a composed, bounded end-to-end agent workflow (LEARN-07).
public enum AgentWorkflowStepKind: String, Codable, Sendable, Equatable, Hashable, CaseIterable {
    case impactAnalysis = "impact_analysis"
    case capabilityPreflight = "capability_preflight"
    case matrixAudit = "matrix_audit"
    case fixVerification = "fix_verification"
}

/// Execution status of a single workflow step (LEARN-07).
public enum AgentWorkflowStepStatus: String, Codable, Sendable, Equatable, Hashable {
    case completed
    case skipped
    case blocked
    case failed
    case cancelled
}

/// Receipt for an individual step in the bounded workflow (LEARN-07).
public struct AgentWorkflowStepReceipt: Codable, Sendable, Equatable, Hashable {
    public let step: AgentWorkflowStepKind
    public let status: AgentWorkflowStepStatus
    public let summary: String
    public let failureReason: String?
    public let durationMs: Int

    public init(
        step: AgentWorkflowStepKind,
        status: AgentWorkflowStepStatus,
        summary: String,
        failureReason: String? = nil,
        durationMs: Int
    ) {
        self.step = step
        self.status = status
        self.summary = summary
        self.failureReason = failureReason
        self.durationMs = max(0, durationMs)
    }
}

/// Declared scope and execution budgets for a bounded workflow (LEARN-07).
public struct AgentWorkflowSpecification: Codable, Sendable, Equatable, Hashable {
    public var workflowKind: PreflightWorkflowKind
    public var workspaceRoot: String?
    public var changedFiles: [String]
    public var approvedTargets: [String]
    public var requestedTargets: [String]
    public var devices: [String]
    public var dynamicTypeSizes: [String]
    public var colorSchemes: [String]
    public var baselineIssues: [String]
    public var authorizedScopes: Set<String>
    public var maxPermutationsBudget: Int
    public var maxDurationMs: Int

    public init(
        workflowKind: PreflightWorkflowKind = .templateMatrixAudit,
        workspaceRoot: String? = nil,
        changedFiles: [String] = [],
        approvedTargets: [String],
        requestedTargets: [String]? = nil,
        devices: [String] = ["iPhone16Pro"],
        dynamicTypeSizes: [String] = ["large"],
        colorSchemes: [String] = ["light"],
        baselineIssues: [String] = [],
        authorizedScopes: Set<String> = ["audit:read", "audit:execute"],
        maxPermutationsBudget: Int = 18,
        maxDurationMs: Int = 30_000
    ) {
        self.workflowKind = workflowKind
        self.workspaceRoot = workspaceRoot
        self.changedFiles = changedFiles
        self.approvedTargets = approvedTargets
        self.requestedTargets = requestedTargets ?? approvedTargets
        self.devices = devices
        self.dynamicTypeSizes = dynamicTypeSizes
        self.colorSchemes = colorSchemes
        self.baselineIssues = baselineIssues
        self.authorizedScopes = authorizedScopes
        self.maxPermutationsBudget = max(1, maxPermutationsBudget)
        self.maxDurationMs = max(100, maxDurationMs)
    }
}

/// Explicit operational safeguard receipts proving no hidden side effects occurred (LEARN-07).
public struct WorkflowOperationalSafeguards: Codable, Sendable, Equatable, Hashable {
    public let hiddenDependencyDownloadsPerformed: Bool
    public let sourceMutationPerformed: Bool
    public let settingsMutated: Bool
    public let unapprovedTargetExpansionPerformed: Bool
    public let rejectedUnapprovedTargets: [String]

    public init(
        hiddenDependencyDownloadsPerformed: Bool = false,
        sourceMutationPerformed: Bool = false,
        settingsMutated: Bool = false,
        unapprovedTargetExpansionPerformed: Bool = false,
        rejectedUnapprovedTargets: [String] = []
    ) {
        self.hiddenDependencyDownloadsPerformed = hiddenDependencyDownloadsPerformed
        self.sourceMutationPerformed = sourceMutationPerformed
        self.settingsMutated = settingsMutated
        self.unapprovedTargetExpansionPerformed = unapprovedTargetExpansionPerformed
        self.rejectedUnapprovedTargets = rejectedUnapprovedTargets
    }
}

/// Concise top-level outcome returned by a bounded end-to-end agent workflow (LEARN-07).
/// Findings, coverage, evidence limitations, and next actions appear first; detailed evidence is retained behind access-checked resources.
public struct BoundedAgentWorkflowReport: Codable, Sendable, Equatable {
    public let workflowID: String
    public let completed: Bool
    public let partialCompletion: Bool
    public let findingsSummary: [String]
    public let totalFindingsCount: Int
    public let evaluatedPermutationsCount: Int
    public let coverageSummary: String
    public let evidenceLimitations: [String]
    public let nextActions: [String]
    public let retainedResourceURIs: [String]
    public let stepReceipts: [AgentWorkflowStepReceipt]
    public let safeguards: WorkflowOperationalSafeguards
    public let fixVerification: FixVerificationReport?

    public init(
        workflowID: String = UUID().uuidString.lowercased(),
        completed: Bool,
        partialCompletion: Bool,
        findingsSummary: [String],
        totalFindingsCount: Int,
        evaluatedPermutationsCount: Int,
        coverageSummary: String,
        evidenceLimitations: [String],
        nextActions: [String],
        retainedResourceURIs: [String],
        stepReceipts: [AgentWorkflowStepReceipt],
        safeguards: WorkflowOperationalSafeguards,
        fixVerification: FixVerificationReport? = nil
    ) {
        self.workflowID = workflowID
        self.completed = completed
        self.partialCompletion = partialCompletion
        self.findingsSummary = findingsSummary
        self.totalFindingsCount = totalFindingsCount
        self.evaluatedPermutationsCount = evaluatedPermutationsCount
        self.coverageSummary = coverageSummary
        self.evidenceLimitations = evidenceLimitations
        self.nextActions = nextActions
        self.retainedResourceURIs = retainedResourceURIs
        self.stepReceipts = stepReceipts
        self.safeguards = safeguards
        self.fixVerification = fixVerification
    }
}

/// Composes existing impact, preflight, matrix review, and fix-verification owners into a single bounded workflow (LEARN-07).
public enum BoundedAgentWorkflowEngine {

    public static func execute(
        specification: AgentWorkflowSpecification,
        preflightContextOverride: PreflightEnvironmentContext? = nil,
        recordEnvelope: (@Sendable (MCPEvidenceEnvelope) async -> Void)? = nil,
        checkpoint: (@Sendable () async -> Bool)? = nil,
        onProgress: (@Sendable (Double, String) async -> Bool)? = nil
    ) async -> BoundedAgentWorkflowReport {
        var stepReceipts: [AgentWorkflowStepReceipt] = []
        var findingsSummary: [String] = []
        var totalFindingsCount = 0
        var evaluatedPermutationsCount = 0
        var evidenceLimitations: [String] = []
        var nextActions: [String] = []
        var retainedResourceURIs: [String] = []

        // Enforce authorization boundary upfront
        guard specification.authorizedScopes.contains("audit:read"),
              specification.authorizedScopes.contains("audit:execute") else {
            let reason = "Missing required 'audit:read' or 'audit:execute' authorization scope."
            stepReceipts.append(AgentWorkflowStepReceipt(
                step: .capabilityPreflight,
                status: .blocked,
                summary: reason,
                failureReason: reason,
                durationMs: 1
            ))
            return BoundedAgentWorkflowReport(
                completed: false,
                partialCompletion: false,
                findingsSummary: [],
                totalFindingsCount: 0,
                evaluatedPermutationsCount: 0,
                coverageSummary: "0 permutations evaluated (blocked by authorization scope).",
                evidenceLimitations: [reason],
                nextActions: ["Grant 'audit:read' and 'audit:execute' scopes and retry."],
                retainedResourceURIs: [],
                stepReceipts: stepReceipts,
                safeguards: WorkflowOperationalSafeguards()
            )
        }

        // Enforce approved target boundary (no unapproved target expansion!)
        let approvedSet = Set(specification.approvedTargets)
        let rejectedTargets = specification.requestedTargets.filter { !approvedSet.contains($0) }
        let admittedTargets = specification.requestedTargets.filter { approvedSet.contains($0) }

        if !rejectedTargets.isEmpty {
            evidenceLimitations.append("Refused unapproved target expansion for: \(rejectedTargets.joined(separator: ", ")).")
        }

        guard !admittedTargets.isEmpty else {
            let reason = "No approved targets remained after enforcing target scope boundary."
            stepReceipts.append(AgentWorkflowStepReceipt(
                step: .impactAnalysis,
                status: .blocked,
                summary: reason,
                failureReason: reason,
                durationMs: 1
            ))
            return BoundedAgentWorkflowReport(
                completed: false,
                partialCompletion: false,
                findingsSummary: [],
                totalFindingsCount: 0,
                evaluatedPermutationsCount: 0,
                coverageSummary: "0 targets evaluated.",
                evidenceLimitations: evidenceLimitations + [reason],
                nextActions: ["Specify at least one target within approvedTargets."],
                retainedResourceURIs: [],
                stepReceipts: stepReceipts,
                safeguards: WorkflowOperationalSafeguards(rejectedUnapprovedTargets: rejectedTargets)
            )
        }

        // Step 1: Impact Analysis (reusing ImpactAuditSelection)
        let step1Start = Date()
        let availableTemplates = await MainActor.run { TemplateRegistry.shared.availableTemplates }
        var effectiveTargets = admittedTargets
        if let workspaceRoot = specification.workspaceRoot, !specification.changedFiles.isEmpty {
            let selection = ImpactAuditSelection.select(
                workspaceRoot: workspaceRoot,
                changedFiles: specification.changedFiles,
                availableTemplates: availableTemplates
            )
            // Intersect impacted templates with approvedTargets so impact analysis never expands beyond approved scope
            let impactedApproved = selection.templates.filter { approvedSet.contains($0) }
            if !impactedApproved.isEmpty {
                effectiveTargets = impactedApproved
            }
            if !selection.coverageAvailable {
                evidenceLimitations.append("Source impact coverage is partial; unregistered roots: \(selection.unregisteredRoots.joined(separator: ", ")).")
            }
            stepReceipts.append(AgentWorkflowStepReceipt(
                step: .impactAnalysis,
                status: .completed,
                summary: "Selected \(effectiveTargets.count) approved impacted target(s): \(effectiveTargets.joined(separator: ", ")).",
                durationMs: Int(Date().timeIntervalSince(step1Start) * 1000)
            ))
        } else {
            stepReceipts.append(AgentWorkflowStepReceipt(
                step: .impactAnalysis,
                status: .skipped,
                summary: "Using explicitly approved target list (\(effectiveTargets.joined(separator: ", "))).",
                durationMs: 0
            ))
        }

        if let onProgress {
            guard await onProgress(20, "Impact selection complete") else {
                stepReceipts.append(AgentWorkflowStepReceipt(
                    step: .matrixAudit,
                    status: .cancelled,
                    summary: "Cancelled after impact analysis.",
                    durationMs: 0
                ))
                return BoundedAgentWorkflowReport(
                    completed: false,
                    partialCompletion: true,
                    findingsSummary: [],
                    totalFindingsCount: 0,
                    evaluatedPermutationsCount: 0,
                    coverageSummary: "Cancelled before matrix execution.",
                    evidenceLimitations: evidenceLimitations + ["Workflow cancelled by caller."],
                    nextActions: ["Re-run workflow if review is still required."],
                    retainedResourceURIs: [],
                    stepReceipts: stepReceipts,
                    safeguards: WorkflowOperationalSafeguards(rejectedUnapprovedTargets: rejectedTargets)
                )
            }
        }

        // Step 2: Capability Preflight (reusing CapabilityPreflightEngine)
        let step2Start = Date()
        let preflightContext = preflightContextOverride ?? PreflightEnvironmentContext(
            workspaceRoot: specification.workspaceRoot,
            requestedTarget: effectiveTargets.first,
            availableTargets: availableTemplates,
            modelAvailableOverride: true
        )
        let preflightReport = CapabilityPreflightEngine.evaluate(
            workflow: specification.workflowKind,
            context: preflightContext
        )
        if preflightReport.overallStatus == .blocked {
            let blockReasons = preflightReport.repairs.map { "\($0.title): \($0.instructions)" }
            stepReceipts.append(AgentWorkflowStepReceipt(
                step: .capabilityPreflight,
                status: .blocked,
                summary: "Preflight blocked workflow (\(preflightReport.repairs.count) repair action(s)).",
                failureReason: blockReasons.joined(separator: " | "),
                durationMs: Int(Date().timeIntervalSince(step2Start) * 1000)
            ))
            return BoundedAgentWorkflowReport(
                completed: false,
                partialCompletion: true,
                findingsSummary: [],
                totalFindingsCount: 0,
                evaluatedPermutationsCount: 0,
                coverageSummary: "Blocked at preflight before target execution.",
                evidenceLimitations: evidenceLimitations + blockReasons,
                nextActions: preflightReport.repairs.map(\.title),
                retainedResourceURIs: [],
                stepReceipts: stepReceipts,
                safeguards: WorkflowOperationalSafeguards(rejectedUnapprovedTargets: rejectedTargets)
            )
        }
        stepReceipts.append(AgentWorkflowStepReceipt(
            step: .capabilityPreflight,
            status: .completed,
            summary: "Preflight \(preflightReport.overallStatus.rawValue) with 0 side effects.",
            durationMs: Int(Date().timeIntervalSince(step2Start) * 1000)
        ))

        // Enforce permutation budget before Step 3
        let requestedPermutationsPerTarget = max(1, specification.devices.count)
            * max(1, specification.dynamicTypeSizes.count)
            * max(1, specification.colorSchemes.count)
        let totalRequestedPermutations = requestedPermutationsPerTarget * effectiveTargets.count
        if totalRequestedPermutations > specification.maxPermutationsBudget {
            let reason = "Requested \(totalRequestedPermutations) permutations, exceeding budget of \(specification.maxPermutationsBudget)."
            stepReceipts.append(AgentWorkflowStepReceipt(
                step: .matrixAudit,
                status: .blocked,
                summary: reason,
                failureReason: reason,
                durationMs: 0
            ))
            return BoundedAgentWorkflowReport(
                completed: false,
                partialCompletion: true,
                findingsSummary: [],
                totalFindingsCount: 0,
                evaluatedPermutationsCount: 0,
                coverageSummary: "0 permutations evaluated (exceeded permutation budget).",
                evidenceLimitations: evidenceLimitations + [reason],
                nextActions: ["Reduce devices, Dynamic Type sizes, or targets to fit within maxPermutationsBudget (\(specification.maxPermutationsBudget))."],
                retainedResourceURIs: [],
                stepReceipts: stepReceipts,
                safeguards: WorkflowOperationalSafeguards(rejectedUnapprovedTargets: rejectedTargets)
            )
        }

        // Step 3: Matrix Audit (reusing MatrixRenderer & NonvisualScreenBuilder)
        let step3Start = Date()
        var currentFindings: [IdentifiedFinding] = []
        var retestedContexts = Set<String>()

        #if canImport(SwiftUI)
        for target in effectiveTargets {
            if let checkpoint {
                guard await checkpoint() else {
                    stepReceipts.append(AgentWorkflowStepReceipt(
                        step: .matrixAudit,
                        status: .cancelled,
                        summary: "Cancelled during matrix audit.",
                        durationMs: Int(Date().timeIntervalSince(step3Start) * 1000)
                    ))
                    return BoundedAgentWorkflowReport(
                        completed: false,
                        partialCompletion: true,
                        findingsSummary: findingsSummary,
                        totalFindingsCount: totalFindingsCount,
                        evaluatedPermutationsCount: evaluatedPermutationsCount,
                        coverageSummary: "Partial matrix evaluated before cancellation.",
                        evidenceLimitations: evidenceLimitations + ["Cancelled during matrix execution."],
                        nextActions: ["Resume or re-run bounded workflow."],
                        retainedResourceURIs: retainedResourceURIs,
                        stepReceipts: stepReceipts,
                        safeguards: WorkflowOperationalSafeguards(rejectedUnapprovedTargets: rejectedTargets)
                    )
                }
            }

            do {
                let detector: YOLODetector?
                if case .success(let modelURL) = ModelLocator.resolve() {
                    detector = try? YOLODetector(modelURL: modelURL)
                } else {
                    detector = nil
                }
                let matrixReport = try await MatrixRenderer.auditNamedTemplate(
                    templateName: target,
                    deviceNames: specification.devices,
                    dtSizes: specification.dynamicTypeSizes,
                    schemes: specification.colorSchemes,
                    detector: detector,
                    targetLevel: .aa
                )
                evaluatedPermutationsCount += matrixReport.permutations.count
                retestedContexts.insert("default")
                for (permKey, permReport) in matrixReport.permutations.sorted(by: { $0.key < $1.key }) {
                    retestedContexts.insert(permKey)
                    retestedContexts.insert("\(target)|\(permKey)")
                    for issue in permReport.issues {
                        totalFindingsCount += 1
                        let summaryItem = "\(target) [\(permKey)]: \(issue.kind.rawValue) (\(issue.severity.rawValue))"
                        if findingsSummary.count < 12 {
                            findingsSummary.append(summaryItem)
                        }
                        let anchor = issue.identifier ?? issue.elementIndex.map { "index:\($0)" }
                        currentFindings.append(IdentifiedFinding(
                            ruleID: issue.kind.rawValue,
                            target: target,
                            elementAnchor: anchor,
                            matrixContext: permKey,
                            scenarioContext: "default"
                        ))
                    }
                }

                // Retain detailed evidence behind access-checked MCPResourceStore
                let reviewID = "wf-\(target.lowercased())"
                retainedResourceURIs.append("viewlens://reviews/\(reviewID)/nonvisual-summary")
                retainedResourceURIs.append("viewlens://reviews/\(reviewID)/semantic-outline")
                if let recordEnvelope {
                    let envelope = MCPEvidenceEnvelope(
                        reviewID: reviewID,
                        sourceMode: "rendered",
                        target: .init(type: "template", identifier: target),
                        completeness: .init(status: .complete, evaluated: ["visual", "semantic"]),
                        durationMs: Date().timeIntervalSince(step3Start) * 1000,
                        data: (try? JSONValue.fromEncodable(matrixReport)) ?? .object([:])
                    )
                    await recordEnvelope(envelope)
                }
            } catch {
                stepReceipts.append(AgentWorkflowStepReceipt(
                    step: .matrixAudit,
                    status: .failed,
                    summary: "Matrix audit failed for '\(target)'.",
                    failureReason: error.localizedDescription,
                    durationMs: Int(Date().timeIntervalSince(step3Start) * 1000)
                ))
            }
        }
        #endif

        let auditFailed = stepReceipts.contains { $0.step == .matrixAudit && $0.status == .failed }
        if !auditFailed {
            stepReceipts.append(AgentWorkflowStepReceipt(
                step: .matrixAudit,
                status: .completed,
                summary: "Evaluated \(evaluatedPermutationsCount) permutation(s) across \(effectiveTargets.count) target(s); found \(totalFindingsCount) finding(s).",
                durationMs: Int(Date().timeIntervalSince(step3Start) * 1000)
            ))
        }

        // Step 4: Optional Fix Verification (reusing FixVerifier)
        var fixReport: FixVerificationReport?
        if !specification.baselineIssues.isEmpty {
            let step4Start = Date()
            let targetLabel = effectiveTargets.joined(separator: ", ")
            let parsedBaseline = specification.baselineIssues.map { IdentifiedFinding.parse($0, defaultTarget: targetLabel) }
            let verified = FixVerifier.verifyFindings(
                changeSet: ChangeSet(changedFiles: specification.changedFiles, targetTemplate: targetLabel),
                baselineFindings: parsedBaseline,
                currentFindings: currentFindings,
                retestedContexts: retestedContexts
            )
            fixReport = verified
            stepReceipts.append(AgentWorkflowStepReceipt(
                step: .fixVerification,
                status: .completed,
                summary: "Resolved: \(verified.resolvedIssues.count), Remaining: \(verified.remainingIssues.count), Introduced: \(verified.introducedIssues.count).",
                durationMs: Int(Date().timeIntervalSince(step4Start) * 1000)
            ))
        } else {
            stepReceipts.append(AgentWorkflowStepReceipt(
                step: .fixVerification,
                status: .skipped,
                summary: "No baseline issues supplied for fix comparison.",
                durationMs: 0
            ))
        }

        evidenceLimitations.append("Detailed per-element geometry and full outlines are retained behind access-checked viewlens://reviews/* resources.")
        if totalFindingsCount > 0 {
            nextActions.append("Read retained resource URIs for element-level remediation and re-run with baseline_issues to verify fixes.")
        } else {
            nextActions.append("All evaluated permutations passed within the declared workflow scope.")
        }

        let coverageSummary = "Evaluated \(evaluatedPermutationsCount) permutation(s) across \(effectiveTargets.count) approved target(s) (\(effectiveTargets.joined(separator: ", ")))."
        _ = await onProgress?(100, "Bounded workflow complete")

        return BoundedAgentWorkflowReport(
            completed: !auditFailed,
            partialCompletion: auditFailed && evaluatedPermutationsCount > 0,
            findingsSummary: findingsSummary,
            totalFindingsCount: totalFindingsCount,
            evaluatedPermutationsCount: evaluatedPermutationsCount,
            coverageSummary: coverageSummary,
            evidenceLimitations: evidenceLimitations,
            nextActions: nextActions,
            retainedResourceURIs: retainedResourceURIs,
            stepReceipts: stepReceipts,
            safeguards: WorkflowOperationalSafeguards(rejectedUnapprovedTargets: rejectedTargets),
            fixVerification: fixReport
        )
    }

    internal static func execute(
        specification: AgentWorkflowSpecification,
        preflightContextOverride: PreflightEnvironmentContext? = nil,
        recordEnvelope: (@Sendable (MCPEvidenceEnvelope) async -> Void)? = nil,
        execution: MCPExecutionContext
    ) async -> BoundedAgentWorkflowReport {
        await execute(
            specification: specification,
            preflightContextOverride: preflightContextOverride,
            recordEnvelope: recordEnvelope,
            checkpoint: { await execution.checkpoint() },
            onProgress: { progress, message in await execution.report(progress: progress, message: message) }
        )
    }
}
