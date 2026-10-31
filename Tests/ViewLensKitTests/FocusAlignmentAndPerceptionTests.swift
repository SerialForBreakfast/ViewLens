import Testing
import Foundation
import CoreGraphics
#if canImport(NativeUIAuditKit)
import NativeUIAuditKit
#endif
@testable import ViewLensKit

@Suite("Focus Alignment & Perception Primitives Tests (Track 4 & ADR-0007)")
struct FocusAlignmentAndPerceptionTests {

    @Test("VisualSemanticCorrelator detects focus desynchronization when visual has focus ring but accessibility lacks it")
    func testFocusDesynchronizationVisualOnly() {
        let visual = DetectedElement(
            type: "primaryButton",
            confidence: 0.95,
            boundingBox: BoundingBox(x: 0.2, y: 0.3, width: 0.6, height: 0.1),
            isFocused: true,
            focusConfidence: 0.98,
            isAmbiguousFocus: false
        )

        let prov = EvidenceProvenance(kind: .measured, source: "testFixture")
        let a11yNode = NativeAccessibilityNode(
            id: NonvisualID("btn_submit"),
            label: "Submit",
            traits: [.isButton], // Missing .isSelected
            frame: BoundingBox(x: 0.2, y: 0.3, width: 0.6, height: 0.1),
            provenance: prov
        )

        let report = VisualSemanticCorrelator.correlate(
            visualElements: [visual],
            accessibilityNodes: [a11yNode]
        )

        #expect(report.matchedPairs.count == 1)
        #expect(report.conflicts.contains { $0.kind == .focusDesynchronization })
        let desync = report.conflicts.first { $0.kind == .focusDesynchronization }
        #expect(desync?.reason.contains("ADR-0007") == true)
    }

    @Test("VisualSemanticCorrelator detects focus desynchronization when accessibility claims focus but visual lacks it")
    func testFocusDesynchronizationA11yOnly() {
        let visual = DetectedElement(
            type: "primaryButton",
            confidence: 0.95,
            boundingBox: BoundingBox(x: 0.2, y: 0.3, width: 0.6, height: 0.1),
            isFocused: false,
            focusConfidence: 0.05,
            isAmbiguousFocus: false
        )

        let prov = EvidenceProvenance(kind: .measured, source: "testFixture")
        let a11yNode = NativeAccessibilityNode(
            id: NonvisualID("btn_submit"),
            label: "Submit",
            traits: [.isButton, .isSelected],
            frame: BoundingBox(x: 0.2, y: 0.3, width: 0.6, height: 0.1),
            provenance: prov
        )

        let report = VisualSemanticCorrelator.correlate(
            visualElements: [visual],
            accessibilityNodes: [a11yNode]
        )

        #expect(report.matchedPairs.count == 1)
        #expect(report.conflicts.contains { $0.kind == .focusDesynchronization })
    }

    @Test("VisualSemanticCorrelator flags ambiguous visual focus")
    func testAmbiguousFocusDetection() {
        let visual = DetectedElement(
            type: "primaryButton",
            confidence: 0.90,
            boundingBox: BoundingBox(x: 0.2, y: 0.3, width: 0.6, height: 0.1),
            isFocused: true,
            focusConfidence: 0.52,
            isAmbiguousFocus: true
        )

        let prov = EvidenceProvenance(kind: .measured, source: "testFixture")
        let a11yNode = NativeAccessibilityNode(
            id: NonvisualID("btn_submit"),
            label: "Submit",
            traits: [.isButton, .isSelected],
            frame: BoundingBox(x: 0.2, y: 0.3, width: 0.6, height: 0.1),
            provenance: prov
        )

        let report = VisualSemanticCorrelator.correlate(
            visualElements: [visual],
            accessibilityNodes: [a11yNode]
        )

        #expect(report.matchedPairs.count == 1)
        #expect(report.conflicts.contains { $0.kind == .ambiguousFocus })
    }

    @Test("VisualSemanticCorrelator passes clean alignment when visual and accessibility focus match")
    func testSynchronizedFocusAlignment() {
        let visual = DetectedElement(
            type: "primaryButton",
            confidence: 0.96,
            boundingBox: BoundingBox(x: 0.2, y: 0.3, width: 0.6, height: 0.1),
            isFocused: true,
            focusConfidence: 0.95,
            isAmbiguousFocus: false
        )

        let prov = EvidenceProvenance(kind: .measured, source: "testFixture")
        let a11yNode = NativeAccessibilityNode(
            id: NonvisualID("btn_submit"),
            label: "Submit",
            traits: [.isButton, .isSelected],
            frame: BoundingBox(x: 0.2, y: 0.3, width: 0.6, height: 0.1),
            provenance: prov
        )

        let report = VisualSemanticCorrelator.correlate(
            visualElements: [visual],
            accessibilityNodes: [a11yNode]
        )

        #expect(report.matchedPairs.count == 1)
        #expect(report.conflicts.isEmpty)
        #expect(report.matchRate == 1.0)
    }

