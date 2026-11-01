import Testing
import Foundation
import CoreGraphics
@testable import ViewLensKit

@Suite("Tranche D: Native Scenarios, Guarded Journeys, and Nonvisual Evidence Browser (LEARN-11, LEARN-12, LEARN-13)")
struct TrancheDScenariosAndJourneysTests {

    // MARK: - LEARN-11: Native Scenario Inventory and Resource Intake

    @Test("LEARN-11: Standard scenario catalog provides all 7 functional states with target-compatible types and stable IDs")
    func scenarioCatalogCoversAllFunctionalStates() {
        let fixtures = NativeScenarioInventoryEngine.buildStandardScenarioCatalog(templateName: "LoginForm")
        #expect(fixtures.count == 7)

        let stateKinds = Set(fixtures.map(\.stateKind))
        #expect(stateKinds.contains(.loading))
        #expect(stateKinds.contains(.empty))
        #expect(stateKinds.contains(.error))
        #expect(stateKinds.contains(.populated))
        #expect(stateKinds.contains(.offline))
        #expect(stateKinds.contains(.permission))
        #expect(stateKinds.contains(.authentication))

        for fixture in fixtures {
            #expect(!fixture.declaredInventory.isEmpty)
            #expect(fixture.targetTemplate == "LoginForm")
            #expect(fixture.declaredInventory.allSatisfy { !$0.id.isEmpty && !$0.intendedLabel.isEmpty })
        }
    }

    @Test("LEARN-11: Declared inventory is evaluated separately from rendered observations, tracking absent and occluded states")
    func inventoryEvaluationSeparatesDeclaredFromRendered() {
        let fixture = NativeScenarioInventoryEngine.buildFixture(templateName: "LoginForm", stateKind: .populated)
        let declared = fixture.declaredInventory

        // Simulate observations: 2 visible, 1 zero-size (occluded), 1 absent
        let rendered: [RenderedObservationItem] = [
            RenderedObservationItem(
                id: "obs_header",
                declaredID: declared[0].id,
                observationStatus: .visible,
                settledBounds: BoundingBox(x: 0.1, y: 0.1, width: 0.8, height: 0.1),
                measuredAlpha: 1.0
            ),
            RenderedObservationItem(
                id: "obs_row_0",
                declaredID: declared[1].id,
                observationStatus: .visible,
                settledBounds: BoundingBox(x: 0.1, y: 0.25, width: 0.8, height: 0.1),
                measuredAlpha: 1.0
            ),
            RenderedObservationItem(
                id: "obs_row_1",
                declaredID: declared[2].id,
                observationStatus: .occluded,
                settledBounds: BoundingBox(x: 0.1, y: 0.4, width: 0.0, height: 0.0), // Zero size = occluded
                measuredAlpha: 1.0
            )
            // declared[3] is omitted -> absent
        ]

        let report = NativeScenarioInventoryEngine.evaluateObservations(
            declared: declared,
            rendered: rendered,
            fixtureID: fixture.id,
            stateKind: fixture.stateKind
        )

        #expect(report.totalDeclaredCount == 4)
        #expect(report.visibleCount == 2)
        #expect(report.occludedCount == 1)
        #expect(report.absentCount == 1)
        #expect(report.occludedItemIDs.contains(declared[2].id))
        #expect(report.absentItemIDs.contains(declared[3].id))
        #expect(report.baselineMeasurementEligible == true)
    }

