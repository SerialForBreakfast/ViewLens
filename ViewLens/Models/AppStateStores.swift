import Foundation
import SwiftUI
import ViewLensKit

enum AppDestination: String, CaseIterable, Identifiable {
    case currentStatus = "Current Status"
    case aiReview = "AI Review"
    case playground = "Playground"
    case history = "History"
    case settings = "Settings"

    var id: String { rawValue }

    var symbol: String {
        switch self {
        case .currentStatus: return "waveform.path.ecg"
        case .aiReview: return "sparkles"
        case .playground: return "flask"
        case .history: return "clock.arrow.circlepath"
        case .settings: return "gearshape"
        }
    }

    var accessibilityIdentifier: String {
        switch self {
        case .currentStatus: return "navigation.currentStatus"
        case .aiReview: return "navigation.aiReview"
        case .playground: return "navigation.playground"
        case .history: return "navigation.history"
        case .settings: return "navigation.settings"
        }
    }
}

@MainActor
@Observable
final class NavigationStore {
    var destination: AppDestination? { didSet { if let destination { UserDefaults.standard.set(destination.rawValue, forKey: "viewlens.lastDestination") } } }
    var showsInspector = true
    var showsImporter = false

    init(defaults: UserDefaults = .standard) {
        if defaults.string(forKey: "viewlens.launchDestination") == "Last-open screen",
           let raw = defaults.string(forKey: "viewlens.lastDestination"), let saved = AppDestination(rawValue: raw) {
            destination = saved
        } else { destination = .currentStatus }
    }
}

@MainActor
@Observable
public final class SystemHealthStore {
    public var mcpStatus = "Listening (stdio)"
    public var doctorReport: DoctorReport?
    public var isRunningDoctor = false

    public init() {}
}

@MainActor
@Observable
public final class PlaygroundStore {
    public enum Mode: String, CaseIterable, Identifiable {
        case importFile = "Import File"
        case template = "Template"
        public var id: String { rawValue }
    }

    public enum DisplayScale: String, CaseIterable, Identifiable {
        case automatic = "Auto"
        case one = "1×"
        case two = "2×"
        case three = "3×"
        public var id: String { rawValue }
        public var value: Double? { switch self { case .automatic: nil; case .one: 1; case .two: 2; case .three: 3 } }
    }

    public var mode: Mode = .importFile
    public var selectedFileURL: URL?
    public var importError: String?
    public var displayScale: DisplayScale = .automatic
    public var wcagLevel = "AA"
    public var optionalDeviceID: String?
    public var minimumConfidence = 0.15
    public var selectedTemplateName = "LoginForm"
    public var selectedDevice: DeviceProfile = .iPhone16Pro
    public var selectedDynamicType: DynamicTypeSize = .large
    public var selectedColorScheme: ColorScheme = .light
    public var selectedDeviceIDs: Set<String> = [DeviceProfile.iPhone16Pro.id]
    public var selectedDynamicTypeNames: Set<String> = ["large"]
    public var selectedAppearanceNames: Set<String> = ["light"]
    public var isDropTargeted = false

    public init() {}
}

enum HistoryReviewFilter: String, CaseIterable, Identifiable {
    case all = "All"
    case complete = "Complete"
    case incomplete = "Incomplete"
    case issues = "Has Findings"
    case screenshots = "Screenshots"
    case templates = "Templates"
    var id: String { rawValue }
}

@MainActor
@Observable
final class HistoryStore {
    var searchText = ""
    var filter: HistoryReviewFilter = .all
    var selectedReviewIDs: Set<UUID> = []
    var reviewPendingDeletion: ReviewRecord?
    var showsComparison = false
    var exportReview: ReviewRecord?

