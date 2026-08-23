import SwiftUI
import ViewLensKit

struct ReviewHistoryView: View {
    @Bindable var model: AppModel
    @Bindable var historyStore: HistoryStore
    let onOpenReview: () -> Void

    init(model: AppModel, onOpenReview: @escaping () -> Void) {
        self.model = model
        self.historyStore = model.historyStore
        self.onOpenReview = onOpenReview
    }

    private var filteredActivities: [MCPAgentActivity] {
        historyStore.filteredActivities(from: model.activityHistory)
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text("History")
                        .font(.largeTitle.bold())
                    Text("Review, reopen, and re-run previous accessibility audits.")
                        .foregroundStyle(.secondary)
                }
                Spacer()
                TextField("Search history", text: $historyStore.searchText)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 240)
            }
            .padding(24)

            Divider()

            if filteredActivities.isEmpty {
                ContentUnavailableView {
                    Label(historyStore.searchText.isEmpty ? "No Review History" : "No Matching Reviews", systemImage: "clock.arrow.circlepath")
                } description: {
                    Text(historyStore.searchText.isEmpty ? "Completed audits will appear here." : "Try a different search term.")
                }
            } else {
                Table(filteredActivities) {
                    TableColumn("Review") { activity in
                        VStack(alignment: .leading, spacing: 2) {
                            Text(activity.auditReport?.target ?? activity.toolName)
                                .fontWeight(.medium)
                            Text(activity.argumentsDescription)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                    }
                    TableColumn("Status") { activity in
                        Label(activity.passed ? "Passed" : "Issues", systemImage: activity.passed ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                            .foregroundStyle(activity.passed ? .green : .orange)
                    }
                    TableColumn("Issues") { activity in
                        Text("\(activity.auditReport?.issues.count ?? 0)")
                            .monospacedDigit()
                    }
                    TableColumn("Duration") { activity in
                        Text(String(format: "%.0f ms", activity.duration * 1000))
                            .monospacedDigit()
                    }
                    TableColumn("Last Run") { activity in
                        Text(activity.timestamp, style: .relative)
                    }
                    TableColumn("") { activity in
                        Button("Open") {
                            open(activity)
                        }
                        .buttonStyle(.borderless)
                    }
                    .width(60)
                }
            }
        }
        .navigationTitle("History")
    }

    private func open(_ activity: MCPAgentActivity) {
        model.openActivity(activity)
        onOpenReview()
    }
}
