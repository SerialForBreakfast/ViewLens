import Foundation
import Testing
@testable import ViewLensKit

@Suite("Deterministic Audit Cache Engine Tests (MCP-18.11)")
struct AuditCacheEngineTests {
    struct TestAuditPayload: Codable, Equatable {
        let score: Double
        let issueCount: Int
    }

    @Test("Deterministic key computation produces identical hash for identical inputs")
    func deterministicKeyGeneration() {
        let payload1 = Data("sample-image-data".utf8)
        let payload2 = Data("sample-image-data".utf8)

        let key1 = AuditCacheEngine.computeKey(sourcePayload: payload1, target: "ProfileView", device: "iPhone16Pro")
        let key2 = AuditCacheEngine.computeKey(sourcePayload: payload2, target: "ProfileView", device: "iPhone16Pro")

        #expect(key1 == key2)
        #expect(!key1.isEmpty)

        let key3 = AuditCacheEngine.computeKey(sourcePayload: payload1, target: "ProfileView", device: "iPhoneSE")
        #expect(key1 != key3)
    }

    @Test("Stores and retrieves audit results with hit/miss provenance")
    func cacheSetAndGet() {
        let cache = AuditCacheEngine()
        let key = "test-cache-key-1"
        let item = TestAuditPayload(score: 0.98, issueCount: 0)

        // Cache miss
        let missResult = cache.get(key: key, as: TestAuditPayload.self)
        #expect(missResult == nil)

        // Set
        cache.set(key: key, value: item, ttlSeconds: 60)

        // Cache hit
        guard let hitResult = cache.get(key: key, as: TestAuditPayload.self) else {
            Issue.record("Expected cache hit")
            return
        }

        #expect(hitResult.item == item)
        #expect(hitResult.provenance.status == "hit")
        #expect(hitResult.provenance.cacheKey == key)
        #expect((hitResult.provenance.ageSeconds ?? 0) >= 0)

        let metrics = cache.metrics
        #expect(metrics.hits == 1)
        #expect(metrics.misses == 1)
        #expect(metrics.hitRatio == 0.5)
    }

    @Test("Expired cache records are evicted")
    func cacheExpiration() {
        let cache = AuditCacheEngine()
        let key = "expiring-key"
        let item = TestAuditPayload(score: 1.0, issueCount: 0)

        // Set with zero TTL
        cache.set(key: key, value: item, ttlSeconds: -1)

        let result = cache.get(key: key, as: TestAuditPayload.self)
        #expect(result == nil)
    }
}
