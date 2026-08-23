import CoreGraphics
import Foundation
import Testing
import ViewLensKit
@testable import ViewLens

@MainActor
struct ReviewStoreTests {
    @Test func completeReviewCommitsAtomically() throws {
        let repository = InMemoryReviewRepository()
        let store = ReviewStore(repository: repository)
        let reviewID = store.begin(source: .template(name: "LoginForm"), environment: ReviewEnvironment())
        store.transition(reviewID: reviewID, to: .detecting, message: "Detecting")

        let issue = ViewLensIssue(
            kind: .contrastRisk,
            severity: .warning,
            description: "Contrast is below the required ratio.",
            wcagCriterion: "WCAG 1.4.3",
            wcagLevel: "AA"
        )
        let image = try #require(makeImage())
        let report = AuditReport(
            sourceMode: .rendered,
            target: "LoginForm",
            dimensions: AuditDimensions(width: 1, height: 1, scale: 1),
            elements: [],
            issues: [issue]
        )
        let activity = MCPAgentActivity(
            toolName: "viewlens_audit_view",
            argumentsDescription: "template: LoginForm",
            duration: 0.1,
            passed: false,
            summary: "1 issue",
            previewImage: image,
            auditReport: report,
            reviewID: reviewID
        )

        store.complete(
            reviewID: reviewID,
            image: image,
            elements: [],
            issues: [issue],
            score: ReviewScore(issues: [issue], evaluatedCriteria: 8, totalCriteria: 8),
            activity: activity
        )

        #expect(store.activeReview?.status == .completed)
        #expect(store.reviews.count == 1)
        #expect(store.activeReview?.findings.count == 1)
        #expect(store.activityHistory.first?.reviewID == reviewID)
        #expect(store.activeReview?.score?.isComplete == true)
    }

    @Test func partialCoverageCannotAppearFullyComplete() throws {
        let store = ReviewStore()
        let reviewID = store.begin(
            source: .image(url: URL(fileURLWithPath: "/tmp/screen.png")),
            environment: ReviewEnvironment()
        )
        let image = try #require(makeImage())
        let report = AuditReport(
            sourceMode: .screenshot,
            image: "screen.png",
            dimensions: AuditDimensions(width: 1, height: 1, scale: 1),
            elements: [],
            issues: []
        )
        let activity = MCPAgentActivity(
            toolName: "viewlens_audit_screenshot",
            argumentsDescription: "file: screen.png",
            duration: 0.1,
            passed: false,
            summary: "Semantic checks not evaluated",
            previewImage: image,
            auditReport: report,
            reviewID: reviewID
        )

        store.complete(
            reviewID: reviewID,
            image: image,
            elements: [],
            issues: [],
            score: ReviewScore(value: 100, evaluatedCriteria: 4, totalCriteria: 8),
            activity: activity
        )

        guard case .incomplete = store.activeReview?.status else {
            Issue.record("Expected incomplete review state")
            return
        }
        #expect(store.activeReview?.score?.value == 100)
        #expect(store.activeReview?.score?.isComplete == false)
    }

    @Test func cancellationPreservesPreviouslyCommittedReview() throws {
        let store = ReviewStore()
        let image = try #require(makeImage())
        let completedID = store.begin(source: .template(name: "First"), environment: ReviewEnvironment())
        let report = AuditReport(
            sourceMode: .rendered,
            target: "First",
            dimensions: AuditDimensions(width: 1, height: 1, scale: 1),
            elements: [],
            issues: []
        )
        let activity = MCPAgentActivity(
            toolName: "viewlens_audit_view",
            argumentsDescription: "template: First",
            duration: 0.1,
            passed: true,
            summary: "Passed",
            previewImage: image,
            auditReport: report,
            reviewID: completedID
        )
        store.complete(
            reviewID: completedID,
            image: image,
            elements: [],
            issues: [],
            score: ReviewScore(value: 100, evaluatedCriteria: 8, totalCriteria: 8),
            activity: activity
        )

        let cancelledID = store.begin(source: .template(name: "Second"), environment: ReviewEnvironment())
        store.transition(reviewID: cancelledID, to: .detecting, message: "Detecting")
        store.cancel(reviewID: cancelledID)

        #expect(store.reviews.map(\.id) == [completedID])
        #expect(store.activeReview?.id == cancelledID)
        #expect(store.activeReview?.status == .cancelled)
        #expect(store.activityHistory.first?.reviewID == completedID)
    }

    @Test func findingIdentifiersRemainStable() {
        let issues = [
            ViewLensIssue(
                kind: .tappableTargetTooSmall,
                severity: .error,
                description: "Target is too small.",
                elementIndex: 2,
                wcagCriterion: "WCAG 2.5.8"
            )
        ]

        let first = ReviewStore.makeFindings(from: issues)
        let second = ReviewStore.makeFindings(from: issues)
        #expect(first.map(\.id) == second.map(\.id))
    }

    private func makeImage() -> CGImage? {
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let context = CGContext(
            data: nil,
            width: 1,
            height: 1,
            bitsPerComponent: 8,
            bytesPerRow: 4,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        )
        return context?.makeImage()
    }
}

@MainActor
struct CurrentStatusStoreTests {
    @Test func filtersIncompleteAndSearchesSourceName() {
        let store = CurrentStatusStore()
        let complete = ReviewRecord(
            source: .template(name: "LoginForm"),
            status: .completed,
            environment: ReviewEnvironment(),
            score: ReviewScore(value: 96, evaluatedCriteria: 8, totalCriteria: 8)
        )
        let incomplete = ReviewRecord(
            source: .image(url: URL(fileURLWithPath: "/tmp/Checkout.png")),
            status: .incomplete(reason: "Semantic tree unavailable"),
            environment: ReviewEnvironment(),
            score: ReviewScore(value: 100, evaluatedCriteria: 4, totalCriteria: 8)
        )

        store.filter = .incomplete
        #expect(store.visibleReviews(from: [complete, incomplete]).map(\.id) == [incomplete.id])

        store.filter = .all
        store.searchText = "login"
        #expect(store.visibleReviews(from: [complete, incomplete]).map(\.id) == [complete.id])
    }

    @Test func passRateExcludesPartialReviewsAndSortsByScore() {
        let store = CurrentStatusStore()
        let high = ReviewRecord(
            source: .template(name: "High"),
            status: .completed,
            environment: ReviewEnvironment(),
            score: ReviewScore(value: 96, evaluatedCriteria: 8, totalCriteria: 8)
        )
        let low = ReviewRecord(
            source: .template(name: "Low"),
            status: .completed,
            environment: ReviewEnvironment(),
            score: ReviewScore(value: 72, evaluatedCriteria: 8, totalCriteria: 8)
        )
        let partial = ReviewRecord(
            source: .image(url: URL(fileURLWithPath: "/tmp/Partial.png")),
            status: .incomplete(reason: "Limited coverage"),
            environment: ReviewEnvironment(),
            score: ReviewScore(value: 100, evaluatedCriteria: 4, totalCriteria: 8)
        )

        #expect(store.passRate(for: [high, low, partial]) == 50)
        store.sort = .scoreHigh
        #expect(store.visibleReviews(from: [low, high, partial]).map(\.id) == [partial.id, high.id, low.id])
    }
}
