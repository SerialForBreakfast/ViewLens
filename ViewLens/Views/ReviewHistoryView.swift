import SwiftUI
import ViewLensKit

struct ReviewHistoryView: View {
    @Bindable var model: AppModel
    @Bindable var historyStore: HistoryStore
    let onOpenReview: () -> Void
    @State private var exportDocument: ReviewExportDocument?
    @State private var exportFormat: ReviewExportFormat = .json
    @State private var showsExporter = false

    init(model: AppModel, onOpenReview: @escaping () -> Void) {
        self.model = model
        self.historyStore = model.historyStore
        self.onOpenReview = onOpenReview
    }

    private var reviews: [ReviewRecord] { historyStore.filteredReviews(from: model.reviewStore.reviews) }
    private var selectedReviews: [ReviewRecord] { model.reviewStore.reviews.filter { historyStore.selectedReviewIDs.contains($0.id) } }

    var body: some View {
        VStack(spacing: 0) {
            header
            persistenceBanner
            Divider()
            if reviews.isEmpty { emptyState } else { historyContent }
        }
        .navigationTitle("History")
        .accessibilityIdentifier("screen.history")
        .confirmationDialog(
            "Delete this review?",
            isPresented: Binding(get: { historyStore.reviewPendingDeletion != nil }, set: { if !$0 { historyStore.reviewPendingDeletion = nil } }),
            titleVisibility: .visible
        ) {
            Button("Delete Review", role: .destructive) {
                if let review = historyStore.reviewPendingDeletion { model.reviewStore.delete(reviewID: review.id) }
                historyStore.reviewPendingDeletion = nil
            }
            Button("Cancel", role: .cancel) { historyStore.reviewPendingDeletion = nil }
        } message: {
            Text("The review record and its stored preview will be permanently removed. This cannot be undone.")
        }
        .sheet(isPresented: $historyStore.showsComparison) {
            if selectedReviews.count == 2 { ReviewComparisonView(older: selectedReviews.sorted { $0.startedAt < $1.startedAt }[0], newer: selectedReviews.sorted { $0.startedAt < $1.startedAt }[1]) }
        }
        .fileExporter(isPresented: $showsExporter, document: exportDocument, contentType: exportFormat.contentType, defaultFilename: exportFilename) { _ in }
    }

