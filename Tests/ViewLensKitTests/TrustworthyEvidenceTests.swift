import Testing
import Foundation
import CoreGraphics
@testable import ViewLensKit

@Suite("Trustworthy Evidence, Provenance Eligibility & Finding Identity Tests (LEARN-01, LEARN-02, LEARN-03)")
struct TrustworthyEvidenceTests {

    // MARK: - LEARN-01: Correct Capture Provenance

    @Test("LEARN-01: Empty and snapshot-only captures do not fabricate measured geometry, visual observations, or device defaults")
    func testCaptureProvenanceNoFabrication() {
        // 1. Empty capture
        let emptyState = StateCaptureEngine.captureState(templateName: "EmptyScreen")
        #expect(emptyState.accessibilityHierarchy.isEmpty)
        #expect(emptyState.visualElements.isEmpty)
        #expect(emptyState.scale == nil)
        #expect(emptyState.safeAreaInsets.isEmpty)
        #expect(emptyState.timestamp == nil)
        #expect(emptyState.deviceMetricsEvidence.kind == .unavailable)
        #expect(emptyState.captureTimingEvidence.kind == .unavailable)
        #expect(emptyState.readingOrderEvidence.kind == .unavailable)
        #expect(emptyState.correlation.status == .unavailable)
        #expect(!emptyState.correlation.isAvailable)
        #expect(emptyState.correlation.evaluatedMatchRate == nil)
        #expect(emptyState.correlation.matchRate == 0.0)
        #expect(!emptyState.conformanceEligible)

        // 2. Snapshot-only capture with supplied labels/values and explicit origin, plus one synthetic placeholder frame
        let snapshots = [
            AccessibilityElementSnapshot(
                identifier: "play_btn",
                label: "Play Episode",
                role: "button",
                value: "Paused",
                frame: nil,
                origin: "tv_test_rig_ax_dump"
            ),
            AccessibilityElementSnapshot(
                identifier: "placeholder_card",
                label: "Featured Show",
                role: "image",
                value: nil,
                frame: BoundingBox(x: 0.1, y: 0.2, width: 0.4, height: 0.3),
                frameProvenance: .synthetic(source: "layout_placeholder", detail: "Synthetic preview box"),
                origin: "template_author"
            )
        ]

        let snapshotState = StateCaptureEngine.captureState(
            templateName: "TVHomeView",
            snapshots: snapshots
        )

        #expect(snapshotState.accessibilityHierarchy.count == 2)
        let firstNode = snapshotState.accessibilityHierarchy[0]
        #expect(firstNode.id.rawValue == "play_btn")
        #expect(firstNode.label == "Play Episode")
        #expect(firstNode.value == "Paused")
        #expect(firstNode.origin == "tv_test_rig_ax_dump")
        #expect(firstNode.provenance.source == "tv_test_rig_ax_dump")
        #expect(firstNode.frame == nil)
        #expect(firstNode.frameProvenance.kind == .unavailable)
        #expect(firstNode.frameProvenance.confidence == nil)

        let secondNode = snapshotState.accessibilityHierarchy[1]
        #expect(secondNode.id.rawValue == "placeholder_card")
        #expect(secondNode.origin == "template_author")
        #expect(secondNode.frame != nil)
        #expect(secondNode.frameProvenance.kind == .synthetic)
        #expect(secondNode.frameProvenance.confidence == nil)

        // Neither node has measured/derived geometry and no independent visual observations exist
        #expect(snapshotState.visualElements.isEmpty)
        #expect(!snapshotState.correlation.isAvailable)
        #expect(snapshotState.correlation.status == .unavailable)
        #expect(!snapshotState.conformanceEligible)
    }

