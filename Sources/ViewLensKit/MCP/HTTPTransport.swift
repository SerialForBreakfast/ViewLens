import Foundation

/// HTTP/SSE Request representation for remote MCP transports.
public struct HTTPTransportRequest: Sendable {
    public let method: String
    public let path: String
    public let headers: [String: String]
    public let body: Data?

    public init(
        method: String = "POST",
        path: String = "/mcp",
        headers: [String: String] = [:],
        body: Data? = nil
    ) {
        self.method = method
        self.path = path
        self.headers = headers
        self.body = body
    }
}

/// HTTP Response representation returned by remote MCP transports.
public struct HTTPTransportResponse: Sendable, Equatable {
    public let statusCode: Int
    public let headers: [String: String]
    public let body: Data

    public init(
        statusCode: Int,
        headers: [String: String] = ["Content-Type": "application/json"],
        body: Data
    ) {
        self.statusCode = statusCode
        self.headers = headers
        self.body = body
    }

    public var bodyString: String {
        String(decoding: body, as: UTF8.self)
    }
}

/// A pure-Swift HTTP & Server-Sent Events (SSE) transport engine for remote MCP interactions.
public final class HTTPTransport: @unchecked Sendable {
    public let server: MCPServer
    public let authValidator: RemoteAuthorizationValidator?
    private let lock = NSLock()
    private var sseClients: [String: @Sendable (Data) -> Void] = [:]

    public init(
        server: MCPServer = MCPServer(),
        authValidator: RemoteAuthorizationValidator? = nil
    ) {
        self.server = server
        self.authValidator = authValidator
    }

    /// Handles an incoming HTTP request, enforcing authentication and routing to JSON-RPC handlers.
    public func handle(request: HTTPTransportRequest) async -> HTTPTransportResponse {
        // 1. Enforce Authentication if validator is configured
        var claims: RemoteAuthClaims?
        if let validator = authValidator {
            do {
                claims = try validator.validate(headers: request.headers)
            } catch let error as RemoteAuthError {
                let errorPayload: [String: Any] = [
                    "jsonrpc": "2.0",
                    "error": [
                        "code": error.errorCode,
                        "message": error.errorMessage
                    ]
                ]
                let data = (try? JSONSerialization.data(withJSONObject: errorPayload)) ?? Data()
                return HTTPTransportResponse(statusCode: 401, body: data)
            } catch {
                let errorPayload: [String: Any] = [
                    "jsonrpc": "2.0",
                    "error": [
                        "code": -32000,
                        "message": "Authorization error: \(error.localizedDescription)"
                    ]
                ]
                let data = (try? JSONSerialization.data(withJSONObject: errorPayload)) ?? Data()
                return HTTPTransportResponse(statusCode: 401, body: data)
            }
        }

        // 2. Handle SSE Subscription channel
        if request.method.uppercased() == "GET" && (request.path == "/events" || request.path == "/sse") {
            let streamHeaders = [
                "Content-Type": "text/event-stream",
                "Cache-Control": "no-cache",
                "Connection": "keep-alive"
            ]
            let greeting = "event: open\ndata: {\"status\":\"connected\",\"server\":\"ViewLens\"}\n\n"
            return HTTPTransportResponse(statusCode: 200, headers: streamHeaders, body: Data(greeting.utf8))
        }

        // 3. Handle JSON-RPC POST request
        guard request.method.uppercased() == "POST" else {
            let errorPayload = "{\"error\":\"Method Not Allowed. Use POST for JSON-RPC or GET /events for SSE\"}"
            return HTTPTransportResponse(statusCode: 405, body: Data(errorPayload.utf8))
        }

        guard let body = request.body, !body.isEmpty else {
            let errorPayload = "{\"jsonrpc\":\"2.0\",\"error\":{\"code\":-32700,\"message\":\"Parse error: Empty request body\"}}"
            return HTTPTransportResponse(statusCode: 400, body: Data(errorPayload.utf8))
        }

        // Execute via MCPServer
        if let responseData = await server.handleRequestData(body) {
            return HTTPTransportResponse(statusCode: 200, body: responseData)
        } else {
            // Notification or fire-and-forget
            return HTTPTransportResponse(statusCode: 204, headers: [:], body: Data())
        }
    }

    /// Formats a JSON-RPC notification into an SSE frame.
    public static func formatSSEEvent(data: Data, eventName: String = "message") -> Data {
        let text = String(decoding: data, as: UTF8.self)
        let frame = "event: \(eventName)\ndata: \(text)\n\n"
        return Data(frame.utf8)
    }
}
