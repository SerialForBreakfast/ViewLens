import Testing
import Foundation
@testable import ViewLensKit

@Suite("Advanced Runtime, Voice Control, State Crawl & Provenance Tests (M16.7-M16.12, M17.1-M17.8)")
struct AdvancedRuntimeAndProvenanceTests {

    @Test("VoiceControlValidator detects name collisions and missing triggers")
    func testVoiceControlValidator() {
        let prov = EvidenceProvenance(kind: .measured, source: "testFixture")

        let btn1 = NativeAccessibilityNode(
            id: NonvisualID("btn_save_1"),
            label: "Save",
            value: nil,
            traits: [.isButton],
            frame: BoundingBox(x: 0.1, y: 0.1, width: 0.3, height: 0.1),
            provenance: prov
        )

        let btn2 = NativeAccessibilityNode(
            id: NonvisualID("btn_save_2"),
            label: "Save",
            value: nil,
            traits: [.isButton],
            frame: BoundingBox(x: 0.5, y: 0.1, width: 0.3, height: 0.1),
            provenance: prov
        )

        let btnNoLabel = NativeAccessibilityNode(
            id: NonvisualID("btn_empty"),
            label: "",
            value: nil,
            traits: [.isButton],
            frame: BoundingBox(x: 0.1, y: 0.3, width: 0.3, height: 0.1),
            provenance: prov
        )

        let report = VoiceControlValidator.validate(nodes: [btn1, btn2, btnNoLabel])
        #expect(!report.passed)
        #expect(report.issues.contains { $0.kind == .nameCollision })
        #expect(report.issues.contains { $0.kind == .missingTrigger })
    }

    @Test("VoiceControlValidator flags an explicit activation point outside its control's bounds")
    func testVoiceControlValidatorActivationPointOutside() {
        let prov = EvidenceProvenance(kind: .measured, source: "testFixture")

        let btnWithBadActivationPoint = NativeAccessibilityNode(
            id: NonvisualID("btn_misplaced"),
            label: "Submit",
            value: nil,
            traits: [.isButton],
            frame: BoundingBox(x: 0.1, y: 0.1, width: 0.3, height: 0.1),
            provenance: prov,
            activationPoint: CGPoint(x: 0.9, y: 0.9)
        )

        let report = VoiceControlValidator.validate(nodes: [btnWithBadActivationPoint])
        #expect(!report.passed)
        #expect(report.issues.contains { $0.kind == .activationPointOutside })
    }

    @Test("VoiceControlValidator never fabricates an activation point when none is reported")
    func testVoiceControlValidatorNoActivationPointNoFabrication() {
        let prov = EvidenceProvenance(kind: .measured, source: "testFixture")

        let btnNoOverride = NativeAccessibilityNode(
            id: NonvisualID("btn_default"),
            label: "Cancel",
            value: nil,
            traits: [.isButton],
            frame: BoundingBox(x: 0.1, y: 0.1, width: 0.3, height: 0.1),
            provenance: prov
        )

        let report = VoiceControlValidator.validate(nodes: [btnNoOverride])
        #expect(report.passed)
        #expect(!report.issues.contains { $0.kind == .activationPointOutside })
    }

    @Test("StateCrawler discovers states and detects loops")
    func testStateCrawler() {
        let prov = EvidenceProvenance(kind: .measured, source: "testFixture")

        let btn = NativeAccessibilityNode(
            id: NonvisualID("btn_next"),
            label: "Next",
            value: nil,
            traits: [.isButton],
            frame: BoundingBox(x: 0.1, y: 0.1, width: 0.8, height: 0.1),
            provenance: prov
        )

        let report = StateCrawler.crawl(templateName: "OnboardingFlow", nodes: [btn], maxDepth: 3, maxStates: 5)
        #expect(report.visitedStateCount >= 1)
        #expect(report.discoveredStates.first?.stateType == .content)
    }

    @Test("StateCrawler stops exploring once maxDurationMs elapses")
    func testStateCrawlerRespectsDurationBudget() {
        let prov = EvidenceProvenance(kind: .measured, source: "testFixture")
        let buttons = (0..<20).map { index in
            NativeAccessibilityNode(
                id: NonvisualID("btn_\(index)"),
                label: "Action \(index)",
                value: nil,
                traits: [.isButton],
                frame: BoundingBox(x: 0.1, y: 0.1, width: 0.8, height: 0.1),
                provenance: prov
            )
        }

        let report = StateCrawler.crawl(
            templateName: "LargeFlow",
            nodes: buttons,
            maxDepth: 20,
            maxStates: 20,
            maxDurationMs: 0
        )

        // Root state is always recorded; the duration budget of 0ms must prevent any further exploration.
        #expect(report.visitedStateCount == 1)
    }