    @Test("LEARN-01: VisualSemanticCorrelator rejects visual observations derived from accessibility nodes or synthetic geometry")
    func testCorrelatorRejectsNonIndependentAndSyntheticObservations() {
        let box = BoundingBox(x: 0.1, y: 0.1, width: 0.5, height: 0.1)
        let measuredNode = NativeAccessibilityNode(
            id: NonvisualID("btn_1"),
            label: "Submit",
            traits: [.isButton],
            frame: box,
            provenance: EvidenceProvenance(kind: .measured, source: "ax_runtime", confidence: 1.0)
        )
        let derivedFromAxVisual = DetectedElement(type: "primaryButton", confidence: 0.99, boundingBox: box)

        let derivedReport = VisualSemanticCorrelator.correlate(
            visualElements: [derivedFromAxVisual],
            accessibilityNodes: [measuredNode],
            visualProvenance: EvidenceProvenance(kind: .derived, source: "accessibility_derived_boxes")
        )
        #expect(derivedReport.status == .ineligible)
        #expect(!derivedReport.isAvailable)
        #expect(derivedReport.matchedPairs.isEmpty)
        #expect(derivedReport.evaluatedMatchRate == nil)

        let syntheticNode = NativeAccessibilityNode(
            id: NonvisualID("btn_syn"),
            label: "Synthetic Button",
            traits: [.isButton],
            frame: box,
            provenance: .synthetic(source: "placeholder"),
            frameProvenance: .synthetic(source: "placeholder")
        )
        let syntheticReport = VisualSemanticCorrelator.correlate(
            visualElements: [derivedFromAxVisual],
            accessibilityNodes: [syntheticNode],
            visualProvenance: EvidenceProvenance(kind: .measured, source: "yoloDetector", confidence: 0.99)
        )
        #expect(syntheticReport.status == .ineligible)
        #expect(!syntheticReport.isAvailable)
        #expect(syntheticReport.matchedPairs.isEmpty)
    }

    @Test("LEARN-01: Actual MCP handler viewlens_capture_state never claims measured correlation or conformance on placeholder/empty captures")
    func testMCPCaptureStateHandlerProvenance() async throws {
        let server = MCPServer()

        // 1. Registered template with authored snapshots but no independent runtime visual capture
        let loginReq = JSONRPCRequest(
            jsonrpc: "2.0",
            id: .int(101),
            method: "tools/call",
            params: .object([
                "name": .string("viewlens_capture_state"),
                "arguments": .object([
                    "template": .string("LoginForm")
                ])
            ])
        )
        let loginRespData = try #require(await server.handleRequest(loginReq))
        let loginJSON = try #require(try JSONSerialization.jsonObject(with: loginRespData) as? [String: Any])
        let loginResult = try #require(loginJSON["result"] as? [String: Any])
        let loginContent = try #require(loginResult["content"] as? [[String: Any]])
        let loginText = try #require(loginContent.first?["text"] as? String)
        let loginStructured = try #require(try JSONSerialization.jsonObject(with: Data(loginText.utf8)) as? [String: Any])

        let visualElements = try #require(loginStructured["visualElements"] as? [Any])
        #expect(visualElements.isEmpty)
        let conformanceEligible = try #require(loginStructured["conformanceEligible"] as? Bool)
        #expect(!conformanceEligible)
        let correlation = try #require(loginStructured["correlation"] as? [String: Any])
        #expect((correlation["status"] as? String) == "unavailable")
        #expect((correlation["isAvailable"] as? Bool) == false)

        let deviceMetricsEv = try #require(loginStructured["deviceMetricsEvidence"] as? [String: Any])
        #expect((deviceMetricsEv["kind"] as? String) == "unavailable")
        let timingEv = try #require(loginStructured["captureTimingEvidence"] as? [String: Any])
        #expect((timingEv["kind"] as? String) == "unavailable")
        let readingOrderEv = try #require(loginStructured["readingOrderEvidence"] as? [String: Any])
        #expect((readingOrderEv["kind"] as? String) == "unavailable")

        // 2. Empty/unregistered template capture via MCP
        let emptyReq = JSONRPCRequest(
            jsonrpc: "2.0",
            id: .int(102),
            method: "tools/call",
            params: .object([
                "name": .string("viewlens_capture_state"),
                "arguments": .object([
                    "template": .string("UnregisteredEmptyTemplate")
                ])
            ])
        )
        let emptyRespData = try #require(await server.handleRequest(emptyReq))
        let emptyJSON = try #require(try JSONSerialization.jsonObject(with: emptyRespData) as? [String: Any])
        let emptyResult = try #require(emptyJSON["result"] as? [String: Any])
        let emptyContent = try #require(emptyResult["content"] as? [[String: Any]])
        let emptyText = try #require(emptyContent.first?["text"] as? String)
        let emptyStructured = try #require(try JSONSerialization.jsonObject(with: Data(emptyText.utf8)) as? [String: Any])
        let emptyNodes = try #require(emptyStructured["accessibilityHierarchy"] as? [Any])
        #expect(emptyNodes.isEmpty)
        #expect((emptyStructured["conformanceEligible"] as? Bool) == false)
    }

