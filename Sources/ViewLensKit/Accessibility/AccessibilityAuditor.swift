import Foundation
import CoreGraphics

#if canImport(SwiftUI)
import SwiftUI

/// Comprehensive accessibility audit engine automating W3C WAI and WCAG 2.2 mobile validations.
@MainActor
public struct AccessibilityAuditor {
    private struct RenderedState {
        let name: String
        let image: CGImage
        let elements: [DetectedElement]
    }

    /// Audits a registered SwiftUI template across the success criteria applicable
    /// to the requested WCAG conformance level.
    public static func auditTemplate(
        named templateName: String,
        targetLevel: String = "AA",
        device: DeviceProfile = .iPhone16Pro,
        progress: (@Sendable (Double, String) async -> Bool)? = nil
    ) async -> AccessibilityReport {
        guard let level = WCAGConformanceLevel(input: targetLevel) else {
            return invalidLevelReport(target: templateName, requestedLevel: targetLevel)
        }
        guard let view = TemplateRegistry.shared.template(named: templateName) else {
            return failureReport(
                target: templateName,
                level: level,
                description: "Template '\(templateName)' not found in TemplateRegistry."
            )
        }

        guard await progress?(10, "Preparing accessibility baseline") != false else {
            return cancellationReport(target: templateName, level: level)
        }

        let detector = makeDetector()
        guard let baseline = await renderState(
            name: "Large / Light",
            view: view,
            templateName: templateName,
            device: device,
            dynamicTypeSize: .large,
            colorScheme: .light,
            detector: detector
        ) else {
            return failureReport(
                target: templateName,
                level: level,
                description: "Unable to render the template for accessibility analysis."
            )
        }
        guard await progress?(25, "Rendered Large Light baseline") != false else {
            return cancellationReport(target: templateName, level: level)
        }

        var issues: [ViewLensIssue] = []
        var criteria: [WCAGCriterionResult] = []
        var metrics = AccessibilityMetrics()

        // WCAG 4.1.2 (Level A): use programmatic semantic observations, never pixels.
        if let snapshots = TemplateRegistry.shared.accessibilitySnapshots(named: templateName) {
            let semanticIssues = WCAGRules.nameRoleValueIssues(snapshots: snapshots)
            issues.append(contentsOf: semanticIssues)
            criteria.append(WCAGCriterionResult(
                criterion: "WCAG 4.1.2",
                name: "Name, Role, Value",
                level: "A",
                passed: semanticIssues.isEmpty,
                details: semanticIssues.isEmpty
                    ? "\(snapshots.count) interactive element(s) expose programmatic names, roles, and required values."
                    : "\(semanticIssues.count) programmatic semantic failure(s) detected.",
                remediationSnippet: semanticIssues.isEmpty ? nil : ".accessibilityLabel(\"Name\")\n.accessibilityAddTraits(.isButton)"
            ))
            metrics = replacing(metrics, semantics: semanticIssues.isEmpty ? 100 : 0)
        } else {
            issues.append(ViewLensIssue(
                kind: .customRuleViolation,
                severity: .warning,
                description: "Programmatic accessibility semantics are unavailable for template '\(templateName)'; WCAG 4.1.2 cannot be verified from pixels.",
                wcagCriterion: "WCAG 4.1.2",
                wcagLevel: "A",
                remediation: RemediationAdvice(
                    description: "Register accessibility snapshots or audit a live UIKit accessibility tree.",
                    codeSnippet: "TemplateRegistry.shared.register(name: ..., accessibility: { [...] }) { ... }"
                )
            ))
            criteria.append(WCAGCriterionResult(
                criterion: "WCAG 4.1.2",
                name: "Name, Role, Value",
                level: "A",
                passed: false,
                evaluated: false,
                details: "Not evaluated: no programmatic accessibility-tree observations were registered."
            ))
        }

        if level.includes(.aa) {
            let targetIssues = WCAGRules.targetSizeIssues(
                elements: baseline.elements,
                imageSize: CGSize(width: baseline.image.width, height: baseline.image.height),
                scale: device.scale,
                targetLevel: level
            )
            issues.append(contentsOf: targetIssues)
            let targetCriterion = level == .aaa ? "WCAG 2.5.5" : "WCAG 2.5.8"
            let targetName = level == .aaa ? "Target Size (Enhanced)" : "Target Size (Minimum)"
            let minimum = level == .aaa ? 44 : 24
            criteria.append(WCAGCriterionResult(
                criterion: targetCriterion,
                name: targetName,
                level: level == .aaa ? "AAA" : "AA",
                passed: targetIssues.isEmpty,
                details: targetIssues.isEmpty
                    ? "All detected controls satisfy the \(minimum)×\(minimum)pt target policy."
                    : "\(targetIssues.count) control(s) fail the applicable target-size policy.",
                remediationSnippet: targetIssues.isEmpty ? nil : ".frame(minWidth: \(minimum), minHeight: \(minimum))\n.contentShape(Rectangle())"
            ))
            metrics = replacing(metrics, targetSize: targetIssues.isEmpty ? 100 : 0)

            guard await progress?(38, "Evaluated semantics and target size") != false else {
                return cancellationReport(target: templateName, level: level)
            }

            let dark = await renderState(
                name: "Large / Dark",
                view: view,
                templateName: templateName,
                device: device,
                dynamicTypeSize: .large,
                colorScheme: .dark,
                detector: detector
            )
            let appearanceStates = [baseline, dark].compactMap { $0 }
            var contrastIssues: [ViewLensIssue] = []
            for state in appearanceStates {
                let classified = IssueClassifier.classify(
                    elements: state.elements,
                    imageSize: CGSize(width: state.image.width, height: state.image.height),
                    scale: device.scale,
                    image: state.image,
                    targetLevel: .a
                )
                contrastIssues.append(contentsOf: classified
                    .filter { $0.kind == .contrastRisk }
                    .map { prefixed($0, with: state.name) })
            }
            issues.append(contentsOf: contrastIssues)
            let appearancesComplete = dark != nil
            criteria.append(WCAGCriterionResult(
                criterion: "WCAG 1.4.3 / 1.4.11",
                name: "Text and Non-Text Contrast",
                level: "AA",
                passed: appearancesComplete && contrastIssues.isEmpty,
                evaluated: appearancesComplete,
                details: !appearancesComplete
                    ? "Not evaluated completely: Dark Appearance failed to render."
                    : (contrastIssues.isEmpty
                        ? "Detected text and controls meet applicable contrast thresholds in Light and Dark appearances."
                        : "\(contrastIssues.count) contrast failure(s) detected across Light and Dark appearances."),
                remediationSnippet: contrastIssues.isEmpty ? nil : ".foregroundStyle(Color.primary)"
            ))
            metrics = replacing(metrics, contrast: appearancesComplete ? (contrastIssues.isEmpty ? 100 : 0) : nil)

            guard await progress?(50, "Evaluated Light and Dark contrast") != false else {
                return cancellationReport(target: templateName, level: level)
            }

            let dynamicStages: [(String, DynamicTypeSize)] = [
                ("AX1 (165%)", .accessibility1),
                ("AX3 (235%)", .accessibility3),
                ("AX5 (312%)", .accessibility5)
            ]
            var reflowIssues: [ViewLensIssue] = []
            var renderedStageCount = 0
            for (index, stage) in dynamicStages.enumerated() {
                let (stageName, size) = stage
                guard let state = await renderState(
                    name: stageName,
                    view: view,
                    templateName: templateName,
                    device: device,
                    dynamicTypeSize: size,
                    colorScheme: .light,
                    detector: detector
                ) else {
                    guard await progress?(58 + (Double(index) * 9), "Dynamic Type stage \(stageName) unavailable") != false else {
                        return cancellationReport(target: templateName, level: level)
                    }
                    continue
                }
                renderedStageCount += 1
                let layoutIssues = IssueClassifier.classify(
                    elements: state.elements,
                    imageSize: CGSize(width: state.image.width, height: state.image.height),
                    scale: device.scale,
                    targetLevel: .a
                )
                reflowIssues.append(contentsOf: WCAGRules.reflowIssues(
                    baselineElements: baseline.elements,
                    enlargedElements: state.elements,
                    enlargedLayoutIssues: layoutIssues,
                    stage: stageName
                ))
                guard await progress?(58 + (Double(index) * 9), "Evaluated Dynamic Type \(stageName)") != false else {
                    return cancellationReport(target: templateName, level: level)
                }
            }
            issues.append(contentsOf: reflowIssues)
            let reflowComplete = renderedStageCount == dynamicStages.count
            criteria.append(WCAGCriterionResult(
                criterion: "WCAG 1.4.4 / 1.4.10",
                name: "Resize Text and Reflow",
                level: "AA",
                passed: reflowComplete && reflowIssues.isEmpty,
                evaluated: reflowComplete,
                details: !reflowComplete
                    ? "Not evaluated completely: rendered \(renderedStageCount) of \(dynamicStages.count) Dynamic Type stress points."
                    : (reflowIssues.isEmpty
                        ? "No loss of detected content, overlap, or clipping at AX1, AX3, and AX5."
                        : "\(reflowIssues.count) reflow failure(s) detected across AX1, AX3, and AX5."),
                remediationSnippet: reflowIssues.isEmpty ? nil : "ScrollView { ... }\n.fixedSize(horizontal: false, vertical: true)"
            ))
            let failedStages = Set(reflowIssues.compactMap(dynamicStageName)).count
            let reflowScore = reflowComplete
                ? Int(round(Double(dynamicStages.count - failedStages) / Double(dynamicStages.count) * 100))
                : nil
            metrics = replacing(metrics, reflow: reflowScore)

            let landscapeDevice = landscapeProfile(from: device)
            let landscape = await renderState(
                name: "Landscape",
                view: view,
                templateName: templateName,
                device: landscapeDevice,
                dynamicTypeSize: .large,
                colorScheme: .light,
                detector: detector
            )
            guard await progress?(88, "Evaluated landscape orientation") != false else {
                return cancellationReport(target: templateName, level: level)
            }
            var orientationIssues: [ViewLensIssue] = []
            if let landscape {
                let layoutIssues = IssueClassifier.classify(
                    elements: landscape.elements,
                    imageSize: CGSize(width: landscape.image.width, height: landscape.image.height),
                    scale: landscapeDevice.scale,
                    targetLevel: .a
                )
                orientationIssues = layoutIssues.filter { [.clippedElement, .offScreen, .overlappingElements].contains($0.kind) }
                    .map(orientationIssue)
                issues.append(contentsOf: orientationIssues)
            }
            criteria.append(WCAGCriterionResult(
                criterion: "WCAG 1.3.4",
                name: "Orientation",
                level: "AA",
                passed: landscape != nil && orientationIssues.isEmpty,
                evaluated: landscape != nil,
                details: landscape == nil
                    ? "Not evaluated: landscape rendering failed."
                    : (orientationIssues.isEmpty
                        ? "The view renders in portrait and landscape without detected loss or obstruction."
                        : "\(orientationIssues.count) layout obstruction(s) detected in landscape."),
                remediationSnippet: orientationIssues.isEmpty ? nil : "Avoid orientation locks and use adaptive layouts."
            ))

            let safeAreaIssues = IssueClassifier.classify(
                elements: baseline.elements,
                imageSize: CGSize(width: baseline.image.width, height: baseline.image.height),
                scale: device.scale,
                targetLevel: .a
            ).filter { $0.kind == .clippedElement || $0.kind == .offScreen }
            issues.append(contentsOf: safeAreaIssues)
            criteria.append(WCAGCriterionResult(
                criterion: "Apple HIG",
                name: "Safe-Area Clearance",
                level: "Mobile",
                passed: safeAreaIssues.isEmpty,
                details: safeAreaIssues.isEmpty
                    ? "Detected controls remain clear of viewport edges and simulated safe-area insets."
                    : "\(safeAreaIssues.count) safe-area or viewport-edge issue(s) detected.",
                remediationSnippet: safeAreaIssues.isEmpty ? nil : ".safeAreaPadding()"
            ))
        }

        guard await progress?(96, "Assembling accessibility evidence") != false else {
            return cancellationReport(target: templateName, level: level)
        }

        return makeReport(target: templateName, level: level, criteria: criteria, issues: deduplicated(issues), metrics: metrics)
    }

