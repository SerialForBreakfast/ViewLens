import Foundation
import CoreGraphics

#if canImport(SwiftUI)
import SwiftUI

public struct MatrixSummary: Codable, Sendable, Equatable, Hashable {
    public let totalPermutations: Int
    public let passedCount: Int
    public let failedCount: Int
    public let worstIssue: String?
    public let failedPermutations: [String]

    public init(
        totalPermutations: Int,
        passedCount: Int,
        failedCount: Int,
        worstIssue: String?,
        failedPermutations: [String]
    ) {
        self.totalPermutations = totalPermutations
        self.passedCount = passedCount
        self.failedCount = failedCount
        self.worstIssue = worstIssue
        self.failedPermutations = failedPermutations
    }
}

public struct MatrixAuditReport: Codable, Sendable, Equatable, Hashable {
    public let sourceMode: AuditSourceMode
    public let template: String
    public let passed: Bool
    public let summary: MatrixSummary
    public let permutations: [String: AuditReport]

    public init(
        sourceMode: AuditSourceMode = .rendered,
        template: String,
        passed: Bool,
        summary: MatrixSummary,
        permutations: [String: AuditReport]
    ) {
        self.sourceMode = sourceMode
        self.template = template
        self.passed = passed
        self.summary = summary
        self.permutations = permutations
    }
}

public struct MatrixRenderer: Sendable {
    public struct Permutation: Sendable {
        public let device: DeviceProfile
        public let dynamicTypeSize: DynamicTypeSize
        public let dtName: String
        public let colorScheme: ColorScheme
        public let schemeName: String

        public var key: String {
            "\(device.id)_\(dtName)_\(schemeName)"
        }
    }

    /// Parses string dynamic type size descriptors into SwiftUI DynamicTypeSize
    public static func parseDynamicTypeSize(_ name: String) -> (size: DynamicTypeSize, name: String) {
        let cleaned = name.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        switch cleaned {
        case "xs", "extrasmall": return (.xSmall, "xSmall")
        case "s", "small": return (.small, "small")
        case "m", "medium": return (.medium, "medium")
        case "l", "large", "default": return (.large, "large")
        case "xl", "extralarge": return (.xLarge, "xLarge")
        case "xxl", "extraextralarge": return (.xxLarge, "xxLarge")
        case "xxxl", "extraextraextralarge": return (.xxxLarge, "xxxLarge")
        case "ax1", "accessibility1", "accessibilitymedium": return (.accessibility1, "accessibility1")
        case "ax2", "accessibility2", "accessibilitylarge": return (.accessibility2, "accessibility2")
        case "ax3", "accessibility3", "accessibilityextralarge": return (.accessibility3, "accessibility3")
        case "ax4", "accessibility4", "accessibilityextraextralarge": return (.accessibility4, "accessibility4")
        case "ax5", "accessibility5", "accessibilityextraextraextralarge": return (.accessibility5, "accessibility5")
        default: return (.large, "large")
        }
    }

    /// Parses color scheme string descriptor
    public static func parseColorScheme(_ name: String) -> (scheme: ColorScheme, name: String) {
        let cleaned = name.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        if cleaned.contains("dark") {
            return (.dark, "dark")
        } else {
            return (.light, "light")
        }
    }

    /// Builds all permutations from input arrays
    public static func buildPermutations(
        devices: [DeviceProfile],
        dynamicTypeSizes: [String],
        colorSchemes: [String]
    ) -> [Permutation] {
        let targetDevices = devices.isEmpty ? [.iPhone16Pro] : devices
        let targetDTs = dynamicTypeSizes.isEmpty ? ["large"] : dynamicTypeSizes
        let targetSchemes = colorSchemes.isEmpty ? ["light"] : colorSchemes

        var permutations: [Permutation] = []

        for device in targetDevices {
            for dtStr in targetDTs {
                let (dt, dtName) = parseDynamicTypeSize(dtStr)
                for schemeStr in targetSchemes {
                    let (scheme, schemeName) = parseColorScheme(schemeStr)
                    permutations.append(Permutation(
                        device: device,
                        dynamicTypeSize: dt,
                        dtName: dtName,
                        colorScheme: scheme,
                        schemeName: schemeName
                    ))
                }
            }
        }

        return permutations
    }

