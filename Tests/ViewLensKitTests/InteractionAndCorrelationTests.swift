import Testing
import Foundation
import CoreGraphics
@testable import ViewLensKit

@Suite("Visual-Semantic Correlation, State Capture & UI Interaction Tests (M15.7-M15.9, M16.1-M16.3)")
struct InteractionAndCorrelationTests {

    @Test("VisualSemanticCorrelator pairs vision detections with accessibility hierarchy and detects conflicts")
    func testVisualSemanticCorrelator() {
        let prov = EvidenceProvenance(kind: .measured, source: "testFixture")

        let visualBtn = DetectedElement(
            type: "primaryButton",
            confidence: 0.95,
            boundingBox: BoundingBox(x: 0.1, y: 0.2, width: 0.8, height: 0.1)
        )

        let visualText = DetectedElement(
            type: "staticText",
            confidence: 0.90,
            boundingBox: BoundingBox(x: 0.1, y: 0.4, width: 0.8, height: 0.05)
        )

        let visualUnmatched = DetectedElement(
            type: "icon",
            confidence: 0.88,
            boundingBox: BoundingBox(x: 0.8, y: 0.05, width: 0.1, height: 0.05)
        )

        let nodeBtn = NativeAccessibilityNode(
            id: NonvisualID("node_btn"),
            label: "Continue",
            value: nil,
            traits: [.isButton],
            frame: BoundingBox(x: 0.1, y: 0.2, width: 0.8, height: 0.1),
            provenance: prov
        )

        let nodeTextNoTrait = NativeAccessibilityNode(
            id: NonvisualID("node_txt"),
            label: "Terms & Conditions",
            value: nil,
            traits: [],
            frame: BoundingBox(x: 0.1, y: 0.4, width: 0.8, height: 0.05),
            provenance: prov
        )

        let nodeUnmatched = NativeAccessibilityNode(
            id: NonvisualID("node_hidden"),
            label: "Hidden Accessibility Description",
            value: nil,
            traits: [.isStaticText],
            frame: BoundingBox(x: 0.1, y: 0.9, width: 0.8, height: 0.05),
            provenance: prov
        )

        let report = VisualSemanticCorrelator.correlate(
            visualElements: [visualBtn, visualText, visualUnmatched],
            accessibilityNodes: [nodeBtn, nodeTextNoTrait, nodeUnmatched],
            minIoUThreshold: 0.2
        )

        #expect(report.matchedPairs.count == 2)
        #expect(report.unmatchedVisualElements.count == 1)
        #expect(report.unmatchedAccessibilityNodes.count == 1)
        #expect(report.unmatchedVisualElements.first?.type == "icon")
        #expect(report.unmatchedAccessibilityNodes.first?.id.rawValue == "node_hidden")
        #expect(report.matchRate > 0.6)
    }

    @Test("StateCaptureEngine creates complete atomic snapshot")
    func testStateCaptureEngine() {
        let snapshots = [
            AccessibilityElementSnapshot(identifier: "login_btn", label: "Log In", role: "button"),
            AccessibilityElementSnapshot(identifier: "username_txt", label: "Username", role: "textField")
        ]

        let state = StateCaptureEngine.captureState(
            templateName: "LoginForm",
            appearance: "dark",
            scale: 3.0,
            snapshots: snapshots
        )

        #expect(state.target == "LoginForm")
        #expect(state.appearance == "dark")
        #expect(state.scale == 3.0)
        #expect(state.accessibilityHierarchy.count == 2)
        #expect(state.visualElements.count == 2)
        #expect(state.correlation.matchedPairs.count == 2)
    }

    @Test("InteractionEngine validates security and executes allowlisted UI actions")
    func testInteractionEngineSafetyAndExecution() {
        // 1. Safe Tap Action
        let tapAction = UIAction(kind: .activate, elementID: "save_button")
        let tapRes = InteractionEngine.performAction(tapAction)
        #expect(tapRes.success)
        #expect(tapRes.message.contains("save_button"))

        // 2. Safe Type Action
        let typeAction = UIAction(kind: .typeText, elementID: "search_bar", text: "SwiftUI navigation")
        let typeRes = InteractionEngine.performAction(typeAction)
        #expect(typeRes.success)
        #expect(typeRes.message.contains("SwiftUI navigation"))

        // 3. Prohibited Secret/Bearer Token
        let badTokenAction = UIAction(kind: .typeText, elementID: "api_input", text: "Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.token12345678")
        let badTokenRes = InteractionEngine.performAction(badTokenAction)
        #expect(!badTokenRes.success)
        #expect(badTokenRes.message.contains("sensitive token"))

        // 4. Prohibited Password Field
        let badPasswordAction = UIAction(kind: .typeText, elementID: "user_password_field", text: "MySecret123")
        let badPasswordRes = InteractionEngine.performAction(badPasswordAction)
        #expect(!badPasswordRes.success)
        #expect(badPasswordRes.message.contains("password"))

        // 5. Scroll & Swipe Actions
        let scrollAction = UIAction(kind: .scroll, direction: "down")
        #expect(InteractionEngine.performAction(scrollAction).success)

        let swipeAction = UIAction(kind: .swipe, direction: "left")
        #expect(InteractionEngine.performAction(swipeAction).success)
    }

    @Test("MCPServer executes viewlens_capture_state and viewlens_ui_perform")
    func testMCPServerCaptureAndPerform() async throws {
        let server = MCPServer()

        // 1. Capture State Tool
        let capReq = JSONRPCRequest(
            id: .string("req-cap"),
            method: "tools/call",
            params: .object([
                "name": .string("viewlens_capture_state"),
                "arguments": .object([
                    "template": .string("LoginForm"),
                    "appearance": .string("dark")
                ])
            ])
        )
        let capRespData = try #require(await server.handleRequest(capReq))
        let capJson = try #require(JSONSerialization.jsonObject(with: capRespData) as? [String: Any])
        let capResult = try #require(capJson["result"] as? [String: Any])
        #expect(capResult["isError"] as? Bool == false)

        // 2. UI Perform Tool (Safe Action)
        let performReq = JSONRPCRequest(
            id: .string("req-act"),
            method: "tools/call",
            params: .object([
                "name": .string("viewlens_ui_perform"),
                "arguments": .object([
                    "action": .string("activate"),
                    "element_id": .string("submit_button")
                ])
            ])
        )
        let actRespData = try #require(await server.handleRequest(performReq))
        let actJson = try #require(JSONSerialization.jsonObject(with: actRespData) as? [String: Any])
        let actResult = try #require(actJson["result"] as? [String: Any])
        #expect(actResult["isError"] as? Bool == false)

        // 3. UI Perform Tool (Prohibited Action)
        let badPerformReq = JSONRPCRequest(
            id: .string("req-bad-act"),
            method: "tools/call",
            params: .object([
                "name": .string("viewlens_ui_perform"),
                "arguments": .object([
                    "action": .string("type_text"),
                    "element_id": .string("account_password"),
                    "text": .string("super_secret_password")
                ])
            ])
        )
        let badActRespData = try #require(await server.handleRequest(badPerformReq))
        let badActJson = try #require(JSONSerialization.jsonObject(with: badActRespData) as? [String: Any])
        let badActResult = try #require(badActJson["result"] as? [String: Any])
        #expect(badActResult["isError"] as? Bool == true)
    }
}
