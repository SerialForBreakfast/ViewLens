import Foundation
import ArgumentParser
import ViewLensKit

struct MCPCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "mcp",
        abstract: "Starts the ViewLens Model Context Protocol (MCP) server over standard input/output (stdio)."
    )

    func run() async throws {
        let server = MCPServer()
        await server.start()
    }
}