    @Test("LEARN-11: Resource intake validates dimensions, aspect, alpha, and marks synthetic substitutes baseline-ineligible")
    func resourceIntakeValidationAndSyntheticMarking() {
        // 1. Valid PNG with RGBA alpha channel (colorType 6)
        var pngData = Data([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]) // PNG header
        pngData.append(contentsOf: [0x00, 0x00, 0x00, 0x0D, 0x49, 0x48, 0x44, 0x52]) // IHDR chunk
        pngData.append(contentsOf: [0x00, 0x00, 0x01, 0x90]) // width: 400
        pngData.append(contentsOf: [0x00, 0x00, 0x01, 0x2C]) // height: 300
        pngData.append(contentsOf: [0x08, 0x06, 0x00, 0x00, 0x00]) // bitDepth 8, colorType 6 (RGBA)

        let realResult = NativeScenarioInventoryEngine.validateResource(
            url: URL(fileURLWithPath: "/Assets/app_icon.png"),
            data: pngData,
            isSyntheticSubstitute: false
        )
        #expect(realResult.isDecodable == true)
        #expect(realResult.width == 400.0)
        #expect(realResult.height == 300.0)
        #expect(realResult.aspectRatio == (400.0 / 300.0))
        #expect(realResult.realAlphaDetected == true)
        #expect(realResult.isSynthetic == false)
        #expect(realResult.baselineMeasurementEligible == true)
        #expect(realResult.validationErrors.isEmpty)

        // 2. Synthetic substitute resource
        let syntheticResult = NativeScenarioInventoryEngine.validateResource(
            url: URL(fileURLWithPath: "/Synthetic/avatar_placeholder.png"),
            data: pngData,
            isSyntheticSubstitute: true
        )
        #expect(syntheticResult.isDecodable == true)
        #expect(syntheticResult.isSynthetic == true)
        #expect(syntheticResult.baselineMeasurementEligible == false) // Must be baseline-ineligible!

        // 3. Corrupt/empty resource
        let corruptResult = NativeScenarioInventoryEngine.validateResource(
            url: URL(fileURLWithPath: "/Corrupt/broken.png"),
            data: Data([0x00, 0x01, 0x02])
        )
        #expect(corruptResult.isDecodable == false)
        #expect(corruptResult.baselineMeasurementEligible == false)
        #expect(!corruptResult.validationErrors.isEmpty)
    }

    @Test("LEARN-11: Stress lab evaluates supported permutations and reports unsupported permutations as not evaluated")
    func stressLabPermutationExecution() {
        let fixture = NativeScenarioInventoryEngine.buildFixture(templateName: "LoginForm", stateKind: .populated)
        let rendered: [RenderedObservationItem] = fixture.declaredInventory.map {
            RenderedObservationItem(
                id: "obs_\($0.id)",
                declaredID: $0.id,
                observationStatus: .visible,
                settledBounds: BoundingBox(x: 0.1, y: 0.1, width: 0.8, height: 0.2),
                measuredAlpha: 1.0
            )
        }

        // Suppose only standard, rtl, and ax5 are supported in this test runner; landscape is unsupported
        let supported: Set<String> = ["perm-standard", "perm-rtl", "perm-ax5"]
        let report = NativeScenarioInventoryEngine.runStressLab(
            fixture: fixture,
            renderedItems: rendered,
            supportedPermutationIDs: supported
        )

        #expect(report.evaluatedPermutationsCount == 3)
        #expect(report.notEvaluatedPermutationsCount > 0)
        #expect(report.allEvaluatedPassed == true)

        let landscapeOutcome = report.permutationOutcomes.first { $0.permutationID == "perm-landscape" }
        #expect(landscapeOutcome?.wasEvaluated == false)
        #expect(landscapeOutcome?.passed == false)
        #expect(landscapeOutcome?.unsupportedReason != nil)
    }

    // MARK: - LEARN-12: Guarded Journeys & Independent Accessibility Focus

