import SwiftUI
import ViewLensKit

public struct ActivityLogView: View {
    @Bindable var model: AppModel

    public init(model: AppModel) {
        self.model = model
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Label("Agent MCP Activity Stream", systemImage: "bolt.horizontal.fill")
                    .font(.headline)
                Spacer()
                Text("\(model.activityHistory.count) requests")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(12)
            .background(Color(NSColor.controlBackgroundColor))

            Divider()

            if model.activityHistory.isEmpty {
                VStack(spacing: 8) {
                    Spacer()
                    Image(systemName: "antenna.radiowaves.left.and.right")
                        .font(.system(size: 32))
                        .foregroundStyle(.secondary)
                    Text("No Agent Requests Yet")
                        .font(.subheadline)
                    Text("Launch Claude Code or Cursor with 'viewlens mcp' to see live tool calls.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)
                    Spacer()
                }
                .frame(maxWidth: .infinity)
            } else {
                List(model.activityHistory) { activity in
                    ActivityRowView(activity: activity, isSelected: model.activeActivity?.id == activity.id) {
                        model.openActivity(activity)
                    }
                }
                .listStyle(.plain)
            }
        }
    }
}

struct ActivityRowView: View {
    let activity: MCPAgentActivity
    let isSelected: Bool
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            HStack(alignment: .top, spacing: 10) {
                Circle()
                    .fill(activity.passed ? Color.green : Color.red)
                    .frame(width: 8, height: 8)
                    .padding(.top, 4)

                VStack(alignment: .leading, spacing: 2) {
                    HStack {
                        Text(activity.toolName)
                            .font(.subheadline)
                            .fontWeight(.semibold)

                        Spacer()

                        Text(String(format: "%.0fms", activity.duration * 1000))
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }

                    Text(activity.argumentsDescription)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)

                    Text(activity.summary)
                        .font(.caption2)
                        .foregroundStyle(activity.passed ? Color.secondary : Color.red)
                }
            }
            .padding(.vertical, 4)
            .background(isSelected ? Color.accentColor.opacity(0.1) : Color.clear)
        }
        .buttonStyle(.plain)
    }
}
