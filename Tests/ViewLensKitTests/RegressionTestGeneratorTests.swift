import Testing
import Foundation
@testable import ViewLensKit

@Suite("RegressionTestGenerator Tests (MCP-17.11)")
struct RegressionTestGeneratorTests {

    private func makeScript() -> FlowScript {
        FlowScript(
            name: "submit_flow",
            targetTemplate: "FixtureFlowForm",
            steps: [
                FlowStep(
                    id: "step1",
                    action: UIAction(kind: .activate, elementID: "SubmitButton"),
                    assertion: FlowAssertion(kind: "element_exists", targetElementID: "SubmitButton")
                )
            ]
        )
    }

    private func makeFixVerification(resolved: [String] = ["tappableTargetTooSmall"], remaining: [String] = [], introduced: [String] = []) -> FixVerificationReport {
        FixVerifier.verify(
            changeSet: ChangeSet(changedFiles: ["Sources/FixtureFlowTemplates.swift"], targetTemplate: "FixtureFlowForm"),
            baselineIssues: resolved + remaining,
            currentIssues: remaining + introduced
        )
    }

    @Test("Generated source is marker-wrapped with the expected region ID")
    func testGeneratedSourceIsMarkerWrapped() {
        let generated = RegressionTestGenerator.generate(script: makeScript(), fixVerification: makeFixVerification())
        #expect(generated.source.contains("// viewlens:generated:begin \(generated.regionID.rawValue)"))
        #expect(generated.source.contains("// viewlens:generated:end \(generated.regionID.rawValue)"))
        #expect(!generated.body.contains("viewlens:generated:begin"))
    }

    @Test("Generated source contains one test per resolved issue")
    func testGeneratedSourceContainsOneTestPerResolvedIssue() {
        let generated = RegressionTestGenerator.generate(
            script: makeScript(),
            fixVerification: makeFixVerification(resolved: ["tappableTargetTooSmall", "insufficientContrast"])
        )
        #expect(generated.source.contains("testResolved_tappableTargetTooSmall"))
        #expect(generated.source.contains("testResolved_insufficientContrast"))
    }

    @Test("Visual baseline test is disabled by default")
    func testVisualBaselineTestIsDisabledByDefault() {
        let generated = RegressionTestGenerator.generate(script: makeScript(), fixVerification: makeFixVerification())
        #expect(generated.source.contains(".disabled("))
        #expect(generated.source.contains("testVisualBaseline"))
    }

    @Test("Remaining and introduced issues are surfaced only as doc comments, never as tests")
    func testRemainingIssuesAreDocCommentsNotTests() {
        let generated = RegressionTestGenerator.generate(
            script: makeScript(),
            fixVerification: makeFixVerification(resolved: [], remaining: ["clippedContent"])
        )
        #expect(generated.source.contains("// Remaining: clippedContent"))
        #expect(!generated.source.contains("func testResolved_clippedContent"))
    }

    @Test("Generated source is syntactically valid Swift")
    func testGeneratedSourceCompiles() throws {
        let generated = RegressionTestGenerator.generate(script: makeScript(), fixVerification: makeFixVerification())

        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("viewlens-generated-test-\(UUID().uuidString).swift")
        try generated.source.write(to: tempURL, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(at: tempURL) }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/swiftc")
        process.arguments = ["-parse", tempURL.path]
        let stderrPipe = Pipe()
        process.standardError = stderrPipe
        try process.run()
        process.waitUntilExit()

        let stderrData = stderrPipe.fileHandleForReading.readDataToEndOfFile()
        let stderrText = String(data: stderrData, encoding: .utf8) ?? ""
        #expect(process.terminationStatus == 0, "swiftc -parse should succeed on generated source:\n\(stderrText)")
    }

    @Test("viewlens_generate_regression_test merges into an existing file without clobbering hand-written code")
    func testGenerateRegressionTestToolMergesIntoExistingFileWithoutClobbering() async throws {
        let server = MCPServer()
        let scratchURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("viewlens-generate-regression-test-\(UUID().uuidString).swift")
        defer { try? FileManager.default.removeItem(at: scratchURL) }

        let handWritten = "import Testing\n\n// hand-written helper, must survive regeneration\nfunc helper() -> Int { 42 }\n"
        try handWritten.write(to: scratchURL, atomically: true, encoding: .utf8)

        func makeRequest(baselineIssue: String) -> JSONRPCRequest {
            JSONRPCRequest(
                id: .string("req-generate"),
                method: "tools/call",
                params: .object([
                    "name": .string("viewlens_generate_regression_test"),
                    "arguments": .object([
                        "template": .string("FixtureFlowForm"),
                        "script_name": .string("submit_flow"),
                        "steps": .array([
                            .object([
                                "id": .string("step1"),
                                "action": .object([
                                    "kind": .string("activate"),
                                    "element_id": .string("SubmitButton")
                                ])
                            ])
                        ]),
                        "baseline_issues": .array([.string(baselineIssue)]),
                        "output_path": .string(scratchURL.path)
                    ])
                ])
            )
        }

        // First generation.
        let first = try #require(await server.handleRequest(makeRequest(baselineIssue: "tappableTargetTooSmall")))
        let firstJson = try #require(JSONSerialization.jsonObject(with: first) as? [String: Any])
        let firstResult = try #require(firstJson["result"] as? [String: Any])
        #expect(firstResult["isError"] as? Bool == false)

        let afterFirst = try String(contentsOf: scratchURL, encoding: .utf8)
        #expect(afterFirst.contains("func helper() -> Int { 42 }"))
        #expect(afterFirst.contains("viewlens:generated:begin FixtureFlowForm:regression:submit_flow"))

        // Second generation with different content: must still preserve the hand-written helper.
        let second = try #require(await server.handleRequest(makeRequest(baselineIssue: "insufficientContrast")))
        let secondJson = try #require(JSONSerialization.jsonObject(with: second) as? [String: Any])
        let secondResult = try #require(secondJson["result"] as? [String: Any])
        #expect(secondResult["isError"] as? Bool == false)

        let afterSecond = try String(contentsOf: scratchURL, encoding: .utf8)
        #expect(afterSecond.contains("func helper() -> Int { 42 }"))
        #expect(afterSecond.contains("viewlens:generated:begin FixtureFlowForm:regression:submit_flow"))
    }
}
