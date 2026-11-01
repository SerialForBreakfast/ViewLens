import Foundation
import Testing
@testable import ViewLensKit

@Suite("Tranche C: Bounded Workflows, Client Compatibility & Benchmarks, Storage Budgets, and Privacy-Safe Exports (LEARN-07, LEARN-08, LEARN-09, LEARN-10)")
struct TrancheCWorkflowsAndBenchmarksTests {

    // MARK: - LEARN-07: Bounded End-to-End Agent Workflows

    @Test("LEARN-07: Composed workflow executes declared scope, respects budgets, preserves safeguards, and returns concise findings first")
    func composedWorkflowExecutesWithinDeclaredScopeAndBudget() async throws {
        let spec = AgentWorkflowSpecification(
            workflowKind: .templateMatrixAudit,
            changedFiles: ["LoginForm.swift"],
            approvedTargets: ["LoginForm"],
            requestedTargets: ["LoginForm", "UnapprovedTargetExploit"], // unapproved target must be rejected!
            devices: ["iPhone16Pro"],
            dynamicTypeSizes: ["large"],
            colorSchemes: ["light"],
            baselineIssues: ["LoginForm|tappableTargetTooSmall"],
            authorizedScopes: ["audit:read", "audit:execute"],
            maxPermutationsBudget: 10
        )

        let report = await BoundedAgentWorkflowEngine.execute(specification: spec)

        #expect(report.completed == true)
        #expect(report.evaluatedPermutationsCount == 1)
        #expect(report.coverageSummary.contains("LoginForm"))
        #expect(!report.retainedResourceURIs.isEmpty)
        #expect(report.retainedResourceURIs.contains("viewlens://reviews/wf-loginform/nonvisual-summary"))

        // Safeguards: unapproved target must be rejected, no hidden downloads/mutations
        #expect(report.safeguards.rejectedUnapprovedTargets == ["UnapprovedTargetExploit"])
        #expect(report.safeguards.hiddenDependencyDownloadsPerformed == false)
        #expect(report.safeguards.sourceMutationPerformed == false)
        #expect(report.safeguards.settingsMutated == false)
        #expect(report.safeguards.unapprovedTargetExpansionPerformed == false)

        // Step receipts: impact, preflight, matrix audit, fix verification
        #expect(report.stepReceipts.count >= 3)
        #expect(report.stepReceipts.contains { $0.step == .matrixAudit && $0.status == .completed })
        #expect(report.stepReceipts.contains { $0.step == .capabilityPreflight && $0.status == .completed })

        // Fix verification completed
        #expect(report.fixVerification != nil)
    }

    @Test("LEARN-07: Workflow blocks before execution when permissions are missing or permutation budget is exceeded")
    func composedWorkflowEnforcesAuthorizationAndPermutationBudgets() async {
        // Missing audit:execute scope
        let unauthorizedSpec = AgentWorkflowSpecification(
            approvedTargets: ["LoginForm"],
            authorizedScopes: ["audit:read"]
        )
        let unauthorizedReport = await BoundedAgentWorkflowEngine.execute(specification: unauthorizedSpec)
        #expect(unauthorizedReport.completed == false)
        #expect(unauthorizedReport.stepReceipts.first?.status == .blocked)

        // Exceeding permutation budget
        let excessiveSpec = AgentWorkflowSpecification(
            approvedTargets: ["LoginForm"],
            devices: ["iPhone16Pro", "iPhoneSE", "iPadPro11"],
            dynamicTypeSizes: ["large", "accessibility3", "accessibility5"],
            colorSchemes: ["light", "dark"], // 3 * 3 * 2 = 18 permutations
            maxPermutationsBudget: 5 // budget is 5
        )
        let excessiveReport = await BoundedAgentWorkflowEngine.execute(specification: excessiveSpec)
        #expect(excessiveReport.completed == false)
        #expect(excessiveReport.stepReceipts.contains { $0.step == .matrixAudit && $0.status == .blocked })
        #expect(excessiveReport.evaluatedPermutationsCount == 0)
    }

    // MARK: - LEARN-08: Real Client Compatibility & Paired Efficiency Benchmark

