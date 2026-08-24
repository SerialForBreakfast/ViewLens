import SwiftUI
import ViewLensKit

struct CurrentStatusView: View {
    @Bindable var model: AppModel
    @Bindable var dashboard: CurrentStatusStore
    let onOpenReview: () -> Void
    let onImport: () -> Void

    init(model: AppModel, onOpenReview: @escaping () -> Void, onImport: @escaping () -> Void) {
        self.model = model
        self.dashboard = model.currentStatusStore
        self.onOpenReview = onOpenReview
        self.onImport = onImport
    }

    private var detectorReady: Bool { model.doctorReport?.status == "ready" }
    private var reviews: [ReviewRecord] { model.reviewStore.reviews }
    private var visibleReviews: [ReviewRecord] { dashboard.visibleReviews(from: reviews) }
    private var passRate: Int? { dashboard.passRate(for: reviews) }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: ViewLensTheme.sectionSpacing) {
                header
                lifecycleBanner
                metrics
                recentReviews
                HStack(alignment: .top, spacing: ViewLensTheme.standardSpacing) {
                    qualityTrend.frame(maxWidth: .infinity)
                    activityFeed.frame(minWidth: 300, idealWidth: 360, maxWidth: 420)
                }
                importDropZone
            }
            .padding(24)
        }
        .background(Color(nsColor: .windowBackgroundColor))
        .navigationTitle("Current Status")
        .accessibilityIdentifier("screen.currentStatus")
        .sheet(isPresented: $dashboard.showsDiagnostics) { DiagnosticsSheet(model: model) }
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 10) {
                    Text("Current Status").font(.largeTitle.bold())
                    HealthPill(
                        title: detectorReady ? "Healthy" : (model.isRunningDoctor ? "Checking" : "Needs attention"),
                        state: detectorReady ? .ready : (model.isRunningDoctor ? .busy : .warning)
                    )
                }
                Text("Service readiness and accessibility review activity").foregroundStyle(.secondary)
            }
            Spacer()
            Button { dashboard.showsDiagnostics = true } label: {
                Label("Diagnostics", systemImage: "stethoscope")
            }
            .help("Open detailed detector and service diagnostics")
            Button { model.runDoctorCheck() } label: {
                if model.isRunningDoctor {
                    ProgressView().controlSize(.small).accessibilityLabel("Checking system health")
                } else {
                    Label("Refresh", systemImage: "arrow.clockwise")
                }
            }
            .disabled(model.isRunningDoctor)
            .keyboardShortcut("r", modifiers: [.command, .shift])
            .help("Refresh service and detector status")
        }
    }

    @ViewBuilder private var lifecycleBanner: some View {
        if model.isRunningDoctor {
            DashboardBanner(title: "Checking system readiness", message: "ViewLens is probing the detector and model assets.", symbol: "stethoscope", color: ViewLensTheme.focus)
        } else if let review = model.reviewStore.activeReview {
            switch review.status {
            case .incomplete(let reason): DashboardBanner(title: "Latest review has limited coverage", message: reason, symbol: "circle.lefthalf.filled", color: .orange)
            case .stale(let reason): DashboardBanner(title: "Latest review is stale", message: reason, symbol: "clock.badge.exclamationmark", color: .orange)
            case .failed(let failure): DashboardBanner(title: failure.title, message: failure.message, symbol: "xmark.octagon.fill", color: .red)
            case .cancelled: DashboardBanner(title: "Review cancelled", message: "Previously completed reviews remain available below.", symbol: "stop.circle.fill", color: .secondary)
            default: EmptyView()
            }
        }
    }

    private var metrics: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 190), spacing: 16)], spacing: 16) {
            StatusMetricCard(title: "MCP Server", value: model.mcpStatus.contains("Listening") ? "Listening" : model.mcpStatus, detail: model.mcpStatus, symbol: "shippingbox", state: model.mcpStatus.contains("Listening") ? .ready : .warning)
            StatusMetricCard(title: "CoreML Detector", value: detectorReady ? "Ready" : (model.isRunningDoctor ? "Checking" : "Unavailable"), detail: detectorReady ? "Model load confirmed" : "Open diagnostics for recovery guidance", symbol: "cpu", state: detectorReady ? .ready : (model.isRunningDoctor ? .busy : .error))
            StatusMetricCard(title: "Active Reviews", value: model.reviewStore.activeReview?.status.isRunning == true ? "1" : "0", detail: model.reviewStore.activeReview?.status.isRunning == true ? model.reviewStore.activeReview?.status.displayName ?? "Working" : "No reviews currently running", symbol: "sparkles", state: model.reviewStore.activeReview?.status.isRunning == true ? .busy : .ready)
            StatusMetricCard(title: "Accessibility Pass Rate", value: passRate.map { "\($0)%" } ?? "—", detail: passRate == nil ? "No complete reviews yet" : "Across complete reviews; partial results excluded", symbol: "chart.bar.xaxis", state: passRate.map { $0 >= 90 ? .ready : ($0 >= 70 ? .warning : .error) } ?? .warning)
        }
    }

    private var recentReviews: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Recent AI Reviews").font(.title3.weight(.semibold))
                    Text("Select a row and press Return to open it.").font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                TextField("Filter reviews", text: $dashboard.searchText)
                    .textFieldStyle(.roundedBorder).frame(width: 190)
                    .accessibilityLabel("Filter recent reviews")
                Picker("Status", selection: $dashboard.filter) {
                    ForEach(DashboardReviewFilter.allCases) { Text($0.rawValue).tag($0) }
                }
                .labelsHidden().frame(width: 130).accessibilityLabel("Review status filter")
                Picker("Sort", selection: $dashboard.sort) {
                    ForEach(DashboardReviewSort.allCases) { Text($0.rawValue).tag($0) }
                }
                .labelsHidden().frame(width: 135).accessibilityLabel("Review sort order")
            }
            .padding(16)
            Divider()

            if reviews.isEmpty {
                ContentUnavailableView {
                    Label("No Reviews Yet", systemImage: "sparkles.rectangle.stack")
                } description: { Text("Import a screen or run a Playground template to begin.") }
                actions: { Button("Import & Validate", action: onImport) }
                .frame(minHeight: 280)
            } else if visibleReviews.isEmpty {
                ContentUnavailableView {
                    Label("No Matching Reviews", systemImage: "line.3.horizontal.decrease.circle")
                } description: { Text("Clear the search or choose a different status filter.") }
                actions: {
                    Button("Clear Filters") { dashboard.searchText = ""; dashboard.filter = .all }
                }
                .frame(minHeight: 280)
            } else {
                Table(visibleReviews, selection: $dashboard.selectedReviewID) {
                    TableColumn("Review") { review in
                        VStack(alignment: .leading, spacing: 2) {
                            Text(review.source.displayName).fontWeight(.medium).lineLimit(1)
                            Text(review.source.sourceType).font(.caption).foregroundStyle(.secondary)
                        }
                        .contextMenu {
                            Button("Open Review") { open(review.id) }
                            Button("Run Again") { rerun(review) }
                        }
                    }
                    TableColumn("Status") { ReviewRecordStatusLabel(review: $0) }
                    TableColumn("Score") { review in
                        Text(review.score.map { "\($0.value)%" } ?? "—").monospacedDigit()
                            .accessibilityLabel(review.score.map { "Score \($0.value) percent" } ?? "Score unavailable")
                    }.width(70)
                    TableColumn("Coverage") { review in
                        Text(review.score?.completenessText ?? "Not evaluated").font(.caption).foregroundStyle(.secondary)
                    }
                    TableColumn("Findings") { Text("\($0.findings.count)").monospacedDigit() }.width(65)
                    TableColumn("Last Run") { Text($0.startedAt, style: .relative) }.width(90)
                    TableColumn("") { review in Button("Open") { open(review.id) }.buttonStyle(.borderless) }.width(52)
                }
                .frame(minHeight: 290)
                .focusable()
                .onKeyPress(.return) {
                    guard let id = dashboard.selectedReviewID else { return .ignored }
                    open(id); return .handled
                }
                .accessibilityLabel("Recent accessibility reviews")
            }
        }
        .viewLensPanel(padding: 0)
    }

    private var qualityTrend: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Quality Trend").font(.title3.weight(.semibold))
                    Text(trendText).font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                Text(trendValues.last.map { "Latest: \(Int($0))%" } ?? "No complete data")
                    .font(.subheadline.monospacedDigit().weight(.semibold))
            }
            if trendValues.isEmpty {
                ContentUnavailableView("No Complete Reviews", systemImage: "chart.xyaxis.line").frame(height: 130)
            } else {
                QualityTrendGraph(values: trendValues).frame(height: 130)
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel("Accessibility quality trend")
                    .accessibilityValue(trendAccessibleValue)
            }
        }
        .viewLensPanel()
    }

    private var activityFeed: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("System & Review Activity").font(.title3.weight(.semibold))
                Spacer(); Image(systemName: "waveform.path.ecg").foregroundStyle(.secondary)
            }.padding(16)
            Divider()
            if activityItems.isEmpty {
                ContentUnavailableView("No Activity", systemImage: "waveform.path.ecg").frame(minHeight: 220)
            } else {
                ForEach(activityItems.prefix(6)) { item in
                    HStack(alignment: .top, spacing: 10) {
                        Image(systemName: item.symbol).foregroundStyle(item.color).accessibilityHidden(true)
                        VStack(alignment: .leading, spacing: 3) {
                            Text(item.title).font(.subheadline.weight(.medium)).lineLimit(2)
                            Text(item.detail).font(.caption).foregroundStyle(.secondary).lineLimit(2)
                            Text(item.timestamp, style: .relative).font(.caption2).foregroundStyle(.tertiary)
                        }
                        Spacer(minLength: 0)
                    }
                    .padding(12).accessibilityElement(children: .combine)
                    Divider().padding(.leading, 38)
                }
            }
        }
        .viewLensPanel(padding: 0)
    }

    private var importDropZone: some View {
        Button(action: onImport) {
            HStack(spacing: 16) {
                Image(systemName: dashboard.isDropTargeted ? "arrow.down.doc.fill" : "rectangle.stack.badge.plus")
                    .font(.title2).foregroundStyle(ViewLensTheme.brand).frame(width: 44, height: 44)
                    .background(ViewLensTheme.brand.opacity(0.12), in: RoundedRectangle(cornerRadius: 10))
                VStack(alignment: .leading, spacing: 3) {
                    Text(dashboard.isDropTargeted ? "Release to validate" : "Drop a screen to validate").font(.headline)
                    Text("PNG, JPEG, and HEIC screenshots use explicit semantic-coverage limits.").font(.caption).foregroundStyle(.secondary)
                }
                Spacer(); Text("Import File").foregroundStyle(ViewLensTheme.brand)
                Image(systemName: "chevron.right").foregroundStyle(.secondary)
            }.contentShape(Rectangle())
        }
        .buttonStyle(.plain).viewLensPanel()
        .overlay { RoundedRectangle(cornerRadius: ViewLensTheme.panelCornerRadius).stroke(dashboard.isDropTargeted ? ViewLensTheme.brand : .clear, style: StrokeStyle(lineWidth: 2, dash: [6])) }
        .dropDestination(for: URL.self) { urls, _ in
            guard let url = urls.first, isSupportedImage(url) else { return false }
            model.auditDroppedImage(url: url); onOpenReview(); return true
        } isTargeted: { dashboard.isDropTargeted = $0 }
        .accessibilityHint("Opens a file chooser. You can also drop an image here.")
    }

    private var trendValues: [Double] {
        reviews.filter { $0.score?.isComplete == true }.sorted { $0.startedAt < $1.startedAt }.suffix(7).compactMap { $0.score.map { Double($0.value) } }
    }
    private var trendText: String {
        guard let first = trendValues.first, let last = trendValues.last else { return "Complete reviews will appear here; partial reviews are excluded." }
        let change = Int(last - first)
        if change == 0 { return "Quality is steady across \(trendValues.count) complete review(s)." }
        return "Quality \(change > 0 ? "improved" : "declined") by \(abs(change)) points across \(trendValues.count) complete review(s)."
    }
    private var trendAccessibleValue: String { "\(trendText) Scores: " + trendValues.map { "\(Int($0)) percent" }.joined(separator: ", ") }
    private var activityItems: [DashboardActivityItem] {
        var items = model.activityHistory.map { DashboardActivityItem(id: $0.id, timestamp: $0.timestamp, title: $0.passed ? "Review completed" : "Review needs attention", detail: $0.summary, symbol: $0.passed ? "checkmark.circle.fill" : "exclamationmark.triangle.fill", color: $0.passed ? .green : .orange) }
        if let report = model.doctorReport {
            items += report.checks.map { DashboardActivityItem(timestamp: Date(), title: $0.status == "confirmed" ? "Diagnostic passed" : "Diagnostic \($0.status)", detail: "\($0.name): \($0.detail)", symbol: $0.status == "confirmed" ? "checkmark.circle.fill" : ($0.status == "failed" ? "xmark.octagon.fill" : "minus.circle.fill"), color: $0.status == "confirmed" ? .green : ($0.status == "failed" ? .red : .secondary)) }
        }
        return items.sorted { $0.timestamp > $1.timestamp }
    }
    private func open(_ id: UUID) { model.openReview(reviewID: id); onOpenReview() }
    private func rerun(_ review: ReviewRecord) {
        switch review.source {
        case .template(let name): model.selectedTemplateName = name; model.renderPlaygroundTemplate()
        case .image(let url): model.auditDroppedImage(url: url)
        }
        onOpenReview()
    }
    private func isSupportedImage(_ url: URL) -> Bool { ["png", "jpg", "jpeg", "heic"].contains(url.pathExtension.lowercased()) }
}

