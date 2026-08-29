import CoreGraphics
import Foundation
import SwiftUI
import ViewLensKit

@MainActor
public protocol ReviewRepository: AnyObject {
    var persistenceState: ReviewPersistenceState { get }
    var storageURL: URL? { get }
    func save(_ review: ReviewRecord)
    func review(id: UUID) -> ReviewRecord?
    func allReviews() -> [ReviewRecord]
    func delete(id: UUID)
    func deleteAll()
    func prune(olderThan cutoff: Date)
    func prunePreviewAssets(olderThan cutoff: Date?)
    func storageBytes() -> Int64
}

@MainActor
public final class InMemoryReviewRepository: ReviewRepository {
    private var records: [UUID: ReviewRecord] = [:]

    public init() {}

    public var persistenceState: ReviewPersistenceState { .ready }
    public var storageURL: URL? { nil }

    public func save(_ review: ReviewRecord) { records[review.id] = review }
    public func review(id: UUID) -> ReviewRecord? { records[id] }
    public func allReviews() -> [ReviewRecord] { records.values.sorted { $0.startedAt > $1.startedAt } }
    public func delete(id: UUID) { records[id] = nil }
    public func deleteAll() { records.removeAll() }
    public func prune(olderThan cutoff: Date) { records = records.filter { $0.value.startedAt >= cutoff } }
    public func prunePreviewAssets(olderThan cutoff: Date?) {
        let ids = records.values.filter { cutoff == nil || $0.startedAt < (cutoff ?? .distantPast) }.map(\.id)
        for id in ids {
            guard var record = records[id] else { continue }
            record.previewImage = nil
            records[id] = record
        }
    }
    public func storageBytes() -> Int64 { 0 }
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
    public private(set) var persistenceState: ReviewPersistenceState

    private let repository: ReviewRepository

    public convenience init() {
        self.init(repository: InMemoryReviewRepository())
    }

    public init(repository: ReviewRepository) {
        self.repository = repository
        self.reviews = repository.allReviews()
        self.persistenceState = repository.persistenceState
    }

    @discardableResult
    public func begin(source: ReviewSource, environment: ReviewEnvironment, startedAt: Date = Date()) -> UUID {
        let review = ReviewRecord(source: source, environment: environment, startedAt: startedAt)
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
        activity: MCPAgentActivity,
        nonvisualScreenModel: NonvisualScreenModel? = nil,
        finishedAt: Date = Date()
    ) {
        guard var review = activeReview, review.id == reviewID else { return }
        review.previewImage = image
        review.elements = elements
        review.findings = Self.makeFindings(from: issues)
        review.score = score
        review.finishedAt = finishedAt
        review.duration = review.finishedAt?.timeIntervalSince(review.startedAt)
        review.status = score.isComplete ? .completed : .incomplete(reason: "Some criteria require a rendered semantic hierarchy.")

        let sourceMode: AuditSourceMode = switch review.source {
        case .template: .rendered
        case .image: .screenshot
        }
        let report = activity.auditReport ?? AuditReport(
            sourceMode: sourceMode,
            target: review.source.displayName,
            dimensions: AuditDimensions(width: Double(image.width), height: Double(image.height), scale: 1.0),
            elements: elements,
            issues: issues
        )
        let screenID = NonvisualID("screen:\(reviewID.uuidString)")
        review.nonvisualScreenModel = nonvisualScreenModel ?? NonvisualScreenBuilder.fromAuditReport(
                report,
                screenID: screenID,
                title: review.source.displayName
            )

        activeReview = review
        activeActivity = activity
        activityHistory.removeAll { $0.reviewID == reviewID }
        activityHistory.insert(activity, at: 0)
        repository.save(review)
        refreshRepositoryState()
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
        refreshRepositoryState()
    }

    public func load(reviewID: UUID) {
        guard let review = repository.review(id: reviewID) else { return }
        activeReview = review
        selectedReviewID = reviewID
        selectedFindingID = nil
    }

    public func delete(reviewID: UUID) {
        repository.delete(id: reviewID)
        refreshRepositoryState()
        if activeReview?.id == reviewID {
            activeReview = nil
            selectedReviewID = nil
            selectedFindingID = nil
        }
    }

    public var storageURL: URL? { repository.storageURL }
    public var storageBytes: Int64 { repository.storageBytes() }

    public func deleteAllReviews() {
        repository.deleteAll()
        reviews = []
        activeReview = nil
        selectedReviewID = nil
        selectedFindingID = nil
        refreshRepositoryState()
    }

    public func applyRetention(days: Int?) {
        guard let days else { refreshRepositoryState(); return }
        repository.prune(olderThan: Calendar.current.date(byAdding: .day, value: -days, to: Date()) ?? .distantPast)
        refreshRepositoryState()
    }

    public func applyAssetRetention(days: Int?) {
        repository.prunePreviewAssets(olderThan: days.map { Calendar.current.date(byAdding: .day, value: -$0, to: Date()) ?? .distantPast })
        refreshRepositoryState()
    }

    private func refreshRepositoryState() {
        reviews = repository.allReviews()
        persistenceState = repository.persistenceState
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
