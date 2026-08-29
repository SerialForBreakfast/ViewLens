import Foundation
import Testing
@testable import ViewLensKit

@Suite("Remote MCP HTTP Transport & Authorization Tests (MCP-18.6, MCP-18.7)")
struct RemoteTransportTests {
    @Test("HTTP transport handles valid JSON-RPC POST request")
    func handlesValidJSONRPCRequest() async throws {
        let server = MCPServer()
        let transport = HTTPTransport(server: server)

        let requestBody = """
        {
          "jsonrpc": "2.0",
          "id": 1,
          "method": "tools/list",
          "params": {}
        }
        """

        let request = HTTPTransportRequest(
            method: "POST",
            path: "/mcp",
            headers: ["Content-Type": "application/json"],
            body: Data(requestBody.utf8)
        )

        let response = await transport.handle(request: request)
        #expect(response.statusCode == 200)

        let json = try #require(JSONSerialization.jsonObject(with: response.body) as? [String: Any])
        #expect(json["jsonrpc"] as? String == "2.0")
        #expect(json["result"] != nil)
    }

    @Test("HTTP transport serves SSE streaming channel")
    func servesSSEStreamChannel() async {
        let transport = HTTPTransport()
        let request = HTTPTransportRequest(method: "GET", path: "/events")
        let response = await transport.handle(request: request)

        #expect(response.statusCode == 200)
        #expect(response.headers["Content-Type"] == "text/event-stream")
        #expect(response.bodyString.contains("event: open"))
    }

    @Test("Rejects unauthorized remote request when validator is configured")
    func rejectsUnauthorizedRequest() async {
        let validator = RemoteAuthorizationValidator(preSharedSecret: "secret-token-123")
        let transport = HTTPTransport(authValidator: validator)

        let request = HTTPTransportRequest(
            method: "POST",
            path: "/mcp",
            headers: [:],
            body: Data("{\"jsonrpc\":\"2.0\",\"id\":1,\"method\":\"tools/list\"}".utf8)
        )

        let response = await transport.handle(request: request)
        #expect(response.statusCode == 401)
        #expect(response.bodyString.contains("Missing required 'Authorization: Bearer <token>' header"))
    }

    @Test("Accepts authorized remote request with valid bearer token")
    func acceptsAuthorizedRequest() async throws {
        let validator = RemoteAuthorizationValidator(preSharedSecret: "secret-token-123")
        let transport = HTTPTransport(authValidator: validator)

        let request = HTTPTransportRequest(
            method: "POST",
            path: "/mcp",
            headers: ["Authorization": "Bearer secret-token-123"],
            body: Data("{\"jsonrpc\":\"2.0\",\"id\":2,\"method\":\"tools/list\"}".utf8)
        )

        let response = await transport.handle(request: request)
        #expect(response.statusCode == 200)
    }

    @Test("Rejects request with insufficient scope")
    func rejectsInsufficientScope() throws {
        let validator = RemoteAuthorizationValidator()
        let token = "readonly-token"
        let claims = RemoteAuthClaims(
            tenantId: "t1",
            userId: "u1",
            audience: "viewlens://remote-service",
            scopes: [.readAudit]
        )
        validator.registerMockToken(token, claims: claims)

        #expect(throws: RemoteAuthError.insufficientScope(required: .executeFlow)) {
            _ = try validator.validate(
                headers: ["Authorization": "Bearer \(token)"],
                requiredScope: .executeFlow
            )
        }
    }
}
