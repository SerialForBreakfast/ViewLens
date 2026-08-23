import Foundation
import CoreGraphics

#if canImport(AppKit)
import AppKit
#endif

/// Result of a visual perceptual comparison between a reference design and a rendered view.
public struct VisualDiffResult: Sendable, Codable, Equatable {
    public let ssimScore: Double              // 0.0 to 1.0 (1.0 = identical, >= 0.98 = passing)
    public let mismatchPercentage: Double      // 0.0% to 100.0% of pixels differing
    public let differingPixelsCount: Int
    public let totalPixelsCount: Int
    public let passed: Bool
    public let tolerance: Double

    public init(
        ssimScore: Double,
        mismatchPercentage: Double,
        differingPixelsCount: Int,
        totalPixelsCount: Int,
        passed: Bool,
        tolerance: Double
    ) {
        self.ssimScore = ssimScore
        self.mismatchPercentage = mismatchPercentage
        self.differingPixelsCount = differingPixelsCount
        self.totalPixelsCount = totalPixelsCount
        self.passed = passed
        self.tolerance = tolerance
    }
}

/// Pure Swift engine for Structural Similarity (SSIM) and perceptual pixel-by-pixel diffing
/// between Figma design reference images and native SwiftUI/UIKit rendered canvases.
public struct VisualDiffEngine: Sendable {

    /// Compares two CGImages using SSIM and pixel-level color distance.
    /// - Parameters:
    ///   - reference: Reference design image (e.g. from Figma or baseline snapshot).
    ///   - candidate: Candidate rendered image (from InProcessCanvasRenderer).
    ///   - thresholdSSIM: Minimum SSIM score to pass (default 0.98).
    ///   - pixelTolerance: Color distance tolerance in range [0.0, 1.0] (default 0.05).
    /// - Returns: VisualDiffResult with scores and pass/fail status.
    public static func compare(
        reference: CGImage,
        candidate: CGImage,
        thresholdSSIM: Double = 0.98,
        pixelTolerance: Double = 0.05
    ) -> VisualDiffResult {
        let refW = reference.width
        let refH = reference.height
        let candW = candidate.width
        let candH = candidate.height

        guard refW > 0, refH > 0, candW > 0, candH > 0 else {
            return VisualDiffResult(
                ssimScore: 0.0,
                mismatchPercentage: 100.0,
                differingPixelsCount: 0,
                totalPixelsCount: 0,
                passed: false,
                tolerance: pixelTolerance
            )
        }

        let commonW = min(refW, candW)
        let commonH = min(refH, candH)
        let totalPixels = commonW * commonH

        guard let refData = extractRGBAPixels(image: reference, width: commonW, height: commonH),
              let candData = extractRGBAPixels(image: candidate, width: commonW, height: commonH) else {
            return VisualDiffResult(
                ssimScore: 0.0,
                mismatchPercentage: 100.0,
                differingPixelsCount: 0,
                totalPixelsCount: totalPixels,
                passed: false,
                tolerance: pixelTolerance
            )
        }

        var differingCount = 0
        let toleranceSq = pixelTolerance * pixelTolerance

        // 1. Pixel Distance Loop
        for i in 0..<totalPixels {
            let offset = i * 4
            let dr = Double(refData[offset]) - Double(candData[offset])
            let dg = Double(refData[offset + 1]) - Double(candData[offset + 1])
            let db = Double(refData[offset + 2]) - Double(candData[offset + 2])

            // Normalized squared Euclidean distance
            let distSq = (dr * dr + dg * dg + db * db) / (3.0 * 255.0 * 255.0)
            if distSq > toleranceSq {
                differingCount += 1
            }
        }

        let mismatchPct = totalPixels > 0 ? (Double(differingCount) / Double(totalPixels)) * 100.0 : 0.0
        let roundedMismatch = Double(round(mismatchPct * 100) / 100)

        // 2. Mean Structural Similarity (MSSIM) Computation over 8x8 windows
        let ssim = computeMSSIM(
            refPixels: refData,
            candPixels: candData,
            width: commonW,
            height: commonH,
            windowSize: 8
        )
        let roundedSSIM = Double(round(ssim * 10000) / 10000)
        let passed = roundedSSIM >= thresholdSSIM && (roundedMismatch <= (pixelTolerance * 100.0))

        return VisualDiffResult(
            ssimScore: roundedSSIM,
            mismatchPercentage: roundedMismatch,
            differingPixelsCount: differingCount,
            totalPixelsCount: totalPixels,
            passed: passed,
            tolerance: pixelTolerance
        )
    }