    // MARK: - LEARN-02: Enforce Evidence Eligibility Across Consumers

    @Test("LEARN-02: Shared EvidenceEligibilityPolicy enforces provenance kinds, freshness, capture identity, and legacy migration")
    func testEvidenceEligibilityPolicyAcrossConsumers() {
        let now = Date()
        let freshIdentity = CaptureIdentity(captureID: "cap_1", target: "HomeView", capturedAt: now)
        let mismatchedIdentity = CaptureIdentity(captureID: "cap_2", target: "HomeView", capturedAt: now)
        let staleIdentity = CaptureIdentity(captureID: "cap_1", target: "HomeView", capturedAt: now.addingTimeInterval(-300))

        // 1. Measured + derived + humanConfirmed -> eligible across all consumers
        let strongEvidence: [String: EvidenceProvenance] = [
            "geometry": EvidenceProvenance(kind: .measured, source: "catalyst_ax", confidence: 1.0),
            "contrast": EvidenceProvenance(kind: .derived, source: "wcag_calc"),
            "voiceover": .humanConfirmed(source: "qa_tester", detail: "Verified on Apple TV 4K")
        ]
        for domain in EvidenceConsumerDomain.allCases {
            let decision = EvidenceEligibilityPolicy.evaluate(
                consumer: domain,
                requiredEvidence: strongEvidence,
                captureIdentity: freshIdentity,
                expectedCaptureIdentity: freshIdentity,
                maxAgeSeconds: 60,
                now: now
            )
            #expect(decision.status == .eligible)
            #expect(decision.isEligible)
            #expect(decision.canPass)
        }

        // 2. Synthetic evidence -> ineligible for gate/correlation/baseline/fixVerification, incomplete for description/export
        let syntheticEvidence: [String: EvidenceProvenance] = [
            "geometry": .synthetic(source: "placeholder", detail: "Synthetic box")
        ]
        let gateSynthetic = EvidenceEligibilityPolicy.evaluate(consumer: .qualityGate, requiredEvidence: syntheticEvidence)
        #expect(gateSynthetic.status == .ineligible)
        #expect(!gateSynthetic.canPass)

        let descSynthetic = EvidenceEligibilityPolicy.evaluate(consumer: .nonvisualDescription, requiredEvidence: syntheticEvidence)
        #expect(descSynthetic.status == .incomplete)
        #expect(!descSynthetic.canPass)

        // 3. Unavailable evidence -> notEvaluated for gate/correlation/baseline/fixVerification
        let unavailableEvidence: [String: EvidenceProvenance] = [
            "semantics": .unavailable(source: "ax_tree", detail: "Missing dump")
        ]
        let gateUnavailable = EvidenceEligibilityPolicy.evaluate(consumer: .qualityGate, requiredEvidence: unavailableEvidence)
        #expect(gateUnavailable.status == .notEvaluated)
        #expect(!gateUnavailable.canPass)

        // 4. Inferred evidence -> eligible for nonvisualDescription, notEvaluated for qualityGate/baselinePromotion
        let inferredEvidence: [String: EvidenceProvenance] = [
            "role": EvidenceProvenance(kind: .inferred, source: "yolo", confidence: 0.85)
        ]
        let descInferred = EvidenceEligibilityPolicy.evaluate(consumer: .nonvisualDescription, requiredEvidence: inferredEvidence)
        #expect(descInferred.status == .eligible)
        #expect(descInferred.canPass)

        let gateInferred = EvidenceEligibilityPolicy.evaluate(consumer: .qualityGate, requiredEvidence: inferredEvidence)
        #expect(gateInferred.status == .notEvaluated)
        #expect(!gateInferred.canPass)

        // 5. Stale and mismatched captures -> incomplete (canPass == false)
        let staleDecision = EvidenceEligibilityPolicy.evaluate(
            consumer: .fixVerification,
            requiredEvidence: strongEvidence,
            captureIdentity: staleIdentity,
            maxAgeSeconds: 60,
            now: now
        )
        #expect(staleDecision.status == .incomplete)
        #expect(!staleDecision.canPass)

        let mismatchDecision = EvidenceEligibilityPolicy.evaluate(
            consumer: .visualSemanticCorrelation,
            requiredEvidence: strongEvidence,
            captureIdentity: mismatchedIdentity,
            expectedCaptureIdentity: freshIdentity,
            now: now
        )
        #expect(mismatchDecision.status == .incomplete)
        #expect(!mismatchDecision.canPass)

        // 6. Legacy report migration limitations
        let legacyLimitations = EvidenceEligibilityPolicy.assessLegacyReport(
            schemaVersion: 1,
            currentSchemaVersion: 3,
            hasProvenance: false,
            hasCaptureIdentity: false
        )
        #expect(legacyLimitations.count == 3)
        let legacyGate = EvidenceEligibilityPolicy.evaluate(
            consumer: .baselinePromotion,
            requiredEvidence: strongEvidence,
            migrationLimitations: legacyLimitations
        )
        #expect(legacyGate.status == .incomplete)
        #expect(!legacyGate.canPass)
    }

