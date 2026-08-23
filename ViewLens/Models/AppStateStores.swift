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
}

@MainActor
@Observable
final class NavigationStore {
    var destination: AppDestination? = .currentStatus
    var showsInspector = true
    var showsImporter = false
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
    public var selectedTemplateName = "LoginForm"
    public var selectedDevice: DeviceProfile = .iPhone16Pro
    public var selectedDynamicType: DynamicTypeSize = .large
    public var selectedColorScheme: ColorScheme = .light

    public init() {}
}

@MainActor
@Observable
final class HistoryStore {
    var searchText = ""

    func filteredActivities(from activities: [MCPAgentActivity]) -> [MCPAgentActivity] {
        guard !searchText.isEmpty else { return activities }
        return activities.filter {
            $0.toolName.localizedStandardContains(searchText) ||
            $0.summary.localizedStandardContains(searchText) ||
            $0.argumentsDescription.localizedStandardContains(searchText)
        }
    }
}

@MainActor
@Observable
final class PreferenceStore {
    private enum Key {
        static let appearance = "viewlens.appearance"
        static let wcagLevel = "viewlens.defaultWCAGLevel"
        static let confirmCancellation = "viewlens.confirmCancellation"
        static let autoRunPlayground = "viewlens.autoRunPlayground"
        static let historyRetention = "viewlens.historyRetention"
    }

    var appearance: String { didSet { defaults.set(appearance, forKey: Key.appearance) } }
    var wcagLevel: String { didSet { defaults.set(wcagLevel, forKey: Key.wcagLevel) } }
    var confirmCancellation: Bool { didSet { defaults.set(confirmCancellation, forKey: Key.confirmCancellation) } }
    var autoRunPlayground: Bool { didSet { defaults.set(autoRunPlayground, forKey: Key.autoRunPlayground) } }
    var historyRetention: String { didSet { defaults.set(historyRetention, forKey: Key.historyRetention) } }

    @ObservationIgnored private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        appearance = defaults.string(forKey: Key.appearance) ?? "System"
        wcagLevel = defaults.string(forKey: Key.wcagLevel) ?? "AA"
        confirmCancellation = defaults.object(forKey: Key.confirmCancellation) as? Bool ?? true
        autoRunPlayground = defaults.object(forKey: Key.autoRunPlayground) as? Bool ?? false
        historyRetention = defaults.string(forKey: Key.historyRetention) ?? "30 days"
    }
}
