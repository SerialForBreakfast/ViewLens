import Foundation
import CoreGraphics

/// Result of a W3C WCAG relative luminance contrast ratio calculation.
public struct ContrastResult: Sendable, Codable, Equatable {
    public let ratio: Double
    public let passesAA: Bool
    public let passesAAA: Bool
    public let passesAALargeText: Bool
    public let foregroundLuminance: Double
    public let backgroundLuminance: Double

    public init(
        ratio: Double,
        passesAA: Bool,
        passesAAA: Bool,
        passesAALargeText: Bool,
        foregroundLuminance: Double,
        backgroundLuminance: Double
    ) {
        self.ratio = ratio
        self.passesAA = passesAA
        self.passesAAA = passesAAA
        self.passesAALargeText = passesAALargeText
        self.foregroundLuminance = foregroundLuminance
        self.backgroundLuminance = backgroundLuminance
    }
}

/// Evaluates color contrast ratios according to W3C WCAG 2.1 / 2.2 Guidelines (1.4.3 Minimum Contrast, 1.4.11 Non-Text Contrast).
public struct ContrastEvaluator: Sendable {

    /// Calculates relative luminance of an sRGB color component in range [0.0, 1.0] per W3C WCAG standard.
    public static func linearize(channel: Double) -> Double {
        let c = max(0.0, min(1.0, channel))
        if c <= 0.04045 {
            return c / 12.92
        } else {
            return pow((c + 0.055) / 1.055, 2.4)
        }
    }

    /// Computes the relative luminance (0.0 = darkest black, 1.0 = brightest white).
    public static func relativeLuminance(r: Double, g: Double, b: Double) -> Double {
        let rLin = linearize(channel: r)
        let gLin = linearize(channel: g)
        let bLin = linearize(channel: b)
        return 0.2126 * rLin + 0.7152 * gLin + 0.0722 * bLin
    }

    /// Computes the WCAG contrast ratio between two relative luminances (1.0:1 to 21.0:1).
    public static func contrastRatio(lum1: Double, lum2: Double) -> Double {
        let l1 = max(lum1, lum2)
        let l2 = min(lum1, lum2)
        return (l1 + 0.05) / (l2 + 0.05)
    }

    /// Evaluates contrast between two RGB colors (components in [0.0, 1.0]).
    public static func evaluate(
        fgR: Double, fgG: Double, fgB: Double,
        bgR: Double, bgG: Double, bgB: Double
    ) -> ContrastResult {
        let fgLum = relativeLuminance(r: fgR, g: fgG, b: fgB)
        let bgLum = relativeLuminance(r: bgR, g: bgG, b: bgB)
        let ratio = contrastRatio(lum1: fgLum, lum2: bgLum)

        // Rounded to 2 decimal places
        let roundedRatio = Double(round(ratio * 100) / 100)

        return ContrastResult(
            ratio: roundedRatio,
            passesAA: roundedRatio >= 4.5,
            passesAAA: roundedRatio >= 7.0,
            passesAALargeText: roundedRatio >= 3.0,
            foregroundLuminance: fgLum,
            backgroundLuminance: bgLum
        )
    }

