import CoreGraphics
import Foundation
import Testing
import ViewLensKit
@testable import ViewLens

@MainActor
struct ReviewStoreTests {
    @Test func lifecycleFailureStaleAndScoreBoundsAreExplicit() throws {
        let repository = InMemoryReviewRepository()
        let store = ReviewStore(repository: repository)
        let reviewID = store.begin(source: .template(name: "Lifecycle"), environment: ReviewEnvironment())
        #expect(store.activeReview?.status == .preparing)
        store.transition(reviewID: reviewID, to: .rendering, message: "Rendering")
        #expect(store.activeReview?.status == .running(.rendering))

        let failure = ReviewFailure(title: "Renderer unavailable", message: "Could not render", recoverySuggestion: "Retry")
        store.fail(reviewID: reviewID, failure: failure)
        #expect(store.activeReview?.status == .failed(failure))
        #expect(store.events.last?.isError == true)

        let persisted = ReviewRecord(source: .template(name: "Persisted"), status: .completed, environment: ReviewEnvironment())
        repository.save(persisted)
        store.markStale(reviewID: persisted.id, reason: "Source changed")
        #expect(repository.review(id: persisted.id)?.status == .stale(reason: "Source changed"))

        #expect(ReviewScore(value: 120, evaluatedCriteria: -1, totalCriteria: -2).value == 100)
        #expect(ReviewScore(value: -20, evaluatedCriteria: 9, totalCriteria: 4).value == 0)
        #expect(ReviewScore(value: 80, evaluatedCriteria: 9, totalCriteria: 4).totalCriteria == 9)
    }

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

    @Test func findingFilterCombinesStandardCriterionSeverityAndElement() {
        let wcag = ReviewFinding(issue: ViewLensIssue(
            kind: .contrastRisk,
            severity: .error,
            description: "Text contrast is too low.",
            elementIndex: 2,
            wcagCriterion: "WCAG 1.4.3"
        ), occurrence: 0)
        let hig = ReviewFinding(issue: ViewLensIssue(
            kind: .clippedElement,
            severity: .warning,
            description: "Control crosses the safe area.",
            elementIndex: 4
        ), occurrence: 0)

        var filter = FindingFilter()
        filter.standard = .wcag
        filter.severities = [.error]
        filter.criterion = "WCAG 1.4.3"
        filter.elementIndex = 2
        filter.searchText = "contrast"

        #expect(filter.matches(wcag))
        #expect(!filter.matches(hig))

        filter.standard = .hig
        filter.severities = [.warning]
        filter.criterion = nil
        filter.elementIndex = 4
        filter.searchText = "safe"
        #expect(filter.matches(hig))
        #expect(!filter.matches(wcag))
    }

    @Test func reviewExportPreservesCoverageAndUnevaluatedCriteria() throws {
        let review = ReviewRecord(
            source: .image(url: URL(fileURLWithPath: "/tmp/Checkout.png")),
            status: .incomplete(reason: "Semantic tree unavailable"),
            environment: ReviewEnvironment(deviceName: "iPhone", wcagLevel: "AA"),
            score: ReviewScore(value: 100, evaluatedCriteria: 4, totalCriteria: 8),
            previewImage: makeImage()
        )
        let document = ReviewExportDocument(review: review, events: [], format: .json)
        let object = try #require(JSONSerialization.jsonObject(with: document.jsonData()) as? [String: Any])
        let score = try #require(object["score"] as? [String: Any])

        #expect(score["evaluatedCriteria"] as? Int == 4)
        #expect(score["totalCriteria"] as? Int == 8)
        #expect(score["complete"] as? Bool == false)
        #expect(score["unevaluatedCriteriaCount"] as? Int == 4)
        #expect(document.annotatedPNGData() != nil)
    }

