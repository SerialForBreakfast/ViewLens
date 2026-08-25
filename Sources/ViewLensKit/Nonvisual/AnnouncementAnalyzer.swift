import Foundation

/// Record of an individual accessibility speech announcement.
public struct AccessibilityAnnouncementRecord: Codable, Sendable, Equatable, Identifiable {
    public let id: UUID
    public let timestamp: TimeInterval
    public let message: String
    public let priority: String
    public let sourceElementID: NonvisualID?

    public init(
        id: UUID = UUID(),
        timestamp: TimeInterval,
        message: String,
        priority: String = "medium",
        sourceElementID: NonvisualID? = nil
    ) {
        self.id = id
        self.timestamp = timestamp
        self.message = message
        self.priority = priority
        self.sourceElementID = sourceElementID
    }
}

/// Potential issues detected in accessibility announcement sequences.
public enum AnnouncementDefectKind: String, Codable, Sendable, Equatable, Hashable, CaseIterable {
    case rapidBurst = "rapid_burst"
    case duplicateConsecutive = "duplicate_consecutive"
    case emptyMessage = "empty_message"
    case outOfOrder = "out_of_order"
}

/// An individual announcement quality defect.
public struct AnnouncementDefect: Codable, Sendable, Equatable, Identifiable {
    public var id: String { "\(kind.rawValue):\(announcementIDs.map(\.uuidString).joined(separator: "-"))" }
    public let kind: AnnouncementDefectKind
    public let announcementIDs: [UUID]
    public let description: String
    public let recommendation: String

    public init(
        kind: AnnouncementDefectKind,
        announcementIDs: [UUID],
        description: String,
        recommendation: String
    ) {
        self.kind = kind
        self.announcementIDs = announcementIDs
        self.description = description
        self.recommendation = recommendation
    }
}

/// Results of accessibility announcement analysis.
public struct AnnouncementAnalysisResult: Codable, Sendable, Equatable {
    public let totalAnnouncements: Int
    public let defects: [AnnouncementDefect]
    public let throttledAnnouncements: [AccessibilityAnnouncementRecord]

    public init(
        totalAnnouncements: Int,
        defects: [AnnouncementDefect] = [],
        throttledAnnouncements: [AccessibilityAnnouncementRecord] = []
    ) {
        self.totalAnnouncements = totalAnnouncements
        self.defects = defects
        self.throttledAnnouncements = throttledAnnouncements
    }

    public var passed: Bool {
        defects.isEmpty
    }
}

/// Analyzes sequences of accessibility announcements for rate-limiting, deduplication, and ordering issues.
public enum AnnouncementAnalyzer {

    public static func analyze(
        announcements: [AccessibilityAnnouncementRecord],
        minimumIntervalSeconds: TimeInterval = 0.5
    ) -> AnnouncementAnalysisResult {
        var defects: [AnnouncementDefect] = []
        var throttled: [AccessibilityAnnouncementRecord] = []

        var lastAccepted: AccessibilityAnnouncementRecord?

        for (index, current) in announcements.enumerated() {
            // 1. Check for empty messages
            let trimmed = current.message.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.isEmpty {
                defects.append(AnnouncementDefect(
                    kind: .emptyMessage,
                    announcementIDs: [current.id],
                    description: "Empty accessibility announcement at timestamp \(current.timestamp)s",
                    recommendation: "Avoid posting empty announcements that interrupt VoiceOver without providing context."
                ))
                continue
            }

            // 2. Check for out-of-order timestamps
            if let last = lastAccepted, current.timestamp < last.timestamp {
                defects.append(AnnouncementDefect(
                    kind: .outOfOrder,
                    announcementIDs: [last.id, current.id],
                    description: "Announcement out of chronological sequence (\(current.timestamp)s followed \(last.timestamp)s)",
                    recommendation: "Ensure asynchronous state updates post announcements in strictly sequential order."
                ))
            }

            // 3. Check for immediate duplicate consecutive messages
            if let last = lastAccepted, last.message.lowercased() == current.message.lowercased() {
                defects.append(AnnouncementDefect(
                    kind: .duplicateConsecutive,
                    announcementIDs: [last.id, current.id],
                    description: "Duplicate consecutive announcement: '\(current.message)'",
                    recommendation: "Suppress redundant duplicate announcements unless state has materially changed."
                ))
                continue
            }

            // 4. Check for rapid unthrottled bursts
            if let last = lastAccepted {
                let delta = current.timestamp - last.timestamp
                if delta < minimumIntervalSeconds && current.priority != "high" {
                    defects.append(AnnouncementDefect(
                        kind: .rapidBurst,
                        announcementIDs: [last.id, current.id],
                        description: "Rapid announcement burst (\(String(format: "%.2f", delta))s < \(minimumIntervalSeconds)s)",
                        recommendation: "Throttle high-frequency status announcements using debounce or phase transitions."
                    ))
                    // Throttle this burst item
                    continue
                }
            }

            throttled.append(current)
            lastAccepted = current
        }

        return AnnouncementAnalysisResult(
            totalAnnouncements: announcements.count,
            defects: defects,
            throttledAnnouncements: throttled
        )
    }
}