private struct ReviewRecordStatusLabel: View {
    let review: ReviewRecord
    var body: some View { Label(review.status.displayName, systemImage: symbol).font(.caption.weight(.medium)).foregroundStyle(color).accessibilityLabel("Status: \(review.status.displayName)") }
    private var symbol: String {
        switch review.status {
        case .completed: return review.findings.isEmpty ? "checkmark.circle.fill" : "exclamationmark.triangle.fill"
        case .incomplete: return "circle.lefthalf.filled"
        case .stale: return "clock.badge.exclamationmark"
        case .failed: return "xmark.octagon.fill"
        case .cancelled: return "stop.circle.fill"
        case .preparing, .queued, .running: return "arrow.triangle.2.circlepath"
        case .idle: return "circle"
        }
    }
    private var color: Color {
        switch review.status {
        case .completed: return review.findings.isEmpty ? .green : .orange
        case .incomplete, .stale: return .orange
        case .failed: return .red
        case .preparing, .queued, .running: return ViewLensTheme.focus
        default: return .secondary
        }
    }
}

private struct DashboardBanner: View {
    let title: String; let message: String; let symbol: String; let color: Color
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: symbol).foregroundStyle(color).font(.title3).accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 3) { Text(title).font(.headline); Text(message).font(.caption).foregroundStyle(.secondary) }
            Spacer()
        }
        .padding(14).background(color.opacity(0.1), in: RoundedRectangle(cornerRadius: 10))
        .overlay { RoundedRectangle(cornerRadius: 10).stroke(color.opacity(0.35)) }
        .accessibilityElement(children: .combine)
    }
}