    func filteredReviews(from reviews: [ReviewRecord]) -> [ReviewRecord] {
        reviews.filter { review in
            let matchesSearch = searchText.isEmpty
                || review.source.displayName.localizedStandardContains(searchText)
                || review.source.sourceType.localizedStandardContains(searchText)
                || review.status.displayName.localizedStandardContains(searchText)
            guard matchesSearch else { return false }
            switch filter {
            case .all: return true
            case .complete: return review.status == .completed
            case .incomplete:
                if case .incomplete = review.status { return true }
                if case .stale = review.status { return true }
                return false
            case .issues: return !review.findings.isEmpty
            case .screenshots: if case .image = review.source { return true }; return false
            case .templates: if case .template = review.source { return true }; return false
            }
        }
    }
}

enum DashboardReviewFilter: String, CaseIterable, Identifiable {
    case all = "All"
    case passed = "Passed"
    case issues = "Has Issues"
    case incomplete = "Incomplete"

    var id: String { rawValue }
}

enum DashboardReviewSort: String, CaseIterable, Identifiable {
    case newest = "Newest"
    case oldest = "Oldest"
    case scoreHigh = "Highest Score"
    case scoreLow = "Lowest Score"
    case name = "Name"

    var id: String { rawValue }
}

@MainActor
@Observable
final class CurrentStatusStore {
    var searchText = ""
    var filter: DashboardReviewFilter = .all
    var sort: DashboardReviewSort = .newest
    var selectedReviewID: UUID?
    var isDropTargeted = false
    var showsDiagnostics = false

    func visibleReviews(from reviews: [ReviewRecord]) -> [ReviewRecord] {
        reviews
            .filter(matches)
            .sorted(by: precedes)
    }

    func passRate(for reviews: [ReviewRecord]) -> Int? {
        let complete = reviews.filter { $0.score?.isComplete == true }
        guard !complete.isEmpty else { return nil }
        let passing = complete.filter { ($0.score?.value ?? 0) >= 90 }.count
        return Int((Double(passing) / Double(complete.count) * 100).rounded())
    }

    private func matches(_ review: ReviewRecord) -> Bool {
        if !searchText.isEmpty,
           !review.source.displayName.localizedStandardContains(searchText),
           !review.source.sourceType.localizedStandardContains(searchText) {
            return false
        }

        switch filter {
        case .all:
            return true
        case .passed:
            return review.status == .completed && (review.score?.value ?? 0) >= 90
        case .issues:
            return !review.findings.isEmpty
        case .incomplete:
            if case .incomplete = review.status { return true }
            if case .stale = review.status { return true }
            return false
        }
    }

    private func precedes(_ lhs: ReviewRecord, _ rhs: ReviewRecord) -> Bool {
        switch sort {
        case .newest: return lhs.startedAt > rhs.startedAt
        case .oldest: return lhs.startedAt < rhs.startedAt
        case .scoreHigh: return (lhs.score?.value ?? -1) > (rhs.score?.value ?? -1)
        case .scoreLow: return (lhs.score?.value ?? 101) < (rhs.score?.value ?? 101)
        case .name: return lhs.source.displayName.localizedStandardCompare(rhs.source.displayName) == .orderedAscending
        }
    }
}

@MainActor
@Observable
public final class PreferenceStore {
    private enum Key {
        static let appearance = "viewlens.appearance"
        static let wcagLevel = "viewlens.defaultWCAGLevel"
        static let confirmCancellation = "viewlens.confirmCancellation"
        static let autoRunPlayground = "viewlens.autoRunPlayground"
        static let historyRetention = "viewlens.historyRetention"
        static let launchDestination = "viewlens.launchDestination"
        static let showMenuBarItem = "viewlens.showMenuBarItem"
        static let targetSizePolicy = "viewlens.targetSizePolicy"
        static let failureSeverity = "viewlens.failureSeverity"
        static let detectorConfidence = "viewlens.detectorConfidence"
        static let assetRetention = "viewlens.assetRetention"
        static let requiredMatrix = "viewlens.requiredMatrix"
        static let customRulePath = "viewlens.customRulePath"
        static let differentiateWithoutColor = "viewlens.differentiateWithoutColor"
        static let nonvisualProfile = "viewlens.nonvisualProfile"
        static let announcePhaseChanges = "viewlens.announcePhaseChanges"
    }