    /// Samples pixels in an image around an element's bounding box and computes contrast ratio.
    public static func sampleContrast(
        image: CGImage,
        box: BoundingBox,
        isLargeTextOrIcon: Bool = false
    ) -> ContrastResult? {
        let imgW = image.width
        let imgH = image.height
        guard imgW > 0, imgH > 0 else { return nil }

        guard let pixels = RGBAImage(image: image) else { return nil }
        let rect = box.toPixelRect(imageSize: CGSize(width: imgW, height: imgH))

        // Use several samples instead of assuming the exact center contains a glyph.
        // The median interior color represents the control surface; the most distant
        // interior sample represents foreground content such as a label or icon.
        let xFractions = [0.25, 0.5, 0.75]
        let yFractions = [0.25, 0.5, 0.75]
        let innerColors = xFractions.flatMap { xFraction in
            yFractions.compactMap { yFraction in
                pixels.sample(
                    x: Int(rect.minX + rect.width * xFraction),
                    y: Int(rect.minY + rect.height * yFraction)
                )
            }
        }

        let inset = max(4, min(12, Int(min(rect.width, rect.height) * 0.15)))
        let outsidePoints = [
            CGPoint(x: rect.minX - CGFloat(inset), y: rect.minY - CGFloat(inset)),
            CGPoint(x: rect.midX, y: rect.minY - CGFloat(inset)),
            CGPoint(x: rect.maxX + CGFloat(inset), y: rect.minY - CGFloat(inset)),
            CGPoint(x: rect.minX - CGFloat(inset), y: rect.midY),
            CGPoint(x: rect.maxX + CGFloat(inset), y: rect.midY),
            CGPoint(x: rect.minX - CGFloat(inset), y: rect.maxY + CGFloat(inset)),
            CGPoint(x: rect.midX, y: rect.maxY + CGFloat(inset)),
            CGPoint(x: rect.maxX + CGFloat(inset), y: rect.maxY + CGFloat(inset))
        ]
        let outerColors = outsidePoints.compactMap { pixels.sample(x: Int($0.x), y: Int($0.y)) }
        guard !innerColors.isEmpty, !outerColors.isEmpty else { return nil }

        let backgroundLuminance = median(outerColors.map(luminance))
        let interiorLuminances = innerColors.map(luminance)
        guard let foregroundLuminance = interiorLuminances.max(by: {
            abs($0 - backgroundLuminance) < abs($1 - backgroundLuminance)
        }) else { return nil }

        let ratio = contrastRatio(lum1: foregroundLuminance, lum2: backgroundLuminance)
        guard ratio > 1.05 else { return nil }
        let roundedRatio = Double(round(ratio * 100) / 100)
        return ContrastResult(
            ratio: roundedRatio,
            passesAA: roundedRatio >= 4.5,
            passesAAA: roundedRatio >= 7.0,
            passesAALargeText: roundedRatio >= 3.0,
            foregroundLuminance: foregroundLuminance,
            backgroundLuminance: backgroundLuminance
        )
    }

    private static func luminance(_ color: (r: Double, g: Double, b: Double)) -> Double {
        relativeLuminance(r: color.r, g: color.g, b: color.b)
    }

    private static func median(_ values: [Double]) -> Double {
        let sorted = values.sorted()
        guard !sorted.isEmpty else { return 0 }
        let middle = sorted.count / 2
        return sorted.count.isMultiple(of: 2)
            ? (sorted[middle - 1] + sorted[middle]) / 2
            : sorted[middle]
    }

    /// Normalizes arbitrary CGImage channel ordering into a known 8-bit RGBA buffer.
    private struct RGBAImage {
        let width: Int
        let height: Int
        let bytes: [UInt8]

        init?(image: CGImage) {
            let imageWidth = image.width
            let imageHeight = image.height
            guard imageWidth > 0, imageHeight > 0 else { return nil }
            guard let storage = Self.render(image: image, width: imageWidth, height: imageHeight) else { return nil }
            width = imageWidth
            height = imageHeight
            bytes = storage
        }

        private static func render(image: CGImage, width: Int, height: Int) -> [UInt8]? {
            var storage = [UInt8](repeating: 0, count: width * height * 4)
            let rendered = storage.withUnsafeMutableBytes { rawBuffer -> Bool in
                guard let context = CGContext(
                    data: rawBuffer.baseAddress,
                    width: width,
                    height: height,
                    bitsPerComponent: 8,
                    bytesPerRow: width * 4,
                    space: CGColorSpaceCreateDeviceRGB(),
                    bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue | CGBitmapInfo.byteOrder32Big.rawValue
                ) else { return false }
                context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
                return true
            }
            return rendered ? storage : nil
        }

        func sample(x: Int, y: Int) -> (r: Double, g: Double, b: Double)? {
            guard x >= 0, x < width, y >= 0, y < height else { return nil }
            let offset = (y * width + x) * 4
            return (
                Double(bytes[offset]) / 255,
                Double(bytes[offset + 1]) / 255,
                Double(bytes[offset + 2]) / 255
            )
        }
    }
}
