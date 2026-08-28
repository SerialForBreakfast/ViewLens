import Testing
import Foundation
@testable import ViewLensKit

@Suite("RuntimeBackend Protocol & Fake Backend Tests (MCP-15.14)")
struct RuntimeBackendTests {

    private func makeDescriptor(bundleID: String = "com.test.app") -> LaunchDescriptor {
        LaunchDescriptor(
            workspaceRoot: "/private/tmp",
            destination: RuntimeDestination(
                id: "sim_iphone_16_pro",
                name: "iPhone 16 Pro",
                kind: .simulator,
                platform: "iOS",
                osVersion: "iOS 18.0",
                isAvailable: true,
                isBooted: true
            ),
            bundleIdentifier: bundleID
        )
    }

    @Test("FakeRuntimeBackend is deterministic across launches")
    func testFakeRuntimeBackendIsDeterministic() async {
        let backend = FakeRuntimeBackend()
        let first = await backend.launch(descriptor: makeDescriptor())
        let second = await backend.launch(descriptor: makeDescriptor())
        #expect(first.pid == second.pid)
        #expect(first.pid == FakeRuntimeBackend.deterministicPid)
    }

    @Test("MCPServer accepts an injected FakeRuntimeBackend and drives it through viewlens_app_launch")
    func testMCPServerAcceptsInjectedFakeBackend() async throws {
        let backend = FakeRuntimeBackend()
        let server = MCPServer(resourceStore: MCPResourceStore(), processController: backend)

        let request = JSONRPCRequest(
            id: .string("req-launch"),
            method: "tools/call",
            params: .object([
                "name": .string("viewlens_app_launch"),
                "arguments": .object([
                    "workspace_root": .string("/private/tmp"),
                    "destination_id": .string("sim_iphone_16_pro"),
                    "bundle_identifier": .string("com.test.app")
                ])
            ])
        )
        _ = try #require(await server.handleRequest(request))
        #expect(await backend.launchCallCount == 1)
    }

    @Test("FakeRuntimeBackend can script a failed launch result")
    func testFakeRuntimeBackendCanScriptFailure() async {
        let backend = FakeRuntimeBackend()
        let failedResult = LaunchResult(bundleIdentifier: "com.test.app", destinationID: "sim_iphone_16_pro", status: "failed")
        await backend.scriptLaunch(bundleIdentifier: "com.test.app", result: failedResult)

        let result = await backend.launch(descriptor: makeDescriptor())
        #expect(result.status == "failed")
    }

    @Test("FakeRuntimeBackend returns nil screenshot when none is scripted")
    func testFakeRuntimeBackendDefaultsToNilScreenshot() async {
        let backend = FakeRuntimeBackend()
        let screenshot = await backend.captureScreenshot(destinationID: "sim_iphone_16_pro")
        #expect(screenshot == nil)
    }

    @Test("ProcessController.captureScreenshot returns nil for non-simulator destinations")
    func testProcessControllerScreenshotUnavailableForMacOSHost() async {
        let controller = ProcessController()
        let screenshot = await controller.captureScreenshot(destinationID: "macos_host")
        #expect(screenshot == nil)
    }
}
