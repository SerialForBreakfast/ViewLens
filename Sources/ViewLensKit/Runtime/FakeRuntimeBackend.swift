import Foundation

/// Deterministic, fully in-memory ``RuntimeBackend`` for fast unit tests (MCP-15.14).
///
/// Unlike ``ProcessController``, which fabricates a random pid on every launch, this backend
/// is deterministic and exposes call history so tests can assert on *what was requested*, not
/// just the synthetic result — the actual gap the real `ProcessController` leaves untestable.
/// Ships in the main `ViewLensKit` target (not the test target) so it is usable without
/// `@testable import`.
public actor FakeRuntimeBackend: RuntimeBackend {
    /// Fixed, non-random pid used for every scripted launch unless overridden per-bundle-id
    /// via ``scriptedLaunches``.
    public static let deterministicPid: Int32 = 9999

    public var scriptedLaunches: [String: LaunchResult] = [:]
    public var scriptedScreenshot: Data?
    public private(set) var launchCallCount = 0
    public private(set) var launchedDescriptors: [LaunchDescriptor] = []

    private var activeLaunches: [String: LaunchResult] = [:]

    public init() {}

    public func launch(descriptor: LaunchDescriptor) -> LaunchResult {
        launchCallCount += 1
        launchedDescriptors.append(descriptor)

        let result = scriptedLaunches[descriptor.bundleIdentifier] ?? LaunchResult(
            bundleIdentifier: descriptor.bundleIdentifier,
            destinationID: descriptor.destination.id,
            pid: Self.deterministicPid,
            status: "running"
        )
        activeLaunches[descriptor.bundleIdentifier] = result
        return result
    }

    public func status(for bundleIdentifier: String) -> LaunchResult? {
        activeLaunches[bundleIdentifier]
    }

    public func terminate(bundleIdentifier: String) -> Bool {
        activeLaunches.removeValue(forKey: bundleIdentifier) != nil
    }

    public func allLaunches() -> [LaunchResult] {
        Array(activeLaunches.values)
    }

    public func captureScreenshot(destinationID: String) -> Data? {
        scriptedScreenshot
    }

    /// Test helper: pre-scripts the result returned for the next ``launch(descriptor:)`` call
    /// matching `bundleIdentifier` (e.g. to simulate a launch failure).
    public func scriptLaunch(bundleIdentifier: String, result: LaunchResult) {
        scriptedLaunches[bundleIdentifier] = result
    }
}
