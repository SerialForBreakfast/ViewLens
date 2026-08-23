import Foundation
import CoreGraphics

/// Evaluates detected elements against Apple Human Interface Guidelines and flags layout defects.
public struct IssueClassifier: Sendable {
    public static let minTouchTargetPoints: Double = 44.0

    /// Classifies layout, touch target, and occlusion defects across detected elements.
    public static func classify(
        elements: [DetectedElement],
        imageSize: CGSize,
        scale: Double? = nil
    ) -> [ViewLensIssue] {
        guard !elements.isEmpty else { return [] }

        let resolvedScale = scale ?? inferDisplayScale(imageWidth: imageSize.width)
        var issues: [ViewLensIssue] = []

        // Rule 1: Tappable touch target size (HIG 44x44pt minimum)
        issues.append(contentsOf: checkTouchTargets(elements: elements, imageSize: imageSize, scale: resolvedScale))

        // Rule 2: Boundary clipping (elements too close to viewport edge)
        issues.append(contentsOf: checkClippedElements(elements: elements, imageSize: imageSize, scale: resolvedScale))

        // Rule 3: Cross-element overlaps (IoU > 0.30 between interactive elements)
        issues.append(contentsOf: checkOverlappingElements(elements: elements, imageSize: imageSize))

        // Rule 4: Off-screen elements (>50% area outside normalized viewport)
        issues.append(contentsOf: checkOffScreenElements(elements: elements))

        return issues
    }

    /// Infers the display scale factor (@2x or @3x) from screenshot pixel width.
    public static func inferDisplayScale(imageWidth: Double) -> Double {
        switch Int(imageWidth) {
        case 750, 828:
            return 2.0
        case 1170, 1179, 1284, 1290, 1320:
            return 3.0
        case 1668, 2048, 2388, 2732: // iPads
            return 2.0
        default:
            return 3.0
        }
    }

    // MARK: - Rule 1: Touch Target Size Check
    private static func checkTouchTargets(
        elements: [DetectedElement],
        imageSize: CGSize,
        scale: Double
    ) -> [ViewLensIssue] {
        var issues: [ViewLensIssue] = []
        let interactiveTypes = Set(["primaryButton", "toggle", "button", "textField"])

        for (index, element) in elements.enumerated() {
            guard interactiveTypes.contains(element.type) else { continue }

            let pixelRect = element.boundingBox.toPixelRect(imageSize: imageSize)
            let heightPt = pixelRect.height / scale
            let widthPt = pixelRect.width / scale

            // Buttons/Toggles must meet the 44pt height and width minimum (with 2pt grace tolerance)
            let isTooShort = heightPt < (minTouchTargetPoints - 2.0)
            let isTooNarrow = widthPt < (minTouchTargetPoints - 2.0)

            if isTooShort || isTooNarrow {
                let dimensionDesc = isTooShort && isTooNarrow ?
                    "size \(Int(round(widthPt)))x\(Int(round(heightPt)))pt" :
                    (isTooShort ? "height \(Int(round(heightPt)))pt" : "width \(Int(round(widthPt)))pt")
                let description = "\(element.type) \(dimensionDesc) is below Apple HIG minimum requirement of \(Int(minTouchTargetPoints))x\(Int(minTouchTargetPoints))pt."
                let remediation = RemediationAdvice(
                    description: "Increase frame dimensions to at least 44x44pt.",
                    codeSnippet: ".frame(minWidth: 44, minHeight: 44)"
                )
                issues.append(ViewLensIssue(
                    kind: .tappableTargetTooSmall,
                    severity: .error,
                    description: description,
                    confidence: element.confidence,
                    elementIndex: index,
                    remediation: remediation
                ))
            }
        }

        return issues
    }