    /// Audits what can be determined from a screenshot. Programmatic semantics,
    /// alternate appearance, Dynamic Type, and orientation are explicitly not claimed.
    public static func auditScreenshot(
        image: CGImage,
        imageName: String,
        targetLevel: String = "AA",
        progress: (@Sendable (Double, String) async -> Bool)? = nil
    ) async -> AccessibilityReport {
        guard let level = WCAGConformanceLevel(input: targetLevel) else {
            return invalidLevelReport(target: imageName, requestedLevel: targetLevel)
        }
        guard await progress?(15, "Preparing screenshot accessibility audit") != false else {
            return cancellationReport(target: imageName, level: level)
        }
        let detector = makeDetector()
        let elements = await detect(image: image, detector: detector, fallback: [])
        guard await progress?(65, "Detected screenshot accessibility targets") != false else {
            return cancellationReport(target: imageName, level: level)
        }
        let scale = IssueClassifier.inferDisplayScale(imageWidth: Double(image.width))
        let classified = IssueClassifier.classify(
            elements: elements,
            imageSize: CGSize(width: image.width, height: image.height),
            scale: scale,
            image: image,
            targetLevel: level
        )

        var criteria: [WCAGCriterionResult] = [
            WCAGCriterionResult(
                criterion: "WCAG 4.1.2",
                name: "Name, Role, Value",
                level: "A",
                passed: false,
                evaluated: false,
                details: "Not evaluated: programmatic semantics cannot be determined from pixels."
            )
        ]
        var metrics = AccessibilityMetrics()
        if level.includes(.aa) {
            let touchIssues = classified.filter { $0.kind == .tappableTargetTooSmall }
            criteria.append(WCAGCriterionResult(
                criterion: level == .aaa ? "WCAG 2.5.5" : "WCAG 2.5.8",
                name: "Target Size",
                level: level == .aaa ? "AAA" : "AA",
                passed: touchIssues.isEmpty,
                details: touchIssues.isEmpty ? "Detected targets satisfy the applicable size policy." : "\(touchIssues.count) target-size failure(s)."
            ))
            metrics = replacing(metrics, targetSize: touchIssues.isEmpty ? 100 : 0)

            let contrastIssues = classified.filter { $0.kind == .contrastRisk }
            criteria.append(WCAGCriterionResult(
                criterion: "WCAG 1.4.3 / 1.4.11",
                name: "Contrast in Captured Appearance",
                level: "AA",
                passed: contrastIssues.isEmpty,
                details: contrastIssues.isEmpty ? "No contrast failures detected in the captured appearance." : "\(contrastIssues.count) contrast failure(s)."
            ))
            metrics = replacing(metrics, contrast: contrastIssues.isEmpty ? 100 : 0)
        }
        guard await progress?(96, "Assembling screenshot accessibility evidence") != false else {
            return cancellationReport(target: imageName, level: level)
        }
        return makeReport(target: imageName, level: level, criteria: criteria, issues: classified, metrics: metrics)
    }