private struct DashboardActivityItem: Identifiable {
    let id: UUID; let timestamp: Date; let title: String; let detail: String; let symbol: String; let color: Color
    init(id: UUID = UUID(), timestamp: Date, title: String, detail: String, symbol: String, color: Color) { self.id = id; self.timestamp = timestamp; self.title = title; self.detail = detail; self.symbol = symbol; self.color = color }
}

private struct QualityTrendGraph: View {
    let values: [Double]
    var body: some View {
        GeometryReader { proxy in
            let points = graphPoints(in: proxy.size)
            ZStack {
                VStack { Divider(); Spacer(); Divider(); Spacer(); Divider() }
                Path { path in guard let first = points.first else { return }; path.move(to: first); for point in points.dropFirst() { path.addLine(to: point) } }
                    .stroke(ViewLensTheme.brand, style: StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round))
                ForEach(Array(points.enumerated()), id: \.offset) { index, point in Circle().fill(ViewLensTheme.brand).frame(width: 8, height: 8).position(point).accessibilityHidden(true).help("\(Int(values[index]))%") }
            }
        }
    }
    private func graphPoints(in size: CGSize) -> [CGPoint] {
        guard !values.isEmpty else { return [] }
        let minValue = max(0, (values.min() ?? 0) - 10); let maxValue = min(100, max((values.max() ?? 100) + 4, minValue + 1)); let step = values.count > 1 ? size.width / CGFloat(values.count - 1) : size.width / 2
        return values.enumerated().map { index, value in let ratio = (value - minValue) / (maxValue - minValue); return CGPoint(x: values.count > 1 ? CGFloat(index) * step : step, y: size.height - CGFloat(ratio) * size.height) }
    }
}
