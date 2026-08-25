import CoreGraphics
import Foundation
import SwiftUI
import ViewLensKit

public enum ReviewSource: Equatable, Sendable {
    case template(name: String)
    case image(url: URL)

    public var displayName: String {
        switch self {
        case .template(let name): return name
        case .image(let url): return url.lastPathComponent
        }
    }

    public var sourceType: String {
        switch self {
        case .template: return "SwiftUI Template"
        case .image: return "Screenshot"
        }
    }
}

public enum ReviewPhase: String, CaseIterable, Codable, Sendable {
    case preparing = "Preparing"
    case rendering = "Rendering"
    case detecting = "Detecting"
    case evaluating = "Evaluating"
    case reviewing = "AI Review"
    case complete = "Complete"
}

public struct ReviewFailure: Error, Equatable, Sendable {
    public let title: String
    public let message: String
    public let recoverySuggestion: String?
    public let technicalDetails: String?

    public init(title: String, message: String, recoverySuggestion: String? = nil, technicalDetails: String? = nil) {
        self.title = title
        self.message = message
        self.recoverySuggestion = recoverySuggestion
        self.technicalDetails = technicalDetails
    }
}

public enum ReviewStatus: Equatable, Sendable {
    case idle
    case preparing
    case queued(position: Int?)
    case running(ReviewPhase)
    case completed
    case incomplete(reason: String)
    case failed(ReviewFailure)
    case cancelled
    case stale(reason: String)

    public var isRunning: Bool {
        switch self {
        case .preparing, .queued, .running: return true
        default: return false
        }
    }

    public var displayName: String {
        switch self {
        case .idle: return "Not started"
        case .preparing: return "Preparing"
        case .queued(let position): return position.map { "Queued (\($0))" } ?? "Queued"
        case .running(let phase): return phase.rawValue
        case .completed: return "Complete"
        case .incomplete: return "Incomplete"
        case .failed: return "Failed"
        case .cancelled: return "Cancelled"
        case .stale: return "Stale"
        }
    }
}

public struct ReviewEnvironment: Equatable, Sendable {
    public let deviceID: String?
    public let deviceName: String?
    public let dynamicType: String?
    public let appearance: String?
    public let wcagLevel: String
    public let detectorName: String?

    public init(
        deviceID: String? = nil,
        deviceName: String? = nil,
        dynamicType: String? = nil,
        appearance: String? = nil,
        wcagLevel: String = "AA",
        detectorName: String? = nil
    ) {
        self.deviceID = deviceID
        self.deviceName = deviceName
        self.dynamicType = dynamicType
        self.appearance = appearance
        self.wcagLevel = wcagLevel
        self.detectorName = detectorName
    }
}

public struct ReviewScore: Equatable, Sendable {
    public let value: Int
    public let evaluatedCriteria: Int
    public let totalCriteria: Int

    public init(value: Int, evaluatedCriteria: Int, totalCriteria: Int) {
        self.value = min(100, max(0, value))
        self.evaluatedCriteria = max(0, evaluatedCriteria)
        self.totalCriteria = max(evaluatedCriteria, totalCriteria)
    }

    public init(issues: [ViewLensIssue], evaluatedCriteria: Int, totalCriteria: Int) {
        let errors = issues.filter { $0.severity == .error }.count
        let warnings = issues.filter { $0.severity == .warning }.count
        let info = issues.filter { $0.severity == .info }.count
        self.init(
            value: 100 - (errors * 12) - (warnings * 5) - info,
            evaluatedCriteria: evaluatedCriteria,
            totalCriteria: totalCriteria
        )
    }

    public var isComplete: Bool { totalCriteria > 0 && evaluatedCriteria == totalCriteria }
    public var completenessText: String { "\(evaluatedCriteria)/\(totalCriteria) criteria evaluated" }
}

public struct ReviewFinding: Identifiable, Equatable, Sendable {
    public typealias ID = String

    public let id: ID
    public let issue: ViewLensIssue

    public init(issue: ViewLensIssue, occurrence: Int) {
        let parts = [
            issue.identifier ?? "element-\(issue.elementIndex ?? -1)",
            issue.kind.rawValue,
            issue.wcagCriterion ?? "no-criterion",
            String(occurrence)
        ]
        self.id = parts.joined(separator: "|")
        self.issue = issue
    }

