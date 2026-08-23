import Foundation
import ArgumentParser

@main
struct ViewLensCLI: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "viewlens",
        abstract: "ViewLens — AI Agent UI Audit & Visual Linter CLI for Native Apple Platforms",
        version: "0.1.0",
        subcommands: [
            DoctorCommand.self,
            ScanCommand.self,
            BatchCommand.self,
            RenderCommand.self,
            MCPCommand.self
        ],
        defaultSubcommand: DoctorCommand.self
    )
}
