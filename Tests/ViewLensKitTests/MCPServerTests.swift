import Testing
import Foundation
@testable import ViewLensKit

@Suite("Pure Swift MCP Protocol Tests")
struct MCPServerTests {
    @Test("Decodes initialize JSON-RPC request")
    func testDecodeInitialize() throws {
        let json = """
        {
          "jsonrpc": "2.0",
          "id": 1,
          "method": "initialize",
          "params": {
            "protocolVersion": "2024-11-05",
            "capabilities": {},
            "clientInfo": { "name": "claude-code", "version": "1.0" }
          }
        }
        """
        let request = try JSONDecoder().decode(JSONRPCRequest.self, from: Data(json.utf8))
        #expect(request.method == "initialize")
        #expect(request.id == .int(1))
    }

    @Test("Encodes tools/list MCP result")
    func testToolsListEncoding() throws {
        let tool = MCPTool(
            name: "viewlens_doctor",
            description: "Readiness probe",
            inputSchema: .object(["type": .string("object")])
        )
        let listResult = MCPToolsListResult(tools: [tool])
        let response = JSONRPCResponse(id: .int(2), result: listResult)

        let data = try JSONEncoder().encode(response)
        let str = String(data: data, encoding: .utf8) ?? ""
        #expect(str.contains("viewlens_doctor"))
        #expect(str.contains("2024-11-05") == false) // tool list response
        #expect(str.contains("\"jsonrpc\":\"2.0\""))
    }

    @Test("Accessibility MCP tool advertises complete level-aware schema")
    func testAccessibilityToolSchema() throws {
        let server = MCPServer()
        let data = try JSONEncoder().encode(server.defineTools())
        let json = String(decoding: data, as: UTF8.self)
        #expect(json.contains("viewlens_accessibility_audit"))
        #expect(json.contains("2.5.8 AA"))
        #expect(json.contains("4.1.2"))
        #expect(json.contains("accessibility5") || json.contains("AX5"))
        #expect(json.contains("\"AAA\""))
    }

    @Test("Accessibility MCP tool rejects invalid conformance levels")
    func testAccessibilityToolInvalidLevel() async throws {
        let json = """
        {
          "jsonrpc": "2.0",
          "id": 7,
          "method": "tools/call",
          "params": {
            "name": "viewlens_accessibility_audit",
            "arguments": { "template": "LoginForm", "wcag_level": "AAAA" }
          }
        }
        """
        let request = try JSONDecoder().decode(JSONRPCRequest.self, from: Data(json.utf8))
        let response = await MCPServer().handleRequest(request)
        let responseText = response.map { String(decoding: $0, as: UTF8.self) } ?? ""
        #expect(responseText.contains("Invalid 'wcag_level'"))
        #expect(responseText.contains("\"isError\":true"))
    }
}
