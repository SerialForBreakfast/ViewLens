import Foundation

/// A generated, marker-wrapped Swift regression test suite ready to be reviewed and merged
/// into the host project's test target (MCP-17.11).
public struct GeneratedRegressionTest: Codable, Sendable, Equatable {
    public let regionID: NonvisualID
    public let suiteName: String
    public let fileName: String
    /// Full marker-wrapped Swift source for this region, self-contained and ready to review
    /// or write as a brand-new file.
    public let source: String
    /// The unwrapped suite body, with no markers — pass this (not ``source``) as
    /// `newContent` to ``GeneratedRegionMerger/merge(regionID:newContent:into:)`` when writing
    /// into a file that may already contain this region, so the markers aren't doubled.
    public let body: String

    public init(regionID: NonvisualID, suiteName: String, fileName: String, source: String, body: String) {
        self.regionID = regionID
        self.suiteName = suiteName
        self.fileName = fileName
        self.source = source
        self.body = body
    }
}

/// Generates reviewable, compilable `swift-testing` regression suites from an approved replay
/// script and its closed-loop fix verification (MCP-17.11).
///
/// Follows the codebase's existing generator convention (`PatchPreviewGenerator`,
/// `ManualVerificationGenerator`): plain deterministic Swift logic building a source string via
/// line-array templating, no SwiftSyntax dependency.
public enum RegressionTestGenerator {

    /// Generates a regression suite covering the replayed flow and every resolved issue from
    /// `fixVerification`. `remainingIssues`/`introducedIssues`/`notRetested` are surfaced only
    /// as doc comments — a regression suite must never encode "this bug still exists" as a
    /// permanently-passing test. The visual-baseline hook is emitted `.disabled(...)` by
    /// default: MCP-17.10 requires elicited user approval before a baseline is recorded, so
    /// this generator never silently wires up an active assertion against an unapproved one.
    public static func generate(
        script: FlowScript,
        fixVerification: FixVerificationReport,
        sourceRecords: [SourceRecord] = []
    ) -> GeneratedRegressionTest {
        let sanitizedTemplate = sanitizedSwiftIdentifier(script.targetTemplate)
        let sanitizedScriptName = sanitizedSwiftIdentifier(script.name)
        let suiteName = "\(sanitizedTemplate)\(sanitizedScriptName)RegressionTests"
        let regionID = NonvisualID("\(script.targetTemplate):regression:\(script.name)")

        var lines: [String] = []
        lines.append("import Testing")
        lines.append("@testable import ViewLensKit")
        lines.append("")
        lines.append("@Suite(\"ViewLens Regression: \(script.targetTemplate) (\(script.name))\")")
        lines.append("struct \(suiteName) {")
        lines.append("")
        lines.append(contentsOf: replayTestLines(script: script))
        lines.append("")

        for issueKind in fixVerification.resolvedIssues.sorted() {
            lines.append(contentsOf: resolvedIssueTestLines(templateName: script.targetTemplate, issueKind: issueKind))
            lines.append("")
        }

        lines.append(contentsOf: remainingIssuesDocComment(fixVerification: fixVerification))
        lines.append(contentsOf: sourceProvenanceDocComment(sourceRecords: sourceRecords))
        lines.append(contentsOf: visualBaselineTestLines(templateName: script.targetTemplate))
        lines.append("}")

        let body = lines.joined(separator: "\n")
        // Reuses GeneratedRegionMerger's own wrapping (via the "no existing file" path) rather
        // than duplicating the marker format here, so `source` and a later real merge always
        // agree on exactly what "wrapped" looks like.
        let wrapped = (try? GeneratedRegionMerger.merge(regionID: regionID, newContent: body, into: nil)) ?? body

        return GeneratedRegressionTest(
            regionID: regionID,
            suiteName: suiteName,
            fileName: "\(suiteName).swift",
            source: wrapped,
            body: body
        )
    }

    private static func replayTestLines(script: FlowScript) -> [String] {
        var lines: [String] = []
        lines.append("    @Test(\"Replays the approved '\(script.name)' flow without regressions\")")
        lines.append("    func testReplayFlow() {")
        lines.append("        let script = FlowScript(")
        lines.append("            schemaVersion: \"\(script.schemaVersion)\",")
        lines.append("            name: \"\(script.name)\",")
        lines.append("            targetTemplate: \"\(script.targetTemplate)\",")
        lines.append("            steps: [")
        for step in script.steps {
            lines.append(contentsOf: stepLiteralLines(step).map { "                " + $0 })
        }
        lines.append("            ]")
        lines.append("        )")
        lines.append("        let report = FlowReplayEngine.replay(script: script)")
        lines.append("        #expect(report.passed, \"Replay of '\(script.name)' should complete without step or assertion failures\")")
        lines.append("    }")
        return lines
    }

    private static func stepLiteralLines(_ step: FlowStep) -> [String] {
        var lines: [String] = []
        lines.append("FlowStep(")
        lines.append("    id: \"\(escaped(step.id))\",")
        lines.append("    action: \(actionLiteral(step.action)),")
        if let assertion = step.assertion {
            lines.append("    assertion: \(assertionLiteral(assertion))")
        } else {
            lines.append("    assertion: nil")
        }
        lines.append("),")
        return lines
    }