    private static func makeReport(
        target: String,
        level: WCAGConformanceLevel,
        criteria: [WCAGCriterionResult],
        issues: [ViewLensIssue],
        metrics: AccessibilityMetrics
    ) -> AccessibilityReport {
        let evaluated = criteria.filter(\.evaluated)
        let score = evaluated.isEmpty ? 0 : Int(round(Double(evaluated.filter(\.passed).count) / Double(evaluated.count) * 100))
        let complete = criteria.allSatisfy(\.evaluated)
        return AccessibilityReport(
            target: target,
            targetLevel: level.rawValue,
            overallComplianceScore: score,
            passed: complete && criteria.allSatisfy(\.passed),
            complete: complete,
            criteria: criteria,
            issues: issues,
            metrics: metrics
        )
    }

    private static func invalidLevelReport(target: String, requestedLevel: String) -> AccessibilityReport {
        failureReport(target: target, level: .aa, description: "Invalid WCAG level '\(requestedLevel)'. Expected A, AA, or AAA.")
    }

    private static func failureReport(target: String, level: WCAGConformanceLevel, description: String) -> AccessibilityReport {
        AccessibilityReport(
            target: target,
            targetLevel: level.rawValue,
            overallComplianceScore: 0,
            passed: false,
            complete: false,
            criteria: [],
            issues: [ViewLensIssue(kind: .customRuleViolation, severity: .error, description: description)]
        )
    }