    @Test("LocaleStressTester generates pseudolocalized strings with expansion")
    func testLocaleStressTester() {
        let original = "Welcome to ViewLens"
        let pseudoResult = LocaleStressTester.generateStressCase(text: original, profile: .pseudolocalization)

        #expect(pseudoResult.transformedText.hasPrefix("[!!!"))
        #expect(pseudoResult.transformedText.hasSuffix("!!!]"))
        #expect(pseudoResult.lengthExpansionRatio > 1.2)

        let rtlResult = LocaleStressTester.generateStressCase(text: original, profile: .rtlMirroring)
        #expect(rtlResult.isRTL)
    }

    @Test("SourceProvenanceEngine returns explicit confidence without fabricating file lines")
    func testSourceProvenanceEngine() {
        // Known file
        let known = SourceProvenanceEngine.traceSource(elementID: "btn_login", templateName: "MCPServer")
        #expect(known.confidence == .approximate)
        #expect(known.filePath?.contains("MCPServer.swift") == true)

        // Unknown uninstrumented target returns unavailable
        let unknown = SourceProvenanceEngine.traceSource(elementID: "unknown_id", templateName: "NonExistentView123")
        #expect(unknown.confidence == .unavailable)
        #expect(unknown.filePath == nil)
    }

    @Test("FixVerifier categorizes resolved issues and detects regressions")
    func testFixVerifier() {
        let changeSet = ChangeSet(changedFiles: ["LoginForm.swift"], targetTemplate: "LoginForm")
        let baseline = ["tappableTargetTooSmall", "contrastTooLow"]
        let current = ["contrastTooLow", "elementOverlap"]

        let report = FixVerifier.verify(changeSet: changeSet, baselineIssues: baseline, currentIssues: current)

        #expect(report.resolvedIssues == ["tappableTargetTooSmall"])
        #expect(report.remainingIssues == ["contrastTooLow"])
        #expect(report.introducedIssues == ["elementOverlap"]) // Regression!
        #expect(report.hasRegressions)
        #expect(!report.passed)
    }

    @Test("MCPServer executes flow_crawl, trace_to_source, and verify_changes tools")
    func testMCPServerAdvancedTools() async throws {
        let server = MCPServer()

        // 1. Flow Crawl
        let crawlReq = JSONRPCRequest(
            id: .string("req-crawl"),
            method: "tools/call",
            params: .object([
                "name": .string("viewlens_flow_crawl"),
                "arguments": .object([
                    "template": .string("LoginForm"),
                    "max_depth": .number(2),
                    "max_states": .number(5)
                ])
            ])
        )
        let crawlData = try #require(await server.handleRequest(crawlReq))
        let crawlJson = try #require(JSONSerialization.jsonObject(with: crawlData) as? [String: Any])
        let crawlRes = try #require(crawlJson["result"] as? [String: Any])
        #expect(crawlRes["isError"] as? Bool == false)

        // 2. Trace To Source
        let traceReq = JSONRPCRequest(
            id: .string("req-trace"),
            method: "tools/call",
            params: .object([
                "name": .string("viewlens_trace_to_source"),
                "arguments": .object([
                    "element_id": .string("btn_login"),
                    "template": .string("LoginForm")
                ])
            ])
        )
        let traceData = try #require(await server.handleRequest(traceReq))
        let traceJson = try #require(JSONSerialization.jsonObject(with: traceData) as? [String: Any])
        let traceRes = try #require(traceJson["result"] as? [String: Any])
        #expect(traceRes["isError"] as? Bool == false)

        // 3. Verify Changes
        let verifyReq = try JSONDecoder().decode(JSONRPCRequest.self, from: Data("""
        {
          "jsonrpc": "2.0",
          "id": 99,
          "method": "tools/call",
          "params": {
            "name": "viewlens_verify_changes",
            "arguments": {
              "template": "LoginForm",
              "changed_files": ["Sources/LoginForm.swift"],
              "baseline_issues": ["tappableTargetTooSmall"]
            },
            "_meta": {
              "io.modelcontextprotocol/protocolVersion": "2026-07-28",
              "io.modelcontextprotocol/clientCapabilities": {}
            }
          }
        }
        """.utf8))
        let verifyData = try #require(await server.handleRequest(verifyReq))
        let verifyJson = try #require(JSONSerialization.jsonObject(with: verifyData) as? [String: Any])
        let verifyRes = try #require(verifyJson["result"] as? [String: Any])
        #expect(verifyRes["structuredContent"] != nil)
    }
}
