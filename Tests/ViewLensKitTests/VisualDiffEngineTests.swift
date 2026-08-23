import Testing
import Foundation
import CoreGraphics
@testable import ViewLensKit

@Suite("Visual Diff & SSIM Design Verification Tests")
struct VisualDiffEngineTests {

    @Test("Identical images produce SSIM 1.0 and 0% mismatch")
    @MainActor
    func testIdenticalImages() {
        guard let view = TemplateRegistry.shared.template(named: "LoginForm"),
              let img1 = InProcessCanvasRenderer.render(profile: .iPhone16Pro, content: { view }),
              let img2 = InProcessCanvasRenderer.render(profile: .iPhone16Pro, content: { view }) else {
            Issue.record("Failed to render test images")
            return
        }

        let result = VisualDiffEngine.compare(reference: img1, candidate: img2)
        #expect(result.passed == true)
        #expect(result.ssimScore >= 0.999)
        #expect(result.mismatchPercentage == 0.0)
    }

    @Test("Differing images produce lower SSIM and detect pixel deltas")
    @MainActor
    func testDifferingImages() {
        guard let loginView = TemplateRegistry.shared.template(named: "LoginForm"),
              let cryptoView = TemplateRegistry.shared.template(named: "CryptoDashboardView"),
              let img1 = InProcessCanvasRenderer.render(profile: .iPhone16Pro, content: { loginView }),
              let img2 = InProcessCanvasRenderer.render(profile: .iPhone16Pro, content: { cryptoView }) else {
            Issue.record("Failed to render test images")
            return
        }

        let result = VisualDiffEngine.compare(reference: img1, candidate: img2)
        #expect(result.passed == false)
        #expect(result.ssimScore < 0.98)
        #expect(result.mismatchPercentage > 5.0)
    }

    @Test("Generates diff heatmap image successfully")
    @MainActor
    func testGenerateHeatmap() {
        guard let loginView = TemplateRegistry.shared.template(named: "LoginForm"),
              let checkoutView = TemplateRegistry.shared.template(named: "CheckoutView"),
              let img1 = InProcessCanvasRenderer.render(profile: .iPhone16Pro, content: { loginView }),
              let img2 = InProcessCanvasRenderer.render(profile: .iPhone16Pro, content: { checkoutView }) else {
            Issue.record("Failed to render test images")
            return
        }

        let heatmap = VisualDiffEngine.generateDiffHeatmap(reference: img1, candidate: img2)
        #expect(heatmap != nil)
        #expect(heatmap?.width == img1.width)
        #expect(heatmap?.height == img1.height)
    }

    @Test("DesignVerifier performs complete verification with accessibility")
    @MainActor
    func testDesignVerifier() async {
        guard let loginView = TemplateRegistry.shared.template(named: "LoginForm"),
              let refImage = InProcessCanvasRenderer.render(profile: .iPhone16Pro, content: { loginView }) else {
            Issue.record("Failed to render reference image")
            return
        }

        let report = await DesignVerifier.verify(
            referenceImage: refImage,
            referenceSource: "Figma_Login_Frame.png",
            templateName: "LoginForm",
            device: .iPhone16Pro,
            thresholdSSIM: 0.98,
            includeAccessibility: true
        )

        #expect(report.passed == true)
        #expect(report.visualDiff.passed == true)
        #expect(report.accessibilityReport?.passed == true)
        #expect(report.formattedMarkdown().contains("ViewLens Design-to-Code Verification"))
    }
}
