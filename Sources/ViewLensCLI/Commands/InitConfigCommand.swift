import Foundation
import ArgumentParser
import ViewLensKit

struct InitConfigCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "init-config",
        abstract: "Generates a starter .viewlens.json configuration file for git hooks and CI quality gates."
    )

    @Option(name: .long, help: "Output filename (default: .viewlens.json)")
    var output: String = ".viewlens.json"

    @Flag(name: .long, help: "Print configuration to stdout without writing to disk")
    var dryRun: Bool = false

    func run() async throws {
        let config = ViewLensConfig()
        let json = config.toJSONString()

        if dryRun {
            print(json)
            return
        }

        let outURL = URL(fileURLWithPath: output)
        try json.write(to: outURL, atomically: true, encoding: .utf8)
        print("✅ Generated starter configuration at: \(output)")
    }
}