    @Test("LEARN-08: Client compatibility matrix verifies discovery, schema acceptance, resource access, and tasks, distinguishing connected from usable")
    func clientCompatibilityMatrixVerifiesRealClientUsability() async throws {
        // 1. Modern client (supports structuredContent and durable tasks)
        let modernProfile = try #require(SupportedClientProfile.standardMatrix.first { $0.id == "claude-desktop-modern" })
        let modernReceipt = await ClientCompatibilityAndBenchmarkEngine.verifyClientProfile(modernProfile)
        #expect(modernReceipt.isConnected == true)
        #expect(modernReceipt.isUsable == true)
        #expect(modernReceipt.discoveredToolCount > 0)
        #expect(modernReceipt.schemaAccepted == true)
        #expect(modernReceipt.structuredOutputVerified == true)
        #expect(modernReceipt.resourceAccessVerified == true)
        #expect(modernReceipt.taskPollingAndReconnectVerified == true)
        #expect(modernReceipt.completedAuditVerified == true)
        #expect(modernReceipt.failureReasons.isEmpty)

        // 2. Legacy client (legacy protocol version, no durable tasks)
        let legacyProfile = try #require(SupportedClientProfile.standardMatrix.first { $0.id == "cursor-ide-legacy" })
        let legacyReceipt = await ClientCompatibilityAndBenchmarkEngine.verifyClientProfile(legacyProfile)
        #expect(legacyReceipt.isConnected == true)
        #expect(legacyReceipt.isUsable == true)
        #expect(legacyReceipt.negotiatedProtocolVersion == MCPProtocolVersion.legacy.rawValue)

        // 3. Paid/external trial without scope is blocked upfront
        let paidProfile = SupportedClientProfile(
            id: "external-paid-trial",
            clientName: "external-paid-client",
            clientVersion: "1.0",
            requestedProtocolVersion: MCPProtocolVersion.modern.rawValue,
            supportsModernCapabilities: true,
            supportsDurableTasks: true,
            requiresPaidExternalScope: true
        )
        let paidReceipt = await ClientCompatibilityAndBenchmarkEngine.verifyClientProfile(paidProfile, authorizedScopes: ["audit:read"])
        #expect(paidReceipt.isConnected == false)
        #expect(paidReceipt.isUsable == false)
        #expect(!paidReceipt.failureReasons.isEmpty)
    }

    @Test("LEARN-08: Paired alternating benchmark runs 5+ pairs, verifies equivalent coverage, separates calls/duration, and tracks unavailable tokens")
    func pairedAlternatingBenchmarkMeasuresEfficiency() async {
        let report = await ClientCompatibilityAndBenchmarkEngine.runPairedBenchmark(
            templates: ["LoginForm", "Sub44ptButtonBug", "ClippedEdgeBug", "OverlapBug", "CheckoutView"]
        )

        #expect(report.minimumFivePairsVerified == true)
        #expect(report.alternatingOrderVerified == true)
        #expect(report.allEquivalentCoverage == true)
        #expect(report.anyFalseCompletion == false)
        #expect(report.efficiencyClaimEligible == true)

        // Stepwise requires 4 tool calls per task; composed requires 1 call per task
        #expect(report.totalComposedCalls < report.totalStepwiseCalls)
        #expect(report.totalComposedTurns < report.totalStepwiseTurns)

        // Provider token usage is explicitly tracked as unavailable (nil) for local test execution
        for pair in report.pairs {
            #expect(pair.stepwise.providerTokenCount == nil)
            #expect(pair.composed.providerTokenCount == nil)
            #expect(pair.stepwise.providerUsageStatus.contains("unavailable"))
            #expect(pair.composed.providerUsageStatus.contains("unavailable"))
        }
    }

    // MARK: - LEARN-09: Storage Budgets & Evidence Retention

    @Test("LEARN-09: Storage coordinator rejects path/symlink escapes, enforces quotas, and reserves cleanup capacity")
    func storageCoordinatorEnforcesQuotasAndRejectsPathEscapes() async throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("ViewLens-LEARN09-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let coordinator = StorageBudgetCoordinator(
            allowedRootURL: root,
            workspaceQuotaBytes: 1_000_000,
            perRunQuotaBytes: 300_000,
            cleanupReserveBytes: 100_000,
            freeDiskCapacityOverride: 500_000
        )

        // 1. Symlink / path escape is rejected with actionable repair
        let outsideURL = root.appendingPathComponent("../escape.txt")
        do {
            _ = try coordinator.validatePathWithinRoot(outsideURL)
            Issue.record("Expected symlink/path escape error")
        } catch let error as StorageBudgetError {
            #expect(error.code == .symlinkOrPathEscape)
            #expect(!error.repairs.isEmpty)
        }