    // MARK: - Rule 2: Boundary Clipping Check
    private static func checkClippedElements(
        elements: [DetectedElement],
        imageSize: CGSize,
        scale: Double
    ) -> [ViewLensIssue] {
        var issues: [ViewLensIssue] = []
        let marginPixels = 3.0 * scale // 3pt buffer from edge

        // Containers like navigationBar or tabBar naturally span full width
        let fullWidthContainers = Set(["navigationBar", "tabBar"])

        for (index, element) in elements.enumerated() {
            if fullWidthContainers.contains(element.type) { continue }

            let rect = element.boundingBox.toPixelRect(imageSize: imageSize)

            let isNearLeftEdge = rect.minX < marginPixels && rect.minX >= 0
            let isNearRightEdge = (imageSize.width - rect.maxX) < marginPixels && rect.maxX <= imageSize.width
            let isNearTopEdge = rect.minY < marginPixels && rect.minY >= 0
            let isNearBottomEdge = (imageSize.height - rect.maxY) < marginPixels && rect.maxY <= imageSize.height

            if isNearLeftEdge || isNearRightEdge || isNearTopEdge || isNearBottomEdge {
                let description = "\(element.type) is clipped or placed within \(Int(marginPixels))px of the screen edge without safe area padding."
                let remediation = RemediationAdvice(
                    description: "Apply standard safe area padding or layout margins.",
                    codeSnippet: ".padding(.horizontal)"
                )
                issues.append(ViewLensIssue(
                    kind: .clippedElement,
                    severity: .warning,
                    description: description,
                    confidence: element.confidence,
                    elementIndex: index,
                    remediation: remediation
                ))
            }
        }

        return issues
    }

    // MARK: - Rule 3: Cross-Element Overlap Check
    private static func checkOverlappingElements(
        elements: [DetectedElement],
        imageSize: CGSize
    ) -> [ViewLensIssue] {
        var issues: [ViewLensIssue] = []
        guard elements.count > 1 else { return [] }

        // We only check for collision between distinct non-container elements
        let containerTypes = Set(["navigationBar", "tabBar"])

        for i in 0..<elements.count {
            for j in (i + 1)..<elements.count {
                let elemA = elements[i]
                let elemB = elements[j]

                if containerTypes.contains(elemA.type) || containerTypes.contains(elemB.type) {
                    continue
                }

                let iou = elemA.boundingBox.iou(with: elemB.boundingBox)
                if iou > 0.30 {
                    let description = "Elements \(elemA.type) [#\(i)] and \(elemB.type) [#\(j)] overlap with IoU \(String(format: "%.2f", iou))."
                    let remediation = RemediationAdvice(
                        description: "Check stack spacing and layout constraints to prevent occlusion.",
                        codeSnippet: "VStack(spacing: 16) { ... }"
                    )
                    issues.append(ViewLensIssue(
                        kind: .overlappingElements,
                        severity: .error,
                        description: description,
                        confidence: max(elemA.confidence, elemB.confidence),
                        elementIndex: i,
                        remediation: remediation
                    ))
                }
            }
        }

        return issues
    }

    // MARK: - Rule 4: Off-Screen Elements Check
    private static func checkOffScreenElements(elements: [DetectedElement]) -> [ViewLensIssue] {
        var issues: [ViewLensIssue] = []

        for (index, element) in elements.enumerated() {
            let box = element.boundingBox
            // If more than 50% of the box extends outside normalized [0,0,1,1]
            let clampedWidth = max(0.0, min(box.maxX, 1.0) - max(box.minX, 0.0))
            let clampedHeight = max(0.0, min(box.maxY, 1.0) - max(box.minY, 0.0))
            let visibleArea = clampedWidth * clampedHeight

            if visibleArea < (box.area * 0.50) && box.area > 0 {
                let description = "\(element.type) is placed over 50% off-screen (visible area: \(Int(visibleArea / box.area * 100))%)."
                let remediation = RemediationAdvice(
                    description: "Constrain element inside viewport bounds.",
                    codeSnippet: ".frame(maxWidth: .infinity)"
                )
                issues.append(ViewLensIssue(
                    kind: .offScreen,
                    severity: .error,
                    description: description,
                    confidence: element.confidence,
                    elementIndex: index,
                    remediation: remediation
                ))
            }
        }

        return issues
    }
}