    var appearance: String { didSet { defaults.set(appearance, forKey: Key.appearance) } }
    var wcagLevel: String { didSet { defaults.set(wcagLevel, forKey: Key.wcagLevel) } }
    var confirmCancellation: Bool { didSet { defaults.set(confirmCancellation, forKey: Key.confirmCancellation) } }
    var autoRunPlayground: Bool { didSet { defaults.set(autoRunPlayground, forKey: Key.autoRunPlayground) } }
    var historyRetention: String { didSet { defaults.set(historyRetention, forKey: Key.historyRetention) } }
    var launchDestination: String { didSet { defaults.set(launchDestination, forKey: Key.launchDestination) } }
    var showMenuBarItem: Bool { didSet { defaults.set(showMenuBarItem, forKey: Key.showMenuBarItem) } }
    var targetSizePolicy: String { didSet { defaults.set(targetSizePolicy, forKey: Key.targetSizePolicy) } }
    var failureSeverity: String { didSet { defaults.set(failureSeverity, forKey: Key.failureSeverity) } }
    var detectorConfidence: Double { didSet { defaults.set(detectorConfidence, forKey: Key.detectorConfidence) } }
    var assetRetention: String { didSet { defaults.set(assetRetention, forKey: Key.assetRetention) } }
    var requiredMatrix: String { didSet { defaults.set(requiredMatrix, forKey: Key.requiredMatrix) } }
    var customRulePath: String { didSet { defaults.set(customRulePath, forKey: Key.customRulePath) } }
    var differentiateWithoutColor: Bool { didSet { defaults.set(differentiateWithoutColor, forKey: Key.differentiateWithoutColor) } }
    var nonvisualProfile: String { didSet { defaults.set(nonvisualProfile, forKey: Key.nonvisualProfile) } }
    var announcePhaseChanges: Bool { didSet { defaults.set(announcePhaseChanges, forKey: Key.announcePhaseChanges) } }

    @ObservationIgnored private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        appearance = defaults.string(forKey: Key.appearance) ?? "System"
        wcagLevel = defaults.string(forKey: Key.wcagLevel) ?? "AA"
        confirmCancellation = defaults.object(forKey: Key.confirmCancellation) as? Bool ?? true
        autoRunPlayground = defaults.object(forKey: Key.autoRunPlayground) as? Bool ?? false
        historyRetention = defaults.string(forKey: Key.historyRetention) ?? "30 days"
        launchDestination = defaults.string(forKey: Key.launchDestination) ?? AppDestination.currentStatus.rawValue
        showMenuBarItem = defaults.object(forKey: Key.showMenuBarItem) as? Bool ?? false
        targetSizePolicy = defaults.string(forKey: Key.targetSizePolicy) ?? "WCAG 2.5.8 (24 pt)"
        failureSeverity = defaults.string(forKey: Key.failureSeverity) ?? "Error"
        detectorConfidence = defaults.object(forKey: Key.detectorConfidence) as? Double ?? 0.15
        assetRetention = defaults.string(forKey: Key.assetRetention) ?? "With review"
        requiredMatrix = defaults.string(forKey: Key.requiredMatrix) ?? "Standard"
        customRulePath = defaults.string(forKey: Key.customRulePath) ?? ""
        differentiateWithoutColor = defaults.object(forKey: Key.differentiateWithoutColor) as? Bool ?? true
        nonvisualProfile = defaults.string(forKey: Key.nonvisualProfile) ?? "Speech"
        announcePhaseChanges = defaults.object(forKey: Key.announcePhaseChanges) as? Bool ?? true
    }

    var retentionDays: Int? {
        switch historyRetention { case "7 days": return 7; case "30 days": return 30; case "90 days": return 90; default: return nil }
    }
}
