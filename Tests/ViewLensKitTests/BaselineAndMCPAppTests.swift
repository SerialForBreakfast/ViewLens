import Testing
import Foundation
@testable import ViewLensKit

@Suite("Visual Baseline Drift, Region Masks, Approval & Interactive MCP App Tests (M17.9, M17.10, M18.1-M18.5)")
struct BaselineAndMCPAppTests {

    @Test("BaselineVerifier evaluates visual drift and applies region masks")
    func testBaselineVerifierWithMasks() {
        let mask = RegionMask(
            id: "status_bar_clock",
            boundingBox: BoundingBox(x: 0.05, y: 0.01, width: 0.2, height: 0.03),
            reason: "Dynamic clock timestamp"
        )

        let report = BaselineVerifier.evaluateDrift(
            templateName: "DashboardView",
            baselinePath: "Baselines/Dashboard_ref.png",
            currentPath: "Current/Dashboard_cur.png",
            masks: [mask],
            rawSSIM: 0.94,
            threshold: 0.95
        )

        // Raw SSIM 0.94 < threshold 0.95, but with mask bonus maskedSSIM reaches 0.96
        #expect(report.overallSSIM == 0.94)
        #expect(report.maskedSSIM >= 0.95)
        #expect(!report.hasMaterialDrift)
        #expect(report.appliedMasks.count == 1)
    }

    @Test("BaselineVerifier processes human approval and rejection records")
    func testBaselineVerifierApproval() {
        let approved = BaselineVerifier.processApproval(
            templateName: "LoginForm",
            baselinePath: "Baselines/Login_ref.png",
            approved: true,
            approvedBy: "reviewer1"
        )
        #expect(approved.status == .approved)
        #expect(approved.approvedBy == "reviewer1")

        let rejected = BaselineVerifier.processApproval(
            templateName: "LoginForm",
            baselinePath: "Baselines/Login_ref.png",
            approved: false,
            approvedBy: "reviewer2"
        )
        #expect(rejected.status == .rejected)
        #expect(rejected.approvedBy == "reviewer2")
    }

    @Test("MCPAppRenderer produces self-contained accessible HTML review application")
    func testMCPAppRendererHTML() {
        let html = MCPAppRenderer.renderAppHTML(
            reviewID: "rev-123",
            templateName: "CheckoutScreen",
            overallStatus: "Passed",
            passedCount: 12,
            failedCount: 0
        )

        #expect(html.contains("<!DOCTYPE html>"))
        #expect(html.contains("ViewLens Review App — CheckoutScreen"))
        #expect(html.contains("role=\"tablist\""))
        #expect(html.contains("role=\"tree\""))
        #expect(html.contains("Touch Target Evaluation"))
        #expect(html.contains("Contrast Ratio"))
    }

    @Test("MCPServer executes baseline approval tool and serves ui://viewlens/review resource")
    func testMCPServerBaselineAndUIApp() async throws {
        let server = MCPServer()

        // 1. Test baseline approve tool
        let approveReq = try JSONDecoder().decode(JSONRPCRequest.self, from: Data("""
        {
          "jsonrpc": "2.0",
          "id": 101,
          "method": "tools/call",
          "params": {
            "name": "viewlens_baseline_approve",
            "arguments": {
              "template": "LoginForm",
              "baseline_path": "Baselines/Login_ref.png",
              "approved": true,
              "approved_by": "lead_designer"
            },
            "_meta": {
              "io.modelcontextprotocol/protocolVersion": "2026-07-28",
              "io.modelcontextprotocol/clientCapabilities": {}
            }
          }
        }
        """.utf8))
        let approveData = try #require(await server.handleRequest(approveReq))
        let approveJson = try #require(JSONSerialization.jsonObject(with: approveData) as? [String: Any])
        let approveRes = try #require(approveJson["result"] as? [String: Any])
        #expect(approveRes["isError"] as? Bool == false)

        // 2. Test reading ui://viewlens/review resource
        let readReq = try JSONDecoder().decode(JSONRPCRequest.self, from: Data("""
        {
          "jsonrpc": "2.0",
          "id": 102,
          "method": "resources/read",
          "params": {
            "uri": "ui://viewlens/review/rev-456",
            "_meta": {
              "io.modelcontextprotocol/protocolVersion": "2026-07-28",
              "io.modelcontextprotocol/clientCapabilities": {}
            }
          }
        }
        """.utf8))
        let readData = try #require(await server.handleRequest(readReq))
        let readJson = try #require(JSONSerialization.jsonObject(with: readData) as? [String: Any])
        let readRes = try #require(readJson["result"] as? [String: Any])
        let contents = try #require(readRes["contents"] as? [[String: Any]])
        #expect(contents.first?["mimeType"] as? String == "text/html")
        #expect(contents.first?["text"] != nil)
    }
}