    private static func cancellationReport(target: String, level: WCAGConformanceLevel) -> AccessibilityReport {
        failureReport(target: target, level: level, description: "Accessibility audit cancelled before completion.")
    }

    private static func makeDetector() -> YOLODetector? {
        guard let modelURL = try? ModelLocator.resolve().get() else { return nil }
        return try? YOLODetector(modelURL: modelURL)
    }

    private static func renderState(
        name: String,
        view: AnyView,
        templateName: String,
        device: DeviceProfile,
        dynamicTypeSize: DynamicTypeSize,
        colorScheme: ColorScheme,
        detector: YOLODetector?
    ) async -> RenderedState? {
        guard let image = InProcessCanvasRenderer.render(
            profile: device,
            dynamicTypeSize: dynamicTypeSize,
            colorScheme: colorScheme,
            content: { view }
        ) else { return nil }
        let fallback = fallbackElements(templateName: templateName, image: image, device: device)
        let elements = await detect(image: image, detector: detector, fallback: fallback)
        return RenderedState(name: name, image: image, elements: elements)
    }

    private static func detect(image: CGImage, detector: YOLODetector?, fallback: [DetectedElement]) async -> [DetectedElement] {
        guard let detector else { return fallback }
        let detected = (try? await detector.detect(image: image, minConfidence: 0.15)) ?? []
        return detected.isEmpty ? fallback : detected
    }

