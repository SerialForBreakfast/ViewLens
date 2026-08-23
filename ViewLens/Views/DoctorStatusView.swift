import SwiftUI
import ViewLensKit

public struct DoctorStatusView: View {
    @Bindable var model: AppModel

    public init(model: AppModel) {
        self.model = model
    }

    public var body: some View {
        HStack(spacing: 16) {
            // MCP Server Status Badge
            HStack(spacing: 8) {
                Circle()
                    .fill(Color.green)
                    .frame(width: 10, height: 10)
                VStack(alignment: .leading, spacing: 2) {
                    Text("MCP Server")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Text(model.mcpStatus)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(RoundedRectangle(cornerRadius: 8).fill(Color.green.opacity(0.1)))

            Divider()
                .frame(height: 28)

            // CoreML Model Readiness
            let isReady = model.doctorReport?.status == "ready"
            HStack(spacing: 8) {
                Image(systemName: isReady ? "brain.head.profile.fill" : "exclamationmark.triangle.fill")
                    .foregroundColor(isReady ? .blue : .orange)

                VStack(alignment: .leading, spacing: 2) {
                    Text("CoreML Detector")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Text(isReady ? "YOLO11n (ANE Active)" : "Model Not Found")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                }
            }

            Divider()
                .frame(height: 28)

            // Active / Recent Tool Activity
            if let activity = model.activeActivity {
                HStack(spacing: 8) {
                    Image(systemName: activity.passed ? "checkmark.circle.fill" : "xmark.circle.fill")
                        .foregroundColor(activity.passed ? .green : .red)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Current Work: \(activity.toolName)")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        Text(activity.summary)
                            .font(.subheadline)
                            .lineLimit(1)
                    }
                }
            } else {
                Text("Waiting for agent activity...")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            // Diagnostics Button
            Button(action: {
                model.runDoctorCheck()
            }) {
                HStack(spacing: 6) {
                    if model.isRunningDoctor {
                        ProgressView()
                            .controlSize(.small)
                    } else {
                        Image(systemName: "stethoscope")
                    }
                    Text("Doctor Probe")
                }
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Color(NSColor.windowBackgroundColor))
    }
}
