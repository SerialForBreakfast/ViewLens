import Foundation

/// Security policy and validator for launch descriptors and process execution.
public enum LaunchSecurityValidator {
    /// Allowlist of permissible environment variable keys.
    public static let allowedEnvironmentKeys: Set<String> = [
        "VIEWLENS_INSPECTION_MODE",
        "UI_TESTING",
        "OS_ACTIVITY_MODE",
        "NSUnbufferedIO",
        "DYLD_PRINT_STATISTICS",
        "SWIFT_DETERMINISTIC_HASHING"
    ]

    /// Sanitizes an environment map to ensure only allowlisted keys are passed to processes.
    public static func sanitizeEnvironment(_ env: [String: String]) -> [String: String] {
        env.filter { allowedEnvironmentKeys.contains($0.key) }
    }

    /// Validates that a workspace root path is well-formed and exists.
    public static func validateWorkspaceRoot(_ path: String) -> Bool {
        var isDir: ObjCBool = false
        return FileManager.default.fileExists(atPath: path, isDirectory: &isDir) && isDir.boolValue
    }
}

/// A strongly typed, scoped launch configuration for target applications.
public struct LaunchDescriptor: Codable, Sendable, Equatable {
    public let workspaceRoot: String
    public let scheme: String?
    public let configuration: String
    public let destination: RuntimeDestination
    public let bundleIdentifier: String
    public let launchArguments: [String]
    public let environment: [String: String]

    public init(
        workspaceRoot: String,
        scheme: String? = nil,
        configuration: String = "Debug",
        destination: RuntimeDestination,
        bundleIdentifier: String,
        launchArguments: [String] = [],
        environment: [String: String] = [:]
    ) {
        self.workspaceRoot = workspaceRoot
        self.scheme = scheme
        self.configuration = configuration
        self.destination = destination
        self.bundleIdentifier = bundleIdentifier
        self.launchArguments = launchArguments
        self.environment = LaunchSecurityValidator.sanitizeEnvironment(environment)
    }
}

/// Result of an application launch execution.
public struct LaunchResult: Codable, Sendable, Equatable {
    public let bundleIdentifier: String
    public let destinationID: String
    public let pid: Int32
    public let status: String
    public let launchedAt: Date

    public init(
        bundleIdentifier: String,
        destinationID: String,
        pid: Int32 = 1000 + Int32.random(in: 1...8999),
        status: String = "running",
        launchedAt: Date = Date()
    ) {
        self.bundleIdentifier = bundleIdentifier
        self.destinationID = destinationID
        self.pid = pid
        self.status = status
        self.launchedAt = launchedAt
    }
}

/// Backend abstraction over application launch lifecycle and screenshot capture, allowing a
/// real process-driven implementation (``ProcessController``) and a deterministic
/// ``FakeRuntimeBackend`` for tests to share the same call sites (MCP-15.14).
public protocol RuntimeBackend: Sendable {
    func launch(descriptor: LaunchDescriptor) async -> LaunchResult
    func status(for bundleIdentifier: String) async -> LaunchResult?
    func terminate(bundleIdentifier: String) async -> Bool
    func allLaunches() async -> [LaunchResult]
    /// Captures a live screenshot from the target destination. Returns `nil` when the backend
    /// has no real capture path for that destination kind (e.g. macOS host capture, which needs
    /// ScreenCaptureKit entitlements out of scope here) rather than fabricating image data.
    func captureScreenshot(destinationID: String) async -> Data?
}

/// Controller managing application lifecycles under strict scope boundaries.
public actor ProcessController: RuntimeBackend {
    private var activeLaunches: [String: LaunchResult] = [:]

    public init() {}

    /// Launches a target application matching the launch descriptor.
    ///
    /// Deliberately synthetic (fabricated pid, no real `xcodebuild`/`simctl` invocation) —
    /// real launch orchestration is out of scope for MCP-15.14; only screenshot capture below
    /// is backed by a real process.
    public func launch(descriptor: LaunchDescriptor) -> LaunchResult {
        let result = LaunchResult(
            bundleIdentifier: descriptor.bundleIdentifier,
            destinationID: descriptor.destination.id,
            status: "running"
        )
        activeLaunches[descriptor.bundleIdentifier] = result
        return result
    }

    /// Queries the status of an active launch by bundle identifier.
    public func status(for bundleIdentifier: String) -> LaunchResult? {
        activeLaunches[bundleIdentifier]
    }

    /// Terminates an active application launch.
    public func terminate(bundleIdentifier: String) -> Bool {
        activeLaunches.removeValue(forKey: bundleIdentifier) != nil
    }

    /// All running launches.
    public func allLaunches() -> [LaunchResult] {
        Array(activeLaunches.values)
    }

    /// Captures a real PNG screenshot from a simulator via `xcrun simctl io <id> screenshot`.
    ///
    /// `destinationID` must be an identifier `simctl` itself recognizes — a device UDID, the
    /// literal `"booted"`, or a unique device name — not one of `DestinationDiscovery`'s
    /// synthetic IDs (e.g. `"sim_iphone_16_pro"`), which have no corresponding real simulator
    /// on disk. Returns `nil` for the macOS host destination (`"macos_host"`, real macOS screen
    /// capture needs ScreenCaptureKit entitlements, out of scope here) or on any `simctl`
    /// failure — never a fabricated image.
    public func captureScreenshot(destinationID: String) async -> Data? {
        guard destinationID != "macos_host" else { return nil }

        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("viewlens-screenshot-\(UUID().uuidString).png")
        defer { try? FileManager.default.removeItem(at: tempURL) }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/xcrun")
        process.arguments = ["simctl", "io", destinationID, "screenshot", tempURL.path]

        do {
            try process.run()
            process.waitUntilExit()
            guard process.terminationStatus == 0 else { return nil }
            return try Data(contentsOf: tempURL)
        } catch {
            return nil
        }
    }
}
