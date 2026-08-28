import Foundation
import ArgumentParser
import ViewLensKit

struct DoctorCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "doctor",
        abstract: "Reports environment readiness: model, Xcode, simulator, permissions, signing, destination, and fixture checks."
    )

    @Option(name: .long, help: "Explicit path to CoreML model (overrides standard discovery)")
    var model: String?

    @Flag(name: .long, help: "Output results as structured JSON")
    var json: Bool = false

    @Flag(name: .long, help: "Run only the fast model checks, skipping Xcode/simulator/permission/signing/destination/fixture probes")
    var quick: Bool = false

    func run() async throws {
        let report = await DoctorEngine.run(
            customModelPath: model,
            categories: quick ? [.model] : Set(DoctorCheckCategory.allCases)
        )
        let allPassed = report.status == "ready"
        let checks = report.checks
        let overallStatus = report.status
        let nextCommand = report.recommendedNextCommand

        if json {
            print(JSONFormatter.encode(report))
        } else {
            print("════════════════════════════════════════════════════════════════════════")
            print("🩺 ViewLens Diagnostic & Readiness Check")
            print("────────────────────────────────────────────────────────────────────────")
            for check in checks {
                let icon = check.status == "confirmed" ? "✅" : (check.status == "skipped" ? "⏭️" : "❌")
                print("  \(icon) \(check.name): \(check.detail)")
            }
            print("────────────────────────────────────────────────────────────────────────")
            print("Status: \(overallStatus == "ready" ? "✅ READY" : "❌ NOT READY")")
            print("Next:   \(nextCommand)")
            print("════════════════════════════════════════════════════════════════════════")
        }

        if !allPassed {
            Darwin.exit(2)
        }
    }
}