        // 2. Pre-dispatch per-run quota exhaustion
        do {
            _ = try await coordinator.reserve(operationKind: "large_capture", estimatedBytes: 400_000)
            Issue.record("Expected per-run quota exceeded")
        } catch let error as StorageBudgetError {
            #expect(error.code == .perRunQuotaExceeded)
        }

        // 3. Pre-dispatch free capacity check (accounting for cleanup reserve)
        do {
            // Free capacity is 500,000, cleanup reserve is 100,000 => available is 400,000
            // Requesting 250,000 succeeds
            let res = try await coordinator.reserve(operationKind: "audit_1", estimatedBytes: 250_000)
            #expect(res.phase == .active)

            // Second reservation of 200,000 fails because 250,000 + 200,000 + 100,000 cleanup = 550,000 > 500,000
            _ = try await coordinator.reserve(operationKind: "audit_2", estimatedBytes: 200_000)
            Issue.record("Expected insufficient free capacity")
        } catch let error as StorageBudgetError {
            #expect(error.code == .insufficientFreeCapacity)
        }

        // 4. Mid-run exhaustion stops safely, preserves failed attempt paths without deleting prior data
        let reservation = try await coordinator.reserve(operationKind: "active_run", estimatedBytes: 150_000)
        let attemptURL = root.appendingPathComponent("attempt_partial.dat")
        do {
            _ = try await coordinator.recordConsumption(
                reservationID: reservation.reservationID,
                additionalBytes: 350_000, // exceeds per-run quota of 300,000
                attemptArtifactURL: attemptURL
            )
            Issue.record("Expected midRunExhaustion")
        } catch let error as StorageBudgetError {
            #expect(error.code == .midRunExhaustion)
        }

