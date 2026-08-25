import Testing
import Foundation
@testable import ViewLensKit

@Suite("Native Accessibility Hierarchy & VoiceOver Traversal Tests (NV-4)")
struct NativeAccessibilityHierarchyTests {

    @Test("VoiceOverPredictor produces ordered traversal and rotor inventory from NonvisualScreenModel")
    func testVoiceOverPredictorAndRotor() {
        let screenID = NonvisualID("screen:login")
        let regionID = NonvisualID("region:form")

        let region = NonvisualRegion(
            id: regionID,
            label: "Login Card",
            role: "card",
            elementIDs: [NonvisualID("el:heading"), NonvisualID("el:username"), NonvisualID("el:submit")]
        )

        let heading = NonvisualElement(
            id: NonvisualID("el:heading"),
            type: "heading",
            visibleLabel: "Welcome Back",
            bounds: BoundingBox(x: 0.1, y: 0.1, width: 0.8, height: 0.05),
            regionID: regionID,
            semantics: NonvisualSemantics(accessibleName: "Welcome Back", role: "heading", isHeading: true)
        )

        let username = NonvisualElement(
            id: NonvisualID("el:username"),
            type: "textField",
            visibleLabel: "Email",
            bounds: BoundingBox(x: 0.1, y: 0.2, width: 0.8, height: 0.06),
            regionID: regionID,
            semantics: NonvisualSemantics(accessibleName: "Email Address", role: "textField", value: "user@example.com")
        )

        let submit = NonvisualElement(
            id: NonvisualID("el:submit"),
            type: "button",
            visibleLabel: "Sign In",
            bounds: BoundingBox(x: 0.1, y: 0.35, width: 0.8, height: 0.08),
            regionID: regionID,
            semantics: NonvisualSemantics(accessibleName: "Sign In", role: "button", hint: "Double tap to log in"),
            isInteractive: true
        )

        let readingSequence = NavigationSequence(
            id: NonvisualID("seq:reading"),
            kind: .readingOrder,
            elementIDs: [heading.id, username.id, submit.id],
            evidence: EvidenceProvenance(kind: .derived, source: "test")
        )

        let model = NonvisualScreenModel(
            id: screenID,
            title: "Login Screen",
            sourceMode: .rendered,
            regions: [region],
            elements: [heading, username, submit],
            navigationSequences: [readingSequence]
        )

        // 1. Predict VoiceOver Transcript
        let transcript = VoiceOverPredictor.predictTranscript(from: model)
        #expect(transcript.entries.count == 3)
        #expect(transcript.entries[0].speechText.contains("Welcome Back"))
        #expect(transcript.entries[0].traits.contains("heading"))
        #expect(transcript.entries[1].speechText.contains("Email Address"))
        #expect(transcript.entries[2].speechText.contains("Sign In"))
        #expect(transcript.entries[2].hint?.contains("Double tap") == true)

        let formattedSpeech = transcript.formattedTranscript(profile: .speech)
        #expect(formattedSpeech.contains("1. Welcome Back"))
        #expect(formattedSpeech.contains("3. Sign In"))

        // 2. Rotor Inventory Extraction
        let rotor = VoiceOverPredictor.extractRotorInventory(from: model)
        #expect(rotor.headings.count == 1)
        #expect(rotor.headings[0].label == "Welcome Back")
        #expect(rotor.interactiveControls.count == 1)
        #expect(rotor.interactiveControls[0].label == "Sign In")
        #expect(rotor.landmarks.count == 1)
        #expect(rotor.landmarks[0].label == "Login Card")
    }
}
