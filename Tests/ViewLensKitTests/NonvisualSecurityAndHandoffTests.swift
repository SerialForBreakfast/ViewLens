import Testing
import Foundation
@testable import ViewLensKit

@Suite("Nonvisual Security, Manual Verification, and Patch Handoff Tests (NV-4.7, NV-4.9, NV-5.6, NV-5.8)")
struct NonvisualSecurityAndHandoffTests {

    @Test("NonvisualRedactor scrubs password fields and Bearer tokens")
    func testNonvisualRedactor() {
        let passwordElement = NonvisualElement(
            id: NonvisualID("el:pwd"),
            type: "secureTextField",
            visibleLabel: "MySecretPassword123",
            semantics: NonvisualSemantics(accessibleName: "Password", role: "secureTextField", value: "SuperSecret99!")
        )

        let tokenElement = NonvisualElement(
            id: NonvisualID("el:label_token"),
            type: "text",
            visibleLabel: "Authorization: Bearer eyJhbGciOiJIUzI1NiJ9.secret_payload",
            semantics: NonvisualSemantics(accessibleName: "API Key: secret_api_key_9999", role: "text")
        )

        let screen = NonvisualScreenModel(
            id: NonvisualID("screen:auth"),
            title: "Auth Screen with Bearer abc123xyz",
            sourceMode: .rendered,
            elements: [passwordElement, tokenElement]
        )

        let redacted = NonvisualRedactor.redact(screen)

        // 1. Password elements should have masked values
        let redactedPwd = redacted.elements.first { $0.id == NonvisualID("el:pwd") }
        #expect(redactedPwd?.visibleLabel == "••••••••")
        #expect(redactedPwd?.semantics?.value == "••••••••")

        // 2. Token element should have masked token pattern
        let redactedToken = redacted.elements.first { $0.id == NonvisualID("el:label_token") }
        #expect(redactedToken?.visibleLabel?.contains("[REDACTED_SECRET]") == true)
        #expect(redactedToken?.visibleLabel?.contains("secret_payload") == false)
        #expect(redactedToken?.semantics?.accessibleName?.contains("[REDACTED_SECRET]") == true)

        // 3. Screen title should have masked Bearer pattern
        #expect(redacted.title?.contains("Bearer [REDACTED_SECRET]") == true)
    }

    @Test("ManualVerificationGenerator creates structured VoiceOver test plans")
    func testManualVerificationGenerator() {
        let screen = NonvisualScreenModel(
            id: NonvisualID("screen:home"),
            title: "Dashboard",
            sourceMode: .rendered,
            elements: [
                NonvisualElement(
                    id: NonvisualID("el:h1"),
                    type: "heading",
                    visibleLabel: "Overview",
                    semantics: NonvisualSemantics(accessibleName: "Overview", role: "heading", isHeading: true)
                ),
                NonvisualElement(
                    id: NonvisualID("el:btn"),
                    type: "button",
                    visibleLabel: "Refresh",
                    semantics: NonvisualSemantics(accessibleName: "Refresh", role: "button"),
                    isInteractive: true
                )
            ]
        )

        let plan = ManualVerificationGenerator.generatePlan(from: screen)

        #expect(plan.steps.count >= 4)
        #expect(plan.steps[0].action.contains("VoiceOver"))
        #expect(plan.steps.contains { $0.action.contains("Rotor") })
        #expect(plan.steps.contains { $0.action.contains("Dynamic Type") })

        let md = plan.formattedMarkdown()
        #expect(md.contains("Manual VoiceOver Verification Plan"))
        #expect(md.contains("Overview"))
    }

    @Test("PatchPreviewGenerator generates structured handoffs and Swift regression tests")
    func testPatchPreviewGenerator() {
        let diff = SemanticScreenDiff(
            beforeScreenID: NonvisualID("screen:before"),
            afterScreenID: NonvisualID("screen:after"),
            changes: [
                SemanticChange(
                    id: NonvisualID("c:1"),
                    elementID: NonvisualID("el:save"),
                    kind: .findingResolved,
                    impact: .material,
                    description: "Missing accessible label fixed"
                )
            ]
        )

        let handoff = PatchPreviewGenerator.generateHandoff(for: "SaveSettingsButton", diff: diff)

        #expect(handoff.affectedElementIDs.contains(NonvisualID("el:save")))
        #expect(handoff.expectedSemanticChanges.count == 1)
        #expect(handoff.generatedSwiftRegressionTest.contains("@Suite"))
        #expect(handoff.generatedSwiftRegressionTest.contains("SaveSettingsButtonAccessibilityTests"))
        #expect(handoff.generatedSwiftRegressionTest.contains("@Test"))
    }
}