    @Test("FlowReplayEngine computes perceptual mutation regions and scale from frame transitions")
    func testPerceptionInFlowReplay() {
        // Create two 200x200 test images: one blank, one with a 50x50 block in the center
        let frame1 = createSolidImage(width: 200, height: 200, grayValue: 0)
        let frame2 = createBlockImage(width: 200, height: 200, blockRect: CGRect(x: 75, y: 75, width: 50, height: 50))

        let prov = EvidenceProvenance(kind: .measured, source: "testFixture")
        let node = NativeAccessibilityNode(
            id: NonvisualID("content_view"),
            label: "Content",
            traits: [.isStaticText],
            frame: BoundingBox(x: 0.1, y: 0.1, width: 0.8, height: 0.8),
            provenance: prov
        )

        let script = FlowScript(
            name: "PerceptionTestFlow",
            targetTemplate: "ContentView",
            steps: [
                FlowStep(
                    id: "step_mutate",
                    action: UIAction(kind: .activate, elementID: "content_view"),
                    assertion: FlowAssertion(kind: "element_exists", targetElementID: "content_view")
                )
            ]
        )

        let report = FlowReplayEngine.replay(
            script: script,
            accessibilityNodes: [node],
            previousFrame: frame1,
            currentFrame: frame2
        )

        #expect(report.passed)
        #expect(report.stepResults.count == 1)
        let stepRes = report.stepResults[0]

        #if canImport(NativeUIAuditKit)
        #expect(stepRes.changeScale != nil)
        #expect(stepRes.changeScale == "local" || stepRes.changeScale == "regional")
        #expect(stepRes.mutatedRegions != nil)
        #expect(!stepRes.mutatedRegions!.isEmpty)
        #expect(stepRes.similarityDistance != nil)
        #endif
    }

    @Test("VisualSemanticCorrelator detects role mismatch when a visual badge lacks accessibility label and value")
    func testBadgeMissingLabelOrValueConflict() {
        let badge = DetectedElement(
            type: "badge",
            confidence: 0.92,
            boundingBox: BoundingBox(x: 0.8, y: 0.1, width: 0.05, height: 0.05)
        )

        let prov = EvidenceProvenance(kind: .measured, source: "testFixture")
        let a11yNode = NativeAccessibilityNode(
            id: NonvisualID("notification_badge"),
            label: nil,
            value: nil,
            traits: [.isStaticText],
            frame: BoundingBox(x: 0.8, y: 0.1, width: 0.05, height: 0.05),
            provenance: prov
        )

        let report = VisualSemanticCorrelator.correlate(
            visualElements: [badge],
            accessibilityNodes: [a11yNode]
        )

        #expect(report.matchedPairs.count == 1)
        #expect(report.conflicts.contains { $0.kind == .roleMismatch && $0.reason.contains("badge") })
    }

    @Test("VisualSemanticCorrelator passes clean correlation when a visual badge provides label or value")
    func testBadgeWithContentPasses() {
        let badge = DetectedElement(
            type: "badge",
            confidence: 0.94,
            boundingBox: BoundingBox(x: 0.8, y: 0.1, width: 0.05, height: 0.05)
        )

        let prov = EvidenceProvenance(kind: .measured, source: "testFixture")
        let a11yNode = NativeAccessibilityNode(
            id: NonvisualID("notification_badge"),
            label: "5 unread notifications",
            value: "5",
            traits: [.isStaticText],
            frame: BoundingBox(x: 0.8, y: 0.1, width: 0.05, height: 0.05),
            provenance: prov
        )

        let report = VisualSemanticCorrelator.correlate(
            visualElements: [badge],
            accessibilityNodes: [a11yNode]
        )

        #expect(report.matchedPairs.count == 1)
        #expect(report.conflicts.isEmpty)
        #expect(report.matchRate == 1.0)
    }

    @Test("FlowReplayEngine matches text anchors with separator tolerance")
    func testTextAnchorSeparatorTolerance() {
        // Multiword anchor matching with bullet or apostrophe separator
        #expect(FlowReplayEngine.matchesTextAnchor("System Settings", in: "System • Settings"))
        #expect(FlowReplayEngine.matchesTextAnchor("General Settings", in: "› General Settings"))
        #expect(FlowReplayEngine.matchesTextAnchor("User Profile", in: "User ' Profile"))
        #expect(!FlowReplayEngine.matchesTextAnchor("Network Settings", in: "General • Settings"))
    }

    // MARK: - Image Creation Helpers

    private func createSolidImage(width: Int, height: Int, grayValue: UInt8) -> CGImage {
        let colorSpace = CGColorSpaceCreateDeviceGray()
        var buffer = [UInt8](repeating: grayValue, count: width * height)
        let context = CGContext(
            data: &buffer,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: width,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.none.rawValue
        )!
        return context.makeImage()!
    }

    private func createBlockImage(width: Int, height: Int, blockRect: CGRect) -> CGImage {
        let colorSpace = CGColorSpaceCreateDeviceGray()
        var buffer = [UInt8](repeating: 0, count: width * height)
        let context = CGContext(
            data: &buffer,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: width,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.none.rawValue
        )!
        context.setFillColor(gray: 1.0, alpha: 1.0)
        context.fill(blockRect)
        return context.makeImage()!
    }
}
