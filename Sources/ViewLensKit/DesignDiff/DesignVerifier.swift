import Foundation
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers

#if canImport(SwiftUI)
import SwiftUI

/// Orchestrates Design-to-Code verification between Figma reference designs and native SwiftUI code.
@MainActor
public struct DesignVerifier {

    /// Verifies a registered SwiftUI template against a reference design image.
    public static func verify(
        referenceImage: CGImage,
        referenceSource: String,
        templateName: String,
        device: DeviceProfile = .iPhone16Pro,
        thresholdSSIM: Double = 0.98,
        pixelTolerance: Double = 0.05,
        includeAccessibility: Bool = true,
        heatmapOutputPath: String? = nil
    ) async -> DesignDiffReport {
        guard let view = TemplateRegistry.shared.template(named: templateName) else {
            let emptyDiff = VisualDiffResult(
                ssimScore: 0.0,
                mismatchPercentage: 100.0,
                differingPixelsCount: 0,
                totalPixelsCount: 0,
                passed: false,
                tolerance: pixelTolerance
            )
            return DesignDiffReport(
                referenceSource: referenceSource,
                candidateTemplate: templateName,
                visualDiff: emptyDiff,
                tokenMismatches: [
                    TokenMismatch(
                        token: "Template",
                        expectedFigma: templateName,
                        actualSwiftUI: "Not found",
                        remediationSnippet: nil
                    )
                ],
                passed: false
            )
        }

        // 1. Render SwiftUI candidate template in-process
        guard let candidateImage = InProcessCanvasRenderer.render(
            profile: device,
            dynamicTypeSize: .large,
            colorScheme: .light,
            content: { view }
        ) else {
            let emptyDiff = VisualDiffResult(
                ssimScore: 0.0,
                mismatchPercentage: 100.0,
                differingPixelsCount: 0,
                totalPixelsCount: 0,
                passed: false,
                tolerance: pixelTolerance
            )
            return DesignDiffReport(
                referenceSource: referenceSource,
                candidateTemplate: templateName,
                visualDiff: emptyDiff,
                passed: false
            )
        }

        // 2. Perform Visual SSIM & Pixel Diff
        let diffResult = VisualDiffEngine.compare(
            reference: referenceImage,
            candidate: candidateImage,
            thresholdSSIM: thresholdSSIM,
            pixelTolerance: pixelTolerance
        )

        // 3. Optional Diff Heatmap export
        if let heatmapPath = heatmapOutputPath,
           let heatmapImage = VisualDiffEngine.generateDiffHeatmap(
            reference: referenceImage,
            candidate: candidateImage,
            pixelTolerance: pixelTolerance
           ) {
            savePNG(image: heatmapImage, to: URL(fileURLWithPath: heatmapPath))
        }

        // 4. Optional Accessibility Audit
        var a11yReport: AccessibilityReport? = nil
        if includeAccessibility {
            a11yReport = await AccessibilityAuditor.auditTemplate(
                named: templateName,
                targetLevel: "AA",
                device: device
            )
        }

        let passed = diffResult.passed && (a11yReport?.passed ?? true)

        return DesignDiffReport(
            referenceSource: referenceSource,
            candidateTemplate: templateName,
            visualDiff: diffResult,
            tokenMismatches: [],
            geometryDeltas: [],
            accessibilityReport: a11yReport,
            passed: passed
        )
    }

    private static func savePNG(image: CGImage, to url: URL) {
        guard let destination = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil) else {
            return
        }
        CGImageDestinationAddImage(destination, image, nil)
        CGImageDestinationFinalize(destination)
    }
}
#endif
