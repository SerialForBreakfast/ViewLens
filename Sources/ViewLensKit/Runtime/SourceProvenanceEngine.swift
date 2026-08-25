import Foundation

/// Confidence level of visual-to-source code provenance tracing.
public enum SourceProvenanceConfidence: String, Codable, Sendable, Equatable {
    case exact
    case approximate
    case unavailable
}

/// An attributed source code location tied to a visual/accessibility element (MCP-17.2, MCP-17.4).
public struct SourceRecord: Codable, Sendable, Equatable {
    public let elementID: String
    public let filePath: String?
    public let line: Int?
    public let symbol: String?
    public let confidence: SourceProvenanceConfidence
    public let detail: String

    public init(
        elementID: String,
        filePath: String? = nil,
        line: Int? = nil,
        symbol: String? = nil,
        confidence: SourceProvenanceConfidence,
        detail: String
    ) {
        self.elementID = elementID
        self.filePath = filePath
        self.line = line
        self.symbol = symbol
        self.confidence = confidence
        self.detail = detail
    }
}

/// Engine mapping runtime elements and templates to responsible source code locations (MCP-17.1 - MCP-17.4).
public enum SourceProvenanceEngine {

    /// Traces an element identifier or template back to source code in the workspace.
    public static func traceSource(
        elementID: String,
        templateName: String,
        workspaceRoot: String = FileManager.default.currentDirectoryPath
    ) -> SourceRecord {
        // Look for matching Swift file in Sources
        let candidateFileName = "\(templateName).swift"
        let sourcesURL = URL(fileURLWithPath: workspaceRoot).appendingPathComponent("Sources")

        if let enumerator = FileManager.default.enumerator(at: sourcesURL, includingPropertiesForKeys: nil) {
            for case let fileURL as URL in enumerator {
                if fileURL.lastPathComponent.lowercased() == candidateFileName.lowercased() {
                    let relativePath = fileURL.path.replacingOccurrences(of: workspaceRoot + "/", with: "")
                    return SourceRecord(
                        elementID: elementID,
                        filePath: relativePath,
                        line: 1,
                        symbol: templateName,
                        confidence: .approximate,
                        detail: "Matched template source file '\(relativePath)' in workspace."
                    )
                }
            }
        }

        return SourceRecord(
            elementID: elementID,
            filePath: nil,
            line: nil,
            symbol: nil,
            confidence: .unavailable,
            detail: "No instrumented debug metadata or exact source file match found for '\(elementID)' in '\(templateName)'."
        )
    }
}
