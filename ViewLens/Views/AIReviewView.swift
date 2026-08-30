import AppKit
import SwiftUI
import ViewLensKit

public enum WorkbenchViewMode: String, CaseIterable, Identifiable, Sendable {
    case canvas = "Canvas"
    case outline = "Outline"
    case split = "Split"

    public var id: String { rawValue }
    public var symbol: String {
        switch self {
        case .canvas: "photo"
        case .outline: "list.bullet.indent"
        case .split: "rectangle.split.2x1"
        }
    }
}

typealias WorkbenchDisplayMode = WorkbenchViewMode

struct AIReviewView: View {
    @Bindable var model: AppModel
    @Binding var showsInspector: Bool
    let onImport: () -> Void

    @State private var displayMode: WorkbenchViewMode = .split
    @State private var exportDocument: ReviewExportDocument?
    @State private var exportFormat: ReviewExportFormat = .json
    @State private var showsExporter = false
    @State private var exportMessage: String?
    @State private var confirmsCancellation = false

    private var review: ReviewRecord? { model.reviewStore.activeReview }
    private var errorCount: Int { model.currentIssues.filter { $0.severity == .error }.count }
    private var warningCount: Int { model.currentIssues.filter { $0.severity == .warning }.count }
    private var infoCount: Int { model.currentIssues.filter { $0.severity == .info }.count }
    private var score: Int { review?.score?.value ?? max(0, 100 - errorCount * 12 - warningCount * 5 - infoCount) }
    private var hasResult: Bool { model.currentImage != nil }
    private var reviewStatus: ReviewStatus { review?.status ?? .idle }

