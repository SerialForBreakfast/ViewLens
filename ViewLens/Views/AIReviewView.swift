import SwiftUI
import ViewLensKit

struct AIReviewView: View {
    @Bindable var model: AppModel
    @Binding var showsInspector: Bool
    let onImport: () -> Void

    private var errorCount: Int { model.currentIssues.filter { $0.severity == .error }.count }
    private var warningCount: Int { model.currentIssues.filter { $0.severity == .warning }.count }
    private var infoCount: Int { model.currentIssues.filter { $0.severity == .info }.count }
    private var score: Int { model.reviewStore.activeReview?.score?.value ?? max(0, 100 - (errorCount * 12) - (warningCount * 5) - infoCount) }
    private var hasResult: Bool { model.currentImage != nil }
    private var reviewStatus: ReviewStatus { model.reviewStore.activeReview?.status ?? .idle }

    var body: some View {
        VStack(spacing: 0) {
            reviewHeader
            reviewStateBanner
            Divider()

            if hasResult {
                HSplitView {
                    VisualInspectorView(model: model)
                        .frame(minWidth: 520)

                    if showsInspector {
                        AIReviewInspector(model: model)
                            .frame(minWidth: 300, idealWidth: 340, maxWidth: 420)
                    }
                }
            } else {
                ContentUnavailableView {
                    Label(reviewStatus.isRunning ? "Review in Progress" : "No AI Review Selected", systemImage: reviewStatus.isRunning ? "sparkles" : "sparkles.rectangle.stack")
                } description: {
                    Text(reviewStatus.isRunning ? reviewStatus.displayName : "Import a screenshot or run a Playground template to begin an accessibility review.")
                } actions: {
                    if reviewStatus.isRunning {
                        Button("Cancel Review", role: .cancel) { model.cancelActiveReview() }
                    } else {
                        Button("Import & Validate", action: onImport)
                            .buttonStyle(.borderedProminent)
                    }
                }
            }
        }
        .background(Color(nsColor: .windowBackgroundColor))
        .navigationTitle("AI Review")
    }

    private var reviewHeader: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top, spacing: 20) {
                VStack(alignment: .leading, spacing: 4) {
                    Label("AI Review", systemImage: "sparkles")
                        .font(.title.bold())
                    Text(model.activeActivity?.auditReport?.target ?? "AI-assisted WCAG 2.2 and Apple HIG audit")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Spacer()

                if reviewStatus.isRunning {
                    Button("Cancel", role: .cancel) {
                        model.cancelActiveReview()
                    }
                    .help("Cancel the active review and preserve the previous completed result")
                }

                if hasResult {
                    VStack(alignment: .trailing, spacing: 2) {
                        HStack(alignment: .firstTextBaseline, spacing: 5) {
                            Text("\(score)")
                                .font(.system(.largeTitle, design: .rounded, weight: .bold))
                                .foregroundStyle(score >= 90 ? .green : (score >= 70 ? .orange : .red))
                            Text("/ 100")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Text("\(model.currentIssues.count) findings · \(model.reviewStore.activeReview?.score?.completenessText ?? "Coverage unavailable")")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel("Accessibility score")
                    .accessibilityValue("\(score) out of 100, \(model.currentIssues.count) findings, \(model.reviewStore.activeReview?.score?.completenessText ?? "coverage unavailable")")
                }
            }

            HStack(spacing: 18) {
                ReviewPhaseTimeline(status: reviewStatus)
                    .frame(maxWidth: 620)

                Spacer()

                if hasResult {
                    SeverityCount(title: "Errors", count: errorCount, color: .red)
                    SeverityCount(title: "Warnings", count: warningCount, color: .orange)
                    SeverityCount(title: "Info", count: infoCount, color: .blue)
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .background(ViewLensTheme.elevatedBackground)
    }

    @ViewBuilder
    private var reviewStateBanner: some View {
        switch reviewStatus {
        case .incomplete(let reason):
            ReviewStateBanner(
                title: "Review completed with limited coverage",
                message: reason,
                symbol: "exclamationmark.triangle.fill",
                color: .orange
            )
        case .failed(let failure):
            ReviewStateBanner(
                title: failure.title,
                message: [failure.message, failure.recoverySuggestion].compactMap { $0 }.joined(separator: " "),
                symbol: "xmark.octagon.fill",
                color: .red
            )
        case .cancelled:
            ReviewStateBanner(
                title: "Review cancelled",
                message: "The previous completed result remains available on the canvas.",
                symbol: "stop.circle.fill",
                color: .secondary
            )
        case .stale(let reason):
            ReviewStateBanner(title: "Results are stale", message: reason, symbol: "clock.badge.exclamationmark", color: .orange)
        default:
            EmptyView()
        }
    }
}

private struct ReviewStateBanner: View {
    let title: String
    let message: String
    let symbol: String
    let color: Color

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: symbol)
                .foregroundStyle(color)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.subheadline.weight(.semibold))
                Text(message).font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 10)
        .background(color.opacity(0.10))
        .accessibilityElement(children: .combine)
    }
}

