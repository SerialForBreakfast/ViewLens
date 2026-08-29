import Foundation

/// Defines standard fine-grained OAuth / MCP authorization scopes.
public enum RemoteAuthScope: String, Codable, Sendable, CaseIterable {
    case readAudit = "read:audit"
    case executeFlow = "execute:flow"
    case adminReview = "admin:review"
    case manageTasks = "manage:tasks"
}

/// Decoded security claims for a remote MCP connection or request.
public struct RemoteAuthClaims: Codable, Sendable, Equatable {
    public let tenantId: String
    public let userId: String
    public let audience: String
    public let scopes: Set<RemoteAuthScope>
    public let issuedAt: Date
    public let expiresAt: Date

    public init(
        tenantId: String,
        userId: String,
        audience: String,
        scopes: Set<RemoteAuthScope>,
        issuedAt: Date = Date(),
        expiresAt: Date = Date().addingTimeInterval(3600)
    ) {
        self.tenantId = tenantId
        self.userId = userId
        self.audience = audience
        self.scopes = scopes
        self.issuedAt = issuedAt
        self.expiresAt = expiresAt
    }

    public var isExpired: Bool {
        Date() > expiresAt
    }

    public func hasScope(_ scope: RemoteAuthScope) -> Bool {
        scopes.contains(scope) || scopes.contains(.adminReview)
    }
}

public enum RemoteAuthError: Error, Sendable, Equatable {
    case missingAuthorizationHeader
    case malformedBearerToken
    case invalidTokenSecret
    case tokenExpired
    case audienceMismatch(expected: String, actual: String)
    case insufficientScope(required: RemoteAuthScope)

    public var errorCode: Int {
        switch self {
        case .missingAuthorizationHeader, .malformedBearerToken, .invalidTokenSecret:
            return -32001 // Unauthorized
        case .tokenExpired:
            return -32002 // Token Expired
        case .audienceMismatch, .insufficientScope:
            return -32003 // Forbidden Scope
        }
    }

    public var errorMessage: String {
        switch self {
        case .missingAuthorizationHeader:
            return "Missing required 'Authorization: Bearer <token>' header"
        case .malformedBearerToken:
            return "Malformed bearer authorization token"
        case .invalidTokenSecret:
            return "Invalid bearer token secret or signature"
        case .tokenExpired:
            return "Remote authorization token has expired"
        case .audienceMismatch(let expected, let actual):
            return "Audience mismatch: expected '\(expected)', got '\(actual)'"
        case .insufficientScope(let required):
            return "Forbidden: missing required '\(required.rawValue)' scope"
        }
    }
}

/// Validates incoming remote HTTP / SSE requests against audience, expiration, and required scopes.
public final class RemoteAuthorizationValidator: @unchecked Sendable {
    public let expectedAudience: String
    public let preSharedSecret: String?
    private let lock = NSLock()
    private var customValidators: [String: RemoteAuthClaims] = [:]

    public init(
        expectedAudience: String = "viewlens://remote-service",
        preSharedSecret: String? = nil
    ) {
        self.expectedAudience = expectedAudience
        self.preSharedSecret = preSharedSecret
    }

    public func registerMockToken(_ token: String, claims: RemoteAuthClaims) {
        lock.lock()
        defer { lock.unlock() }
        customValidators[token] = claims
    }

    public func validate(
        headers: [String: String],
        requiredScope: RemoteAuthScope? = nil
    ) throws -> RemoteAuthClaims {
        guard let authHeader = headers["authorization"] ?? headers["Authorization"] else {
            throw RemoteAuthError.missingAuthorizationHeader
        }

        guard authHeader.lowercased().hasPrefix("bearer ") else {
            throw RemoteAuthError.malformedBearerToken
        }

        let token = String(authHeader.dropFirst(7)).trimmingCharacters(in: .whitespacesAndNewlines)
        guard !token.isEmpty else {
            throw RemoteAuthError.malformedBearerToken
        }

        lock.lock()
        let registeredClaims = customValidators[token]
        lock.unlock()

        let claims: RemoteAuthClaims
        if let reg = registeredClaims {
            claims = reg
        } else if let secret = preSharedSecret, token == secret {
            claims = RemoteAuthClaims(
                tenantId: "default-tenant",
                userId: "authenticated-agent",
                audience: expectedAudience,
                scopes: Set(RemoteAuthScope.allCases)
            )
        } else {
            throw RemoteAuthError.invalidTokenSecret
        }

        guard !claims.isExpired else {
            throw RemoteAuthError.tokenExpired
        }

        guard claims.audience == expectedAudience else {
            throw RemoteAuthError.audienceMismatch(expected: expectedAudience, actual: claims.audience)
        }

        if let required = requiredScope, !claims.hasScope(required) {
            throw RemoteAuthError.insufficientScope(required: required)
        }

        return claims
    }
}
