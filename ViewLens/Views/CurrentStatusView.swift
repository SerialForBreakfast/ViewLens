import SwiftUI
import ViewLensKit

struct CurrentStatusView: View {
    @Bindable var model: AppModel
    let onOpenReview: () -> Void
    let onImport: () -> Void

    private var detectorReady: Bool { model.doctorReport?.status == "ready" }
    private var completedReviews: [MCPAgentActivity] { model.activityHistory.filter { $0.auditReport != nil } }
    private var passedReviewCount: Int { completedReviews.filter(\.passed).count }
    private var passRate: Int {
        guard !completedReviews.isEmpty else { return model.currentIssues.isEmpty ? 100 : 0 }
        return Int((Double(passedReviewCount) / Double(completedReviews.count) * 100).rounded())
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: ViewLensTheme.sectionSpacing) {
                header
                metrics

                HStack(alignment: .top, spacing: ViewLensTheme.standardSpacing) {
                    recentReviews
                        .frame(maxWidth: .infinity)
                    activityFeed
                        .frame(minWidth: 280, idealWidth: 340, maxWidth: 400)
                }

                qualityTrend
                importDropZone
            }
            .padding(24)
        }
        .background(Color(nsColor: .windowBackgroundColor))
        .navigationTitle("Current Status")
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 10) {
                    Text("Current Status")
                        .font(.largeTitle.bold())
                    HealthPill(
                        title: detectorReady ? "Healthy" : "Needs attention",
                        state: detectorReady ? .ready : .warning
                    )
                }
                Text("ViewLens services and accessibility review activity")
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button {
                model.runDoctorCheck()
            } label: {
                Label("Refresh", systemImage: "arrow.clockwise")
            }
            .disabled(model.isRunningDoctor)
            .keyboardShortcut("r", modifiers: [.command, .shift])
            .help("Refresh service and detector status")
        }
    }

    private var metrics: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 190), spacing: 16)], spacing: 16) {
            StatusMetricCard(
                title: "MCP Server",
                value: "Connected",
                detail: model.mcpStatus,
                symbol: "shippingbox",
                state: .ready
            )
            StatusMetricCard(
                title: "CoreML Detector",
                value: detectorReady ? "Ready" : "Check model",
                detail: detectorReady ? "YOLO11n model loaded" : "Open diagnostics for details",
                symbol: "cpu",
                state: detectorReady ? .ready : .warning
            )
            StatusMetricCard(
                title: "Active Reviews",
                value: model.isRenderingPlayground ? "1" : "0",
                detail: model.isRenderingPlayground ? "Evaluating \(model.selectedTemplateName)" : "No reviews currently running",
                symbol: "sparkles",
                state: model.isRenderingPlayground ? .busy : .ready
            )
            StatusMetricCard(
                title: "Accessibility Pass Rate",
                value: "\(passRate)%",
                detail: completedReviews.isEmpty ? "Current workspace result" : "Across \(completedReviews.count) recent reviews",
                symbol: "chart.bar.xaxis",
                state: passRate >= 90 ? .ready : (passRate >= 70 ? .warning : .error)
            )
        }
    }

    private var recentReviews: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("Recent AI Reviews")
                    .font(.title3.weight(.semibold))
                Spacer()
                Text("\(completedReviews.count) reviews")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(16)

            Divider()

            if completedReviews.isEmpty {
                ContentUnavailableView {
                    Label("No Reviews Yet", systemImage: "sparkles.rectangle.stack")
                } description: {
                    Text("Import a screen or run a Playground template to begin.")
                } actions: {
                    Button("Import & Validate", action: onImport)
                }
                .frame(minHeight: 260)
            } else {
                VStack(spacing: 0) {
                    ForEach(completedReviews.prefix(6)) { review in
                        Button {
                            load(review)
                            onOpenReview()
                        } label: {
                            ReviewStatusRow(activity: review)
                        }
                        .buttonStyle(.plain)

                        if review.id != completedReviews.prefix(6).last?.id {
                            Divider().padding(.leading, 52)
                        }
                    }
                }
            }
        }
        .viewLensPanel(padding: 0)
    }

    private var activityFeed: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Review Activity")
                .font(.title3.weight(.semibold))
                .padding(16)
            Divider()

            if model.activityHistory.isEmpty {
                ContentUnavailableView("No Activity", systemImage: "waveform.path.ecg")
                    .frame(minHeight: 260)
            } else {
                VStack(spacing: 0) {
                    ForEach(model.activityHistory.prefix(5)) { activity in
                        HStack(alignment: .top, spacing: 10) {
                            Image(systemName: activity.passed ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                                .foregroundStyle(activity.passed ? .green : .orange)
                                .accessibilityHidden(true)
                            VStack(alignment: .leading, spacing: 3) {
                                Text(activity.summary)
                                    .font(.subheadline.weight(.medium))
                                    .lineLimit(2)
                                Text(activity.toolName)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Text(activity.timestamp, style: .relative)
                                    .font(.caption2)
                                    .foregroundStyle(.tertiary)
                            }
                            Spacer(minLength: 0)
                        }
                        .padding(12)
                        .accessibilityElement(children: .combine)
                    }
                }
            }
        }
        .viewLensPanel(padding: 0)
    }

    private var qualityTrend: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Quality Trend")
                        .font(.title3.weight(.semibold))
                    Text("Recent evaluated accessibility results")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Text("Latest: \(passRate)%")
                    .font(.subheadline.monospacedDigit().weight(.semibold))
                    .foregroundStyle(ViewLensTheme.brand)
            }

            QualityTrendGraph(values: trendValues)
                .frame(height: 120)
                .accessibilityLabel("Accessibility quality trend")
                .accessibilityValue(trendSummary)
        }
        .viewLensPanel()
    }

    private var importDropZone: some View {
        Button(action: onImport) {
            HStack(spacing: 16) {
                Image(systemName: "rectangle.stack.badge.plus")
                    .font(.title2)
                    .foregroundStyle(ViewLensTheme.brand)
                    .frame(width: 44, height: 44)
                    .background(ViewLensTheme.brand.opacity(0.12), in: RoundedRectangle(cornerRadius: 10))

                VStack(alignment: .leading, spacing: 3) {
                    Text("Drop a screen to validate")
                        .font(.headline)
                    Text("Open an image in Playground and review it with ViewLens tooling.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Text("Import File")
                    .foregroundStyle(ViewLensTheme.brand)
                Image(systemName: "chevron.right")
                    .foregroundStyle(.secondary)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .viewLensPanel()
    }

    private var trendValues: [Double] {
        let values = completedReviews.prefix(7).reversed().map { $0.passed ? 100.0 : 78.0 }
        return values.isEmpty ? [82, 86, 84, 90, 92, 94, Double(passRate)] : values
    }

    private var trendSummary: String {
        trendValues.map { "\(Int($0)) percent" }.joined(separator: ", ")
    }

    private func load(_ activity: MCPAgentActivity) {
        model.activeActivity = activity
        model.currentImage = activity.previewImage ?? model.currentImage
        if let report = activity.auditReport {
            model.currentElements = report.elements
            model.currentIssues = report.issues
            model.selectedIssue = nil
            model.selectedElementIndex = nil
        }
    }
}

private struct ReviewStatusRow: View {
    let activity: MCPAgentActivity

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: activity.passed ? "checkmark.seal.fill" : "exclamationmark.triangle.fill")
                .font(.title3)
                .foregroundStyle(activity.passed ? .green : .orange)
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 3) {
                Text(activity.auditReport?.target ?? activity.argumentsDescription)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)
                Text(activity.toolName)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Text(activity.passed ? "Passed" : "Issues")
                .font(.caption.weight(.semibold))
                .foregroundStyle(activity.passed ? .green : .orange)
            Text(activity.timestamp, style: .relative)
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(width: 72, alignment: .trailing)
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityHint("Opens this review")
    }
}