    /// Generates an annotated diff heatmap image where matching pixels are dimmed
    /// and differing pixels are highlighted in vibrant red/magenta.
    public static func generateDiffHeatmap(
        reference: CGImage,
        candidate: CGImage,
        pixelTolerance: Double = 0.05
    ) -> CGImage? {
        let width = min(reference.width, candidate.width)
        let height = min(reference.height, candidate.height)
        guard width > 0, height > 0 else { return nil }

        guard let refData = extractRGBAPixels(image: reference, width: width, height: height),
              let candData = extractRGBAPixels(image: candidate, width: width, height: height) else {
            return nil
        }

        let totalPixels = width * height
        var outputData = [UInt8](repeating: 0, count: totalPixels * 4)
        let toleranceSq = pixelTolerance * pixelTolerance

        for i in 0..<totalPixels {
            let offset = i * 4
            let r1 = Double(refData[offset])
            let g1 = Double(refData[offset + 1])
            let b1 = Double(refData[offset + 2])

            let r2 = Double(candData[offset])
            let g2 = Double(candData[offset + 1])
            let b2 = Double(candData[offset + 2])

            let dr = r1 - r2
            let dg = g1 - g2
            let db = b1 - b2
            let distSq = (dr * dr + dg * dg + db * db) / (3.0 * 255.0 * 255.0)

            if distSq > toleranceSq {
                // Highlight mismatch in vibrant neon magenta: RGB(255, 0, 110)
                outputData[offset] = 255
                outputData[offset + 1] = 0
                outputData[offset + 2] = 110
                outputData[offset + 3] = 255
            } else {
                // Dim matching content to 25% grayscale
                let gray = UInt8((r2 * 0.299 + g2 * 0.587 + b2 * 0.114) * 0.25)
                outputData[offset] = gray
                outputData[offset + 1] = gray
                outputData[offset + 2] = gray
                outputData[offset + 3] = 255
            }
        }

        guard let colorSpace = CGColorSpace(name: CGColorSpace.sRGB),
              let context = CGContext(
                data: &outputData,
                width: width,
                height: height,
                bitsPerComponent: 8,
                bytesPerRow: width * 4,
                space: colorSpace,
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
              ) else {
            return nil
        }

        return context.makeImage()
    }

    // MARK: - Private Helpers

    private static func extractRGBAPixels(image: CGImage, width: Int, height: Int) -> [UInt8]? {
        var pixelData = [UInt8](repeating: 0, count: width * height * 4)
        guard let colorSpace = CGColorSpace(name: CGColorSpace.sRGB),
              let context = CGContext(
                data: &pixelData,
                width: width,
                height: height,
                bitsPerComponent: 8,
                bytesPerRow: width * 4,
                space: colorSpace,
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
              ) else {
            return nil
        }

        context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
        return pixelData
    }

    private static func computeMSSIM(
        refPixels: [UInt8],
        candPixels: [UInt8],
        width: Int,
        height: Int,
        windowSize: Int
    ) -> Double {
        let c1 = 0.0001 // (0.01 * 1.0)^2
        let c2 = 0.0009 // (0.03 * 1.0)^2

        let blocksX = width / windowSize
        let blocksY = height / windowSize
        guard blocksX > 0, blocksY > 0 else { return 1.0 }

        var totalSSIM = 0.0
        var blockCount = 0

        for by in 0..<blocksY {
            for bx in 0..<blocksX {
                var sumX = 0.0
                var sumY = 0.0
                var sumX2 = 0.0
                var sumY2 = 0.0
                var sumXY = 0.0
                let n = Double(windowSize * windowSize)

                for wy in 0..<windowSize {
                    let py = by * windowSize + wy
                    for wx in 0..<windowSize {
                        let px = bx * windowSize + wx
                        let offset = (py * width + px) * 4

                        // Luminance approximation in [0.0, 1.0]
                        let lx = (0.299 * Double(refPixels[offset]) + 0.587 * Double(refPixels[offset + 1]) + 0.114 * Double(refPixels[offset + 2])) / 255.0
                        let ly = (0.299 * Double(candPixels[offset]) + 0.587 * Double(candPixels[offset + 1]) + 0.114 * Double(candPixels[offset + 2])) / 255.0

                        sumX += lx
                        sumY += ly
                        sumX2 += lx * lx
                        sumY2 += ly * ly
                        sumXY += lx * ly
                    }
                }

                let muX = sumX / n
                let muY = sumY / n
                let sigmaX2 = max(0.0, (sumX2 / n) - (muX * muX))
                let sigmaY2 = max(0.0, (sumY2 / n) - (muY * muY))
                let sigmaXY = (sumXY / n) - (muX * muY)

                let numerator = (2.0 * muX * muY + c1) * (2.0 * sigmaXY + c2)
                let denominator = (muX * muX + muY * muY + c1) * (sigmaX2 + sigmaY2 + c2)
                let blockSSIM = denominator > 0 ? (numerator / denominator) : 1.0

                totalSSIM += max(0.0, min(1.0, blockSSIM))
                blockCount += 1
            }
        }

        return blockCount > 0 ? (totalSSIM / Double(blockCount)) : 1.0
    }
}