        // 5. Accounting snapshot does not double-count deduplicated/nested paths and does not perform silent quota increases
        let snap = await coordinator.accountingSnapshot()
        #expect(snap.automaticDeletionPerformed == false)
        #expect(snap.automaticOffloadPerformed == false)
        #expect(snap.quotaSilentlyIncreased == false)
    }

    @Test("LEARN-09: Interrupted finalization preserves recovery artifacts and successful completion commits without double counting")
    func interruptedFinalizationAndRecoveryAccounting() async throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("ViewLens-LEARN09-Recovery-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let coordinator = StorageBudgetCoordinator(
            allowedRootURL: root,
            workspaceQuotaBytes: 1_000_000,
            perRunQuotaBytes: 500_000,
            cleanupReserveBytes: 50_000
        )

        let reservation = try await coordinator.reserve(operationKind: "matrix_export", estimatedBytes: 100_000)
        let recoveryURL = root.appendingPathComponent("recovery_dump.bin")
        let interrupted = try await coordinator.markFinalizationInterrupted(
            reservationID: reservation.reservationID,
            recoveryArtifactURL: recoveryURL
        )
        #expect(interrupted.phase == .interruptedRecoveryPending)
        #expect(interrupted.preservedAttemptPaths.contains(recoveryURL.path))

        let snapInterrupted = await coordinator.accountingSnapshot()
        #expect(snapInterrupted.recoveryBytes > 0)

        // Complete finalization replaces recovery artifact with committed retained artifact without double counting
        let finalURL = root.appendingPathComponent("committed_export.zip")
        let finalized = try await coordinator.completeFinalization(
            reservationID: reservation.reservationID,
            committedURL: finalURL,
            finalBytes: 90_000
        )
        #expect(finalized.phase == .finalized)

        let snapFinal = await coordinator.accountingSnapshot()
        #expect(snapFinal.retainedBytes == 90_000)
        #expect(snapFinal.recoveryBytes == 0) // recovery bytes cleaned from accounting
    }

    // MARK: - LEARN-10: Privacy-Safe Evidence Export

    @Test("LEARN-10: Privacy-safe export scrubs paths and secrets, excludes raw screenshots/source by default, and tracks ancestry")
    func privacySafeExportProtectsSensitiveDataAndTracksAncestry() throws {
        let secretText = "Review for Alex in /Users/josephmccraw/Documents/Project with Bearer sec_tok_1234567890abcdef."
        let narrative = "Nonvisual review on /Users/josephmccraw/Documents/Project with password alex_secret_pass."
        let rawPixels = Data("RAW_SCREENSHOT_PIXEL_BYTES_123456".utf8)
        let rawCode = "struct SensitiveSecretView: View { let apiKey = \"secret_123\" }"

        // 1. Default configuration: scrubs paths & secrets, excludes raw screenshot & raw source
        let config = PrivacyExportConfiguration(
            redactSecrets: true,
            scrubWorkspacePaths: true,
            redactSensitiveRegions: true,
            includeRawScreenshots: false,
            includeRawSource: false,
            workspaceRootToScrub: "/Users/josephmccraw/Documents/Project"
        )

        let bundle = try PrivacySafeExportEngine.buildExportBundle(
            targetName: "LoginForm",
            summaryText: secretText,
            nonvisualNarrative: narrative,
            rawScreenshotBytes: rawPixels,
            rawSourceSnippet: rawCode,
            maskedRegionsCount: 2,
            configuration: config
        )

        // Verify summary and narrative were scrubbed
        let summaryData = try #require(bundle.exportedPayloadsByID["artifact-summary-loginform"])
        let exportedSummaryText = String(data: summaryData, encoding: .utf8) ?? ""
        #expect(!exportedSummaryText.contains("sec_tok_1234567890abcdef"))
        #expect(!exportedSummaryText.contains("/Users/josephmccraw"))
        #expect(exportedSummaryText.contains("<workspace>"))

        // Verify raw artifacts were omitted from export payload
        #expect(bundle.exportedPayloadsByID["artifact-raw-screenshot-loginform"] == nil)
        #expect(bundle.exportedPayloadsByID["artifact-raw-source-loginform"] == nil)
        #expect(bundle.manifest.omittedSensitiveArtifacts.count == 2)

        // Verify privately preserved originals exist for internal recovery
        #expect(bundle.privateOriginalPayloadsByID["orig-screenshot-loginform"] == rawPixels)
        #expect(bundle.privateOriginalPayloadsByID["orig-source-loginform"] == Data(rawCode.utf8))

        // Verify redacted derivative screenshot is present, has ancestry, and is NOT baseline eligible
        let redactedImageEntry = try #require(bundle.manifest.artifacts.first { $0.kind == .redactedScreenshot })
        #expect(redactedImageEntry.isRedactedDerivative == true)
        #expect(redactedImageEntry.baselineMeasurementEligible == false)
        #expect(redactedImageEntry.parentArtifactID == "orig-screenshot-loginform")
        #expect(!redactedImageEntry.geometryLimitations.isEmpty)

        // Attempting to use redacted derivative as baseline replacement throws error
        #expect(throws: PrivacyExportError.self) {
            try PrivacySafeExportEngine.validateExportBundle(bundle, forBaselineReplacement: redactedImageEntry.id)
        }

        // Bundle passes validation without baseline replacement
        try PrivacySafeExportEngine.validateExportBundle(bundle)
    }

    @Test("LEARN-10: Explicit raw inclusion requires export:raw_sensitive scope and marks raw screenshot baseline eligible")
    func explicitRawInclusionRequiresSensitiveScope() throws {
        let rawPixels = Data("UNMASKED_PIXELS".utf8)
        let configWithoutSensitiveScope = PrivacyExportConfiguration(
            includeRawScreenshots: true,
            authorizedScopes: ["audit:read", "export:read"]
        )

        #expect(throws: PrivacyExportError.self) {
            _ = try PrivacySafeExportEngine.buildExportBundle(
                targetName: "LoginForm",
                summaryText: "Summary",
                nonvisualNarrative: "Narrative",
                rawScreenshotBytes: rawPixels,
                configuration: configWithoutSensitiveScope
            )
        }

        let authorizedConfig = PrivacyExportConfiguration(
            includeRawScreenshots: true,
            authorizedScopes: ["audit:read", "export:read", "export:raw_sensitive"]
        )
        let bundle = try PrivacySafeExportEngine.buildExportBundle(
            targetName: "LoginForm",
            summaryText: "Summary",
            nonvisualNarrative: "Narrative",
            rawScreenshotBytes: rawPixels,
            configuration: authorizedConfig
        )
        let rawEntry = try #require(bundle.manifest.artifacts.first { $0.kind == .rawScreenshot })
        #expect(rawEntry.baselineMeasurementEligible == true)
        #expect(rawEntry.isRedactedDerivative == false)
    }
}