    public init(id: ID, issue: ViewLensIssue) {
        self.id = id
        self.issue = issue
    }
}

public struct ReviewEvent: Identifiable, Equatable, Sendable {
    public let id: UUID
    public let timestamp: Date
    public let phase: ReviewPhase?
    public let message: String
    public let isError: Bool

    public init(id: UUID = UUID(), timestamp: Date = Date(), phase: ReviewPhase? = nil, message: String, isError: Bool = false) {
        self.id = id
        self.timestamp = timestamp
        self.phase = phase
        self.message = message
        self.isError = isError
    }
}

public struct ReviewRecord: Identifiable, Sendable {
    public let id: UUID
    public let source: ReviewSource
    public var status: ReviewStatus
    public let environment: ReviewEnvironment
    public var score: ReviewScore?
    public var findings: [ReviewFinding]
    public var elements: [DetectedElement]
    public var previewImage: CGImage?
    public var nonvisualScreenModel: NonvisualScreenModel?
    public let startedAt: Date
    public var finishedAt: Date?
    public var duration: TimeInterval?

    public init(
        id: UUID = UUID(),
        source: ReviewSource,
        status: ReviewStatus = .preparing,
        environment: ReviewEnvironment,
        score: ReviewScore? = nil,
        findings: [ReviewFinding] = [],
        elements: [DetectedElement] = [],
        previewImage: CGImage? = nil,
        nonvisualScreenModel: NonvisualScreenModel? = nil,
        startedAt: Date = Date(),
        finishedAt: Date? = nil,
        duration: TimeInterval? = nil
    ) {
        self.id = id
        self.source = source
        self.status = status
        self.environment = environment
        self.score = score
        self.findings = findings
        self.elements = elements
        self.previewImage = previewImage
        self.nonvisualScreenModel = nonvisualScreenModel
        self.startedAt = startedAt
        self.finishedAt = finishedAt
        self.duration = duration
    }
}

public enum FindingStandard: String, CaseIterable, Identifiable, Sendable {
    case all = "All Standards"
    case wcag = "WCAG"
    case hig = "Apple HIG"

    public var id: String { rawValue }
}

public struct FindingFilter: Equatable, Sendable {
    public var searchText = ""
    public var severities: Set<ViewLensSeverity> = []
    public var standard: FindingStandard = .all
    public var criterion: String?
    public var elementIndex: Int?

    public init() {}

    public func matches(_ finding: ReviewFinding) -> Bool {
        let issue = finding.issue
        if !severities.isEmpty && !severities.contains(issue.severity) { return false }
        if standard == .wcag && issue.wcagCriterion == nil { return false }
        if standard == .hig && issue.wcagCriterion != nil { return false }
        if let criterion, issue.wcagCriterion != criterion { return false }
        if let elementIndex, issue.elementIndex != elementIndex { return false }
        if !searchText.isEmpty {
            let matchesText = issue.displayTitle.localizedStandardContains(searchText)
                || issue.description.localizedStandardContains(searchText)
                || (issue.wcagCriterion?.localizedStandardContains(searchText) ?? false)
            if !matchesText { return false }
        }
        return true
    }
}

/// Represents an MCP tool invocation recorded by the live agent monitor.
public struct MCPAgentActivity: Identifiable, Sendable {
    public let id: UUID
    public let timestamp: Date
    public let toolName: String
    public let argumentsDescription: String
    public let duration: TimeInterval
    public let passed: Bool
    public let summary: String
    public let previewImage: CGImage?
    public let auditReport: AuditReport?
    public let reviewID: UUID?

    public init(
        id: UUID = UUID(),
        timestamp: Date = Date(),
        toolName: String,
        argumentsDescription: String,
        duration: TimeInterval,
        passed: Bool,
        summary: String,
        previewImage: CGImage? = nil,
        auditReport: AuditReport? = nil,
        reviewID: UUID? = nil
    ) {
        self.id = id
        self.timestamp = timestamp
        self.toolName = toolName
        self.argumentsDescription = argumentsDescription
        self.duration = duration
        self.passed = passed
        self.summary = summary
        self.previewImage = previewImage
        self.auditReport = auditReport
        self.reviewID = reviewID
    }
}
