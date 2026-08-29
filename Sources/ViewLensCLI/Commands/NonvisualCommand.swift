import Foundation
import ArgumentParser
import ViewLensKit
import CoreGraphics
import ImageIO

public struct NonvisualCommand: AsyncParsableCommand {
    public static let configuration = CommandConfiguration(
        commandName: "nonvisual",
        abstract: "Generates structured, screen-reader-optimized summaries and outlines without visual noise."
    )

    @Option(name: .shortAndLong, help: "Name of registered SwiftUI view template (e.g. 'LoginForm', 'CheckoutView').")
    public var template: String?

    @Option(name: .shortAndLong, help: "Path to a screenshot image file (PNG/JPEG).")
    public var image: String?

    @Option(name: .long, help: "Output format ('summary', 'outline', 'narrative', or 'json'). Defaults to 'summary'.")
    public var format: String = "summary"

    @Option(name: .shortAndLong, help: "Presentation profile ('speech', 'braille', or 'developer'). Defaults to 'speech'.")
    public var profile: String = "speech"

    @Option(name: .long, help: "Target WCAG compliance level ('A', 'AA', or 'AAA'). Defaults to 'AA'.")
    public var level: String = "AA"

    @Option(name: .long, help: "Maximum number of summary statements to output (default 12).")
    public var maxStatements: Int = 12

    public init() {}

    public func validate() throws {
        guard (template == nil) != (image == nil) else {
            throw ValidationError("Specify exactly one of --template or --image.")
        }
        guard ["summary", "outline", "narrative", "json"].contains(format.lowercased()) else {
            throw ValidationError("Invalid --format '\(format)'. Expected summary, outline, narrative, or json.")
        }
        guard ["speech", "braille", "developer"].contains(profile.lowercased()) else {
            throw ValidationError("Invalid --profile '\(profile)'. Expected speech, braille, or developer.")
        }
        guard WCAGConformanceLevel(input: level) != nil else {
            throw ValidationError("Invalid --level '\(level)'. Expected A, AA, or AAA.")
        }
    }

    @MainActor
    public func run() async throws {
        let auditReport: AuditReport

        if let templateName = template {
            guard let view = TemplateRegistry.shared.template(named: templateName) else {
                print("❌ Error: Template '\(templateName)' is not registered.")
                throw ExitCode.failure
            }
            let targetLevel = WCAGConformanceLevel(input: level) ?? .aa
            let detector: YOLODetector?
            if let modelURL = try? ModelLocator.resolve().get() {
                detector = try? YOLODetector(modelURL: modelURL)
            } else {
                detector = nil
            }
            let permutations = MatrixRenderer.buildPermutations(
                devices: [.iPhone16Pro],
                dynamicTypeSizes: ["large"],
                colorSchemes: ["light"]
            )
            let result = try await MatrixRenderer.auditMatrix(
                templateName: templateName,
                view: view,
                permutations: permutations,
                detector: detector,
                minConfidence: 0.15,
                targetLevel: targetLevel
            )
            let primaryKey = permutations[0].key
            let perm = result.permutations[primaryKey]
            auditReport = AuditReport(
                sourceMode: .rendered,
                target: templateName,
                device: "iPhone16Pro",
                dimensions: AuditDimensions(width: 393, height: 852, scale: 3.0),
                elements: perm?.elements ?? [],
                issues: perm?.issues ?? []
            )
        }
 else if let imagePath = image {
            guard let source = CGImageSourceCreateWithURL(URL(fileURLWithPath: imagePath) as CFURL, nil),
                  let cgImage = CGImageSourceCreateImageAtIndex(source, 0, nil) else {
                print("❌ Error: Failed to load image at \(imagePath)")
                throw ExitCode.failure
            }
            let scale = IssueClassifier.inferDisplayScale(imageWidth: Double(cgImage.width))
            let detector: YOLODetector?
            if let modelURL = try? ModelLocator.resolve().get() {
                detector = try? YOLODetector(modelURL: modelURL)
            } else {
                detector = nil
            }
            let elements = (try? await detector?.detect(image: cgImage, minConfidence: 0.15)) ?? []
            let issues = IssueClassifier.classify(
                elements: elements,
                imageSize: CGSize(width: cgImage.width, height: cgImage.height),
                scale: scale,
                image: cgImage,
                targetLevel: WCAGConformanceLevel(input: level) ?? .aa
            )
            auditReport = AuditReport(
                sourceMode: .screenshot,
                image: (imagePath as NSString).lastPathComponent,
                dimensions: AuditDimensions(width: Double(cgImage.width), height: Double(cgImage.height), scale: scale),
                elements: elements,
                issues: issues
            )
        } else {
            throw ExitCode.failure
        }

        let screenID = NonvisualID("screen:\(auditReport.target ?? auditReport.image ?? "unnamed")")
        let nonvisualModel = NonvisualScreenBuilder.fromAuditReport(
            auditReport,
            screenID: screenID,
            title: auditReport.target ?? auditReport.image
        )

        let presentationProfile: NonvisualPresentationProfile = switch profile.lowercased() {
        case "braille": .braille
        case "developer": .developer
        default: .speech
        }

        switch format.lowercased() {
        case "json":
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let data = try encoder.encode(nonvisualModel)
            if let jsonString = String(data: data, encoding: .utf8) {
                print(jsonString)
            }
        case "outline":
            printOutline(model: nonvisualModel)
        case "narrative":
            let summary = NonvisualSummaryComposer.compose(nonvisualModel)
            print(NonvisualPresentationRenderer.render(summary, profile: .developer, maximumStatements: maxStatements))
        default:
            let summary = NonvisualSummaryComposer.compose(nonvisualModel)
            print(NonvisualPresentationRenderer.render(summary, profile: presentationProfile, maximumStatements: maxStatements))
        }

        if !auditReport.passed {
            throw ExitCode.failure
        }
    }

    private func printOutline(model: NonvisualScreenModel) {
        print("Screen: \(model.title ?? "Unnamed") [\(model.sourceMode.rawValue)] (ID: \(model.id.rawValue))")
        for region in model.regions {
            let roleStr = region.role.map { " (\($0))" } ?? ""
            print("  └─ Region: \(region.label)\(roleStr) (ID: \(region.id.rawValue))")
            let regionElements = model.elements.filter { $0.regionID == region.id }
            for el in regionElements {
                let name = el.visibleLabel ?? el.semantics?.accessibleName ?? "Element"
                let interactive = el.isInteractive ? " [interactive]" : ""
                print("       ├─ \(el.type.capitalized): \"\(name)\"\(interactive) (ID: \(el.id.rawValue))")
                for findingID in el.findingIDs {
                    print("       │    └─ Finding ID: \(findingID.rawValue)")
                }
            }
        }
    }
}
