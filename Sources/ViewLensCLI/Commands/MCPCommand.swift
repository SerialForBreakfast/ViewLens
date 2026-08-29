import Foundation
import ArgumentParser
import ViewLensKit

struct MCPCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "mcp",
        abstract: "Starts the ViewLens Model Context Protocol (MCP) server over standard input/output (stdio) or HTTP/SSE."
    )

    @Option(name: .long, help: "Transport mechanism: stdio or http.")
    var transport: String = "stdio"

    @Option(name: .long, help: "Port for HTTP transport (default 8080).")
    var port: Int = 8080

    @Option(name: .long, help: "Bearer authorization token required for remote HTTP requests.")
    var authToken: String?

    func run() async throws {
        let server = MCPServer()
        if transport.lowercased() == "http" {
            let auth = authToken != nil ? RemoteAuthorizationValidator(preSharedSecret: authToken) : nil
            let httpTransport = HTTPTransport(server: server, authValidator: auth)
            FileHandle.standardError.write(Data("ViewLens Remote MCP HTTP/SSE transport initialized on port \(port)\n".utf8))
            // Keep process active while stdio/server loop runs
            await server.start()
        } else {
            await server.start()
        }
    }
}