    private var header: some View {
        VStack(spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text("History").font(.largeTitle.bold())
                    Text("Search, compare, export, and manage durable accessibility reviews.").foregroundStyle(.secondary)
                }
                Spacer()
                Button { historyStore.showsComparison = true } label: { Label("Compare", systemImage: "rectangle.split.2x1") }
                    .disabled(!canCompare)
                    .help("Select two reviews with stored previews")
                Menu {
                    ForEach(ReviewExportFormat.allCases) { format in Button(format.rawValue) { export(selectedReviews.first, as: format) } }
                } label: { Label("Export", systemImage: "square.and.arrow.up") }
                .disabled(selectedReviews.count != 1)
                Button { if let review = selectedReviews.first { model.rerunReview(review); onOpenReview() } } label: { Label("Re-run", systemImage: "arrow.clockwise") }
                    .disabled(selectedReviews.count != 1)
                Button(role: .destructive) { historyStore.reviewPendingDeletion = selectedReviews.first } label: { Label("Delete", systemImage: "trash") }
                    .disabled(selectedReviews.count != 1)
            }
            HStack {
                TextField("Search target, source, or status", text: $historyStore.searchText).textFieldStyle(.roundedBorder).frame(maxWidth: 340)
                    .accessibilityIdentifier("history.search")
                Picker("History Filter", selection: $historyStore.filter) {
                    ForEach(HistoryReviewFilter.allCases) { Text($0.rawValue).tag($0) }
                }.pickerStyle(.menu).labelsHidden()
                Spacer()
                Text("\(reviews.count) review\(reviews.count == 1 ? "" : "s")").font(.caption).foregroundStyle(.secondary)
            }
        }.padding(20).background(ViewLensTheme.elevatedBackground)
    }

    @ViewBuilder private var persistenceBanner: some View {
        switch model.reviewStore.persistenceState {
        case .ready: EmptyView()
        case .migrated(let version): historyBanner("History migrated", "Schema \(version) was upgraded without discarding reviews.", "arrow.triangle.2.circlepath", .blue)
        case .unavailable(let message): historyBanner("History unavailable", message, "externaldrive.badge.exclamationmark", .red)
        case .corrupt(let message): historyBanner("History data is corrupt", message, "doc.badge.ellipsis", .red)
        case .migrationRequired(let version): historyBanner("Newer history schema", "Schema \(version) requires a newer ViewLens version.", "arrow.up.doc", .orange)
        }
    }

    private func historyBanner(_ title: String, _ message: String, _ symbol: String, _ color: Color) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: symbol).foregroundStyle(color).accessibilityHidden(true)
            VStack(alignment: .leading) { Text(title).fontWeight(.semibold); Text(message).font(.caption).foregroundStyle(.secondary) }
            Spacer()
        }.padding(12).background(color.opacity(0.10)).accessibilityElement(children: .combine)
    }

    private var emptyState: some View {
        ContentUnavailableView {
            Label(model.reviewStore.reviews.isEmpty ? "No Review History" : "No Matching Reviews", systemImage: "clock.arrow.circlepath")
        } description: {
            Text(model.reviewStore.reviews.isEmpty ? "Completed audits will persist here after you run them." : "Clear the search or choose another saved filter.")
        }
    }

    private var historyContent: some View {
        HSplitView {
            Table(reviews, selection: $historyStore.selectedReviewIDs) {
                TableColumn("Target") { review in
                    VStack(alignment: .leading, spacing: 2) {
                        Text(review.source.displayName).fontWeight(.medium)
                        Text(review.source.sourceType).font(.caption).foregroundStyle(.secondary)
                    }
                }
                TableColumn("Score") { review in
                    Text(review.score.map { "\($0.value)" } ?? "—").monospacedDigit()
                        .accessibilityLabel(review.score.map { "Score \($0.value) out of 100" } ?? "Score unavailable")
                }.width(54)
                TableColumn("Coverage") { review in Text(review.score?.completenessText ?? "Unavailable").font(.caption) }
                TableColumn("Status") { review in ReviewStatusLabel(status: review.status) }
                TableColumn("Date") { review in Text(review.startedAt, style: .date) }
                TableColumn("Duration") { review in Text(review.duration.map { String(format: "%.0f ms", $0 * 1000) } ?? "—").monospacedDigit() }
            }
            .contextMenu(forSelectionType: UUID.self) { selection in
                if selection.count == 1, let id = selection.first, let review = model.reviewStore.reviews.first(where: { $0.id == id }) {
                    Button("Open") { open(review) }
                    Button("Re-run") { model.rerunReview(review); onOpenReview() }
                    Menu("Export") { ForEach(ReviewExportFormat.allCases) { format in Button(format.rawValue) { export(review, as: format) } } }
                    Divider(); Button("Delete", role: .destructive) { historyStore.reviewPendingDeletion = review }
                }
            } primaryAction: { selection in
                if let id = selection.first, let review = model.reviewStore.reviews.first(where: { $0.id == id }) { open(review) }
            }
            .frame(minWidth: 600)

            if selectedReviews.count == 1 { ReviewHistoryDetail(review: selectedReviews[0], onOpen: { open(selectedReviews[0]) }) }
            else { ContentUnavailableView("Select a Review", systemImage: "sidebar.right", description: Text("Choose one row for details or two rows to compare.")) }
        }
    }

    private var exportFilename: String { "ViewLens-History.\(exportFormat.filenameExtension)" }
    private var canCompare: Bool {
        selectedReviews.count == 2 && !selectedReviews.contains { $0.previewImage == nil }
            && Set(selectedReviews.map(\.source.sourceType)).count == 1
    }
    private func open(_ review: ReviewRecord) { model.openReview(reviewID: review.id); onOpenReview() }
    private func export(_ review: ReviewRecord?, as format: ReviewExportFormat) {
        guard let review else { return }
        exportFormat = format; exportDocument = ReviewExportDocument(review: review, events: [], format: format); showsExporter = true
    }
}

private struct ReviewStatusLabel: View {
    let status: ReviewStatus
    private var symbol: String {
        switch status { case .completed: "checkmark.circle.fill"; case .failed: "xmark.octagon.fill"; case .incomplete, .stale: "exclamationmark.triangle.fill"; case .cancelled: "stop.circle.fill"; default: "clock.fill" }
    }
    var body: some View { Label(status.displayName, systemImage: symbol).font(.caption).accessibilityElement(children: .combine) }
}