private struct AIReviewInspector: View {
    @Bindable var model: AppModel
    @State private var selectedSection = InspectorSection.findings
    @State private var searchText = ""

    private enum InspectorSection: String, CaseIterable, Identifiable {
        case findings = "Findings"
        case activity = "Activity"
        case details = "Details"
        var id: String { rawValue }
    }

    private var filteredIssues: [ViewLensIssue] {
        guard !searchText.isEmpty else { return model.currentIssues }
        return model.currentIssues.filter {
            $0.displayTitle.localizedStandardContains(searchText) ||
            $0.description.localizedStandardContains(searchText) ||
            ($0.wcagCriterion?.localizedStandardContains(searchText) ?? false)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            Picker("Inspector Section", selection: $selectedSection) {
                ForEach(InspectorSection.allCases) { section in
                    Text(section.rawValue).tag(section)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .padding(12)

            Divider()

            switch selectedSection {
            case .findings:
                findings
            case .activity:
                reviewActivity
            case .details:
                details
            }
        }
        .background(Color(nsColor: .controlBackgroundColor))
    }

    private var findings: some View {
        VStack(spacing: 0) {
            TextField("Search findings", text: $searchText)
                .textFieldStyle(.roundedBorder)
                .padding(12)

            HStack(spacing: 12) {
                SeverityCount(title: "Errors", count: model.currentIssues.filter { $0.severity == .error }.count, color: .red)
                SeverityCount(title: "Warnings", count: model.currentIssues.filter { $0.severity == .warning }.count, color: .orange)
                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.bottom, 10)

            Divider()

            if filteredIssues.isEmpty {
                ContentUnavailableView(
                    searchText.isEmpty ? "No Findings" : "No Matching Findings",
                    systemImage: searchText.isEmpty ? "checkmark.seal.fill" : "magnifyingglass",
                    description: Text(searchText.isEmpty ? "The current checks found no accessibility issues." : "Try a different search term.")
                )
            } else {
                ScrollView {
                    LazyVStack(spacing: 8) {
                        ForEach(Array(filteredIssues.enumerated()), id: \.offset) { _, issue in
                            IssueCardView(issue: issue, isSelected: model.selectedIssue == issue) {
                                model.selectedIssue = issue
                                model.selectedElementIndex = issue.elementIndex
                            }
                        }
                    }
                    .padding(8)
                }
            }

            if let issue = model.selectedIssue {
                Divider()
                remediation(for: issue)
            }
        }
    }

    private func remediation(for issue: ViewLensIssue) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Suggested Remediation", systemImage: "lightbulb.fill")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.primary)

            Text(issue.remediation?.description ?? "Review the affected element against the cited requirement.")
                .font(.caption)
                .foregroundStyle(.secondary)

            if let snippet = issue.remediation?.codeSnippet {
                Button {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(snippet, forType: .string)
                } label: {
                    Label("Copy Guidance", systemImage: "doc.on.doc")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding(12)
        .background(ViewLensTheme.elevatedBackground)
    }

    private var details: some View {
        Form {
            Section("Review") {
                LabeledContent("Target", value: model.activeActivity?.auditReport?.target ?? "Current workspace")
                LabeledContent("Tool", value: model.activeActivity?.toolName ?? "—")
                LabeledContent("Duration", value: String(format: "%.0f ms", (model.activeActivity?.duration ?? 0) * 1000))
                LabeledContent("Result", value: model.activeActivity?.passed == true ? "Passed" : "Findings detected")
                LabeledContent("Lifecycle", value: model.reviewStore.activeReview?.status.displayName ?? "Not started")
                LabeledContent("Coverage", value: model.reviewStore.activeReview?.score?.completenessText ?? "Unavailable")
            }
            Section("Environment") {
                LabeledContent("Device", value: model.selectedDevice.name)
                LabeledContent("Dynamic Type", value: String(describing: model.selectedDynamicType))
                LabeledContent("Appearance", value: model.selectedColorScheme == .dark ? "Dark" : "Light")
                LabeledContent("Detector", value: model.doctorReport?.status == "ready" ? "Ready" : "Unavailable")
            }
        }
        .formStyle(.grouped)
    }

    private var reviewActivity: some View {
        Group {
            if model.reviewStore.events.isEmpty {
                ContentUnavailableView("No Review Activity", systemImage: "waveform.path.ecg")
            } else {
                List(model.reviewStore.events) { event in
                    HStack(alignment: .top, spacing: 10) {
                        Image(systemName: event.isError ? "xmark.octagon.fill" : "checkmark.circle")
                            .foregroundStyle(event.isError ? .red : ViewLensTheme.brand)
                            .accessibilityHidden(true)
                        VStack(alignment: .leading, spacing: 3) {
                            Text(event.message)
                                .font(.subheadline)
                            HStack {
                                if let phase = event.phase {
                                    Text(phase.rawValue)
                                }
                                Text(event.timestamp, style: .time)
                            }
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        }
                    }
                    .accessibilityElement(children: .combine)
                }
                .listStyle(.plain)
            }
        }
    }
}