    private static func actionLiteral(_ action: UIAction) -> String {
        var parts = ["kind: .\(action.kind.rawValue == "type_text" ? "typeText" : (action.kind.rawValue == "key_shortcut" ? "keyShortcut" : (action.kind.rawValue == "move_focus" ? "moveFocus" : action.kind.rawValue)))"]
        if let elementID = action.elementID { parts.append("elementID: \"\(escaped(elementID))\"") }
        if let coordinate = action.coordinate { parts.append("coordinate: \(coordinate)") }
        if let text = action.text { parts.append("text: \"\(escaped(text))\"") }
        if let direction = action.direction { parts.append("direction: \"\(escaped(direction))\"") }
        if let shortcut = action.shortcut { parts.append("shortcut: \"\(escaped(shortcut))\"") }
        return "UIAction(\(parts.joined(separator: ", ")))"
    }

    private static func assertionLiteral(_ assertion: FlowAssertion) -> String {
        var parts = ["kind: \"\(escaped(assertion.kind))\"", "targetElementID: \"\(escaped(assertion.targetElementID))\""]
        if let expected = assertion.expectedValue {
            parts.append("expectedValue: \"\(escaped(expected))\"")
        }
        return "FlowAssertion(\(parts.joined(separator: ", ")))"
    }

    private static func resolvedIssueTestLines(templateName: String, issueKind: String) -> [String] {
        let sanitizedKind = sanitizedSwiftIdentifier(issueKind)
        var lines: [String] = []
        lines.append("    @Test(\"Resolved: '\(issueKind)' no longer present on '\(templateName)'\")")
        lines.append("    @MainActor")
        lines.append("    func testResolved_\(sanitizedKind)() async throws {")
        lines.append("        guard let view = TemplateRegistry.shared.template(named: \"\(templateName)\") else {")
        lines.append("            Issue.record(\"\(templateName) template missing\")")
        lines.append("            return")
        lines.append("        }")
        lines.append("        let permutations = MatrixRenderer.buildPermutations(devices: [.iPhoneSE], dynamicTypeSizes: [\"large\"], colorSchemes: [\"light\"])")
        lines.append("        let report = try await MatrixRenderer.auditMatrix(templateName: \"\(templateName)\", view: view, permutations: permutations)")
        lines.append("        let stillPresent = report.permutations.values.flatMap(\\.issues).contains { $0.kind.rawValue == \"\(issueKind)\" }")
        lines.append("        #expect(!stillPresent, \"'\(issueKind)' should remain resolved on '\(templateName)'\")")
        lines.append("    }")
        return lines
    }

    private static func remainingIssuesDocComment(fixVerification: FixVerificationReport) -> [String] {
        guard !fixVerification.remainingIssues.isEmpty || !fixVerification.introducedIssues.isEmpty || !fixVerification.notRetested.isEmpty else {
            return []
        }
        var lines: [String] = ["    // Not encoded as tests \u{2014} a regression suite must not treat known-remaining issues as permanent passes:"]
        if !fixVerification.remainingIssues.isEmpty {
            lines.append("    // Remaining: \(fixVerification.remainingIssues.joined(separator: ", "))")
        }
        if !fixVerification.introducedIssues.isEmpty {
            lines.append("    // Introduced (regressions): \(fixVerification.introducedIssues.joined(separator: ", "))")
        }
        if !fixVerification.notRetested.isEmpty {
            lines.append("    // Not retested: \(fixVerification.notRetested.joined(separator: ", "))")
        }
        lines.append("")
        return lines
    }

    private static func sourceProvenanceDocComment(sourceRecords: [SourceRecord]) -> [String] {
        guard !sourceRecords.isEmpty else { return [] }
        var lines: [String] = ["    // Source provenance (never fabricated \u{2014} \"unavailable\" means ViewLens found no instrumented location):"]
        for record in sourceRecords {
            let location = record.filePath.map { path in "\(path)\(record.line.map { ":\($0)" } ?? "")" } ?? "unavailable"
            lines.append("    // \(record.elementID) -> \(location) (confidence: \(record.confidence.rawValue))")
        }
        lines.append("")
        return lines
    }

    private static func visualBaselineTestLines(templateName: String) -> [String] {
        [
            "    @Test(",
            "        \"Visual baseline: '\(templateName)' matches the approved baseline\",",
            "        .disabled(\"Baseline path must be supplied and approved via viewlens_design_diff before enabling\")",
            "    )",
            "    func testVisualBaseline() throws {",
            "        // Intentionally left disabled: MCP-17.10 requires elicited user approval before",
            "        // recording or replacing an approved baseline. Enable only after that approval.",
            "    }"
        ]
    }

    private static func escaped(_ value: String) -> String {
        value.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "\"", with: "\\\"")
    }

    private static func sanitizedSwiftIdentifier(_ value: String) -> String {
        let allowed = value.unicodeScalars.map { CharacterSet.alphanumerics.contains($0) ? Character($0) : "_" }
        let cleaned = String(allowed)
        guard let first = cleaned.first, first.isNumber else { return cleaned }
        return "_" + cleaned
    }
}
