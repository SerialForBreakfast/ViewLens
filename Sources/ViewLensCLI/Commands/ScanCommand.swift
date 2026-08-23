import Foundation
import ArgumentParser
import ViewLensKit
import ImageIO
import CoreGraphics

public enum OutputFormat: String, ExpressibleByArgument, Sendable {
    case table
    case json
}

struct ScanCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "scan",
        abstract: "Audits one or more screenshot images for UI elements and HIG layout defects."
    )

    @Argument(help: "Path to one or more screenshot images")
    var images: [String]

    @Option(name: .long, help: "Explicit path to CoreML model")
    var model: String?

    @Option(name: .long, help: "Output format: table or json")
    var format: OutputFormat = .table

    @Option(name: .long, help: "Minimum detection confidence threshold (0.0 - 1.0)")
    var minConfidence: Float = 0.10

    @Option(name: .long, help: "Display scale factor override (e.g. 2.0 for @2x, 3.0 for @3x)")
    var scale: Double?

    @Option(name: .long, help: "Write annotated image with bounding box overlays to specified output PNG path")
    var overlay: String?

    @Flag(name: .long, help: "Exit code 1 if any HIG or layout issues are detected (CI gate)")
    var strict: Bool = false

    func run() async throws {
        guard !images.isEmpty else {
            fputs(JSONFormatter.errorJSON(message: "No input images provided", nextCommand: "viewlens scan <image-path>"), stderr)
            Darwin.exit(2)
        }

        // 1. Resolve CoreML model
        let modelURL: URL
        switch ModelLocator.resolve(customPath: model) {
        case .success(let url):
            modelURL = url
        case .failure(let error):
            fputs(JSONFormatter.errorJSON(message: error.localizedDescription, nextCommand: "viewlens doctor"), stderr)
            Darwin.exit(2)
        }

        // 2. Initialize detector
        let detector: YOLODetector
        do {
            detector = try YOLODetector(modelURL: modelURL)
        } catch {
            fputs(JSONFormatter.errorJSON(message: "Failed to initialize detector: \(error.localizedDescription)", nextCommand: "viewlens doctor"), stderr)
            Darwin.exit(2)
        }

        var reports: [AuditReport] = []
        var anyFailures = false

        // 3. Process images
        for imagePath in images {
            let expandedPath = (imagePath as NSString).expandingTildeInPath
            let imageURL = URL(fileURLWithPath: expandedPath)

            guard let imageSource = CGImageSourceCreateWithURL(imageURL as CFURL, nil),
                  let cgImage = CGImageSourceCreateImageAtIndex(imageSource, 0, nil) else {
                fputs(JSONFormatter.errorJSON(message: "Cannot load image at '\(imagePath)'", nextCommand: "Check file path"), stderr)
                Darwin.exit(2)
            }

            let imgWidth = Double(cgImage.width)
            let imgHeight = Double(cgImage.height)
            let imgSize = CGSize(width: imgWidth, height: imgHeight)
            let resolvedScale = scale ?? IssueClassifier.inferDisplayScale(imageWidth: imgWidth)

            // Inference
            let detectedElements: [DetectedElement]
            do {
                detectedElements = try await detector.detect(image: cgImage, minConfidence: minConfidence)
            } catch {
                fputs(JSONFormatter.errorJSON(message: "Inference failed: \(error.localizedDescription)"), stderr)
                Darwin.exit(2)
            }

            // Rules Evaluation
            let issues = IssueClassifier.classify(elements: detectedElements, imageSize: imgSize, scale: resolvedScale)

            let report = AuditReport(
                sourceMode: .screenshot,
                image: imagePath,
                dimensions: AuditDimensions(width: imgWidth, height: imgHeight, scale: resolvedScale),
                elements: detectedElements,
                issues: issues
            )

            reports.append(report)
            if !report.passed {
                anyFailures = true
            }

            // Overlay generation if requested
            if let overlayPath = overlay {
                if let annotated = OverlayRenderer.render(image: cgImage, elements: detectedElements, issues: issues) {
                    let outURL = URL(fileURLWithPath: (overlayPath as NSString).expandingTildeInPath)
                    try? OverlayRenderer.write(image: annotated, to: outURL)
                }
            }
        }

        // 4. Format and print output
        if format == .json {
            if reports.count == 1 {
                print(JSONFormatter.encode(reports[0]))
            } else {
                print(JSONFormatter.encode(reports))
            }
        } else {
            for report in reports {
                print(TableFormatter.format(report: report))
            }
        }

        // 5. Check CI strict exit gate
        if strict && anyFailures {
            Darwin.exit(1)
        }
    }
}
