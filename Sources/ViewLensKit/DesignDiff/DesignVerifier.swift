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
        heatmapOutputPath: String? = nil,
        progress: (@Sendable (Double, String) async -> Bool)? = nil
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

        guard await progress?(10, "Preparing design verification render") != false else {
            return cancellationReport(referenceSource: referenceSource, templateName: templateName, pixelTolerance: pixelTolerance)
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
        guard await progress?(30, "Rendered candidate template") != false else {
            return cancellationReport(referenceSource: referenceSource, templateName: templateName, pixelTolerance: pixelTolerance)
        }

        // 2. Perform Visual SSIM & Pixel Diff
        let diffResult = VisualDiffEngine.compare(
            reference: referenceImage,
            candidate: candidateImage,
            thresholdSSIM: thresholdSSIM,
            pixelTolerance: pixelTolerance
        )
        guard await progress?(52, "Computed SSIM and pixel differences") != false else {
            return cancellationReport(referenceSource: referenceSource, templateName: templateName, pixelTolerance: pixelTolerance)
        }

        // 3. Optional Diff Heatmap export
        if let heatmapPath = heatmapOutputPath {
            guard await progress?(60, "Generating design-diff heatmap") != false else {
                return cancellationReport(referenceSource: referenceSource, templateName: templateName, pixelTolerance: pixelTolerance)
            }
            if let heatmapImage = VisualDiffEngine.generateDiffHeatmap(
                reference: referenceImage,
                candidate: candidateImage,
                pixelTolerance: pixelTolerance
            ) {
                guard await progress?(68, "Writing design-diff heatmap") != false else {
                    return cancellationReport(referenceSource: referenceSource, templateName: templateName, pixelTolerance: pixelTolerance)
                }
                savePNG(image: heatmapImage, to: URL(fileURLWithPath: heatmapPath))
            }
        }
        guard await progress?(72, "Design artifact stage complete") != false else {
            return cancellationReport(referenceSource: referenceSource, templateName: templateName, pixelTolerance: pixelTolerance)
        }

        // 4. Optional Accessibility Audit
        var a11yReport: AccessibilityReport? = nil
        if includeAccessibility {
            a11yReport = await AccessibilityAuditor.auditTemplate(
                named: templateName,
                targetLevel: "AA",
                device: device,
                progress: { value, message in
                    await progress?(72 + (value * 0.24), message) ?? true
                }
            )
        }

        guard await progress?(96, "Assembling design verification evidence") != false else {
            return cancellationReport(referenceSource: referenceSource, templateName: templateName, pixelTolerance: pixelTolerance)
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

    private static func cancellationReport(
        referenceSource: String,
        templateName: String,
        pixelTolerance: Double
    ) -> DesignDiffReport {
        DesignDiffReport(
            referenceSource: referenceSource,
            candidateTemplate: templateName,
            visualDiff: VisualDiffResult(
                ssimScore: 0,
                mismatchPercentage: 100,
                differingPixelsCount: 0,
                totalPixelsCount: 0,
                passed: false,
                tolerance: pixelTolerance
            ),
            passed: false
        )
    }
}
#endif
