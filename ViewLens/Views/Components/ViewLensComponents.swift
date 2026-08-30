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
    let status: ReviewStatus

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
        switch status {
        case .completed, .incomplete, .stale: return phases.count - 1
        case .running(let phase): return max(0, activeIndex(for: phase))
        default: return 0
        }
    }

    private func state(for index: Int) -> (color: Color, symbol: String, label: String, isActive: Bool) {
        switch status {
        case .completed:
            return (.green, "checkmark", "Complete", index == phases.count - 1)
        case .incomplete:
            return (index == phases.count - 1 ? .orange : .green, index == phases.count - 1 ? "exclamationmark" : "checkmark", index == phases.count - 1 ? "Complete with limited coverage" : "Complete", index == phases.count - 1)
        case .stale:
            return (index == phases.count - 1 ? .orange : .green, index == phases.count - 1 ? "clock" : "checkmark", index == phases.count - 1 ? "Stale" : "Complete", index == phases.count - 1)
        case .running(let phase):
            let activeIndex = activeIndex(for: phase)
            if index < activeIndex { return (.green, "checkmark", "Complete", false) }
            if index == activeIndex { return (ViewLensTheme.focus, "ellipsis", "In progress", true) }
        case .failed:
            return (index == completedPhaseCount ? .red : .secondary, index == completedPhaseCount ? "xmark" : "circle", index == completedPhaseCount ? "Failed" : "Pending", index == completedPhaseCount)
        case .cancelled:
            return (.secondary, index == completedPhaseCount ? "stop.fill" : "circle", index == completedPhaseCount ? "Cancelled" : "Pending", index == completedPhaseCount)
        case .preparing, .queued:
            if index == 0 { return (ViewLensTheme.focus, "ellipsis", status.displayName, true) }
        case .idle:
            break
        }
        return (.secondary, "circle", "Pending", false)
    }

    private func activeIndex(for phase: ReviewPhase) -> Int {
        switch phase {
        case .preparing, .rendering: return 0
        case .detecting: return 1
        case .evaluating: return 2
        case .reviewing: return 3
        case .complete: return 4
        }
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

// MARK: - Section 6: Standard Design System Components

/// Circular score display with completeness tracking and accessible announcements.
public struct ScoreRing: View {
    public let score: Int
    public let evaluatedCriteriaCount: Int
    public let totalCriteriaCount: Int
    public var size: CGFloat = 64

    public init(
        score: Int,
        evaluatedCriteriaCount: Int = 8,
        totalCriteriaCount: Int = 8,
        size: CGFloat = 64
    ) {
        self.score = max(0, min(100, score))
        self.evaluatedCriteriaCount = evaluatedCriteriaCount
        self.totalCriteriaCount = max(1, totalCriteriaCount)
        self.size = size
    }

    private var scoreColor: Color {
        if score >= 90 { return .green }
        if score >= 70 { return .orange }
        return .red
    }

    public var body: some View {
        ZStack {
            // Background track
            Circle()
                .stroke(Color.secondary.opacity(0.18), lineWidth: size * 0.1)

            // Progress indicator
            Circle()
                .trim(from: 0, to: CGFloat(score) / 100.0)
                .stroke(scoreColor, style: StrokeStyle(lineWidth: size * 0.1, lineCap: .round))
                .rotationEffect(.degrees(-90))

            // Score text
            VStack(spacing: 0) {
                Text("\(score)")
                    .font(.system(size: size * 0.36, weight: .bold, design: .rounded))
                    .foregroundColor(.primary)
            }
        }
        .frame(width: size, height: size)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Accessibility Score")
        .accessibilityValue("\(score) out of 100. \(evaluatedCriteriaCount) of \(totalCriteriaCount) criteria evaluated.")
    }
}

/// Standard reference badge for WCAG and Apple HIG criteria.
public struct CriterionBadge: View {
    public let standard: String
    public let level: String?

    public init(standard: String, level: String? = "AA") {
        self.standard = standard
        self.level = level
    }

    public var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "checkmark.shield")
                .font(.caption2)
            Text(level != nil ? "\(standard) \(level!)" : standard)
                .font(.caption.weight(.medium))
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color.secondary.opacity(0.12), in: Capsule())
        .overlay(Capsule().stroke(Color.secondary.opacity(0.24), lineWidth: 1))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Standard")
        .accessibilityValue(level != nil ? "\(standard) Level \(level!)" : standard)
    }
}

