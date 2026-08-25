import AppKit
import SwiftUI
import UniformTypeIdentifiers
import ViewLensKit

enum ReviewExportFormat: String, CaseIterable, Identifiable {
    case json = "JSON Report"
    case markdown = "Markdown Report"
    case annotatedPNG = "Annotated PNG"
    case reportBundle = "Report Bundle"

    var id: String { rawValue }
    var contentType: UTType {
        switch self {
        case .json: return .json
        case .markdown: return UTType(filenameExtension: "md") ?? .plainText
        case .annotatedPNG: return .png
        case .reportBundle: return .viewLensReport
        }
    }
    var filenameExtension: String {
        switch self {
        case .json: return "json"
        case .markdown: return "md"
        case .annotatedPNG: return "png"
        case .reportBundle: return "viewlensreport"
        }
    }
}

extension UTType {
    static let viewLensReport = UTType(exportedAs: "com.showblender.viewlens.report", conformingTo: .package)
}

struct ReviewExportDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.json, UTType(filenameExtension: "md") ?? .plainText, .png, .viewLensReport] }

    let review: ReviewRecord
    let events: [ReviewEvent]
    let format: ReviewExportFormat

    init(review: ReviewRecord, events: [ReviewEvent], format: ReviewExportFormat) {
        self.review = review
        self.events = events
        self.format = format
    }

    init(configuration: ReadConfiguration) throws {
        throw CocoaError(.fileReadUnsupportedScheme)
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        switch format {
        case .json:
            return FileWrapper(regularFileWithContents: try jsonData())
        case .markdown:
            return FileWrapper(regularFileWithContents: Data(markdown().utf8))
        case .annotatedPNG:
            guard let data = annotatedPNGData() else { throw CocoaError(.fileWriteUnknown) }
            return FileWrapper(regularFileWithContents: data)
        case .reportBundle:
            var files: [String: FileWrapper] = [
                "report.json": FileWrapper(regularFileWithContents: try jsonData()),
                "report.md": FileWrapper(regularFileWithContents: Data(markdown().utf8))
            ]
            if let nonvisual = review.nonvisualScreenModel,
               let nonvisualData = try? JSONEncoder().encode(nonvisual) {
                files["nonvisual-screen.json"] = FileWrapper(regularFileWithContents: nonvisualData)
                let summary = NonvisualSummaryComposer.compose(nonvisual)
                let summaryText = NonvisualPresentationRenderer.render(summary, profile: .developer)
                files["nonvisual-summary.txt"] = FileWrapper(regularFileWithContents: Data(summaryText.utf8))
            }
            if let preview = annotatedPNGData() {
                files["annotated-preview.png"] = FileWrapper(regularFileWithContents: preview)
                let overlayDesc = previewOverlayTextualDescription()
                files["annotated-preview-description.txt"] = FileWrapper(regularFileWithContents: Data(overlayDesc.utf8))
            }
            return FileWrapper(directoryWithFileWrappers: files)
        }
    }

    func jsonData() throws -> Data {
        let score = review.score
        let unevaluatedCount = max(0, (score?.totalCriteria ?? 0) - (score?.evaluatedCriteria ?? 0))
        var payload: [String: Any] = [
            "schemaVersion": 2,
            "reviewID": review.id.uuidString,
            "source": ["name": review.source.displayName, "type": review.source.sourceType],
            "status": review.status.displayName,
            "score": [
                "value": jsonValue(score?.value),
                "evaluatedCriteria": jsonValue(score?.evaluatedCriteria),
                "totalCriteria": jsonValue(score?.totalCriteria),
                "complete": jsonValue(score?.isComplete),
                "unevaluatedCriteriaCount": unevaluatedCount
            ],
            "environment": [
                "device": jsonValue(review.environment.deviceName),
                "dynamicType": jsonValue(review.environment.dynamicType),
                "appearance": jsonValue(review.environment.appearance),
                "wcagLevel": review.environment.wcagLevel,
                "detector": jsonValue(review.environment.detectorName)
            ],
            "findings": review.findings.map { finding in
                let issue = finding.issue
                return [
                    "id": finding.id,
                    "title": issue.displayTitle,
                    "kind": issue.kind.rawValue,
                    "severity": issue.severity.rawValue,
                    "description": issue.description,
                    "criterion": jsonValue(issue.wcagCriterion),
                    "level": jsonValue(issue.wcagLevel),
                    "elementIndex": jsonValue(issue.elementIndex),
                    "remediation": jsonValue(issue.remediation?.description),
                    "codeSnippet": jsonValue(issue.remediation?.codeSnippet)
                ] as [String: Any]
            },
            "events": events.map { ["timestamp": ISO8601DateFormatter().string(from: $0.timestamp), "phase": jsonValue($0.phase?.rawValue), "message": $0.message, "error": $0.isError] }
        ]

        if let nonvisual = review.nonvisualScreenModel,
           let nonvisualData = try? JSONEncoder().encode(nonvisual),
           let nonvisualObj = try? JSONSerialization.jsonObject(with: nonvisualData) {
            payload["nonvisualScreenModel"] = nonvisualObj
        }

        return try JSONSerialization.data(withJSONObject: payload, options: [.prettyPrinted, .sortedKeys])
    }

    private func jsonValue<T>(_ value: T?) -> Any {
        value.map { $0 as Any } ?? NSNull()
    }

    func markdown() -> String {
        let score = review.score
        let unevaluated = max(0, (score?.totalCriteria ?? 0) - (score?.evaluatedCriteria ?? 0))
        var lines = [
            "# ViewLens Accessibility Review",
            "",
            "- **Review ID:** `\(review.id.uuidString)`",
            "- **Source:** \(review.source.displayName) (\(review.source.sourceType))",
            "- **Status:** \(review.status.displayName)",
            "- **Score:** \(score.map { "\($0.value)/100" } ?? "Unavailable")",
            "- **Coverage:** \(score?.completenessText ?? "Unavailable")",
            "- **Unevaluated criteria:** \(unevaluated)",
            "- **WCAG target:** \(review.environment.wcagLevel)",
            "",
            "## Findings",
            ""
        ]
        if review.findings.isEmpty {
            lines.append("No findings were recorded for the evaluated criteria.")
        } else {
            for finding in review.findings {
                let issue = finding.issue
                lines += [
                    "### \(issue.displayTitle) <a id=\"finding-\(finding.id)\"></a>",
                    "",
                    "- Severity: \(issue.severity.rawValue.capitalized)",
                    "- Criterion: \(issue.wcagCriterion ?? "Apple HIG")",
                    "- Finding ID: `\(finding.id)`",
                    "",
                    issue.description,
                    "",
                    "**Deterministic remediation:** \(issue.remediation?.description ?? "Review the affected element against the cited requirement.")",
                    ""
                ]
                if let snippet = issue.remediation?.codeSnippet {
                    lines += ["```swift", snippet, "```", ""]
                }
            }
        }

        if let nonvisual = review.nonvisualScreenModel {
            lines += [
                "",
                "## Nonvisual Screen Outline & Hierarchy",
                "",
                "- **Screen ID:** `\(nonvisual.id.rawValue)`",
                "- **Source Mode:** \(nonvisual.sourceMode.rawValue)",
                "- **Regions:** \(nonvisual.regions.count)",
                "- **Elements:** \(nonvisual.elements.count)",
                "- **Interactive Elements:** \(nonvisual.elements.filter(\.isInteractive).count)",
                "",
                "### Regions & Elements",
                ""
            ]
            for region in nonvisual.regions {
                lines.append("#### Region: \(region.label) (`\(region.id.rawValue)`)")
                let regionElements = nonvisual.elements.filter { $0.regionID == region.id }
                for el in regionElements {
                    let name = el.visibleLabel ?? el.semantics?.accessibleName ?? "Element \(el.visualIndex ?? 0)"
                    lines.append("- **\(el.type.capitalized)**: \(name) <a id=\"element-\(el.id.rawValue)\"></a> (`\(el.id.rawValue)`)")
                }
                lines.append("")
            }

            let summary = NonvisualSummaryComposer.compose(nonvisual)
            lines += [
                "### Screen Summary Statements",
                ""
            ]
            for statement in summary.statements {
                lines.append("- [\(statement.category.rawValue.capitalized)] \(statement.text)")
            }
            lines.append("")
        }

        lines += [
            "## Visual Overlay Equivalents",
            "",
            previewOverlayTextualDescription(),
            ""
        ]

        return lines.joined(separator: "\n")
    }

    func previewOverlayTextualDescription() -> String {
        var lines = [
            "Textual Overlay Equivalent & Spatial Layout",
            "Target: \(review.source.displayName)",
            "Review ID: \(review.id.uuidString)",
            "Status: \(review.status.displayName)",
            ""
        ]
        if review.findings.isEmpty {
            lines.append("No visual overlay highlights (all evaluated criteria passed without finding annotations).")
        } else {
            lines.append("Visual Finding Overlays (\(review.findings.count)):")
            for finding in review.findings {
                let loc: String
                if let index = finding.issue.elementIndex, review.elements.indices.contains(index) {
                    let box = review.elements[index].boundingBox
                    loc = "at box [x: \(String(format: "%.2f", box.x)), y: \(String(format: "%.2f", box.y)), w: \(String(format: "%.2f", box.width)), h: \(String(format: "%.2f", box.height))]"
                } else {
                    loc = "at screen scope"
                }
                lines.append("- [\(finding.issue.severity.rawValue.uppercased())] \(finding.issue.displayTitle) \(loc) (Finding ID: \(finding.id))")
            }
        }
        return lines.joined(separator: "\n")
    }

    func annotatedPNGData() -> Data? {
        guard let image = review.previewImage else { return nil }
        let width = image.width
        let height = image.height
        guard let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return nil }

        context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
        context.setLineWidth(max(2, CGFloat(width) / 300))
        for finding in review.findings {
            guard let index = finding.issue.elementIndex, review.elements.indices.contains(index) else { continue }
            let box = review.elements[index].boundingBox
            let rect = CGRect(
                x: box.x * CGFloat(width),
                y: (1 - box.y - box.height) * CGFloat(height),
                width: box.width * CGFloat(width),
                height: box.height * CGFloat(height)
            )
            let color: NSColor = finding.issue.severity == .error ? .systemRed : (finding.issue.severity == .warning ? .systemOrange : .systemBlue)
            context.setStrokeColor(color.cgColor)
            context.setFillColor(color.withAlphaComponent(0.16).cgColor)
            context.setLineDash(phase: 0, lengths: finding.issue.severity == .warning ? [8, 5] : [])
            context.fill(rect)
            context.stroke(rect.insetBy(dx: 1, dy: 1))
        }
        guard let annotated = context.makeImage() else { return nil }
        let representation = NSBitmapImageRep(cgImage: annotated)
        return representation.representation(using: .png, properties: [:])
    }
}
