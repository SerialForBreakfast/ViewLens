import CoreGraphics
import Foundation
import SwiftUI
import ViewLensKit

@MainActor
public protocol ReviewRepository: AnyObject {
    func save(_ review: ReviewRecord)
    func review(id: UUID) -> ReviewRecord?
    func allReviews() -> [ReviewRecord]
    func delete(id: UUID)
}

@MainActor
public final class InMemoryReviewRepository: ReviewRepository {
    private var records: [UUID: ReviewRecord] = [:]

    public init() {}

    public func save(_ review: ReviewRecord) { records[review.id] = review }
    public func review(id: UUID) -> ReviewRecord? { records[id] }
    public func allReviews() -> [ReviewRecord] { records.values.sorted { $0.startedAt > $1.startedAt } }
    public func delete(id: UUID) { records[id] = nil }
}

@MainActor
@Observable
public final class ReviewStore {
    public private(set) var activeReview: ReviewRecord?
    public private(set) var reviews: [ReviewRecord] = []
    public private(set) var events: [ReviewEvent] = []
    public var selectedReviewID: UUID?
    public var selectedFindingID: ReviewFinding.ID?
    public var filter = FindingFilter()
    public var activeActivity: MCPAgentActivity?
    public private(set) var activityHistory: [MCPAgentActivity] = []

    private let repository: ReviewRepository

    public convenience init() {
        self.init(repository: InMemoryReviewRepository())
    }

    public init(repository: ReviewRepository) {
        self.repository = repository
        self.reviews = repository.allReviews()
    }

    @discardableResult
    public func begin(source: ReviewSource, environment: ReviewEnvironment) -> UUID {
        let review = ReviewRecord(source: source, environment: environment)
        activeReview = review
        selectedReviewID = review.id
        selectedFindingID = nil
        events = [ReviewEvent(phase: .preparing, message: "Preparing \(source.displayName)")]
        return review.id
    }

    public func transition(reviewID: UUID, to phase: ReviewPhase, message: String) {
        guard activeReview?.id == reviewID else { return }
        activeReview?.status = .running(phase)
        events.append(ReviewEvent(phase: phase, message: message))
    }

    public func complete(
        reviewID: UUID,
        image: CGImage,
        elements: [DetectedElement],
        issues: [ViewLensIssue],
        score: ReviewScore,
        activity: MCPAgentActivity
    ) {
        guard var review = activeReview, review.id == reviewID else { return }
        review.previewImage = image
        review.elements = elements
        review.findings = Self.makeFindings(from: issues)
        review.score = score
        review.finishedAt = Date()
        review.duration = review.finishedAt?.timeIntervalSince(review.startedAt)
        review.status = score.isComplete ? .completed : .incomplete(reason: "Some criteria require a rendered semantic hierarchy.")

        activeReview = review
        activeActivity = activity
        activityHistory.removeAll { $0.reviewID == reviewID }
        activityHistory.insert(activity, at: 0)
        repository.save(review)
        reviews = repository.allReviews()
        events.append(ReviewEvent(phase: .complete, message: score.isComplete ? "Review complete" : "Review complete with limited coverage"))
    }

    public func fail(reviewID: UUID, failure: ReviewFailure) {
        guard activeReview?.id == reviewID else { return }
        activeReview?.status = .failed(failure)
        events.append(ReviewEvent(message: failure.message, isError: true))
    }

    public func cancel(reviewID: UUID) {
        guard activeReview?.id == reviewID, activeReview?.status.isRunning == true else { return }
        activeReview?.status = .cancelled
        events.append(ReviewEvent(message: "Review cancelled"))
    }

    public func markStale(reviewID: UUID, reason: String) {
        guard var review = repository.review(id: reviewID) ?? (activeReview?.id == reviewID ? activeReview : nil) else { return }
        review.status = .stale(reason: reason)
        repository.save(review)
        if activeReview?.id == reviewID { activeReview = review }
        reviews = repository.allReviews()
    }

    public func load(reviewID: UUID) {
        guard let review = repository.review(id: reviewID) else { return }
        activeReview = review
        selectedReviewID = reviewID
        selectedFindingID = nil
    }

    public func delete(reviewID: UUID) {
        repository.delete(id: reviewID)
        reviews = repository.allReviews()
        if activeReview?.id == reviewID {
            activeReview = nil
            selectedReviewID = nil
            selectedFindingID = nil
        }
    }

    public var filteredFindings: [ReviewFinding] {
        (activeReview?.findings ?? []).filter(filter.matches)
    }

    public static func makeFindings(from issues: [ViewLensIssue]) -> [ReviewFinding] {
        var occurrences: [String: Int] = [:]
        return issues.map { issue in
            let key = [issue.identifier ?? "", issue.kind.rawValue, issue.wcagCriterion ?? ""].joined(separator: "|")
            let occurrence = occurrences[key, default: 0]
            occurrences[key] = occurrence + 1
            return ReviewFinding(issue: issue, occurrence: occurrence)
        }
    }
}

@MainActor
@Observable
public final class CanvasStore {
    public var image: CGImage?
    public var elements: [DetectedElement] = []
    public var findings: [ReviewFinding] = []
    public var selectedElementIndex: Int?
    public var selectedFindingID: ReviewFinding.ID?
    public var showOverlays = true
    public var showSafeAreaGuides = true
    public var showElementLabels = true

    public init() {}

    public var issues: [ViewLensIssue] { findings.map(\.issue) }

    public var selectedIssue: ViewLensIssue? {
        get { findings.first { $0.id == selectedFindingID }?.issue }
        set {
            guard let newValue else {
                selectedFindingID = nil
                selectedElementIndex = nil
                return
            }
            let finding = findings.first { $0.issue == newValue }
            selectedFindingID = finding?.id
            selectedElementIndex = newValue.elementIndex
        }
    }

    public func update(image: CGImage, elements: [DetectedElement], issues: [ViewLensIssue]) {
        self.image = image
        self.elements = elements
        self.findings = ReviewStore.makeFindings(from: issues)
        selectedElementIndex = nil
        selectedFindingID = nil
    }

    public func load(review: ReviewRecord) {
        image = review.previewImage
        elements = review.elements
        findings = review.findings
        selectedElementIndex = nil
        selectedFindingID = nil
    }

    public func replaceIssues(_ issues: [ViewLensIssue]) {
        findings = ReviewStore.makeFindings(from: issues)
        selectedElementIndex = nil
        selectedFindingID = nil
    }
}
