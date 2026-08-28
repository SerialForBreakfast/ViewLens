import Testing
import Foundation
@testable import ViewLensKit

/// Gated integration suite exercising the *real* ``ProcessController`` screenshot capture path
/// against a genuinely booted simulator. Skipped by default so `swift test` stays fast and
/// simulator-independent; opt in with:
///
///   VIEWLENS_ENABLE_INTEGRATION_TESTS=1 swift test --filter RuntimeBackendIntegrationTests
@Suite(
    "Live Simulator Capture (gated, MCP-15.14)",
    .enabled(if: ProcessInfo.processInfo.environment["VIEWLENS_ENABLE_INTEGRATION_TESTS"] == "1")
)
struct RuntimeBackendIntegrationTests {

    /// Finds a currently-booted simulator's UDID via `xcrun simctl list devices booted --json`,
    /// or returns `nil` if none is booted.
    private func bootedSimulatorUDID() -> String? {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/xcrun")
        process.arguments = ["simctl", "list", "devices", "booted", "--json"]
        let pipe = Pipe()
        process.standardOutput = pipe
        guard (try? process.run()) != nil else { return nil }
        process.waitUntilExit()
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        guard let parsed = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let devicesByRuntime = parsed["devices"] as? [String: [[String: Any]]] else {
            return nil
        }
        for devices in devicesByRuntime.values {
            if let udid = devices.first(where: { ($0["state"] as? String) == "Booted" })?["udid"] as? String {
                return udid
            }
        }
        return nil
    }

    @Test("Real ProcessController captures a non-empty PNG screenshot from a booted simulator")
    func testRealScreenshotCapture() async throws {
        guard let udid = bootedSimulatorUDID() else {
            // Diagnostic skip rather than a failure: no simulator is booted on this machine.
            return
        }

        let controller = ProcessController()
        let screenshot = try #require(await controller.captureScreenshot(destinationID: udid))
        #expect(!screenshot.isEmpty)
        // PNG magic bytes.
        #expect(screenshot.starts(with: [0x89, 0x50, 0x4E, 0x47]))
    }

    @Test("Real ProcessController returns nil for the macOS host destination")
    func testRealScreenshotCaptureUnavailableForMacOSHost() async {
        let controller = ProcessController()
        let screenshot = await controller.captureScreenshot(destinationID: "macos_host")
        #expect(screenshot == nil)
    }
}