    /// Renders and audits a view across a matrix of device profiles and traits in-process.
    @MainActor
    public static func auditMatrix<Content: View>(
        templateName: String,
        view: Content,
        permutations: [Permutation],
        detector: YOLODetector? = nil,
        minConfidence: Float = 0.10,
        outputDirectory: URL? = nil
    ) async throws -> MatrixAuditReport {
        var reportsByPermutation: [String: AuditReport] = [:]
        var failedKeys: [String] = []
        var worstIssue: String?

        if let outDir = outputDirectory {
            try? FileManager.default.createDirectory(at: outDir, withIntermediateDirectories: true)
        }

        for perm in permutations {
            guard let image = InProcessCanvasRenderer.render(
                profile: perm.device,
                dynamicTypeSize: perm.dynamicTypeSize,
                colorScheme: perm.colorScheme,
                content: { view }
            ) else {
                continue
            }

            let imgWidth = Double(image.width)
            let imgHeight = Double(image.height)
            let imageSize = CGSize(width: imgWidth, height: imgHeight)

            // Inference (if model is available)
            let elements: [DetectedElement]
            if let detector = detector {
                elements = (try? await detector.detect(image: image, minConfidence: minConfidence)) ?? []
            } else {
                elements = []
            }

            // Rules Evaluation
            let issues = IssueClassifier.classify(
                elements: elements,
                imageSize: imageSize,
                scale: perm.device.scale
            )

            let report = AuditReport(
                sourceMode: .rendered,
                target: "\(templateName) [\(perm.key)]",
                device: perm.device.name,
                dimensions: AuditDimensions(width: imgWidth, height: imgHeight, scale: perm.device.scale),
                elements: elements,
                issues: issues
            )

            reportsByPermutation[perm.key] = report

            if !report.passed {
                failedKeys.append(perm.key)
                if worstIssue == nil {
                    worstIssue = "\(report.summary.worstIssue ?? "Issue") on \(perm.key)"
                }
            }

            // Save overlay if output directory is provided
            if let outDir = outputDirectory {
                if let annotated = OverlayRenderer.render(image: image, elements: elements, issues: issues) {
                    let outPath = outDir.appendingPathComponent("\(templateName)_\(perm.key).png")
                    try? OverlayRenderer.write(image: annotated, to: outPath)
                }
            }
        }

        let passed = failedKeys.isEmpty
        let summary = MatrixSummary(
            totalPermutations: permutations.count,
            passedCount: permutations.count - failedKeys.count,
            failedCount: failedKeys.count,
            worstIssue: worstIssue,
            failedPermutations: failedKeys
        )

        return MatrixAuditReport(
            sourceMode: .rendered,
            template: templateName,
            passed: passed,
            summary: summary,
            permutations: reportsByPermutation
        )
    }

    /// Renders a registered template by name across a device matrix on the MainActor
    @MainActor
    public static func auditNamedTemplate(
        templateName: String,
        deviceNames: [String] = ["iPhoneSE", "iPhone16Pro"],
        dtSizes: [String] = ["large", "accessibility3"],
        schemes: [String] = ["light", "dark"],
        detector: YOLODetector? = nil,
        outputDirectory: URL? = nil
    ) async throws -> MatrixAuditReport {
        guard let view = TemplateRegistry.shared.template(named: templateName) else {
            let available = TemplateRegistry.shared.availableTemplates.joined(separator: ", ")
            throw NSError(
                domain: "ViewLensMatrix",
                code: 404,
                userInfo: [NSLocalizedDescriptionKey: "Template '\(templateName)' not found. Available: \(available)"]
            )
        }

        let deviceList = deviceNames.compactMap { DeviceProfile.named($0) }
        let permutations = buildPermutations(
            devices: deviceList.isEmpty ? [.iPhoneSE, .iPhone16Pro] : deviceList,
            dynamicTypeSizes: dtSizes,
            colorSchemes: schemes
        )

        return try await auditMatrix(
            templateName: templateName,
            view: view,
            permutations: permutations,
            detector: detector,
            outputDirectory: outputDirectory
        )
    }
}
#endif
