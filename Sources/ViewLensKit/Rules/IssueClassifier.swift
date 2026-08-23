import Foundation
import CoreGraphics

/// Evaluates detected elements against Apple Human Interface Guidelines and W3C WCAG 2.2 accessibility rules.
public struct IssueClassifier: Sendable {
    public static let minTouchTargetPoints: Double = 44.0

    /// Classifies layout, touch target, occlusion, and WCAG accessibility defects across detected elements.
    public static func classify(
        elements: [DetectedElement],
        imageSize: CGSize,
        scale: Double? = nil,
        image: CGImage? = nil,
        targetLevel: WCAGConformanceLevel = .aaa
    ) -> [ViewLensIssue] {
        guard !elements.isEmpty else { return [] }

        let resolvedScale = scale ?? inferDisplayScale(imageWidth: imageSize.width)
        var issues: [ViewLensIssue] = []

        // Rule 1: Tappable touch target size (HIG 44x44pt / WCAG 2.5.5 AAA / WCAG 2.5.8 AA)
        issues.append(contentsOf: WCAGRules.targetSizeIssues(
            elements: elements,
            imageSize: imageSize,
            scale: resolvedScale,
            targetLevel: targetLevel
        ))

        // Rule 2: Boundary clipping (Apple HIG safe-area / viewport clearance)
        issues.append(contentsOf: checkClippedElements(elements: elements, imageSize: imageSize, scale: resolvedScale))

        // Rule 3: Cross-element overlaps (WCAG 1.4.10 Reflow collision)
        issues.append(contentsOf: checkOverlappingElements(elements: elements, imageSize: imageSize))

        // Rule 4: Off-screen elements (Apple HIG viewport bounding)
        issues.append(contentsOf: checkOffScreenElements(elements: elements))

        // Rule 5: Color contrast analysis if source CGImage is provided (WCAG 1.4.3 Minimum Contrast)
        if let image = image {
            issues.append(contentsOf: checkContrast(image: image, elements: elements))
        }

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

    // MARK: - Rule 2: Boundary Clipping Check (Apple HIG)
    private static func checkClippedElements(
        elements: [DetectedElement],
        imageSize: CGSize,
        scale: Double
    ) -> [ViewLensIssue] {
        var issues: [ViewLensIssue] = []
        let marginPixels = 3.0 * scale // 3pt buffer from edge
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
                    wcagCriterion: "Apple HIG",
                    wcagLevel: "Mobile",
                    remediation: remediation
                ))
            }
        }

        return issues
    }

    // MARK: - Rule 3: Cross-Element Overlap Check (WCAG 1.4.10)
    private static func checkOverlappingElements(
        elements: [DetectedElement],
        imageSize: CGSize
    ) -> [ViewLensIssue] {
        var issues: [ViewLensIssue] = []
        guard elements.count > 1 else { return [] }
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
                        wcagCriterion: "WCAG 1.4.10",
                        wcagLevel: "AA",
                        remediation: remediation
                    ))
                }
            }
        }

        return issues
    }

    // MARK: - Rule 4: Off-Screen Elements Check (Apple HIG)
    private static func checkOffScreenElements(elements: [DetectedElement]) -> [ViewLensIssue] {
        var issues: [ViewLensIssue] = []

        for (index, element) in elements.enumerated() {
            let box = element.boundingBox
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
                    wcagCriterion: "Apple HIG",
                    wcagLevel: "Mobile",
                    remediation: remediation
                ))
            }
        }

        return issues
    }

    // MARK: - Rule 5: Color Contrast Check (WCAG 1.4.3 / 1.4.11)
    private static func checkContrast(image: CGImage, elements: [DetectedElement]) -> [ViewLensIssue] {
        var issues: [ViewLensIssue] = []
        let textAndControlTypes = Set(["primaryButton", "secondaryButton", "textField", "label"])

        for (index, element) in elements.enumerated() {
            guard textAndControlTypes.contains(element.type) else { continue }

            let isNonTextControl = element.type != "label"
            if let result = ContrastEvaluator.sampleContrast(
                image: image,
                box: element.boundingBox,
                isLargeTextOrIcon: isNonTextControl
            ) {
                let passes = isNonTextControl ? result.passesAALargeText : result.passesAA
                if !passes {
                    let criterion = isNonTextControl ? "WCAG 1.4.11" : "WCAG 1.4.3"
                    let threshold = isNonTextControl ? 3.0 : 4.5
                    let desc = "\(element.type) contrast ratio is \(String(format: "%.1f", result.ratio)):1, which fails \(criterion) AA minimum of \(String(format: "%.1f", threshold)):1."
                    let remediation = RemediationAdvice(
                        description: "Increase contrast between foreground content and background surface.",
                        codeSnippet: ".foregroundStyle(Color.primary)"
                    )
                    issues.append(ViewLensIssue(
                        kind: .contrastRisk,
                        severity: .warning,
                        description: desc,
                        confidence: element.confidence,
                        elementIndex: index,
                        wcagCriterion: criterion,
                        wcagLevel: "AA",
                        remediation: remediation
                    ))
                }
            }
        }

        return issues
    }
}
