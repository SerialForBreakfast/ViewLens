import Foundation
import Testing
@testable import ViewLensKit

@Suite("Tranche B: Build/Capture Receipt Chain, Capability Preflight, and Bounded Execution (LEARN-04, LEARN-05, LEARN-06)")
struct TrancheBExecutionAndPreflightTests {

    // MARK: - LEARN-04: Build and Capture Receipt Chain

    @Test("LEARN-04: Valid source -> build -> capture receipt chain sets sourceChangesVerified = true and fidelityBaselineEligible = true")
    func validBuildCaptureReceiptChainVerifiesSourceChanges() throws {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("ViewLens-LEARN04-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let fileURL = tempDir.appendingPathComponent("LoginForm.swift")
        try Data("struct LoginForm { let buttonHeight = 44 }\n".utf8).write(to: fileURL)

        let pins = [PackageDependencyRecord(identity: "swift-argument-parser", location: "https://github.com/apple/swift-argument-parser", version: "1.5.0", revision: "abc1234")]
        let sourceReceipt = BuildCaptureChainValidator.computeSourceReceipt(
            workspaceRoot: tempDir.path,
            target: "LoginForm",
            relativeFilePaths: ["LoginForm.swift"],
            uncommittedFiles: ["LoginForm.swift"],
            dependencyPins: pins
        )
        #expect(sourceReceipt.includesUncommittedChanges)
        #expect(sourceReceipt.uncommittedFiles == ["LoginForm.swift"])
        #expect(sourceReceipt.dependencyPins == pins)

        let artifactDigest = BuildCaptureChainValidator.sha256Hex(Data("compiled-binary-v1".utf8))
        let buildReceipt = BuildArtifactReceipt(
            workspaceRoot: sourceReceipt.workspaceRoot,
            target: "LoginForm",
            scheme: "ViewLens",
            configuration: "Debug",
            toolchainIdentifier: "Swift 6.0",
            preBuildSourceReceipt: sourceReceipt,
            postBuildSourceDigest: sourceReceipt.sourceDigest,
            buildSucceeded: true,
            artifactPath: "/tmp/Build/Products/Debug/LoginForm.app",
            artifactDigest: artifactDigest
        )

        let captureReceipt = BoundCaptureReceipt(
            captureIdentity: CaptureIdentity(
                captureID: "cap-learn04-1",
                target: "LoginForm",
                capturedAt: Date(),
                artifactDigest: artifactDigest,
                environmentKey: "iPhone16Pro_large_light"
            ),
            buildReceiptID: buildReceipt.receiptID,
            artifactDigest: artifactDigest,
            target: "LoginForm",
            runtimeDestination: "in_process_host",
            requestedPermutations: ["iPhone16Pro_large_light"],
            capturedPermutations: ["iPhone16Pro_large_light"],
            resourceProvenances: [
                "Strings": EvidenceProvenance(kind: .measured, source: "Bundle.main.localizedString")
            ],
            usedSyntheticSubstitutes: false
        )

        let baselineFinding = IdentifiedFinding(
            ruleID: "tappableTargetTooSmall",
            target: "LoginForm",
            elementAnchor: "SignInButton",
            matrixContext: "iPhone16Pro_large_light",
            scenarioContext: "default"
        )

        let report = FixVerifier.verifyWithReceiptChain(
            changeSet: ChangeSet(changedFiles: ["LoginForm.swift"], targetTemplate: "LoginForm"),
            expectedWorkspaceRoot: sourceReceipt.workspaceRoot,
            expectedTarget: "LoginForm",
            buildReceipt: buildReceipt,
            captureReceipt: captureReceipt,
            currentSourceDigest: sourceReceipt.sourceDigest,
            baselineFindings: [baselineFinding],
            currentFindings: [],
            retestedContexts: ["iPhone16Pro_large_light"]
        )

        #expect(report.sourceChangesVerified == true)
        #expect(report.passed == true)
        #expect(report.resolvedIssues == [baselineFinding.displayKey])
        #expect(report.chainReceipt?.fidelityBaselineEligible == true)
        #expect(report.chainReceipt?.failureCodes.isEmpty == true)
    }

    @Test("LEARN-04: Rejects source drift during build, changed source after build, wrong target, missing dependencies, build failure, stale artifact, partial recapture, and synthetic substitutes")
    func rejectsInvalidBuildCaptureReceiptChains() throws {
        let workspace = "/tmp/ViewLensWorkspace"
        let preSource = SourceTreeReceipt(
            workspaceRoot: workspace,
            target: "LoginForm",
            sourceDigest: "digest-v1",
            fileDigests: ["LoginForm.swift": "digest-v1"]
        )
        let validBuild = BuildArtifactReceipt(
            workspaceRoot: workspace,
            target: "LoginForm",
            toolchainIdentifier: "Swift 6.0",
            preBuildSourceReceipt: preSource,
            postBuildSourceDigest: "digest-v1",
            buildSucceeded: true,
            artifactDigest: "artifact-v1"
        )
        let identity = CaptureIdentity(
            captureID: "cap-learn04-2",
            target: "LoginForm",
            capturedAt: Date(),
            artifactDigest: "artifact-v1",
            environmentKey: "iPhone16Pro_large_light"
        )
        let validCapture = BoundCaptureReceipt(
            captureIdentity: identity,
            buildReceiptID: validBuild.receiptID,
            artifactDigest: "artifact-v1",
            target: "LoginForm",
            requestedPermutations: ["iPhone16Pro_large_light", "iPhoneSE_accessibility3_dark"],
            capturedPermutations: ["iPhone16Pro_large_light", "iPhoneSE_accessibility3_dark"]
        )

        // 1. Source drift during build
        let driftedBuild = BuildArtifactReceipt(
            workspaceRoot: workspace,
            target: "LoginForm",
            toolchainIdentifier: "Swift 6.0",
            preBuildSourceReceipt: preSource,
            postBuildSourceDigest: "digest-v2-modified-mid-build",
            buildSucceeded: true,
            artifactDigest: "artifact-v1"
        )
        #expect(driftedBuild.driftDetectedDuringBuild == true)
        #expect(driftedBuild.buildSucceeded == false)
        let driftChain = BuildCaptureChainValidator.validateChain(
            expectedWorkspaceRoot: workspace,
            expectedTarget: "LoginForm",
            buildReceipt: driftedBuild,
            captureReceipt: validCapture
        )
        #expect(driftChain.sourceChangesVerified == false)
        #expect(driftChain.failureCodes.contains(.sourceDriftDuringBuild))

        // 2. Source changed after build
        let postChangeChain = BuildCaptureChainValidator.validateChain(
            expectedWorkspaceRoot: workspace,
            expectedTarget: "LoginForm",
            buildReceipt: validBuild,
            captureReceipt: validCapture,
            currentSourceDigest: "digest-v3-post-build"
        )
        #expect(postChangeChain.sourceChangesVerified == false)
        #expect(postChangeChain.failureCodes.contains(.sourceChangedAfterBuild))

        // 3. Wrong target
        let wrongTargetChain = BuildCaptureChainValidator.validateChain(
            expectedWorkspaceRoot: workspace,
            expectedTarget: "CheckoutView",
            buildReceipt: validBuild,
            captureReceipt: validCapture
        )
        #expect(wrongTargetChain.sourceChangesVerified == false)
        #expect(wrongTargetChain.failureCodes.contains(.wrongTarget))

        // 4. Missing dependencies & build failure
        let failedBuild = BuildArtifactReceipt(
            workspaceRoot: workspace,
            target: "LoginForm",
            toolchainIdentifier: "Swift 6.0",
            preBuildSourceReceipt: preSource,
            buildSucceeded: false,
            failureReason: "Linker failed"
        )
        let failedBuildChain = BuildCaptureChainValidator.validateChain(
            expectedWorkspaceRoot: workspace,
            expectedTarget: "LoginForm",
            buildReceipt: failedBuild,
            captureReceipt: validCapture,
            missingDependencies: ["CoreMLModelPkg"]
        )
        #expect(failedBuildChain.sourceChangesVerified == false)
        #expect(failedBuildChain.failureCodes.contains(.missingDependencies))
        #expect(failedBuildChain.failureCodes.contains(.buildFailed))

        // 5. Stale / mismatched artifact digest
        let staleCapture = BoundCaptureReceipt(
            captureIdentity: identity,
            buildReceiptID: validBuild.receiptID,
            artifactDigest: "stale-artifact-v0",
            target: "LoginForm",
            requestedPermutations: ["iPhone16Pro_large_light"],
            capturedPermutations: ["iPhone16Pro_large_light"]
        )
        let staleChain = BuildCaptureChainValidator.validateChain(
            expectedWorkspaceRoot: workspace,
            expectedTarget: "LoginForm",
            buildReceipt: validBuild,
            captureReceipt: staleCapture
        )
        #expect(staleChain.sourceChangesVerified == false)
        #expect(staleChain.failureCodes.contains(.staleOrMismatchedArtifact))

        // 6. Partial recapture
        let partialCapture = BoundCaptureReceipt(
            captureIdentity: identity,
            buildReceiptID: validBuild.receiptID,
            artifactDigest: "artifact-v1",
            target: "LoginForm",
            requestedPermutations: ["iPhone16Pro_large_light", "iPhoneSE_accessibility3_dark"],
            capturedPermutations: ["iPhone16Pro_large_light"]
        )
        let partialChain = BuildCaptureChainValidator.validateChain(
            expectedWorkspaceRoot: workspace,
            expectedTarget: "LoginForm",
            buildReceipt: validBuild,
            captureReceipt: partialCapture
        )
        #expect(partialChain.sourceChangesVerified == false)
        #expect(partialChain.failureCodes.contains(.partialRecapture))

        // 7. Synthetic substitute remains fidelity-baseline-ineligible
        let syntheticCapture = BoundCaptureReceipt(
            captureIdentity: identity,
            buildReceiptID: validBuild.receiptID,
            artifactDigest: "artifact-v1",
            target: "LoginForm",
            requestedPermutations: ["iPhone16Pro_large_light"],
            capturedPermutations: ["iPhone16Pro_large_light"],
            resourceProvenances: ["AvatarImage": .synthetic(source: "placeholder_avatar")],
            usedSyntheticSubstitutes: true
        )
        let syntheticChain = BuildCaptureChainValidator.validateChain(
            expectedWorkspaceRoot: workspace,
            expectedTarget: "LoginForm",
            buildReceipt: validBuild,
            captureReceipt: syntheticCapture
        )
        #expect(syntheticChain.fidelityBaselineEligible == false)
        #expect(syntheticChain.failureCodes.contains(.syntheticSubstituteUsed))
    }

    @Test("LEARN-04: MCP viewlens_verify_changes binds receipt chain when supplied")
    func mcpVerifyChangesBindsReceiptChain() async throws {
        let server = MCPServer()
        let workspace = FileManager.default.currentDirectoryPath
        let preSource = SourceTreeReceipt(
            workspaceRoot: workspace,
            target: "LoginForm",
            sourceDigest: "digest-mcp-1",
            fileDigests: ["LoginForm.swift": "digest-mcp-1"]
        )
        let buildReceipt = BuildArtifactReceipt(
            workspaceRoot: workspace,
            target: "LoginForm",
            toolchainIdentifier: "Swift 6.0",
            preBuildSourceReceipt: preSource,
            postBuildSourceDigest: "digest-mcp-1",
            buildSucceeded: true,
            artifactDigest: "artifact-mcp-1"
        )
        let captureReceipt = BoundCaptureReceipt(
            captureIdentity: CaptureIdentity(
                captureID: "cap-learn04-mcp",
                target: "LoginForm",
                capturedAt: Date(),
                artifactDigest: "artifact-mcp-1",
                environmentKey: "iPhone16Pro_large_light"
            ),
            buildReceiptID: buildReceipt.receiptID,
            artifactDigest: "artifact-mcp-1",
            target: "LoginForm",
            requestedPermutations: ["iPhone16Pro_large_light"],
            capturedPermutations: ["iPhone16Pro_large_light"]
        )

        let buildJSON = try JSONValue.fromEncodable(buildReceipt)
        let captureJSON = try JSONValue.fromEncodable(captureReceipt)

        let request = JSONRPCRequest(
            jsonrpc: "2.0",
            id: .int(401),
            method: "tools/call",
            params: .object([
                "name": .string("viewlens_verify_changes"),
                "arguments": .object([
                    "template": .string("LoginForm"),
                    "changed_files": .array([.string("LoginForm.swift")]),
                    "baseline_issues": .array([]),
                    "expected_target": .string("LoginForm"),
                    "build_receipt": buildJSON,
                    "capture_receipt": captureJSON,
                    "current_source_digest": .string("digest-mcp-1")
                ])
            ])
        )
        let responseData = try #require(await server.handleRequest(request))
        let json = try #require(JSONSerialization.jsonObject(with: responseData) as? [String: Any])
        let result = try #require(json["result"] as? [String: Any])
        let content = try #require(result["content"] as? [[String: Any]])
        let text = try #require(content.first?["text"] as? String)
        let structured = try #require(JSONSerialization.jsonObject(with: Data(text.utf8)) as? [String: Any])
        #expect(structured["sourceChangesVerified"] as? Bool == true)
        #expect(structured["verificationScope"] as? String == "bound_build_capture_chain")
    }

    // MARK: - LEARN-05: Capability-Based Preflight & Guided Repair

    @Test("LEARN-05: Native-only workflow is ready when YOLO model is unavailable and executes zero side effects")
    func nativeOnlyWorkflowReadyWithoutModelAndZeroSideEffects() {
        let context = PreflightEnvironmentContext(
            requestedTarget: "LoginForm",
            availableTargets: ["LoginForm"],
            modelAvailableOverride: false
        )
        let report = CapabilityPreflightEngine.evaluate(workflow: .nativeOnlyCheck, context: context)
        #expect(report.overallStatus == .ready)
        #expect(report.preflightSideEffectsExecuted == 0)

        let modelCheck = report.prerequisites[.model]
        #expect(modelCheck?.status == .notRequired)
        #expect(modelCheck?.isBlocking == false)

        // Contrast with screenshotAudit, which DOES require the model
        let screenshotReport = CapabilityPreflightEngine.evaluate(workflow: .screenshotAudit, context: context)
        #expect(screenshotReport.overallStatus == .blocked)
        let screenshotModelCheck = screenshotReport.prerequisites[.model]
        #expect(screenshotModelCheck?.status == .blocked)
        #expect(screenshotModelCheck?.cause == .missingModel)
        #expect(screenshotModelCheck?.repair != nil)
        #expect(!screenshotReport.repairs.isEmpty)
    }

    @Test("LEARN-05: Detects denied access, unavailable tools, partial discovery, wrong target, stale replies, pending cleanup, and previews effects")
    func preflightDetectsFailureModesWithGuidedRepairs() {
        let context = PreflightEnvironmentContext(
            workspaceRoot: "/nonexistent/path/learn05",
            requestedTarget: "MissingTargetScreen",
            availableTargets: ["LoginForm"],
            modelAvailableOverride: false,
            xcodeAvailableOverride: false,
            simulatorAvailableOverride: false,
            accessibilityTrustedOverride: false,
            screenRecordingGrantedOverride: false,
            partialDiscoveryTruncated: true,
            missingDependencies: ["MissingDependencyPkg"],
            availableStorageBytes: 1_024,
            minimumRequiredStorageBytes: 100 * 1_024 * 1_024,
            activeOwnerForTarget: "task-99",
            hasPendingCleanup: true,
            hasStaleReply: true
        )

        let report = CapabilityPreflightEngine.evaluate(workflow: .liveSimulatorCapture, context: context)
        #expect(report.overallStatus == .blocked)
        #expect(report.preflightSideEffectsExecuted == 0)
        #expect(report.effectPreview.willLaunch == true)
        #expect(report.effectPreview.willCapture == true)
        #expect(report.effectPreview.requiredScopes.contains("simulator:control"))

        #expect(report.prerequisites[.access]?.status == .blocked)
        #expect(report.prerequisites[.access]?.cause == .permissionDenied)

        #expect(report.prerequisites[.toolchain]?.status == .blocked)
        #expect(report.prerequisites[.toolchain]?.cause == .missingXcode)

        #expect(report.prerequisites[.target]?.status == .blocked)
        #expect(report.prerequisites[.target]?.cause == .wrongTarget)

        #expect(report.prerequisites[.runtime]?.status == .blocked)
        #expect(report.prerequisites[.runtime]?.cause == .staleReply)

        #expect(report.prerequisites[.storage]?.status == .blocked)
        #expect(report.prerequisites[.storage]?.cause == .insufficientStorage)

        #expect(report.prerequisites[.ownership]?.status == .blocked)
        #expect(report.prerequisites[.ownership]?.cause == .pendingCleanup)

        // Verify partial discovery surfaces unknown status when source context discovery is truncated
        let partialTargetContext = PreflightEnvironmentContext(
            workspaceRoot: FileManager.default.currentDirectoryPath,
            requestedTarget: "LoginForm",
            availableTargets: ["LoginForm"],
            partialDiscoveryTruncated: true
        )
        let partialReport = CapabilityPreflightEngine.evaluate(workflow: .sourceBuildAndVerify, context: partialTargetContext)
        #expect(partialReport.prerequisites[.sourceContext]?.status == .unknown)
        #expect(partialReport.prerequisites[.sourceContext]?.cause == .partialDiscovery)
    }

    // MARK: - LEARN-06: Bounded Execution & Uncertain Outcomes

    @Test("LEARN-06: Generation identity rejects late callbacks, reports contention separately, and preserves uncertain timeout & failed cleanup evidence")
    func boundedExecutionPhasesContentionLateCallbacksAndCleanup() async throws {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("ViewLens-LEARN06-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let store = MCPTaskStore(
            directory: tempDir,
            maximumConcurrentActiveTasks: 2
        )

        // 1. Admit task on target "LoginForm" (starts in .queued, then transitions to .running on claimExecution)
        let admitted = try await store.admitAndCreate(
            toolName: "viewlens_audit_view",
            arguments: ["template": .string("LoginForm")],
            targetKey: "LoginForm",
            requiresCleanup: true
        )
        #expect(admitted.status == .working)
        #expect(admitted.phase == .queued)
        #expect(admitted.generationID == 1)

        let claimed = try #require(await store.claimExecution(taskID: admitted.taskId))
        #expect(claimed.generationID == 1)
        let runningSnapshot = try await store.snapshot(taskID: admitted.taskId)
        #expect(runningSnapshot.phase == .running)

        // 2. Overlapping request on same target is rejected with targetContention (distinct from stalled target)
        do {
            _ = try await store.admitAndCreate(
                toolName: "viewlens_audit_view",
                arguments: ["template": .string("LoginForm")],
                targetKey: "LoginForm"
            )
            Issue.record("Expected targetContention error")
        } catch let error as MCPTaskStore.AdmissionError {
            #expect(error == .targetContention(targetKey: "LoginForm", ownerTaskID: admitted.taskId))
        }

        // 3. Timeout records uncertain outcome (providerConfirmedStopped == false, automaticReplayAuthorized == false)
        //    and transitions task to cleanup_pending while bumping generationID
        let timedOut = try await store.recordTimeout(
            taskID: admitted.taskId,
            reason: "Renderer exceeded 5s deadline"
        )
        #expect(timedOut.phase == .cleanupPending)
        #expect(timedOut.terminalEvidence.timedOut == true)
        #expect(timedOut.terminalEvidence.cleanupReceipt?.providerConfirmedStopped == false)
        #expect(timedOut.terminalEvidence.cleanupReceipt?.automaticReplayAuthorized == false)
        #expect(timedOut.generationID == 2)

        // 4. Late callback from generation 1 is rejected and increments lateCallbacksRejected
        let lateProgressAccepted = await store.report(
            taskID: admitted.taskId,
            generationID: 1,
            progress: 90,
            message: "Late progress from old generation"
        )
        #expect(lateProgressAccepted == false)

        let lateCompleteAccepted = try await store.complete(
            taskID: admitted.taskId,
            generationID: 1,
            result: .object([:])
        )
        #expect(lateCompleteAccepted == false)

        let afterLate = try await store.snapshot(taskID: admitted.taskId)
        #expect(afterLate.terminalEvidence.lateCallbacksRejected == 2)

        // 5. While in cleanup_pending, new admission on "LoginForm" reports pendingCleanup
        do {
            _ = try await store.admitAndCreate(
                toolName: "viewlens_audit_view",
                arguments: ["template": .string("LoginForm")],
                targetKey: "LoginForm"
            )
            Issue.record("Expected pendingCleanup error")
        } catch let error as MCPTaskStore.AdmissionError {
            #expect(error == .pendingCleanup(targetKey: "LoginForm", taskID: admitted.taskId))
        }

        // 6. Failed cleanup retains both the original timeout failure and the cleanup receipt
        let afterFailedCleanup = try await store.completeCleanup(
            taskID: admitted.taskId,
            succeeded: false,
            cleanupFailureReason: "Temp directory lock still held"
        )
        #expect(afterFailedCleanup.status == .failed)
        #expect(afterFailedCleanup.phase == .cleanupPending)
        #expect(afterFailedCleanup.terminalEvidence.originalFailureReason == "Renderer exceeded 5s deadline")
        #expect(afterFailedCleanup.terminalEvidence.cleanupReceipt?.cleanupCompleted == false)
        #expect(afterFailedCleanup.terminalEvidence.cleanupReceipt?.cleanupFailureReason == "Temp directory lock still held")

        // 7. Successful recovery cleanup releases target ownership so a new task can be admitted
        let recoveredCleanup = try await store.completeCleanup(
            taskID: admitted.taskId,
            succeeded: true
        )
        #expect(recoveredCleanup.phase == .failed)
        #expect(recoveredCleanup.terminalEvidence.cleanupReceipt?.cleanupCompleted == true)
        #expect(recoveredCleanup.terminalEvidence.cleanupReceipt?.providerConfirmedStopped == true)

        let readmitted = try await store.admitAndCreate(
            toolName: "viewlens_audit_view",
            arguments: ["template": .string("LoginForm")],
            targetKey: "LoginForm"
        )
        #expect(readmitted.phase == .queued)
    }
}