    @Test("LEARN-02: SeparatedFocusState keeps predicted, keyboard, accessibility, and human VoiceOver focus channels distinct")
    func testSeparatedFocusChannels() {
        let focusState = SeparatedFocusState(
            predictedInputFocus: FocusObservation(
                elementID: "card_1",
                label: "Featured Movie",
                channel: .predictedInputFocus,
                provenance: EvidenceProvenance(kind: .inferred, source: "focus_heuristic", confidence: 0.75)
            ),
            nativeKeyboardFocus: FocusObservation(
                elementID: "search_field",
                label: "Search",
                channel: .nativeKeyboardFocus,
                provenance: EvidenceProvenance(kind: .measured, source: "uikit_first_responder", confidence: 1.0)
            ),
            accessibilityFocus: nil,
            humanVoiceOverObservation: nil
        )

        #expect(!focusState.hasVerifiedAssistiveFocus)
        #expect(EvidenceEligibilityPolicy.evaluateFocusChannel(focusState, requiredChannel: .predictedInputFocus).canPass)
        #expect(EvidenceEligibilityPolicy.evaluateFocusChannel(focusState, requiredChannel: .nativeKeyboardFocus).canPass)
        #expect(!EvidenceEligibilityPolicy.evaluateFocusChannel(focusState, requiredChannel: .accessibilityFocus).canPass)
        #expect(!EvidenceEligibilityPolicy.evaluateFocusChannel(focusState, requiredChannel: .humanVoiceOverObservation).canPass)

        // Human VoiceOver channel rejects non-humanConfirmed provenance
        let spoofedVoiceOverState = SeparatedFocusState(
            humanVoiceOverObservation: FocusObservation(
                elementID: "card_1",
                channel: .humanVoiceOverObservation,
                provenance: EvidenceProvenance(kind: .inferred, source: "model_guess", confidence: 0.9)
            )
        )
        let voDecision = EvidenceEligibilityPolicy.evaluateFocusChannel(spoofedVoiceOverState, requiredChannel: .humanVoiceOverObservation)
        #expect(voDecision.status == .ineligible)
        #expect(!voDecision.canPass)
    }

