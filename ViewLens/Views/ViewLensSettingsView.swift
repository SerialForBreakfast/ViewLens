import SwiftUI
import ViewLensKit

struct ViewLensSettingsView: View {
    @Bindable var model: AppModel
    @Bindable var preferences: PreferenceStore

    init(model: AppModel) {
        self.model = model
        self.preferences = model.preferenceStore
    }

    var body: some View {
        Form {
            Section("General") {
                Picker("Appearance", selection: $preferences.appearance) {
                    Text("System").tag("System")
                    Text("Light").tag("Light")
                    Text("Dark").tag("Dark")
                }
                Toggle("Confirm before cancelling active reviews", isOn: $preferences.confirmCancellation)
            }

            Section("Audit Policy") {
                Picker("Default WCAG target", selection: $preferences.wcagLevel) {
                    Text("Level A").tag("A")
                    Text("Level AA").tag("AA")
                    Text("Level AAA").tag("AAA")
                }
                Toggle("Auto-run Playground when configuration changes", isOn: $preferences.autoRunPlayground)
            }

            Section("Storage") {
                Picker("Review history retention", selection: $preferences.historyRetention) {
                    Text("7 days").tag("7 days")
                    Text("30 days").tag("30 days")
                    Text("90 days").tag("90 days")
                    Text("Forever").tag("Forever")
                }
                LabeledContent("Reviews in this session", value: "\(model.activityHistory.count)")
            }

            Section("Diagnostics") {
                LabeledContent("MCP Server", value: model.mcpStatus)
                LabeledContent("CoreML Detector", value: model.doctorReport?.status == "ready" ? "Ready" : "Needs attention")
                Button {
                    model.runDoctorCheck()
                } label: {
                    Label("Run Doctor Probe", systemImage: "stethoscope")
                }
                .disabled(model.isRunningDoctor)
            }
        }
        .formStyle(.grouped)
        .frame(maxWidth: 720)
        .padding(.horizontal, 24)
        .navigationTitle("Settings")
    }
}
