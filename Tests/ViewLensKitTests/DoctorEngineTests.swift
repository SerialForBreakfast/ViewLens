import Testing
import Foundation
@testable import ViewLensKit

// Serialized: several tests below stub the shared `DoctorEngine.runShellCommand` seam, which
// is process-global mutable state and would otherwise race under Swift Testing's default
// parallel execution.
@Suite("DoctorEngine Diagnostics Tests (MCP-15.12)", .serialized)
struct DoctorEngineTests {

    @Test("Model checks match legacy 3-check shape")
    func testModelChecksMatchLegacyBehavior() async {
        // A nonexistent custom path still falls back to bundled/env model discovery (existing
        // ModelLocator behavior), so this only verifies the check *shape*, not pass/fail.
        let report = await DoctorEngine.run(
            customModelPath: "/private/tmp/viewlens-doctor-test-nonexistent.mlpackage",
            categories: [.model]
        )
        let names = Set(report.checks.map(\.name))
        #expect(names == ["model_found", "model_size", "model_loads"])
    }

    @Test("Categories filter applies only requested checks")
    func testCategoriesFilterAppliesOnlyRequestedChecks() async {
        let report = await DoctorEngine.run(categories: [.model])
        #expect(!report.checks.contains { $0.name.hasPrefix("xcode_") })
        #expect(!report.checks.contains { $0.name.hasPrefix("simulator_") })
        #expect(!report.checks.contains { $0.name.hasPrefix("accessibility_") })
        #expect(!report.checks.contains { $0.name == "destination_resolved" })
        #expect(!report.checks.contains { $0.name == "fixture_app_ready" })
    }

    @Test("Permission checks never throw or hang")
    func testPermissionChecksNeverThrowOrHang() async {
        let start = DispatchTime.now()
        let checks = DoctorEngine.permissionChecks()
        let elapsedSeconds = Double(DispatchTime.now().uptimeNanoseconds - start.uptimeNanoseconds) / 1_000_000_000.0
        #expect(elapsedSeconds < 2.0)
        #expect(checks.contains { $0.name == "automation_permission" && $0.status == "skipped" })
    }

    @Test("Xcode and simulator checks degrade gracefully when tooling is missing")
    func testXcodeAndSimulatorChecksDegradeGracefullyWhenToolingMissing() async {
        let original = DoctorEngine.runShellCommand
        defer { DoctorEngine.runShellCommand = original }
        DoctorEngine.runShellCommand = { _, _ in (exitCode: 1, stdout: "") }

        let xcode = DoctorEngine.xcodeChecks()
        #expect(xcode.allSatisfy { $0.status == "failed" })

        let simulator = DoctorEngine.simulatorChecks()
        #expect(simulator.allSatisfy { $0.status == "failed" })
    }

    @Test("Only model and destination failures block readiness")
    func testOnlyModelAndDestinationFailuresBlockReadiness() async {
        let original = DoctorEngine.runShellCommand
        defer { DoctorEngine.runShellCommand = original }
        // Force every shelled-out probe (xcode, simulator, signing) to fail.
        DoctorEngine.runShellCommand = { _, _ in (exitCode: 1, stdout: "") }

        let report = await DoctorEngine.run(
            workspaceRoot: "/private/tmp/viewlens-doctor-test-workspace",
            categories: [.model, .xcode, .simulator, .signing, .destination]
        )

        // Model resolves via the real ModelLocator, which may or may not find a model on this
        // machine; destination always resolves (macOS host is always present per
        // DestinationDiscovery), so the only way this test's forced xcode/simulator/signing
        // failures could flip status to not_ready is if they were wrongly load-bearing.
        let modelFailed = report.checks.contains { $0.name == "model_found" && $0.status == "failed" }
        if !modelFailed {
            #expect(report.status == "ready")
        }
        #expect(report.checks.contains { $0.name == "xcode_installed" && $0.status == "failed" })
        #expect(report.checks.contains { $0.name == "signing_identity" && $0.status == "failed" })
    }

    @Test("Simulator checks parse a well-formed simctl JSON payload")
    func testSimulatorChecksParsesWellFormedPayload() async {
        let original = DoctorEngine.runShellCommand
        defer { DoctorEngine.runShellCommand = original }
        DoctorEngine.runShellCommand = { executable, arguments in
            guard arguments.contains("simctl") else { return (1, "") }
            let json = """
            {"devices":{"com.apple.CoreSimulator.SimRuntime.iOS-18-0":[{"isAvailable":true,"name":"iPhone 16 Pro"}]}}
            """
            return (0, json)
        }

        let checks = DoctorEngine.simulatorChecks()
        #expect(checks.contains { $0.name == "simulator_runtime_available" && $0.status == "confirmed" })
        #expect(checks.contains { $0.name == "simulator_device_available" && $0.status == "confirmed" })
    }

    @Test("Signing check is skipped without a workspace root")
    func testSigningChecksSkippedWithoutWorkspaceRoot() {
        let checks = DoctorEngine.signingChecks(workspaceRoot: nil)
        #expect(checks.first?.status == "skipped")
    }

    @Test("Fixture checks confirm the registered FixtureFlow* templates")
    func testFixtureChecksConfirmRegisteredTemplates() async {
        let checks = await DoctorEngine.fixtureChecks()
        #expect(checks.first?.name == "fixture_app_ready")
        #expect(checks.first?.status == "confirmed")
    }
}