    @Test("LEARN-02: NonvisualSummaryComposer, BaselineVerifier, and QualityGateEvaluator enforce eligibility")
    func testConsumersEnforceEligibility() {
        // 1. NonvisualSummaryComposer treats synthetic evidence as partial, never complete
        let syntheticModel = NonvisualScreenModel(
            id: NonvisualID("screen_syn"),
            sourceMode: .rendered,
            elements: [
                NonvisualElement(
                    id: NonvisualID("el_1"),
                    type: "button",
                    bounds: BoundingBox(x: 0.1, y: 0.1, width: 0.5, height: 0.1),
                    visualEvidence: .synthetic(source: "placeholder"),
                    semanticEvidence: EvidenceProvenance(kind: .measured, source: "ax", confidence: 1.0)
                )
            ]
        )
        let summary = NonvisualSummaryComposer.compose(syntheticModel)
        #expect(summary.completeness.visual == .partial)
        let modelEligibility = NonvisualSummaryComposer.eligibility(for: syntheticModel)
        #expect(modelEligibility.status == .incomplete)
        #expect(!modelEligibility.canPass)

        // Validator flags synthetic evidence claiming confidence 1.0
        let invalidSyntheticModel = NonvisualScreenModel(
            id: NonvisualID("screen_bad"),
            sourceMode: .rendered,
            elements: [
                NonvisualElement(
                    id: NonvisualID("el_bad"),
                    type: "button",
                    visualEvidence: EvidenceProvenance(kind: .synthetic, source: "fake", confidence: 1.0),
                    semanticEvidence: EvidenceProvenance(kind: .measured, source: "ax", confidence: 1.0)
                )
            ]
        )
        let validationIssues = NonvisualModelValidator.validate(invalidSyntheticModel)
        #expect(validationIssues.contains { $0.code == .invalidEvidence })

        // 2. BaselineVerifier rejects approval when evidence is synthetic or stale
        let rejectedApproval = BaselineVerifier.processApproval(
            templateName: "LoginForm",
            baselinePath: "/tmp/baseline.png",
            approved: true,
            approvedBy: "qa",
            evidenceProvenance: .synthetic(source: "placeholder")
        )
        #expect(rejectedApproval.status == .rejected)
        #expect(!rejectedApproval.eligibility.canPass)

        // 3. QualityGateEvaluator fails when evidence eligibility cannot pass
        let permReport = AuditReport(
            sourceMode: .rendered,
            target: "LoginForm",
            elements: [],
            issues: []
        )
        let matrixReport = MatrixAuditReport(
            sourceMode: .rendered,
            template: "LoginForm",
            passed: true,
            summary: MatrixSummary(
                totalPermutations: 1,
                passedCount: 1,
                failedCount: 0,
                worstIssue: nil,
                failedPermutations: []
            ),
            permutations: ["iPhone16Pro_large_light": permReport]
        )
        let notEvaluatedDecision = EvidenceEligibilityPolicy.evaluate(
            consumer: .qualityGate,
            requiredEvidence: ["semantics": .unavailable(source: "ax", detail: "Not captured")]
        )
        let gateResult = QualityGateEvaluator.evaluate(
            gateName: "ci",
            config: GateConfig(failOn: .error, purposes: []),
            matrixReport: matrixReport,
            eligibility: notEvaluatedDecision
        )
        #expect(!gateResult.passed)
        #expect(gateResult.eligibility.status == .notEvaluated)
    }

    // MARK: - LEARN-03: Match Fixes by Stable Finding Identity

