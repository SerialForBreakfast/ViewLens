import Foundation
import ArgumentParser
import ViewLensKit

struct DoctorCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "doctor",
        abstract: "Reports environment readiness: model path, file size, and CoreML cold-load warmup test."
    )

    @Option(name: .long, help: "Explicit path to CoreML model (overrides standard discovery)")
    var model: String?

    @Flag(name: .long, help: "Output results as structured JSON")
    var json: Bool = false

    func run() async throws {
        var checks: [DiagnosticCheck] = []
        var allPassed = true

        // 1. Check Model Existence
        let modelResult = ModelLocator.resolve(customPath: model)
        let resolvedURL: URL?

        switch modelResult {
        case .success(let url):
            resolvedURL = url
            checks.append(DiagnosticCheck(name: "model_found", status: "confirmed", detail: url.path))
        case .failure(let error):
            resolvedURL = nil
            allPassed = false
            checks.append(DiagnosticCheck(name: "model_found", status: "failed", detail: error.localizedDescription))
        }

        // 2. Check Model Size
        if let url = resolvedURL {
            do {
                let sizeBytes = try ModelLocator.calculateSize(at: url)
                let sizeMB = Double(sizeBytes) / (1024.0 * 1024.0)
                let formattedMB = String(format: "%.1fMB", sizeMB)

                if sizeMB <= ModelLocator.maxExpectedSizeMB && sizeMB > 0.1 {
                    checks.append(DiagnosticCheck(name: "model_size", status: "confirmed", detail: "\(formattedMB) (< \(Int(ModelLocator.maxExpectedSizeMB))MB)"))
                } else {
                    allPassed = false
                    checks.append(DiagnosticCheck(name: "model_size", status: "failed", detail: "\(formattedMB) exceeds expectation"))
                }
            } catch {
                allPassed = false
                checks.append(DiagnosticCheck(name: "model_size", status: "failed", detail: error.localizedDescription))
            }
        } else {
            checks.append(DiagnosticCheck(name: "model_size", status: "skipped", detail: "Model not found"))
        }

        // 3. Check Model Cold-Load
        if let url = resolvedURL {
            let start = DispatchTime.now()
            do {
                _ = try YOLODetector(modelURL: url)
                let end = DispatchTime.now()
                let elapsedSeconds = Double(end.uptimeNanoseconds - start.uptimeNanoseconds) / 1_000_000_000.0
                checks.append(DiagnosticCheck(name: "model_loads", status: "confirmed", detail: String(format: "Cold load: %.2fs", elapsedSeconds)))
            } catch {
                allPassed = false
                checks.append(DiagnosticCheck(name: "model_loads", status: "failed", detail: error.localizedDescription))
            }
        } else {
            checks.append(DiagnosticCheck(name: "model_loads", status: "skipped", detail: "Model not found"))
        }

        let overallStatus = allPassed ? "ready" : "not_ready"
        let nextCommand = allPassed ? "viewlens scan <image-path>" : "export VIEWLENS_MODEL_PATH=/path/to/best.mlpackage"

        let report = DoctorReport(status: overallStatus, checks: checks, recommendedNextCommand: nextCommand)

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
