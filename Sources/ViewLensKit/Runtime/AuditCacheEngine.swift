import Foundation
import CryptoKit

/// Provenance metadata describing cache resolution for an audit result.
public struct AuditCacheProvenance: Codable, Sendable, Equatable {
    public let status: String // "hit", "miss", "bypassed"
    public let cacheKey: String
    public let ageSeconds: Double?
    public let modelVersion: String
    public let rulesVersion: String

    public init(
        status: String,
        cacheKey: String,
        ageSeconds: Double? = nil,
        modelVersion: String = "YOLO11n-v2.0",
        rulesVersion: String = "HIG-WCAG22-v1.0"
    ) {
        self.status = status
        self.cacheKey = cacheKey
        self.ageSeconds = ageSeconds
        self.modelVersion = modelVersion
        self.rulesVersion = rulesVersion
    }
}

/// A stored cache record with metadata and TTL expiration.
private struct CacheRecord: Sendable {
    let key: String
    let createdAt: Date
    let expiresAt: Date
    let payload: Data
}

/// Deterministic, content-addressed multi-dimensional cache for ViewLens visual, template,
/// and accessibility audit evaluations (MCP-18.11).
public final class AuditCacheEngine: @unchecked Sendable {
    public static let shared = AuditCacheEngine()

    private let lock = NSLock()
    private var records: [String: CacheRecord] = [:]
    private var hitCount: Int = 0
    private var missCount: Int = 0

    public init() {}

    /// Computes a deterministic SHA-256 cache key from input parameters.
    public static func computeKey(
        sourcePayload: Data,
        target: String,
        device: String = "default",
        dynamicType: String = "large",
        colorScheme: String = "light",
        wcagLevel: String = "AA",
        rulesVersion: String = "1.0",
        modelVersion: String = "2.0"
    ) -> String {
        var hasher = SHA256()
        hasher.update(data: sourcePayload)
        hasher.update(data: Data(target.utf8))
        hasher.update(data: Data(device.utf8))
        hasher.update(data: Data(dynamicType.utf8))
        hasher.update(data: Data(colorScheme.utf8))
        hasher.update(data: Data(wcagLevel.utf8))
        hasher.update(data: Data(rulesVersion.utf8))
        hasher.update(data: Data(modelVersion.utf8))
        let digest = hasher.finalize()
        return digest.map { String(format: "%02x", $0) }.joined()
    }

    /// Retrieves an entry from cache if present and unexpired.
    public func get<T: Decodable>(key: String, as type: T.Type) -> (item: T, provenance: AuditCacheProvenance)? {
        lock.lock()
        defer { lock.unlock() }

        guard let record = records[key] else {
            missCount += 1
            return nil
        }

        let now = Date()
        guard now < record.expiresAt else {
            records.removeValue(forKey: key)
            missCount += 1
            return nil
        }

        guard let decoded = try? JSONDecoder().decode(type, from: record.payload) else {
            records.removeValue(forKey: key)
            missCount += 1
            return nil
        }

        hitCount += 1
        let age = now.timeIntervalSince(record.createdAt)
        let provenance = AuditCacheProvenance(
            status: "hit",
            cacheKey: key,
            ageSeconds: max(0, age)
        )
        return (decoded, provenance)
    }

    /// Stores an encodable item in cache with a TTL (default 1 hour).
    public func set<T: Encodable>(key: String, value: T, ttlSeconds: TimeInterval = 3600) {
        guard let data = try? JSONEncoder().encode(value) else { return }
        let now = Date()
        let record = CacheRecord(
            key: key,
            createdAt: now,
            expiresAt: now.addingTimeInterval(ttlSeconds),
            payload: data
        )

        lock.lock()
        records[key] = record
        lock.unlock()
    }

    /// Clears expired items or all entries.
    public func purgeExpired() {
        lock.lock()
        defer { lock.unlock() }
        let now = Date()
        records = records.filter { $0.value.expiresAt > now }
    }

    public func clear() {
        lock.lock()
        defer { lock.unlock() }
        records.removeAll()
        hitCount = 0
        missCount = 0
    }

    /// Cache statistics.
    public var metrics: (hits: Int, misses: Int, totalEntries: Int, hitRatio: Double) {
        lock.lock()
        defer { lock.unlock() }
        let total = hitCount + missCount
        let ratio = total > 0 ? Double(hitCount) / Double(total) : 0.0
        return (hitCount, missCount, records.count, ratio)
    }
}
