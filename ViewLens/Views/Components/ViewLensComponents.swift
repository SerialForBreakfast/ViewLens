import SwiftUI
import ViewLensKit

enum ViewLensHealthState: String {
    case ready = "Ready"
    case busy = "Working"
    case warning = "Attention"
    case error = "Unavailable"

    var color: Color {
        switch self {
        case .ready: return .green
        case .busy: return ViewLensTheme.focus
        case .warning: return .orange
        case .error: return .red
        }
    }

    var symbol: String {
        switch self {
        case .ready: return "checkmark.circle.fill"
        case .busy: return "arrow.triangle.2.circlepath"
        case .warning: return "exclamationmark.triangle.fill"
        case .error: return "xmark.octagon.fill"
        }
    }
}

struct HealthPill: View {
    let title: String
    let state: ViewLensHealthState

    var body: some View {
        Label(title, systemImage: state.symbol)
            .font(.caption.weight(.medium))
            .foregroundStyle(state.color)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(state.color.opacity(0.12), in: Capsule())
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(title)
            .accessibilityValue(state.rawValue)
    }
}

struct StatusMetricCard: View {
    let title: String
    let value: String
    let detail: String
    let symbol: String
    let state: ViewLensHealthState

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: symbol)
                    .font(.title2)
                    .foregroundStyle(state.color)
                    .frame(width: 32, height: 32)

                Spacer()

                Image(systemName: state.symbol)
                    .foregroundStyle(state.color)
                    .accessibilityHidden(true)
            }

            Text(value)
                .font(.system(.title2, design: .rounded, weight: .semibold))
                .lineLimit(1)

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.headline)
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 126, alignment: .leading)
        .viewLensPanel()
        .accessibilityElement(children: .combine)
        .accessibilityValue("\(value), \(state.rawValue). \(detail)")
    }
}

struct SeverityCount: View {
    let title: String
    let count: Int
    let color: Color

    var body: some View {
        HStack(spacing: 7) {
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)
                .accessibilityHidden(true)
            Text("\(count)")
                .font(.headline.monospacedDigit())
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(count) \(title)")
    }
}

struct ReviewPhaseTimeline: View {
    let isRunning: Bool
    let hasResult: Bool

    private let phases = ["Import", "Detect", "Evaluate", "AI Review", "Complete"]

    var body: some View {
        HStack(spacing: 0) {
            ForEach(Array(phases.enumerated()), id: \.offset) { index, phase in
                let phaseState = state(for: index)

                HStack(spacing: 0) {
                    VStack(spacing: 6) {
                        ZStack {
                            Circle()
                                .fill(phaseState.color.opacity(0.16))
                                .frame(width: 28, height: 28)
                            Image(systemName: phaseState.symbol)
                                .font(.caption.weight(.bold))
                                .foregroundStyle(phaseState.color)
                        }
                        Text(phase)
                            .font(.caption2)
                            .foregroundStyle(phaseState.isActive ? .primary : .secondary)
                            .lineLimit(1)
                    }
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel(phase)
                    .accessibilityValue(phaseState.label)

                    if index < phases.count - 1 {
                        Rectangle()
                            .fill(index < completedPhaseCount ? Color.green : Color.secondary.opacity(0.25))
                            .frame(height: 2)
                            .padding(.horizontal, 5)
                            .padding(.bottom, 20)
                    }
                }
                .frame(maxWidth: .infinity)
            }
        }
    }

    private var completedPhaseCount: Int {
        if hasResult { return phases.count - 1 }
        if isRunning { return 2 }
        return 0
    }

    private func state(for index: Int) -> (color: Color, symbol: String, label: String, isActive: Bool) {
        if hasResult {
            return (.green, "checkmark", "Complete", index == phases.count - 1)
        }
        if isRunning {
            if index < 2 { return (.green, "checkmark", "Complete", false) }
            if index == 2 { return (ViewLensTheme.focus, "ellipsis", "In progress", true) }
        }
        return (.secondary, "circle", "Pending", false)
    }
}

extension ViewLensIssue {
    var displayTitle: String {
        switch kind {
        case .tappableTargetTooSmall: return "Touch Target Too Small"
        case .clippedElement: return "Clipped Element"
        case .overlappingElements: return "Overlapping Elements"
        case .offScreen: return "Element Off Screen"
        case .ambiguousAutoLayout: return "Ambiguous Layout"
        case .missingAccessibilityLabel: return "Missing Accessibility Label"
        case .missingAccessibilityTrait: return "Missing Accessibility Trait"
        case .textTruncated: return "Text Truncated"
        case .contrastRisk: return "Low Color Contrast"
        case .dynamicTypeOverflow: return "Dynamic Type Overflow"
        case .customRuleViolation: return "Custom Rule Violation"
        }
    }
}
