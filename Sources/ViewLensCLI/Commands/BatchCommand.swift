import Foundation
import ArgumentParser
import ViewLensKit
import ImageIO
import CoreGraphics

struct BatchCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "batch",
        abstract: "Recursively audits all matching screenshots in a directory with a single model load."
    )

    @Argument(help: "Target directory containing screenshot images")
    var directory: String

    @Option(name: .long, help: "File extension pattern (default: png)")
    var pattern: String = "png"

    @Option(name: .long, help: "Explicit path to CoreML model")
    var model: String?

    @Option(name: .long, help: "Output file path for consolidated JSON report")
    var output: String?

    @Option(name: .long, help: "Minimum detection confidence threshold (0.0 - 1.0)")
    var minConfidence: Float = 0.10

    @Flag(name: .long, help: "Exit code 1 if any HIG or layout issues are detected")
    var strict: Bool = false

    func run() async throws {
        let dirURL = URL(fileURLWithPath: (directory as NSString).expandingTildeInPath)
        var isDir: ObjCBool = false

        guard FileManager.default.fileExists(atPath: dirURL.path, isDirectory: &isDir), isDir.boolValue else {
            fputs(JSONFormatter.errorJSON(message: "Directory '\(directory)' does not exist or is not a directory"), stderr)
            Darwin.exit(2)
        }

        // Find all matching images
        let enumerator = FileManager.default.enumerator(at: dirURL, includingPropertiesForKeys: nil)
        var matchedFiles: [URL] = []
        let cleanExt = pattern.replacingOccurrences(of: "*.", with: "").replacingOccurrences(of: ".", with: "").lowercased()

        while let fileURL = enumerator?.nextObject() as? URL {
            if fileURL.pathExtension.lowercased() == cleanExt {
                matchedFiles.append(fileURL)
            }
        }

        guard !matchedFiles.isEmpty else {
            let emptyReports: [AuditReport] = []
            print(JSONFormatter.encode(emptyReports))
            return
        }

        // Resolve model
        let modelURL: URL
        switch ModelLocator.resolve(customPath: model) {
        case .success(let url):
            modelURL = url
        case .failure(let error):
            fputs(JSONFormatter.errorJSON(message: error.localizedDescription, nextCommand: "viewlens doctor"), stderr)
            Darwin.exit(2)
        }

        let detector: YOLODetector
        do {
            detector = try YOLODetector(modelURL: modelURL)
        } catch {
            fputs(JSONFormatter.errorJSON(message: "Failed to initialize detector: \(error.localizedDescription)"), stderr)
            Darwin.exit(2)
        }

        var reports: [AuditReport] = []
        var anyFailures = false

        for fileURL in matchedFiles {
            guard let imageSource = CGImageSourceCreateWithURL(fileURL as CFURL, nil),
                  let cgImage = CGImageSourceCreateImageAtIndex(imageSource, 0, nil) else {
                continue
            }

            let imgWidth = Double(cgImage.width)
            let imgHeight = Double(cgImage.height)
            let imgSize = CGSize(width: imgWidth, height: imgHeight)
            let resolvedScale = IssueClassifier.inferDisplayScale(imageWidth: imgWidth)

            guard let detectedElements = try? await detector.detect(image: cgImage, minConfidence: minConfidence) else {
                continue
            }

            let issues = IssueClassifier.classify(elements: detectedElements, imageSize: imgSize, scale: resolvedScale)
            let report = AuditReport(
                sourceMode: .screenshot,
                image: fileURL.path,
                dimensions: AuditDimensions(width: imgWidth, height: imgHeight, scale: resolvedScale),
                elements: detectedElements,
                issues: issues
            )

            reports.append(report)
            if !report.passed {
                anyFailures = true
            }
        }

        let jsonOutput = JSONFormatter.encode(reports)

        if let outputPath = output {
            let outURL = URL(fileURLWithPath: (outputPath as NSString).expandingTildeInPath)
            try? jsonOutput.write(to: outURL, atomically: true, encoding: .utf8)
            print("Wrote consolidated report with \(reports.count) screenshots to \(outputPath)")
        } else {
            print(jsonOutput)
        }

        if strict && anyFailures {
            Darwin.exit(1)
        }
    }
}