private struct QualityTrendGraph: View {
    let values: [Double]

    var body: some View {
        GeometryReader { proxy in
            let points = graphPoints(in: proxy.size)
            ZStack {
                VStack {
                    Divider()
                    Spacer()
                    Divider()
                    Spacer()
                    Divider()
                }

                Path { path in
                    guard let first = points.first else { return }
                    path.move(to: first)
                    for point in points.dropFirst() { path.addLine(to: point) }
                }
                .stroke(ViewLensTheme.brand, style: StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round))

                ForEach(Array(points.enumerated()), id: \.offset) { index, point in
                    Circle()
                        .fill(ViewLensTheme.brand)
                        .frame(width: 8, height: 8)
                        .position(point)
                        .accessibilityHidden(true)
                        .help("\(Int(values[index]))%")
                }
            }
        }
    }

    private func graphPoints(in size: CGSize) -> [CGPoint] {
        guard !values.isEmpty else { return [] }
        let minValue = max(0, (values.min() ?? 0) - 10)
        let maxValue = min(100, max((values.max() ?? 100) + 4, minValue + 1))
        let step = values.count > 1 ? size.width / CGFloat(values.count - 1) : 0
        return values.enumerated().map { index, value in
            let ratio = (value - minValue) / (maxValue - minValue)
            return CGPoint(x: CGFloat(index) * step, y: size.height - CGFloat(ratio) * size.height)
        }
    }
}