    var body: some View {
        VStack(spacing: 0) {
            reviewHeader
            reviewStateBanner
            Divider()
            if hasResult {
                HSplitView {
                    workbenchMainView
                        .frame(minWidth: 480, maxWidth: .infinity, maxHeight: .infinity)
                    if showsInspector {
                        AIReviewInspector(model: model)
                            .frame(minWidth: 320, idealWidth: 360, maxWidth: 480, maxHeight: .infinity)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                emptyState
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(nsColor: .windowBackgroundColor))
        .navigationTitle("AI Review")
        .accessibilityIdentifier("screen.aiReview")
        .onReceive(NotificationCenter.default.publisher(for: .viewLensSetWorkbenchMode)) { notification in
            if let mode = notification.object as? WorkbenchViewMode {
                displayMode = mode
            }
        }
        .fileExporter(isPresented: $showsExporter, document: exportDocument, contentType: exportFormat.contentType, defaultFilename: exportFilename) { result in
            exportMessage = switch result {
            case .success: "Export completed."
            case .failure(let error): "Export failed: \(error.localizedDescription)"
            }
        }
        .alert("Review Export", isPresented: Binding(get: { exportMessage != nil }, set: { if !$0 { exportMessage = nil } })) {
            Button("OK") { exportMessage = nil }
        } message: { Text(exportMessage ?? "") }
        .confirmationDialog("Cancel the active review?", isPresented: $confirmsCancellation, titleVisibility: .visible) {
            Button("Cancel Review", role: .destructive) { model.cancelActiveReview() }
            Button("Keep Running", role: .cancel) {}
        } message: { Text("The in-progress result will be discarded. The previous completed review remains available in History.") }
    }

    private var emptyState: some View {
        ContentUnavailableView {
            Label(emptyStateTitle, systemImage: emptyStateSymbol)
        } description: {
            Text(emptyStateDescription)
        } actions: {
            if reviewStatus.isRunning {
                Button("Cancel Review", role: .cancel) { requestCancellation() }.accessibilityIdentifier("review.cancel")
            } else {
                Button("Import & Validate", action: onImport).buttonStyle(.borderedProminent)
            }
        }
    }

    private var emptyStateTitle: String {
        switch reviewStatus {
        case .failed: return "Review Failed"
        case .cancelled: return "Review Cancelled"
        case .preparing, .queued, .running: return "Review in Progress"
        default: return "No AI Review Selected"
        }
    }
    private var emptyStateSymbol: String {
        switch reviewStatus {
        case .failed: return "xmark.octagon"
        case .cancelled: return "stop.circle"
        case .preparing, .queued, .running: return "sparkles"
        default: return "sparkles.rectangle.stack"
        }
    }
    private var emptyStateDescription: String {
        switch reviewStatus {
        case .failed(let failure): return [failure.message, failure.recoverySuggestion].compactMap { $0 }.joined(separator: " ")
        case .cancelled: return "Import a source or rerun a template when you are ready."
        case .preparing, .queued, .running: return reviewStatus.displayName
        default: return "Import a screenshot or run a Playground template to begin an accessibility review."
        }
    }

    private var reviewHeader: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top, spacing: 20) {
                VStack(alignment: .leading, spacing: 4) {
                    Label("AI Review", systemImage: "sparkles").font(.title.bold())
                    Text(model.activeActivity?.auditReport?.target ?? review?.source.displayName ?? "AI-assisted WCAG 2.2 and Apple HIG audit")
                        .font(.subheadline).foregroundStyle(.secondary).lineLimit(1)
                }
                Spacer()
                Text(reviewStatus.displayName)
                    .font(.caption.weight(.semibold)).padding(.horizontal, 9).padding(.vertical, 5)
                    .background(statusColor.opacity(0.14), in: Capsule()).overlay { Capsule().stroke(statusColor, lineWidth: 1) }
                    .accessibilityLabel("Review status: \(reviewStatus.displayName)")
                if reviewStatus.isRunning {
                    Button("Cancel", role: .cancel) { requestCancellation() }.accessibilityIdentifier("review.cancel")
                        .help("Cancel the active review and preserve the previous completed result")
                }
                if hasResult {
                    Picker("View Mode", selection: $displayMode) {
                        ForEach(WorkbenchDisplayMode.allCases) { mode in
                            Label(mode.rawValue, systemImage: mode.symbol).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                    .frame(width: 220)
                    .accessibilityLabel("Workbench view mode")
                    .accessibilityIdentifier("review.viewMode")

                    Menu {
                        ForEach(ReviewExportFormat.allCases) { format in Button(format.rawValue) { prepareExport(format) } }
                    } label: { Label("Export", systemImage: "square.and.arrow.up") }
                    .accessibilityIdentifier("review.export")
                    .help("Export data, Markdown, an annotated image, or a report bundle")
                    scoreSummary
                }
            }
            HStack(spacing: 18) {
                ReviewPhaseTimeline(status: reviewStatus).frame(maxWidth: 620)
                Spacer()
                if hasResult {
                    SeverityCount(title: "Errors", count: errorCount, color: .red)
                    SeverityCount(title: "Warnings", count: warningCount, color: .orange)
                    SeverityCount(title: "Info", count: infoCount, color: .blue)
                }
            }
        }
        .padding(.horizontal, 20).padding(.vertical, 16).background(ViewLensTheme.elevatedBackground)
    }

    @ViewBuilder
    private var workbenchMainView: some View {
        switch displayMode {
        case .canvas:
            VisualInspectorView(model: model)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        case .outline:
            NonvisualOutlineView(model: model)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        case .split:
            HSplitView {
                VisualInspectorView(model: model)
                    .frame(minWidth: 340, maxWidth: .infinity, maxHeight: .infinity)
                NonvisualOutlineView(model: model)
                    .frame(minWidth: 260, maxWidth: .infinity, maxHeight: .infinity)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private var scoreSummary: some View {
        VStack(alignment: .trailing, spacing: 2) {
            HStack(alignment: .firstTextBaseline, spacing: 5) {
                Text("\(score)").font(.system(.largeTitle, design: .rounded, weight: .bold)).foregroundStyle(scoreColor)
                Text("/ 100").font(.caption).foregroundStyle(.secondary)
            }
            Text("\(model.currentIssues.count) findings · \(review?.score?.completenessText ?? "Coverage unavailable")")
                .font(.caption).foregroundStyle(.secondary)
        }
        .accessibilityElement(children: .ignore).accessibilityLabel("Accessibility score")
        .accessibilityValue("\(score) out of 100, \(model.currentIssues.count) findings, \(review?.score?.completenessText ?? "coverage unavailable")")
    }

    private var scoreColor: Color { score >= 90 ? .green : (score >= 70 ? .orange : .red) }
    private var statusColor: Color {
        switch reviewStatus {
        case .completed: return .green
        case .failed: return .red
        case .incomplete, .stale: return .orange
        case .cancelled: return .secondary
        default: return ViewLensTheme.brand
        }
    }

    @ViewBuilder private var reviewStateBanner: some View {
        switch reviewStatus {
        case .incomplete(let reason): ReviewStateBanner(title: "Review completed with limited coverage", message: reason, symbol: "exclamationmark.triangle.fill", color: .orange)
        case .failed(let failure): ReviewStateBanner(title: failure.title, message: [failure.message, failure.recoverySuggestion].compactMap { $0 }.joined(separator: " "), symbol: "xmark.octagon.fill", color: .red)
        case .cancelled: ReviewStateBanner(title: "Review cancelled", message: "The previous completed result remains available on the canvas.", symbol: "stop.circle.fill", color: .secondary)
        case .stale(let reason): ReviewStateBanner(title: "Results are stale", message: reason, symbol: "clock.badge.exclamationmark", color: .orange)
        default: EmptyView()
        }
    }

    private var exportFilename: String {
        let base = review?.source.displayName.replacingOccurrences(of: ".", with: "-") ?? "ViewLens-Review"
        return "\(base)-accessibility.\(exportFormat.filenameExtension)"
    }
    private func prepareExport(_ format: ReviewExportFormat) {
        guard let review else { return }
        exportFormat = format
        exportDocument = ReviewExportDocument(review: review, events: model.reviewStore.events, format: format)
        showsExporter = true
    }

    private func requestCancellation() {
        if model.preferenceStore.confirmCancellation { confirmsCancellation = true } else { model.cancelActiveReview() }
    }
}

private struct ReviewStateBanner: View {
    let title: String; let message: String; let symbol: String; let color: Color
    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: symbol).foregroundStyle(color).accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.subheadline.weight(.semibold))
                Text(message).font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(.horizontal, 20).padding(.vertical, 10).background(color.opacity(0.10))
        .accessibilityElement(children: .combine)
    }
}

private struct AIReviewInspector: View {
    @Bindable var model: AppModel
    @State private var selectedSection = InspectorSection.findings
    @State private var expandedFindingIDs: Set<ReviewFinding.ID> = []
    @State private var copiedFindingID: ReviewFinding.ID?

    private enum InspectorSection: String, CaseIterable, Identifiable {
        case findings = "Findings", activity = "Activity", details = "Details"
        var id: String { rawValue }
    }
    private var filter: FindingFilter { model.reviewStore.filter }
    private var findings: [ReviewFinding] { model.reviewStore.filteredFindings }
    private var allFindings: [ReviewFinding] { model.reviewStore.activeReview?.findings ?? [] }
    private var criteria: [String] { Array(Set(allFindings.compactMap(\.issue.wcagCriterion))).sorted() }
    private var elementIndices: [Int] { Array(Set(allFindings.compactMap(\.issue.elementIndex))).sorted() }

    var body: some View {
        VStack(spacing: 0) {
            Picker("Inspector Section", selection: $selectedSection) {
                ForEach(InspectorSection.allCases) { Text($0.rawValue).tag($0) }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .padding(12)

            Divider()

            switch selectedSection {
            case .findings:
                findingsSection
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            case .activity:
                reviewActivity
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            case .details:
                details
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(nsColor: .controlBackgroundColor))
    }

    private var findingsSection: some View {
        VStack(spacing: 0) {
            filterControls
            Divider()
            if findings.isEmpty {
                ContentUnavailableView(
                    allFindings.isEmpty ? "No Findings" : "No Matching Findings",
                    systemImage: allFindings.isEmpty ? "checkmark.seal.fill" : "line.3.horizontal.decrease.circle",
                    description: Text(allFindings.isEmpty ? "No issues were found in the evaluated criteria." : "Clear or adjust filters to see other findings.")
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 8) {
                        ForEach(findings) { finding in
                            FindingDisclosureCard(
                                finding: finding,
                                element: finding.issue.elementIndex.flatMap { model.currentElements.indices.contains($0) ? model.currentElements[$0] : nil },
                                isSelected: model.reviewStore.selectedFindingID == finding.id,
                                isExpanded: Binding(
                                    get: { expandedFindingIDs.contains(finding.id) },
                                    set: { if $0 { expandedFindingIDs.insert(finding.id) } else { expandedFindingIDs.remove(finding.id) } }
                                ),
                                copied: copiedFindingID == finding.id,
                                onSelect: { model.selectFinding(finding) },
                                onCopy: { copyGuidance(finding) }
                            )
                        }
                    }.padding(8)
                }
            }
        }
    }

    private var filterControls: some View {
        VStack(spacing: 8) {
            TextField("Search title, description, or criterion", text: Binding(
                get: { model.reviewStore.filter.searchText }, set: { model.reviewStore.filter.searchText = $0 }
            )).textFieldStyle(.roundedBorder)
                .accessibilityIdentifier("findings.search")
            HStack(spacing: 6) {
                Menu("Severity") {
                    ForEach([ViewLensSeverity.error, .warning, .info], id: \.self) { severity in
                        Button { toggleSeverity(severity) } label: {
                            Label(severity.rawValue.capitalized, systemImage: filter.severities.contains(severity) ? "checkmark" : severitySymbol(severity))
                        }
                    }
                }
                Menu(filter.standard.rawValue) {
                    ForEach(FindingStandard.allCases) { standard in
                        Button { model.reviewStore.filter.standard = standard } label: {
                            Label(standard.rawValue, systemImage: filter.standard == standard ? "checkmark" : "circle")
                        }
                    }
                }
                Menu(filter.criterion ?? "Criterion") {
                    Button("All Criteria") { model.reviewStore.filter.criterion = nil }; Divider()
                    ForEach(criteria, id: \.self) { criterion in Button(criterion) { model.reviewStore.filter.criterion = criterion } }
                }
                Menu(filter.elementIndex.map { "Element #\($0)" } ?? "Element") {
                    Button("All Elements") { model.reviewStore.filter.elementIndex = nil }; Divider()
                    ForEach(elementIndices, id: \.self) { index in Button("#\(index) \(elementName(index))") { model.reviewStore.filter.elementIndex = index } }
                }
                Spacer()
                Button { model.reviewStore.filter = FindingFilter() } label: {
                    Label("Clear Filters", systemImage: "xmark.circle").labelStyle(.iconOnly).frame(minWidth: 28, minHeight: 28)
                }.disabled(filter == FindingFilter()).help("Clear all finding filters")
            }
            Text("Showing \(findings.count) of \(allFindings.count) findings")
                .font(.caption).foregroundStyle(.secondary).frame(maxWidth: .infinity, alignment: .leading)
        }.controlSize(.small).padding(12)
    }

    private var details: some View {
        Form {
            Section("Review") {
                LabeledContent("Source", value: model.reviewStore.activeReview?.source.displayName ?? "Current workspace")
                LabeledContent("Tool", value: model.activeActivity?.toolName ?? "—")
                LabeledContent("Duration", value: String(format: "%.0f ms", (model.reviewStore.activeReview?.duration ?? model.activeActivity?.duration ?? 0) * 1000))
                LabeledContent("Lifecycle", value: model.reviewStore.activeReview?.status.displayName ?? "Not started")
                LabeledContent("Coverage", value: model.reviewStore.activeReview?.score?.completenessText ?? "Unavailable")
                LabeledContent("Unevaluated", value: "\(unevaluatedCriteria) criteria")
            }
            Section("Environment") {
                let environment = model.reviewStore.activeReview?.environment
                LabeledContent("Device", value: environment?.deviceName ?? "Not recorded")
                LabeledContent("Dynamic Type", value: environment?.dynamicType ?? "Not recorded")
                LabeledContent("Appearance", value: environment?.appearance ?? "Not recorded")
                LabeledContent("WCAG level", value: environment?.wcagLevel ?? "AA")
                LabeledContent("Detector", value: environment?.detectorName ?? "Not recorded")
            }
        }.formStyle(.grouped)
    }

    private var unevaluatedCriteria: Int {
        guard let score = model.reviewStore.activeReview?.score else { return 0 }
        return max(0, score.totalCriteria - score.evaluatedCriteria)
    }
    private var reviewActivity: some View {
        Group {
            if model.reviewStore.events.isEmpty {
                ContentUnavailableView("No Review Activity", systemImage: "waveform.path.ecg")
            } else {
                List(model.reviewStore.events) { event in
                    HStack(alignment: .top, spacing: 10) {
                        Image(systemName: event.isError ? "xmark.octagon.fill" : "checkmark.circle")
                            .foregroundStyle(event.isError ? .red : ViewLensTheme.brand).accessibilityHidden(true)
                        VStack(alignment: .leading, spacing: 3) {
                            Text(event.message).font(.subheadline)
                            HStack { if let phase = event.phase { Text(phase.rawValue) }; Text(event.timestamp, style: .time) }
                                .font(.caption).foregroundStyle(.secondary)
                        }
                    }.accessibilityElement(children: .combine)
                }.listStyle(.plain)
            }
        }
    }

    private func elementName(_ index: Int) -> String { model.currentElements.indices.contains(index) ? model.currentElements[index].type : "Unknown" }
    private func toggleSeverity(_ severity: ViewLensSeverity) {
        if model.reviewStore.filter.severities.contains(severity) { model.reviewStore.filter.severities.remove(severity) }
        else { model.reviewStore.filter.severities.insert(severity) }
    }
    private func severitySymbol(_ severity: ViewLensSeverity) -> String {
        switch severity { case .error: return "xmark.octagon"; case .warning: return "exclamationmark.triangle"; case .info: return "info.circle" }
    }
    private func copyGuidance(_ finding: ReviewFinding) {
        let issue = finding.issue
        let text = [issue.remediation?.description, issue.remediation?.codeSnippet].compactMap { $0 }.joined(separator: "\n\n")
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text.isEmpty ? issue.description : text, forType: .string)
        copiedFindingID = finding.id
        Task {
            try? await Task.sleep(for: .seconds(2))
            if copiedFindingID == finding.id { copiedFindingID = nil }
        }
    }
}

private struct FindingDisclosureCard: View {
    let finding: ReviewFinding
    let element: DetectedElement?
    let isSelected: Bool
    @Binding var isExpanded: Bool
    let copied: Bool
    let onSelect: () -> Void
    let onCopy: () -> Void
    private var issue: ViewLensIssue { finding.issue }
    private var color: Color { issue.severity == .error ? .red : (issue.severity == .warning ? .orange : .blue) }
    private var symbol: String { issue.severity == .error ? "xmark.octagon.fill" : (issue.severity == .warning ? "exclamationmark.triangle.fill" : "info.circle.fill") }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 8) {
                Button(action: onSelect) {
                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: symbol).foregroundStyle(color).accessibilityHidden(true)
                        VStack(alignment: .leading, spacing: 4) {
                            Text(issue.displayTitle).font(.subheadline.weight(.semibold)).foregroundStyle(.primary)
                            Text("\(issue.severity.rawValue.capitalized) · \(issue.wcagCriterion ?? "Apple HIG")").font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                    }.contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(issue.displayTitle)
                .accessibilityValue("\(issue.severity.rawValue.capitalized), \(issue.wcagCriterion ?? "Apple HIG")")
                .accessibilityHint("Selects this finding and reveals its affected element on the canvas")
                Button { isExpanded.toggle(); onSelect() } label: {
                    Label(isExpanded ? "Collapse finding" : "Expand finding", systemImage: "chevron.right")
                        .labelStyle(.iconOnly).rotationEffect(.degrees(isExpanded ? 90 : 0)).frame(minWidth: 28, minHeight: 28)
                }
                .buttonStyle(.plain)
                .accessibilityValue(isExpanded ? "Expanded" : "Collapsed")
            }.padding(10)
            if isExpanded {
                Divider()
                VStack(alignment: .leading, spacing: 10) {
                    detailLabel("Evidence", value: issue.description)
                    HStack {
                        detailLabel("Affected element", value: issue.elementIndex.map { "#\($0) \(element?.type ?? "Unknown")" } ?? "Screen-level")
                        Spacer()
                        detailLabel("Confidence", value: issue.confidence.map { "\(Int($0 * 100))%" } ?? "Not reported")
                    }
                    let requirement = [issue.wcagCriterion, issue.wcagLevel].compactMap { $0 }.joined(separator: " ")
                    detailLabel("Requirement", value: requirement.isEmpty ? "Apple Human Interface Guidelines" : requirement)
                    detailLabel("Deterministic remediation", value: issue.remediation?.description ?? "Review the affected element against the cited requirement.")
                    if let snippet = issue.remediation?.codeSnippet {
                        Text(snippet).font(.system(.caption, design: .monospaced)).textSelection(.enabled)
                            .padding(8).frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color(nsColor: .textBackgroundColor), in: RoundedRectangle(cornerRadius: 6))
                    }
                    VStack(alignment: .leading, spacing: 3) {
                        Label("AI guidance (advisory)", systemImage: "sparkles").font(.caption.weight(.semibold))
                        Text("Use this evidence as context for a proposed code change. Review and preview every patch before applying it.")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    HStack {
                        Button(action: onCopy) { Label(copied ? "Copied" : "Copy Guidance", systemImage: copied ? "checkmark" : "doc.on.doc") }
                        Button("Apply Fix (Preview Required)") {}.disabled(true)
                            .help("Apply Fix becomes available only after a generated patch can be previewed and approved.")
                    }.buttonStyle(.bordered)
                }.padding(10)
            }
        }
        .background(RoundedRectangle(cornerRadius: 8).fill(isSelected ? Color.accentColor.opacity(0.12) : ViewLensTheme.elevatedBackground))
        .overlay { RoundedRectangle(cornerRadius: 8).stroke(isSelected ? Color.accentColor : color.opacity(0.45), lineWidth: isSelected ? 2 : 1) }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("finding.card")
    }

    private func detailLabel(_ title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title).font(.caption2.weight(.semibold)).foregroundStyle(.secondary)
            Text(value).font(.caption).textSelection(.enabled)
        }
    }
}
