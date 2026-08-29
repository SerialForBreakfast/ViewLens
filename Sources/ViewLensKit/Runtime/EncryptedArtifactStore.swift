import Foundation
import CryptoKit

/// Error types for encrypted artifact storage operations.
public enum EncryptedStoreError: Error, Sendable, Equatable {
    case artifactNotFound(String)
    case artifactExpired
    case decryptionFailed
    case invalidSignedToken
    case unauthorizedTenantAccess
}

/// AES-GCM Encrypted payload container persisted on disk.
private struct EncryptedPayload: Codable, Sendable {
    let nonce: Data
    let ciphertext: Data
    let tag: Data
    let createdAt: Date
    let expiresAt: Date
}

/// Tenant-isolated, AES-GCM encrypted artifact storage with TTL expiration,
/// secure deletion, and signed URL generation (MCP-18.9).
public final class EncryptedArtifactStore: @unchecked Sendable {
    public let storageDirectory: URL
    private let masterKey: SymmetricKey
    private let signingSecret: SymmetricKey
    private let lock = NSLock()

    public init(
        storageDirectory: URL? = nil,
        masterKey: SymmetricKey? = nil
    ) {
        let dir = storageDirectory ?? FileManager.default.temporaryDirectory
            .appendingPathComponent("viewlens-encrypted-artifacts-\(UUID().uuidString)", isDirectory: true)
        self.storageDirectory = dir
        self.masterKey = masterKey ?? SymmetricKey(size: .bits256)
        self.signingSecret = SymmetricKey(size: .bits256)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    }

    /// Stores artifact data encrypted with AES-GCM under tenant/review isolation.
    public func store(
        tenantId: String,
        reviewId: String,
        artifactId: String,
        data: Data,
        ttlSeconds: TimeInterval = 604_800 // 7 days default
    ) throws -> URL {
        lock.lock()
        defer { lock.unlock() }

        let tenantDir = storageDirectory
            .appendingPathComponent(tenantId, isDirectory: true)
            .appendingPathComponent(reviewId, isDirectory: true)
        try FileManager.default.createDirectory(at: tenantDir, withIntermediateDirectories: true)

        let nonce = AES.GCM.Nonce()
        let sealedBox = try AES.GCM.seal(data, using: masterKey, nonce: nonce)

        let now = Date()
        let payload = EncryptedPayload(
            nonce: Data(sealedBox.nonce),
            ciphertext: sealedBox.ciphertext,
            tag: sealedBox.tag,
            createdAt: now,
            expiresAt: now.addingTimeInterval(ttlSeconds)
        )

        let fileURL = tenantDir.appendingPathComponent("\(artifactId).enc")
        let encoded = try JSONEncoder().encode(payload)
        try encoded.write(to: fileURL, options: .atomic)
        return fileURL
    }

    /// Decrypts and retrieves an artifact if not expired.
    public func retrieve(
        tenantId: String,
        reviewId: String,
        artifactId: String
    ) throws -> Data {
        lock.lock()
        defer { lock.unlock() }

        let fileURL = storageDirectory
            .appendingPathComponent(tenantId, isDirectory: true)
            .appendingPathComponent(reviewId, isDirectory: true)
            .appendingPathComponent("\(artifactId).enc")

        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            throw EncryptedStoreError.artifactNotFound(artifactId)
        }

        let data = try Data(contentsOf: fileURL)
        let payload = try JSONDecoder().decode(EncryptedPayload.self, from: data)

        guard Date() < payload.expiresAt else {
            try? FileManager.default.removeItem(at: fileURL)
            throw EncryptedStoreError.artifactExpired
        }

        let nonce = try AES.GCM.Nonce(data: payload.nonce)
        let sealedBox = try AES.GCM.SealedBox(nonce: nonce, ciphertext: payload.ciphertext, tag: payload.tag)
        return try AES.GCM.open(sealedBox, using: masterKey)
    }

    /// Generates a signed, expiring access token for an artifact.
    public func generateSignedToken(
        tenantId: String,
        reviewId: String,
        artifactId: String,
        expiresInSeconds: TimeInterval = 300
    ) -> String {
        let expiration = Date().addingTimeInterval(expiresInSeconds).timeIntervalSince1970
        let payloadString = "\(tenantId):\(reviewId):\(artifactId):\(Int(expiration))"
        let signature = HMAC<SHA256>.authenticationCode(for: Data(payloadString.utf8), using: signingSecret)
        let sigHex = signature.map { String(format: "%02x", $0) }.joined()
        let token = "\(payloadString):\(sigHex)"
        return Data(token.utf8).base64EncodedString()
    }

    /// Validates a signed token and returns tenant, review, and artifact references.
    public func validateSignedToken(_ tokenBase64: String) throws -> (tenantId: String, reviewId: String, artifactId: String) {
        guard let tokenData = Data(base64Encoded: tokenBase64),
              let tokenString = String(data: tokenData, encoding: .utf8) else {
            throw EncryptedStoreError.invalidSignedToken
        }

        let parts = tokenString.split(separator: ":").map(String.init)
        guard parts.count == 5 else {
            throw EncryptedStoreError.invalidSignedToken
        }

        let tenantId = parts[0]
        let reviewId = parts[1]
        let artifactId = parts[2]
        guard let expTimestamp = Double(parts[3]) else {
            throw EncryptedStoreError.invalidSignedToken
        }
        let signatureHex = parts[4]

        let payloadString = "\(tenantId):\(reviewId):\(artifactId):\(Int(expTimestamp))"
        let expectedSig = HMAC<SHA256>.authenticationCode(for: Data(payloadString.utf8), using: signingSecret)
        let expectedHex = expectedSig.map { String(format: "%02x", $0) }.joined()

        guard signatureHex == expectedHex else {
            throw EncryptedStoreError.invalidSignedToken
        }

        guard Date().timeIntervalSince1970 < expTimestamp else {
            throw EncryptedStoreError.artifactExpired
        }

        return (tenantId, reviewId, artifactId)
    }

    /// Completely purges all data for a specific tenant.
    public func purgeTenant(tenantId: String) throws {
        lock.lock()
        defer { lock.unlock() }

        let tenantDir = storageDirectory.appendingPathComponent(tenantId, isDirectory: true)
        if FileManager.default.fileExists(atPath: tenantDir.path) {
            try FileManager.default.removeItem(at: tenantDir)
        }
    }
}