    @Test("LEARN-03: FixVerifier distinguishes duplicate rule kinds across controls, renamed/moved elements, partial matrices, and new findings")
    func testFixVerifierStableFindingIdentity() {
        let changeSet = ChangeSet(changedFiles: ["Sources/LoginForm.swift"], targetTemplate: "LoginForm")

        // Case 1a: Duplicate rule kinds on different controls (btn_cancel fixed, btn_submit still failing)
        let baselineDuplicates = [
            IdentifiedFinding(ruleID: "touchTargetTooSmall", target: "LoginForm", elementAnchor: "btn_cancel", matrixContext: "iPhone16Pro_large_light"),
            IdentifiedFinding(ruleID: "touchTargetTooSmall", target: "LoginForm", elementAnchor: "btn_submit", matrixContext: "iPhone16Pro_large_light")
        ]
        let currentPartialFix = [
            IdentifiedFinding(ruleID: "touchTargetTooSmall", target: "LoginForm", elementAnchor: "btn_submit", matrixContext: "iPhone16Pro_large_light")
        ]
        let dupReport = FixVerifier.verifyFindings(
            changeSet: changeSet,
            baselineFindings: baselineDuplicates,
            currentFindings: currentPartialFix
        )
        #expect(dupReport.resolvedIssues == ["LoginForm|iPhone16Pro_large_light|default|touchTargetTooSmall|btn_cancel"])
        #expect(dupReport.remainingIssues == ["LoginForm|iPhone16Pro_large_light|default|touchTargetTooSmall|btn_submit"])
        #expect(dupReport.introducedIssues.isEmpty)
        #expect(!dupReport.hasRegressions)
        #expect(!dupReport.passed)

        // Case 1b: Duplicate rule kinds where existing control remains and a second control introduces the same rule
        let currentDupRegression = [
            IdentifiedFinding(ruleID: "touchTargetTooSmall", target: "LoginForm", elementAnchor: "btn_cancel", matrixContext: "iPhone16Pro_large_light"),
            IdentifiedFinding(ruleID: "touchTargetTooSmall", target: "LoginForm", elementAnchor: "btn_submit", matrixContext: "iPhone16Pro_large_light"),
            IdentifiedFinding(ruleID: "touchTargetTooSmall", target: "LoginForm", elementAnchor: "btn_help", matrixContext: "iPhone16Pro_large_light")
        ]
        let dupRegressionReport = FixVerifier.verifyFindings(
            changeSet: changeSet,
            baselineFindings: baselineDuplicates,
            currentFindings: currentDupRegression
        )
        #expect(dupRegressionReport.remainingIssues.count == 2)
        #expect(dupRegressionReport.introducedIssues == ["LoginForm|iPhone16Pro_large_light|default|touchTargetTooSmall|btn_help"])
        #expect(dupRegressionReport.hasRegressions)
        #expect(!dupRegressionReport.passed)

        // Case 2: Renamed or moved element with same rule in same context -> uncertain/ambiguous, retained in notRetested
        let baselineRenamed = [
            IdentifiedFinding(ruleID: "missingAccessibilityLabel", target: "LoginForm", elementAnchor: "old_avatar_icon", matrixContext: "iPhone16Pro_large_light")
        ]
        let currentRenamed = [
            IdentifiedFinding(ruleID: "missingAccessibilityLabel", target: "LoginForm", elementAnchor: "new_profile_badge", matrixContext: "iPhone16Pro_large_light")
        ]
        let renamedReport = FixVerifier.verifyFindings(
            changeSet: changeSet,
            baselineFindings: baselineRenamed,
            currentFindings: currentRenamed
        )
        #expect(renamedReport.resolvedIssues.isEmpty)
        #expect(renamedReport.notRetested.contains("LoginForm|iPhone16Pro_large_light|default|missingAccessibilityLabel|old_avatar_icon"))
        #expect(!renamedReport.uncertainFindings.isEmpty)
        #expect(renamedReport.comparisons.first?.outcome == .uncertain)
        #expect(renamedReport.comparisons.first?.certainty == .ambiguous)
        #expect(!renamedReport.passed)

        // Case 3: Partial matrix execution -> un-retested matrix context retained in notRetested
        let baselineMatrix = [
            IdentifiedFinding(ruleID: "textTruncated", target: "LoginForm", elementAnchor: "title_lbl", matrixContext: "iPhone16Pro_large_light"),
            IdentifiedFinding(ruleID: "textTruncated", target: "LoginForm", elementAnchor: "title_lbl", matrixContext: "iPhoneSE_accessibility5_dark")
        ]
        let partialMatrixReport = FixVerifier.verifyFindings(
            changeSet: changeSet,
            baselineFindings: baselineMatrix,
            currentFindings: [],
            retestedContexts: ["iPhone16Pro_large_light"]
        )
        #expect(partialMatrixReport.resolvedIssues == ["LoginForm|iPhone16Pro_large_light|default|textTruncated|title_lbl"])
        #expect(partialMatrixReport.notRetested == ["LoginForm|iPhoneSE_accessibility5_dark|default|textTruncated|title_lbl"])
        #expect(!partialMatrixReport.passed)

        // Case 4: Unrelated new finding in another rule while baseline finding is resolved
        let unrelatedReport = FixVerifier.verifyFindings(
            changeSet: changeSet,
            baselineFindings: [
                IdentifiedFinding(ruleID: "touchTargetTooSmall", target: "LoginForm", elementAnchor: "btn_submit", matrixContext: "iPhone16Pro_large_light")
            ],
            currentFindings: [
                IdentifiedFinding(ruleID: "wcagContrastAA", target: "LoginForm", elementAnchor: "subtitle_lbl", matrixContext: "iPhone16Pro_large_light")
            ]
        )
        #expect(unrelatedReport.resolvedIssues.count == 1)
        #expect(unrelatedReport.introducedIssues == ["LoginForm|iPhone16Pro_large_light|default|wcagContrastAA|subtitle_lbl"])
        #expect(unrelatedReport.hasRegressions)
        #expect(!unrelatedReport.passed)
    }
}
