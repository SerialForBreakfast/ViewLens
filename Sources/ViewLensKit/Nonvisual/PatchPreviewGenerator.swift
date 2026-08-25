import Foundation

/// A structured patch preview and regression test handoff for developer or AI agent consumption.
public struct PatchPreviewHandoff: Codable, Sendable, Equatable {
    public let componentName: String
    public let affectedElementIDs: [NonvisualID]
    public let expectedSemanticChanges: [String]
    public let rollbackInstructions: String
    public let generatedSwiftRegressionTest: String

    public init(
        componentName: String,
        affectedElementIDs: [NonvisualID],
        expectedSemanticChanges: [String],
        rollbackInstructions: String,
        generatedSwiftRegressionTest: String
    ) {
        self.componentName = componentName
        self.affectedElementIDs = affectedElementIDs.sorted()
        self.expectedSemanticChanges = expectedSemanticChanges
        self.rollbackInstructions = rollbackInstructions
        self.generatedSwiftRegressionTest = generatedSwiftRegressionTest
    }

    public func formattedMarkdown() -> String {
        return """
        ## 🛠️ ViewLens Patch-Preview & Verification Handoff
        
        **Target Component:** `\(componentName)`  
        **Affected Nodes:** \(affectedElementIDs.map { "`\($0.rawValue)`" }.joined(separator: ", "))
        
        ### 📋 Expected Semantic Improvements
        \(expectedSemanticChanges.map { "- \($0)" }.joined(separator: "\n"))
        
        ### 🔄 Rollback Instructions
        \(rollbackInstructions)
        
        ### 🧪 Generated Swift Testing Regression Assertions
        ```swift
        \(generatedSwiftRegressionTest)
        ```
        """
    }
}

/// Generates patch-preview handoffs and deterministic Swift regression tests.
public enum PatchPreviewGenerator {

    public static func generateHandoff(
        for componentName: String,
        diff: SemanticScreenDiff,
        targetFile: String? = nil
    ) -> PatchPreviewHandoff {
        let file = targetFile ?? "Views/\(componentName).swift"
        let affectedIDs = diff.changes.map(\.elementID)
        let uniqueAffectedIDs = Array(Set(affectedIDs)).sorted()

        var semanticChanges: [String] = []
        for change in diff.changes {
            semanticChanges.append("\(change.kind.rawValue): \(change.description)")
        }

        let rollback = "To revert: discard changes in `\(file)` via `git checkout -- \(file)`."

        let testCode = generateRegressionTest(componentName: componentName, diff: diff)

        return PatchPreviewHandoff(
            componentName: componentName,
            affectedElementIDs: uniqueAffectedIDs,
            expectedSemanticChanges: semanticChanges,
            rollbackInstructions: rollback,
            generatedSwiftRegressionTest: testCode
        )
    }

    public static func generateRegressionTest(
        componentName: String,
        diff: SemanticScreenDiff
    ) -> String {
        let cleanName = componentName.replacingOccurrences(of: " ", with: "")
        var lines: [String] = [
            "import Testing",
            "import ViewLensKit",
            "",
            "@Suite(\"Accessibility Regressions: \(componentName)\")",
            "struct \(cleanName)AccessibilityTests {",
            "",
            "    @Test(\"\(componentName) maintains required accessibility semantics\")",
            "    func testAccessibilitySemantics() async throws {",
            "        let report = try await MatrixRenderer.auditTemplate(\"\(cleanName)\")",
            "        #expect(report.passed, \"Expected \(componentName) to pass accessibility quality gates\")",
            "        #expect(report.issues.isEmpty, \"Found unexpected accessibility issues\")"
        ]

        for change in diff.changes where change.kind == .findingResolved {
            lines.append("        // Regression check: \(change.description)")
            lines.append("        #expect(!report.issues.contains { $0.description.contains(\"\(change.elementID.rawValue)\") })")
        }

        lines.append("    }")
        lines.append("}")

        return lines.joined(separator: "\n")
    }
}
