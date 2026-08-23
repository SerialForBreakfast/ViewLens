import SwiftUI
import ViewLensKit

struct AIReviewView: View {
    @Bindable var model: AppModel
    @Binding var showsInspector: Bool
    let onImport: () -> Void

    private var errorCount: Int { model.currentIssues.filter { $0.severity == .error }.count }
    private var warningCount: Int { model.currentIssues.filter { $0.severity == .warning }.count }
    private var infoCount: Int { model.currentIssues.filter { $0.severity == .info }.count }
    private var score: Int { max(0, 100 - (errorCount * 12) - (warningCount * 5) - infoCount) }
    private var hasResult: Bool { model.currentImage != nil && model.activeActivity != nil }

    var body: some View {
        VStack(spacing: 0) {
            reviewHeader
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
                    Label("No AI Review Selected", systemImage: "sparkles.rectangle.stack")
                } description: {
                    Text("Import a screenshot or run a Playground template to begin an accessibility review.")
                } actions: {
                    Button("Import & Validate", action: onImport)
                        .buttonStyle(.borderedProminent)
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
                        Text("\(model.currentIssues.count) findings · WCAG 2.2 AA")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel("Accessibility score")
                    .accessibilityValue("\(score) out of 100, \(model.currentIssues.count) findings, WCAG 2.2 level AA")
                }
            }

            HStack(spacing: 18) {
                ReviewPhaseTimeline(isRunning: model.isRenderingPlayground, hasResult: hasResult && !model.isRenderingPlayground)
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
                ActivityLogView(model: model)
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
}
