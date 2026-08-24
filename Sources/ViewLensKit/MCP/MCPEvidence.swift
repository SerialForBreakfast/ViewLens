import Foundation

/// Stable machine-readable failures returned inside modern tool evidence.
public enum MCPToolErrorCode: String, Codable, CaseIterable, Sendable {
    case invalidInput = "invalid_input"
    case unsupportedCapability = "unsupported_capability"
    case unavailableEvidence = "unavailable_evidence"
    case expiredHandle = "expired_handle"
    case permissionDenied = "permission_denied"
    case cancelled = "cancelled"
    case buildFailure = "build_failure"
    case runtimeFailure = "runtime_failure"
}

public struct MCPStructuredError: Codable, Sendable, Equatable {
    public let code: MCPToolErrorCode
    public let message: String
    public let recoverable: Bool

    public init(code: MCPToolErrorCode, message: String, recoverable: Bool = true) {
        self.code = code
        self.message = message
        self.recoverable = recoverable
    }
}

/// Shared envelope for token-efficient evidence returned by modern MCP tools.
public struct MCPEvidenceEnvelope: Encodable, Sendable {
    public struct Target: Codable, Sendable, Equatable {
        public let type: String
        public let identifier: String

        public init(type: String, identifier: String) {
            self.type = type
            self.identifier = identifier
        }
    }

    public struct Environment: Codable, Sendable, Equatable {
        public let platform: String
        public let server: MCPImplementation

        public init(platform: String = "macOS", server: MCPImplementation = .viewLens) {
            self.platform = platform
            self.server = server
        }
    }

    public struct Completeness: Codable, Sendable, Equatable {
        public enum Status: String, Codable, Sendable {
            case complete
            case partial
            case unavailable
        }

        public let status: Status
        public let evaluated: [String]
        public let notEvaluated: [String]

        public init(status: Status, evaluated: [String], notEvaluated: [String] = []) {
            self.status = status
            self.evaluated = evaluated
            self.notEvaluated = notEvaluated
        }
    }

    public struct Artifact: Codable, Sendable, Equatable {
        public let kind: String
        public let path: String
        public let mediaType: String

        public init(kind: String, path: String, mediaType: String) {
            self.kind = kind
            self.path = path
            self.mediaType = mediaType
        }
    }

    public struct Timing: Codable, Sendable, Equatable {
        public let durationMs: Double

        public init(durationMs: Double) {
            self.durationMs = durationMs
        }
    }

    public let schemaVersion = "1.0"
    public let reviewID: String
    public let sourceMode: String
    public let target: Target
    public let environment: Environment
    public let completeness: Completeness
    public let findings: [JSONValue]
    public let artifacts: [Artifact]
    public let timing: Timing
    public let warnings: [String]
    public let recoveryActions: [String]
    public let data: JSONValue
    public let error: MCPStructuredError?

    enum CodingKeys: String, CodingKey {
        case schemaVersion
        case reviewID = "reviewId"
        case sourceMode, target, environment, completeness, findings, artifacts, timing
        case warnings, recoveryActions, data, error
    }

    public init(
        reviewID: String = UUID().uuidString.lowercased(),
        sourceMode: String,
        target: Target,
        completeness: Completeness,
        findings: [JSONValue] = [],
        artifacts: [Artifact] = [],
        durationMs: Double,
        warnings: [String] = [],
        recoveryActions: [String] = [],
        data: JSONValue,
        error: MCPStructuredError? = nil
    ) {
        self.reviewID = reviewID
        self.sourceMode = sourceMode
        self.target = target
        self.environment = Environment()
        self.completeness = completeness
        self.findings = findings
        self.artifacts = artifacts
        self.timing = Timing(durationMs: durationMs)
        self.warnings = warnings
        self.recoveryActions = recoveryActions
        self.data = data
        self.error = error
    }

    public var jsonValue: JSONValue? {
        try? JSONValue.fromEncodable(self)
    }
}

public extension JSONValue {
    static func fromEncodable<T: Encodable>(_ value: T) throws -> JSONValue {
        let data = try JSONEncoder().encode(value)
        return try JSONDecoder().decode(JSONValue.self, from: data)
    }
}
