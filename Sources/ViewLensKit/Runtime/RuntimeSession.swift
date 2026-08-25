import Foundation

/// Type of runtime destination for UI inspection.
public enum RuntimeDestinationKind: String, Codable, Sendable, Equatable, Hashable {
    case macOSApp = "macos_app"
    case simulator = "simulator"
}

/// A target device, simulator, or application destination where UI can be inspected.
public struct RuntimeDestination: Codable, Sendable, Equatable, Hashable, Identifiable {
    public let id: String
    public let name: String
    public let kind: RuntimeDestinationKind
    public let platform: String
    public let osVersion: String?
    public let isAvailable: Bool
    public let isBooted: Bool

    public init(
        id: String,
        name: String,
        kind: RuntimeDestinationKind,
        platform: String = "iOS",
        osVersion: String? = nil,
        isAvailable: Bool = true,
        isBooted: Bool = false
    ) {
        self.id = id
        self.name = name
        self.kind = kind
        self.platform = platform
        self.osVersion = osVersion
        self.isAvailable = isAvailable
        self.isBooted = isBooted
    }
}

/// Lifecycle state of an active runtime review session.
public enum RuntimeSessionState: String, Codable, Sendable, Equatable, Hashable {
    case active
    case paused
    case closed
    case expired
}

/// An isolated, expiring runtime review session with a destination.
public struct RuntimeSession: Codable, Sendable, Equatable, Identifiable {
    public let id: String
    public let destination: RuntimeDestination
    public let workspaceRoot: String
    public let bundleIdentifier: String?
    public let createdAt: Date
    public var expiresAt: Date
    public var state: RuntimeSessionState

    public init(
        id: String = "session_\(UUID().uuidString.prefix(12).lowercased())",
        destination: RuntimeDestination,
        workspaceRoot: String,
        bundleIdentifier: String? = nil,
        createdAt: Date = Date(),
        ttlSeconds: TimeInterval = 1800,
        state: RuntimeSessionState = .active
    ) {
        self.id = id
        self.destination = destination
        self.workspaceRoot = workspaceRoot
        self.bundleIdentifier = bundleIdentifier
        self.createdAt = createdAt
        self.expiresAt = createdAt.addingTimeInterval(ttlSeconds)
        self.state = state
    }

    public func isExpired(at date: Date = Date()) -> Bool {
        state == .expired || date >= expiresAt
    }
}

/// Actor managing active runtime sessions with automatic TTL expiration and lease renewal.
public actor RuntimeSessionStore {
    public static let defaultTTL: TimeInterval = 1800 // 30 minutes

    private var sessions: [String: RuntimeSession] = [:]

    public init() {}

    public func createSession(
        destination: RuntimeDestination,
        workspaceRoot: String,
        bundleIdentifier: String? = nil,
        ttlSeconds: TimeInterval = defaultTTL
    ) -> RuntimeSession {
        let session = RuntimeSession(
            destination: destination,
            workspaceRoot: workspaceRoot,
            bundleIdentifier: bundleIdentifier,
            ttlSeconds: ttlSeconds
        )
        sessions[session.id] = session
        return session
    }

    public func getSession(id: String) -> RuntimeSession? {
        guard var session = sessions[id] else { return nil }
        if session.isExpired() {
            session.state = .expired
            sessions[id] = session
        }
        return session
    }

    public func renewLease(id: String, extensionSeconds: TimeInterval = defaultTTL) -> RuntimeSession? {
        guard var session = sessions[id], session.state == .active else { return nil }
        session.expiresAt = Date().addingTimeInterval(extensionSeconds)
        sessions[id] = session
        return session
    }

    public func closeSession(id: String) -> RuntimeSession? {
        guard var session = sessions[id] else { return nil }
        session.state = .closed
        sessions[id] = session
        return session
    }

    public func allActiveSessions() -> [RuntimeSession] {
        let now = Date()
        return sessions.values.filter { $0.state == .active && !($0.isExpired(at: now)) }
    }
}