private struct ReviewHistoryDetail: View {
    let review: ReviewRecord
    let onOpen: () -> Void
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                if let image = review.previewImage { Image(decorative: image, scale: 1).resizable().scaledToFit().frame(maxHeight: 240).clipShape(RoundedRectangle(cornerRadius: 8)) }
                Text(review.source.displayName).font(.title2.bold())
                LabeledContent("Status", value: review.status.displayName)
                LabeledContent("Score", value: review.score.map { "\($0.value)/100" } ?? "Unavailable")
                LabeledContent("Coverage", value: review.score?.completenessText ?? "Unavailable")
                LabeledContent("Findings", value: "\(review.findings.count)")
                LabeledContent("Environment", value: [review.environment.deviceName, review.environment.dynamicType, review.environment.appearance].compactMap { $0 }.joined(separator: " · "))
                Button("Open in AI Review", action: onOpen).buttonStyle(.borderedProminent)
            }.padding(16)
        }.frame(minWidth: 260, idealWidth: 320, maxWidth: 380)
    }
}

private struct ReviewComparisonView: View {
    @Environment(\.dismiss) private var dismiss
    let older: ReviewRecord
    let newer: ReviewRecord
    private var olderKeys: Set<String> { Set(older.findings.map { "\($0.issue.kind.rawValue)|\($0.issue.wcagCriterion ?? "HIG")" }) }
    private var newerKeys: Set<String> { Set(newer.findings.map { "\($0.issue.kind.rawValue)|\($0.issue.wcagCriterion ?? "HIG")" }) }
    private var visualDiff: VisualDiffResult? {
        guard let first = older.previewImage, let second = newer.previewImage else { return nil }
        return VisualDiffEngine.compare(reference: first, candidate: second)
    }
    private var heatmap: CGImage? {
        guard let first = older.previewImage, let second = newer.previewImage else { return nil }
        return VisualDiffEngine.generateDiffHeatmap(reference: first, candidate: second)
    }
    var body: some View {
        VStack(spacing: 0) {
            HStack { Text("Review Comparison").font(.title2.bold()); Spacer(); Button("Done") { dismiss() }.keyboardShortcut(.cancelAction) }.padding(16)
            Divider()
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    HStack(spacing: 20) { comparisonCard("Earlier", older); comparisonCard("Later", newer) }
                    HStack(spacing: 24) {
                        comparisonMetric("Score change", scoreChange)
                        comparisonMetric("Introduced", "\(newerKeys.subtracting(olderKeys).count) findings")
                        comparisonMetric("Resolved", "\(olderKeys.subtracting(newerKeys).count) findings")
                        if let visualDiff { comparisonMetric("Visual similarity", visualDiff.ssimScore.formatted(.percent.precision(.fractionLength(2)))) }
                    }
                    GroupBox("Environment differences") {
                        VStack(alignment: .leading) {
                            comparisonRow("Device", older.environment.deviceName, newer.environment.deviceName)
                            comparisonRow("Dynamic Type", older.environment.dynamicType, newer.environment.dynamicType)
                            comparisonRow("Appearance", older.environment.appearance, newer.environment.appearance)
                            comparisonRow("WCAG target", older.environment.wcagLevel, newer.environment.wcagLevel)
                        }.frame(maxWidth: .infinity, alignment: .leading).padding(8)
                    }
                    if let heatmap {
                        GroupBox("Visual difference heatmap") {
                            Image(decorative: heatmap, scale: 1).resizable().scaledToFit().frame(maxHeight: 320).frame(maxWidth: .infinity)
                        }
                    }
                }.padding(20)
            }
        }.frame(minWidth: 760, minHeight: 620)
    }
    private var scoreChange: String {
        guard let old = older.score?.value, let new = newer.score?.value else { return "Unavailable" }
        let change = new - old; return change == 0 ? "No change" : "\(change > 0 ? "+" : "")\(change) points"
    }
    private func comparisonCard(_ label: String, _ review: ReviewRecord) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label).font(.caption).foregroundStyle(.secondary); Text(review.source.displayName).font(.headline)
            if let image = review.previewImage { Image(decorative: image, scale: 1).resizable().scaledToFit().frame(height: 180).clipShape(RoundedRectangle(cornerRadius: 6)) }
            Text(review.startedAt, style: .date).font(.caption)
        }.frame(maxWidth: .infinity, alignment: .leading)
    }
    private func comparisonMetric(_ title: String, _ value: String) -> some View {
        VStack(alignment: .leading) { Text(title).font(.caption).foregroundStyle(.secondary); Text(value).font(.headline) }
    }
    private func comparisonRow(_ title: String, _ old: String?, _ new: String?) -> some View {
        HStack { Text(title).frame(width: 110, alignment: .leading); Text(old ?? "—"); Image(systemName: "arrow.right").accessibilityHidden(true); Text(new ?? "—").fontWeight(old == new ? .regular : .semibold) }
    }
}