/// Finding priority badge (Critical, Serious, Moderate, Minor, Info).
public struct SeverityBadge: View {
    public let severity: ViewLensSeverity

    public init(severity: ViewLensSeverity) {
        self.severity = severity
    }

    private var color: Color {
        switch severity {
        case .error: return .red
        case .warning: return .orange
        case .info: return .blue
        }
    }

    private var symbol: String {
        switch severity {
        case .error: return "xmark.octagon.fill"
        case .warning: return "exclamationmark.triangle.fill"
        case .info: return "info.circle.fill"
        }
    }

    public var body: some View {
        Label(severity.displayName, systemImage: symbol)
            .font(.caption.weight(.semibold))
            .foregroundColor(color)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(color.opacity(0.12), in: RoundedRectangle(cornerRadius: ViewLensTheme.controlCornerRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: ViewLensTheme.controlCornerRadius, style: .continuous)
                    .stroke(color.opacity(0.3), lineWidth: 1)
            )
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Severity")
            .accessibilityValue(severity.displayName)
    }
}

/// Multi-state contextual notice banner.
public struct BannerNotice: View {
    public enum BannerType {
        case info
        case warning
        case error
        case incomplete

        var color: Color {
            switch self {
            case .info: return ViewLensTheme.focus
            case .warning, .incomplete: return .orange
            case .error: return .red
            }
        }

        var symbol: String {
            switch self {
            case .info: return "info.circle.fill"
            case .warning, .incomplete: return "exclamationmark.triangle.fill"
            case .error: return "xmark.octagon.fill"
            }
        }
    }

    public let type: BannerType
    public let title: String
    public let message: String
    public var actionTitle: String?
    public var action: (() -> Void)?

    public init(
        type: BannerType,
        title: String,
        message: String,
        actionTitle: String? = nil,
        action: (() -> Void)? = nil
    ) {
        self.type = type
        self.title = title
        self.message = message
        self.actionTitle = actionTitle
        self.action = action
    }

    public var body: some View {
        HStack(alignment: .top, spacing: ViewLensTheme.compactSpacing) {
            Image(systemName: type.symbol)
                .font(.headline)
                .foregroundColor(type.color)
                .padding(.top, 2)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                Text(message)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            if let actionTitle = actionTitle, let action = action {
                Button(actionTitle, action: action)
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
            }
        }
        .padding(ViewLensTheme.cardPadding)
        .background(type.color.opacity(0.08), in: RoundedRectangle(cornerRadius: ViewLensTheme.panelCornerRadius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: ViewLensTheme.panelCornerRadius, style: .continuous)
                .stroke(type.color.opacity(0.3), lineWidth: 1)
        )
        .accessibilityElement(children: .combine)
    }
}

/// Standardized empty state component for ViewLens workspaces.
public struct EmptyStateView: View {
    public let symbol: String
    public let title: String
    public let description: String
    public var buttonTitle: String?
    public var buttonAction: (() -> Void)?

    public init(
        symbol: String,
        title: String,
        description: String,
        buttonTitle: String? = nil,
        buttonAction: (() -> Void)? = nil
    ) {
        self.symbol = symbol
        self.title = title
        self.description = description
        self.buttonTitle = buttonTitle
        self.buttonAction = buttonAction
    }

    public var body: some View {
        VStack(spacing: ViewLensTheme.standardSpacing) {
            Image(systemName: symbol)
                .font(.system(size: 40))
                .foregroundColor(.secondary)

            VStack(spacing: ViewLensTheme.microSpacing) {
                Text(title)
                    .font(.headline)
                Text(description)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 320)
            }

            if let buttonTitle = buttonTitle, let buttonAction = buttonAction {
                Button(buttonTitle, action: buttonAction)
                    .buttonStyle(.borderedProminent)
                    .padding(.top, ViewLensTheme.compactSpacing)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(ViewLensTheme.majorSpacing)
        .accessibilityElement(children: .combine)
    }
}