    @Test func findingAndCanvasSelectionStaySynchronized() throws {
        let reviewStore = ReviewStore()
        let canvasStore = CanvasStore()
        let model = AppModel(
            reviewStore: reviewStore,
            canvasStore: canvasStore,
            healthStore: SystemHealthStore(),
            playgroundStore: PlaygroundStore(),
            loadsInitialSample: false
        )
        let issue = ViewLensIssue(
            kind: .tappableTargetTooSmall,
            severity: .error,
            description: "Target is too small.",
            elementIndex: 0,
            wcagCriterion: "WCAG 2.5.8"
        )
        canvasStore.update(
            image: try #require(makeImage()),
            elements: [DetectedElement(type: "primaryButton", confidence: 0.95, boundingBox: BoundingBox(x: 0, y: 0, width: 1, height: 1))],
            issues: [issue]
        )
        let finding = try #require(canvasStore.findings.first)

        model.selectFinding(finding)
        #expect(reviewStore.selectedFindingID == finding.id)
        #expect(canvasStore.selectedElementIndex == 0)

        model.selectElement(at: 0)
        #expect(canvasStore.selectedFindingID == finding.id)
        #expect(reviewStore.selectedFindingID == finding.id)
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

@MainActor
struct DurableReviewRepositoryTests {
    @Test func completedReviewAndPreviewSurviveRepositoryReload() throws {
        let root = temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: root) }
        let repository = FileReviewRepository(rootURL: root)
        let image = try #require(makeImage())
        let review = ReviewRecord(
            source: .template(name: "LoginForm"),
            status: .completed,
            environment: ReviewEnvironment(deviceName: "iPhone 16 Pro", wcagLevel: "AA"),
            score: ReviewScore(value: 94, evaluatedCriteria: 8, totalCriteria: 8),
            findings: [ReviewFinding(issue: ViewLensIssue(kind: .contrastRisk, severity: .warning, description: "Low contrast", wcagCriterion: "WCAG 1.4.3"), occurrence: 0)],
            previewImage: image
        )
        repository.save(review)

        let reloaded = FileReviewRepository(rootURL: root)
        let restored = try #require(reloaded.review(id: review.id))
        #expect(restored.source == review.source)
        #expect(restored.score == review.score)
        #expect(restored.findings.map(\.id) == review.findings.map(\.id))
        #expect(restored.previewImage != nil)
        #expect(reloaded.persistenceState == .ready)
    }

    @Test func schemaOneManifestMigratesWithoutDataLoss() throws {
        let root = temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: root) }
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        try Data("{\"schemaVersion\":1,\"reviews\":[]}".utf8).write(to: root.appendingPathComponent("reviews.json"))

        let repository = FileReviewRepository(rootURL: root)
        #expect(repository.persistenceState == .migrated(fromVersion: 1))
        let json = try #require(JSONSerialization.jsonObject(with: Data(contentsOf: root.appendingPathComponent("reviews.json"))) as? [String: Any])
        #expect(json["schemaVersion"] as? Int == 2)
    }

    @Test func corruptManifestProducesExplicitState() throws {
        let root = temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: root) }
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        try Data("not-json".utf8).write(to: root.appendingPathComponent("reviews.json"))

        let repository = FileReviewRepository(rootURL: root)
        guard case .corrupt = repository.persistenceState else {
            Issue.record("Expected corrupt persistence state")
            return
        }
    }

    @Test func retentionAndDeleteAllRemoveOnlyIntendedRecords() {
        let repository = InMemoryReviewRepository()
        let old = ReviewRecord(source: .template(name: "Old"), status: .completed, environment: ReviewEnvironment(), startedAt: .distantPast)
        let recent = ReviewRecord(source: .template(name: "Recent"), status: .completed, environment: ReviewEnvironment(), previewImage: makeImage(), startedAt: Date())
        repository.save(old); repository.save(recent)
        repository.prune(olderThan: Calendar.current.date(byAdding: .day, value: -30, to: Date())!)
        #expect(repository.allReviews().map(\.id) == [recent.id])
        repository.prunePreviewAssets(olderThan: nil)
        #expect(repository.review(id: recent.id)?.previewImage == nil)
        repository.deleteAll()
        #expect(repository.allReviews().isEmpty)
    }

    private func temporaryDirectory() -> URL {
        FileManager.default.temporaryDirectory.appendingPathComponent("ViewLensTests-\(UUID().uuidString)", isDirectory: true)
    }

    private func makeImage() -> CGImage? {
        CGContext(data: nil, width: 2, height: 2, bitsPerComponent: 8, bytesPerRow: 8, space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)?.makeImage()
    }
}

@MainActor
struct HistoryStoreTests {
    @Test func filtersDurableReviewsBySourceStatusAndSearch() {
        let store = HistoryStore()
        let template = ReviewRecord(source: .template(name: "LoginForm"), status: .completed, environment: ReviewEnvironment())
        let screenshot = ReviewRecord(source: .image(url: URL(fileURLWithPath: "/tmp/Checkout.png")), status: .incomplete(reason: "Limited coverage"), environment: ReviewEnvironment())

        store.filter = .templates
        #expect(store.filteredReviews(from: [template, screenshot]).map(\.id) == [template.id])
        store.filter = .incomplete
        #expect(store.filteredReviews(from: [template, screenshot]).map(\.id) == [screenshot.id])
        store.filter = .all
        store.searchText = "checkout"
        #expect(store.filteredReviews(from: [template, screenshot]).map(\.id) == [screenshot.id])
    }
}
