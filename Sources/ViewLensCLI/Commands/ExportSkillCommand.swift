import Foundation
import ArgumentParser
import ViewLensKit

struct ExportSkillCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "export-skill",
        abstract: "Exports the ViewLens AI Agent Skill Playbook (ViewLensSkill.md / SKILL.md) for Claude Code, Cursor, Windsurf, and Antigravity.",
        aliases: ["skill"]
    )

    @Option(name: .long, help: "Output file path (e.g. ViewLensSkill.md or .agents/skills/viewlens/SKILL.md)")
    var output: String?

    @Option(name: .long, help: "Target agent framework to install: agents, claude, cursor, or all")
    var target: String?

    @Flag(name: .long, help: "Print skill markdown to stdout")
    var printToStdout: Bool = false

    func run() async throws {
        let markdown = SkillGenerator.generateSkillMarkdown()

        if printToStdout {
            print(markdown)
            return
        }

        let repoRoot = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)

        if let customOut = output {
            let outURL = URL(fileURLWithPath: (customOut as NSString).expandingTildeInPath)
            let parentDir = outURL.deletingLastPathComponent()
            try? FileManager.default.createDirectory(at: parentDir, withIntermediateDirectories: true)
            try markdown.write(to: outURL, atomically: true, encoding: .utf8)
            print("✅ Exported ViewLens Agent Skill to: \(customOut)")
            return
        }

        if let targetName = target?.lowercased() {
            switch targetName {
            case "agents":
                let dest = repoRoot.appendingPathComponent(".agents/skills/viewlens/SKILL.md")
                try? FileManager.default.createDirectory(at: dest.deletingLastPathComponent(), withIntermediateDirectories: true)
                try markdown.write(to: dest, atomically: true, encoding: .utf8)
                print("✅ Exported Agent Skill to: .agents/skills/viewlens/SKILL.md")

            case "claude":
                let dest = repoRoot.appendingPathComponent(".claude/skills/viewlens/SKILL.md")
                try? FileManager.default.createDirectory(at: dest.deletingLastPathComponent(), withIntermediateDirectories: true)
                try markdown.write(to: dest, atomically: true, encoding: .utf8)
                print("✅ Exported Claude Code Skill to: .claude/skills/viewlens/SKILL.md")

            case "cursor":
                let dest = repoRoot.appendingPathComponent(".cursor/rules/viewlens.mdc")
                try? FileManager.default.createDirectory(at: dest.deletingLastPathComponent(), withIntermediateDirectories: true)
                try markdown.write(to: dest, atomically: true, encoding: .utf8)
                print("✅ Exported Cursor Rule to: .cursor/rules/viewlens.mdc")

            case "all":
                let paths = [
                    repoRoot.appendingPathComponent("ViewLensSkill.md"),
                    repoRoot.appendingPathComponent(".agents/skills/viewlens/SKILL.md"),
                    repoRoot.appendingPathComponent(".claude/skills/viewlens/SKILL.md"),
                    repoRoot.appendingPathComponent(".cursor/rules/viewlens.mdc")
                ]
                for p in paths {
                    try? FileManager.default.createDirectory(at: p.deletingLastPathComponent(), withIntermediateDirectories: true)
                    try? markdown.write(to: p, atomically: true, encoding: .utf8)
                }
                print("✅ Exported ViewLens Skill across all agent destinations (.agents, .claude, .cursor, and ViewLensSkill.md).")

            default:
                let dest = repoRoot.appendingPathComponent("ViewLensSkill.md")
                try markdown.write(to: dest, atomically: true, encoding: .utf8)
                print("✅ Exported ViewLens Agent Skill to: ViewLensSkill.md")
            }
            return
        }

        // Default export: Write both ViewLensSkill.md at root and .agents/skills/viewlens/SKILL.md
        let rootFile = repoRoot.appendingPathComponent("ViewLensSkill.md")
        let agentsFile = repoRoot.appendingPathComponent(".agents/skills/viewlens/SKILL.md")

        try? FileManager.default.createDirectory(at: agentsFile.deletingLastPathComponent(), withIntermediateDirectories: true)
        try markdown.write(to: rootFile, atomically: true, encoding: .utf8)
        try markdown.write(to: agentsFile, atomically: true, encoding: .utf8)

        print("✅ Exported ViewLens Agent Skill to:")
        print("   • ViewLensSkill.md (Workspace root)")
        print("   • .agents/skills/viewlens/SKILL.md (Agent skill folder)")
    }
}