    @Test("LEARN-12: Guarded journey checks policy before every action, enforcing step and duration budgets")
    func guardedJourneyPolicyEnforcement() {
        let route = JourneyRoute(
            name: "LoginToDashboard",
            sourceState: "LoginView",
            destinationState: "DashboardView",
            allowedActionKinds: [.activate, .typeText],
            stepBudget: 2,
            durationBudgetMs: 5000
        )
        let policy = JourneyPolicy(maxStepLimit: 2, maxDurationMs: 5000)

        // 1. Allowed action within budget
        let (approved1, reason1) = GuardedJourneyEngine.validateActionPolicy(
            action: UIAction(kind: .activate, elementID: "btn_login"),
            route: route,
            policy: policy,
            currentStepIndex: 0,
            elapsedDurationMs: 100
        )
        #expect(approved1 == true)
        #expect(reason1 == nil)

        // 2. Disallowed action kind
        let (approved2, reason2) = GuardedJourneyEngine.validateActionPolicy(
            action: UIAction(kind: .scroll, elementID: "scroll_view"),
            route: route,
            policy: policy,
            currentStepIndex: 1,
            elapsedDurationMs: 200
        )
        #expect(approved2 == false)
        #expect(reason2?.contains("Action kind 'scroll' is not permitted") == true)

        // 3. Step budget exceeded
        let (approved3, reason3) = GuardedJourneyEngine.validateActionPolicy(
            action: UIAction(kind: .activate, elementID: "btn_login"),
            route: route,
            policy: policy,
            currentStepIndex: 2, // At limit
            elapsedDurationMs: 300
        )
        #expect(approved3 == false)
        #expect(reason3?.contains("Step budget exceeded") == true)
    }

    @Test("LEARN-12: Separates dispatch, observed effect, focus, announcements, and detects focus races and duplicate announcements")
    func guardedJourneyFocusRaceAndDefectDetection() {
        let route = JourneyRoute(
            name: "FormSubmission",
            sourceState: "FormEntry",
            destinationState: "FormConfirmation",
            allowedActionKinds: [.activate, .typeText],
            stepBudget: 5,
            durationBudgetMs: 10000
        )

        let steps: [(action: UIAction, targetState: String, inputFocus: JourneyFocusTarget?, a11yFocus: JourneyFocusTarget?, announcements: [String])] = [
            (
                action: UIAction(kind: .typeText, elementID: "field_email", text: "user@example.com"),
                targetState: "FormEntry",
                inputFocus: JourneyFocusTarget(elementID: "field_email", label: "Email", role: "textField"),
                a11yFocus: JourneyFocusTarget(elementID: "field_email", label: "Email", role: "textField"),
                announcements: ["Editing Email"]
            ),
            (
                // Focus race: Input focus is at field_password while VoiceOver focus jumped to terms_link!
                action: UIAction(kind: .activate, elementID: "btn_submit"),
                targetState: "FormConfirmation",
                inputFocus: JourneyFocusTarget(elementID: "field_password", label: "Password", role: "secureTextField"),
                a11yFocus: JourneyFocusTarget(elementID: "terms_link", label: "Terms of Service", role: "link"),
                announcements: ["Form submitted", "Form submitted"] // Duplicate consecutive announcements!
            )
        ]

        let report = GuardedJourneyEngine.executeScriptedJourney(route: route, steps: steps)

        #expect(report.completedSuccessfully == true)
        #expect(report.visitedStates.contains("FormEntry"))
        #expect(report.visitedStates.contains("FormConfirmation"))
        #expect(report.observedEdges.count == 1) // Only FormEntry -> FormConfirmation transition

        // Defect detections
        #expect(report.focusRacesCount == 1)
        #expect(report.duplicateAnnouncementsCount == 1)
        #expect(!report.generatedManualVerificationSteps.isEmpty)
        #expect(report.generatedManualVerificationSteps.contains { $0.contains("focus race") })
    }

    // MARK: - LEARN-13: Nonvisual Evidence Browser & Release Qualification

