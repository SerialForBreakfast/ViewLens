import Foundation
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers

#if canImport(AppKit)
import AppKit
#endif

public struct OverlayRenderer: Sendable {
    /// Renders color-coded bounding boxes and issue tags on top of a source CGImage.
    public static func render(
        image: CGImage,
        elements: [DetectedElement],
        issues: [ViewLensIssue] = []
    ) -> CGImage? {
        let width = image.width
        let height = image.height
        let imageSize = CGSize(width: width, height: height)

        guard let colorSpace = CGColorSpace(name: CGColorSpace.sRGB),
              let context = CGContext(
                data: nil,
                width: width,
                height: height,
                bitsPerComponent: 8,
                bytesPerRow: 0,
                space: colorSpace,
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
              ) else {
            return nil
        }

        // Draw original background image
        context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))

        // Flip coordinates for CoreGraphics drawing
        context.saveGState()

        // Map issues to element indices
        var elementIssues: [Int: [ViewLensIssue]] = [:]
        for issue in issues {
            if let idx = issue.elementIndex {
                elementIssues[idx, default: []].append(issue)
            }
        }

        for (index, element) in elements.enumerated() {
            let pixelRect = element.boundingBox.toPixelRect(imageSize: imageSize)
            // CGContext origin is bottom-left, flip Y for drawing
            let flippedY = Double(height) - pixelRect.maxY
            let cgRect = CGRect(x: pixelRect.minX, y: flippedY, width: pixelRect.width, height: pixelRect.height)

            let issuesForElement = elementIssues[index] ?? []
            let hasError = issuesForElement.contains { $0.severity == .error }
            let hasWarning = issuesForElement.contains { $0.severity == .warning }

            // Select color based on HIG compliance status
            let strokeColor: CGColor
            let fillColor: CGColor

            if hasError {
                strokeColor = CGColor(srgbRed: 0.95, green: 0.20, blue: 0.20, alpha: 0.95) // Red
                fillColor = CGColor(srgbRed: 0.95, green: 0.20, blue: 0.20, alpha: 0.12)
            } else if hasWarning {
                strokeColor = CGColor(srgbRed: 0.95, green: 0.65, blue: 0.10, alpha: 0.95) // Amber
                fillColor = CGColor(srgbRed: 0.95, green: 0.65, blue: 0.10, alpha: 0.10)
            } else {
                strokeColor = CGColor(srgbRed: 0.15, green: 0.80, blue: 0.35, alpha: 0.90) // Green
                fillColor = CGColor(srgbRed: 0.15, green: 0.80, blue: 0.35, alpha: 0.08)
            }

            // Draw bounding box fill and stroke
            context.setFillColor(fillColor)
            context.fill(cgRect)

            context.setStrokeColor(strokeColor)
            context.setLineWidth(hasError ? 3.5 : 2.0)
            context.stroke(cgRect)

            // Draw header label chip background
            let labelHeight: CGFloat = 22.0
            let labelY = flippedY + pixelRect.height
            let chipRect = CGRect(x: pixelRect.minX, y: labelY, width: min(pixelRect.width, 180.0), height: labelHeight)

            context.setFillColor(strokeColor)
            context.fill(chipRect)
        }

        context.restoreGState()
        return context.makeImage()
    }

    /// Writes a CGImage to a destination file URL in PNG format.
    public static func write(image: CGImage, to fileURL: URL) throws {
        guard let destination = CGImageDestinationCreateWithURL(
            fileURL as CFURL,
            UTType.png.identifier as CFString,
            1,
            nil
        ) else {
            throw NSError(domain: "ViewLensOverlay", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to create CGImageDestination at \(fileURL.path)"])
        }

        CGImageDestinationAddImage(destination, image, nil)
        guard CGImageDestinationFinalize(destination) else {
            throw NSError(domain: "ViewLensOverlay", code: 2, userInfo: [NSLocalizedDescriptionKey: "Failed to finalize PNG image at \(fileURL.path)"])
        }
    }
}
