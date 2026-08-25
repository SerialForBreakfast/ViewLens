import Testing
import Foundation
@testable import ViewLensKit

@Suite("Flow Replay & Accessibility Focus Graph Tests (M16.4, M16.5, M16.13)")
struct FlowReplayAndFocusGraphTests {

    @Test("FlowReplayEngine replays multi-step interactions and verifies assertions")
    func testFlowReplayEngine() {
        let prov = EvidenceProvenance(kind: .measured, source: "testFixture")

        let btnNode = NativeAccessibilityNode(
            id: NonvisualID("btn_login"),
            label: "Sign In",
            value: nil,
            traits: [.isButton],
            frame: BoundingBox(x: 0.1, y: 0.2, width: 0.8, height: 0.1),
            provenance: prov
        )

        let txtNode = NativeAccessibilityNode(
            id: NonvisualID("txt_status"),
            label: "Welcome Back User",
            value: nil,
            traits: [.isStaticText],
            frame: BoundingBox(x: 0.1, y: 0.4, width: 0.8, height: 0.05),
            provenance: prov
        )

        let nodes = [btnNode, txtNode]

        let step1 = FlowStep(
            id: "step_1",
            action: UIAction(kind: .activate, elementID: "btn_login"),
            assertion: FlowAssertion(kind: "element_exists", targetElementID: "btn_login")
        )

        let step2 = FlowStep(
            id: "step_2",
            action: UIAction(kind: .moveFocus, elementID: "txt_status"),
            assertion: FlowAssertion(kind: "element_contains_text", targetElementID: "txt_status", expectedValue: "Welcome")
        )

        let script = FlowScript(
            name: "LoginFlow",
            targetTemplate: "LoginForm",
            steps: [step1, step2]
        )

        let report = FlowReplayEngine.replay(script: script, accessibilityNodes: nodes)
        #expect(report.passed)
        #expect(report.stepResults.count == 2)
        #expect(report.stepResults.allSatisfy { $0.assertionPassed })
    }

    @Test("FocusGraphEngine constructs natural reading order and traversal links")
    func testFocusGraphEngine() {
        let prov = EvidenceProvenance(kind: .measured, source: "testFixture")

        let header = NativeAccessibilityNode(
            id: NonvisualID("header_nav"),
            label: "Dashboard",
            value: nil,
            traits: [.isHeader],
            frame: BoundingBox(x: 0.1, y: 0.05, width: 0.8, height: 0.08),
            provenance: prov
        )

        let item1 = NativeAccessibilityNode(
            id: NonvisualID("card_1"),
            label: "Account Balance",
            value: nil,
            traits: [.isStaticText],
            frame: BoundingBox(x: 0.1, y: 0.20, width: 0.35, height: 0.15),
            provenance: prov
        )

        let item2 = NativeAccessibilityNode(
            id: NonvisualID("card_2"),
            label: "Recent Activity",
            value: nil,
            traits: [.isStaticText],
            frame: BoundingBox(x: 0.55, y: 0.20, width: 0.35, height: 0.15),
            provenance: prov
        )

        let button = NativeAccessibilityNode(
            id: NonvisualID("btn_transfer"),
            label: "Transfer Funds",
            value: nil,
            traits: [.isButton],
            frame: BoundingBox(x: 0.1, y: 0.45, width: 0.8, height: 0.10),
            provenance: prov
        )

        // Pass in jumbled order to verify natural sorting
        let graph = FocusGraphEngine.buildGraph(nodes: [button, item2, header, item1])

        #expect(graph.readingOrder == ["header_nav", "card_1", "card_2", "btn_transfer"])
        #expect(graph.nodes.count == 4)
        #expect(graph.isTraversable)

        // Verify sequential links
        #expect(graph.nodes[0].id == "header_nav")
        #expect(graph.nodes[0].nextID == "card_1")
        #expect(graph.nodes[1].previousID == "header_nav")
        #expect(graph.nodes[1].nextID == "card_2")
    }

    @Test("MCPServer executes viewlens_flow_replay and viewlens_accessibility_graph")
    func testMCPServerFlowAndFocusGraphTools() async throws {
        let server = MCPServer()

        // 1. Accessibility Graph Tool
        let graphReq = JSONRPCRequest(
            id: .string("req-graph"),
            method: "tools/call",
            params: .object([
                "name": .string("viewlens_accessibility_graph"),
                "arguments": .object([
                    "template": .string("LoginForm")
                ])
            ])
        )
        let graphRespData = try #require(await server.handleRequest(graphReq))
        let graphJson = try #require(JSONSerialization.jsonObject(with: graphRespData) as? [String: Any])
        let graphResult = try #require(graphJson["result"] as? [String: Any])
        #expect(graphResult["isError"] as? Bool == false)

        // 2. Flow Replay Tool
        let replayReq = JSONRPCRequest(
            id: .string("req-replay"),
            method: "tools/call",
            params: .object([
                "name": .string("viewlens_flow_replay"),
                "arguments": .object([
                    "template": .string("LoginForm"),
                    "name": .string("SmokeTest"),
                    "actions": .array([
                        .object([
                            "id": .string("s1"),
                            "action": .string("activate"),
                            "element_id": .string("btn_login")
                        ])
                    ])
                ])
            ])
        )
        let replayRespData = try #require(await server.handleRequest(replayReq))
        let replayJson = try #require(JSONSerialization.jsonObject(with: replayRespData) as? [String: Any])
        let replayResult = try #require(replayJson["result"] as? [String: Any])
        #expect(replayResult["isError"] as? Bool == false)
    }
}