    @Test("LEARN-13: Nonvisual evidence browser generates text-first report, braille lines, and non-color status labels")
    func nonvisualEvidenceBrowserFormatting() {
        let issues: [ViewLensIssue] = [
            ViewLensIssue(
                kind: .tappableTargetTooSmall,
                severity: .error,
                description: "Primary submit button height is 32pt (below 44pt minimum)",
                elementIndex: 1,
                identifier: "btn_submit",
                wcagCriterion: "2.5.8",
                remediation: RemediationAdvice(description: "Set frame(minHeight: 44)")
            ),
            ViewLensIssue(
                kind: .contrastRisk,
                severity: .warning,
                description: "Secondary label contrast ratio is 3.8:1 (below 4.5:1)",
                elementIndex: 2,
                identifier: "lbl_caption",
                wcagCriterion: "1.4.3",
                remediation: RemediationAdvice(description: "Use ViewLensTheme.primaryText")
            )
        ]

        let snapshot = NonvisualEvidenceBrowserEngine.buildSnapshot(
            reviewID: "rev-2026-001",
            title: "LoginForm",
            buildIdentity: "build-2026.11.01",
            issues: issues,
            humanReviewAccepted: false
        )

        #expect(snapshot.overallStatus == .error)
        #expect(snapshot.items.count == 2)
        #expect(snapshot.items[0].status == .error)
        #expect(snapshot.items[0].status.rawValue == "[ERROR]")
        #expect(snapshot.items[0].brailleSummaryLine.contains(":: [ERR] el-1 (tappableTargetTooSmall) #2.5.8"))
        #expect(snapshot.items[1].status == .warning)
        #expect(snapshot.items[1].status.rawValue == "[WARNING]")
        #expect(snapshot.items[1].brailleSummaryLine.contains(":: [WARN] el-2 (contrastRisk) #1.4.3"))

        let textReport = snapshot.formattedTextReport()
        #expect(textReport.contains("# Nonvisual Evidence Review: LoginForm"))
        #expect(textReport.contains("[ERROR] tappableTargetTooSmall (el-1)"))
        #expect(textReport.contains("[WARNING] contrastRisk (el-2)"))
        #expect(textReport.contains("viewlens://reviews/rev-2026-001/report"))
    }

    @Test("LEARN-13: Release qualification strictly enforces that automated checks alone cannot close human release acceptance")
    func releaseQualificationEnforcesHumanATSignOff() {
        // 1. Automated checks pass (0 errors), but human AT sign-off is missing
        let cleanSnapshot = NonvisualEvidenceBrowserEngine.buildSnapshot(
            reviewID: "rev-clean",
            title: "CleanView",
            buildIdentity: "build-001",
            issues: [
                ViewLensIssue(kind: .contrastRisk, severity: .info, description: "Informational notice")
            ],
            humanReviewAccepted: false
        )
        #expect(cleanSnapshot.qualificationDecision.automatedChecksPassed == true)
        #expect(cleanSnapshot.qualificationDecision.humanReleaseAccepted == false)
        #expect(cleanSnapshot.qualificationDecision.isQualifiedForRelease == false) // CANNOT release without human sign-off!

        // 2. Automated checks pass AND human AT review is confirmed
        let signedOffSnapshot = NonvisualEvidenceBrowserEngine.buildSnapshot(
            reviewID: "rev-signed",
            title: "SignedOffView",
            buildIdentity: "build-002",
            issues: [],
            humanReviewAccepted: true,
            pendingReviewerNotes: []
        )
        #expect(signedOffSnapshot.qualificationDecision.automatedChecksPassed == true)
        #expect(signedOffSnapshot.qualificationDecision.humanReleaseAccepted == true)
        #expect(signedOffSnapshot.qualificationDecision.isQualifiedForRelease == true) // Fully qualified!

        // 3. Automated checks fail (has error), human cannot override to release
        let failedSnapshot = NonvisualEvidenceBrowserEngine.buildSnapshot(
            reviewID: "rev-failed",
            title: "FailedView",
            buildIdentity: "build-003",
            issues: [
                ViewLensIssue(kind: .clippedElement, severity: .error, description: "Clipped element")
            ],
            humanReviewAccepted: true
        )
        #expect(failedSnapshot.qualificationDecision.automatedChecksPassed == false)
        #expect(failedSnapshot.qualificationDecision.isQualifiedForRelease == false)
    }
}