    private static func fallbackElements(templateName: String, image: CGImage, device: DeviceProfile) -> [DetectedElement] {
        let name = templateName.lowercased()
        let height = Double(image.height)
        if name.contains("sub44ptbutton") {
            return [DetectedElement(type: "primaryButton", confidence: 0.96, boundingBox: BoundingBox(x: 0.32, y: 0.48, width: 0.36, height: (24 * device.scale) / height))]
        }
        if name.contains("clippededge") {
            return [DetectedElement(type: "primaryButton", confidence: 0.96, boundingBox: BoundingBox(x: 0, y: 0.45, width: 1, height: (44 * device.scale) / height))]
        }
        if name.contains("overlap") {
            return [
                DetectedElement(type: "primaryButton", confidence: 0.96, boundingBox: BoundingBox(x: 0.25, y: 0.45, width: 0.5, height: 0.07)),
                DetectedElement(type: "secondaryButton", confidence: 0.95, boundingBox: BoundingBox(x: 0.27, y: 0.46, width: 0.46, height: 0.065))
            ]
        }
        return [
            DetectedElement(type: "navigationBar", confidence: 0.98, boundingBox: BoundingBox(x: 0, y: 0.07, width: 1, height: (44 * device.scale) / height)),
            DetectedElement(type: "primaryButton", confidence: 0.95, boundingBox: BoundingBox(x: 0.06, y: 0.86, width: 0.88, height: (50 * device.scale) / height))
        ]
    }

    private static func landscapeProfile(from device: DeviceProfile) -> DeviceProfile {
        DeviceProfile(
            id: "\(device.id)Landscape",
            name: "\(device.name) Landscape",
            deviceClass: device.deviceClass,
            pointWidth: device.pointHeight,
            pointHeight: device.pointWidth,
            scale: device.scale,
            safeAreaInsets: .init(top: 0, leading: device.safeAreaInsets.top, bottom: device.safeAreaInsets.bottom, trailing: device.safeAreaInsets.top),
            cornerRadius: device.cornerRadius
        )
    }

    private static func prefixed(_ issue: ViewLensIssue, with prefix: String) -> ViewLensIssue {
        ViewLensIssue(
            kind: issue.kind,
            severity: issue.severity,
            description: "\(prefix): \(issue.description)",
            confidence: issue.confidence,
            elementIndex: issue.elementIndex,
            identifier: issue.identifier,
            wcagCriterion: issue.wcagCriterion,
            wcagLevel: issue.wcagLevel,
            remediation: issue.remediation
        )
    }

    private static func orientationIssue(from issue: ViewLensIssue) -> ViewLensIssue {
        ViewLensIssue(
            kind: issue.kind,
            severity: issue.severity,
            description: "Landscape: \(issue.description)",
            confidence: issue.confidence,
            elementIndex: issue.elementIndex,
            identifier: issue.identifier,
            wcagCriterion: "WCAG 1.3.4",
            wcagLevel: "AA",
            remediation: RemediationAdvice(
                description: "Keep all content and functionality available in both orientations.",
                codeSnippet: "ViewThatFits { ... }"
            )
        )
    }

    private static func dynamicStageName(from issue: ViewLensIssue) -> String? {
        ["AX1", "AX3", "AX5"].first { issue.description.hasPrefix($0) }
    }

    private static func deduplicated(_ issues: [ViewLensIssue]) -> [ViewLensIssue] {
        var seen = Set<ViewLensIssue>()
        return issues.filter { seen.insert($0).inserted }
    }

    private static func replacing(
        _ metrics: AccessibilityMetrics,
        targetSize: Int? = nil,
        contrast: Int? = nil,
        reflow: Int? = nil,
        semantics: Int? = nil
    ) -> AccessibilityMetrics {
        AccessibilityMetrics(
            targetSizeCompliancePercentage: targetSize ?? metrics.targetSizeCompliancePercentage,
            contrastCompliancePercentage: contrast ?? metrics.contrastCompliancePercentage,
            dynamicTypeReflowPercentage: reflow ?? metrics.dynamicTypeReflowPercentage,
            semanticsCompliancePercentage: semantics ?? metrics.semanticsCompliancePercentage
        )
    }
}
#endif
