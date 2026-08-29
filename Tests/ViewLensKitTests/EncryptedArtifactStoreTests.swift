import Foundation
import Testing
@testable import ViewLensKit

@Suite("Encrypted Artifact Store Tests (MCP-18.9)")
struct EncryptedArtifactStoreTests {
    @Test("Encrypts, stores, and decrypts artifact round-trip")
    func encryptsAndDecryptsArtifact() throws {
        let store = EncryptedArtifactStore()
        let sampleData = Data("sample-screenshot-pixels-and-overlay".utf8)

        let tenantId = "tenant-apple-dev"
        let reviewId = "review-login-001"
        let artifactId = "overlay-iphone16"

        _ = try store.store(tenantId: tenantId, reviewId: reviewId, artifactId: artifactId, data: sampleData)

        let retrieved = try store.retrieve(tenantId: tenantId, reviewId: reviewId, artifactId: artifactId)
        #expect(retrieved == sampleData)
    }

    @Test("Generates and validates signed artifact tokens")
    func signedTokenLifecycle() throws {
        let store = EncryptedArtifactStore()
        let tenantId = "tenant-a"
        let reviewId = "review-1"
        let artifactId = "diff-map"

        let token = store.generateSignedToken(
            tenantId: tenantId,
            reviewId: reviewId,
            artifactId: artifactId,
            expiresInSeconds: 60
        )

        let validated = try store.validateSignedToken(token)
        #expect(validated.tenantId == tenantId)
        #expect(validated.reviewId == reviewId)
        #expect(validated.artifactId == artifactId)
    }

    @Test("Rejects expired signed tokens")
    func rejectsExpiredSignedTokens() {
        let store = EncryptedArtifactStore()
        let token = store.generateSignedToken(
            tenantId: "tenant-a",
            reviewId: "review-1",
            artifactId: "diff-map",
            expiresInSeconds: -10
        )

        #expect(throws: EncryptedStoreError.artifactExpired) {
            _ = try store.validateSignedToken(token)
        }
    }

    @Test("Purging tenant securely removes all tenant artifacts")
    func purgesTenantArtifacts() throws {
        let store = EncryptedArtifactStore()
        let tenantId = "tenant-ephemeral"
        let reviewId = "review-temp"
        let artifactId = "art-1"

        _ = try store.store(tenantId: tenantId, reviewId: reviewId, artifactId: artifactId, data: Data("ephemeral".utf8))
        _ = try store.retrieve(tenantId: tenantId, reviewId: reviewId, artifactId: artifactId)

        try store.purgeTenant(tenantId: tenantId)

        #expect(throws: EncryptedStoreError.artifactNotFound(artifactId)) {
            _ = try store.retrieve(tenantId: tenantId, reviewId: reviewId, artifactId: artifactId)
        }
    }
}
