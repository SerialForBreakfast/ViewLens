import AppKit
import SwiftUI
import ViewLensKit

struct ViewLensSettingsView: View {
    @Bindable var model: AppModel
    @Bindable var preferences: PreferenceStore
    @State private var showsDiagnostics = false
    @State private var showsStorageManagement = false

    init(model: AppModel) {
        self.model = model
        self.preferences = model.preferenceStore
    }

    var body: some View {
        Form {
            generalSection
            auditPolicySection
            integrationsSection
            storageSection
            accessibilitySection
            diagnosticsSection
        }
        .formStyle(.grouped).frame(maxWidth: 760).padding(.horizontal, 24)
        .navigationTitle("Settings")
        .accessibilityIdentifier("screen.settings")
        .sheet(isPresented: $showsDiagnostics) { DiagnosticsSheet(model: model) }
        .sheet(isPresented: $showsStorageManagement) { StorageManagementSheet(model: model) }
        .onChange(of: preferences.historyRetention) { _, _ in model.applyRetentionPolicy() }
        .onChange(of: preferences.assetRetention) { _, _ in model.applyAssetRetentionPolicy() }
        .onChange(of: preferences.wcagLevel) { _, _ in model.applyAuditPreferenceDefaults() }
        .onChange(of: preferences.detectorConfidence) { _, _ in if confidenceIsValid { model.applyAuditPreferenceDefaults() } }
        .onChange(of: preferences.requiredMatrix) { _, _ in model.applyAuditPreferenceDefaults() }
    }

    private var generalSection: some View {
        Section("General") {
            Picker("Launch destination", selection: $preferences.launchDestination) {
                Text("Current Status").tag(AppDestination.currentStatus.rawValue)
                Text("Last-open screen").tag("Last-open screen")
            }
            Picker("Appearance", selection: $preferences.appearance) { Text("System").tag("System"); Text("Light").tag("Light"); Text("Dark").tag("Dark") }
            Toggle("Show menu bar status item", isOn: $preferences.showMenuBarItem)
            Toggle("Confirm before cancelling active reviews", isOn: $preferences.confirmCancellation)
        }
    }

    private var auditPolicySection: some View {
        Section("Audit Policy") {
            Picker("Default WCAG target", selection: $preferences.wcagLevel) { Text("Level A").tag("A"); Text("Level AA").tag("AA"); Text("Level AAA").tag("AAA") }
            Picker("Target-size policy", selection: $preferences.targetSizePolicy) { Text("WCAG 2.5.8 (24 pt)").tag("WCAG 2.5.8 (24 pt)"); Text("WCAG 2.5.5 (44 pt)").tag("WCAG 2.5.5 (44 pt)") }
            Picker("Quality-gate failure", selection: $preferences.failureSeverity) { Text("Error").tag("Error"); Text("Warning").tag("Warning"); Text("Any finding").tag("Any finding") }
            Picker("Required matrix", selection: $preferences.requiredMatrix) { Text("Standard").tag("Standard"); Text("Expanded").tag("Expanded"); Text("Exhaustive").tag("Exhaustive") }
            LabeledContent("Detector confidence") {
                TextField("Confidence", value: $preferences.detectorConfidence, format: .number.precision(.fractionLength(2))).frame(width: 72).multilineTextAlignment(.trailing)
            }
            if !confidenceIsValid {
                Label("Enter a value from 0.05 through 0.95.", systemImage: "exclamationmark.triangle.fill").font(.caption).foregroundStyle(.red)
            }
            TextField("Custom rules file (optional)", text: $preferences.customRulePath)
            if !preferences.customRulePath.isEmpty && !FileManager.default.fileExists(atPath: preferences.customRulePath) {
                Label("The custom rules file does not exist.", systemImage: "doc.badge.ellipsis").font(.caption).foregroundStyle(.orange)
            }
            Toggle("Auto-run Playground when configuration changes", isOn: $preferences.autoRunPlayground)
        }
    }

    private var integrationsSection: some View {
        Section("Integrations") {
            LabeledContent("MCP Server", value: model.mcpStatus)
            LabeledContent("CoreML model", value: model.doctorReport?.status == "ready" ? "Ready" : "Needs attention")
            LabeledContent("CLI", value: "viewlens")
        }
    }

    private var storageSection: some View {
        Section("Storage") {
            Picker("Review history retention", selection: $preferences.historyRetention) { Text("7 days").tag("7 days"); Text("30 days").tag("30 days"); Text("90 days").tag("90 days"); Text("Forever").tag("Forever") }
            Picker("Preview assets", selection: $preferences.assetRetention) { Text("With review").tag("With review"); Text("30 days").tag("30 days"); Text("Do not retain").tag("Do not retain") }
            LabeledContent("Stored reviews", value: "\(model.reviewStore.reviews.count)")
            LabeledContent("Storage used", value: ByteCountFormatter.string(fromByteCount: model.reviewStore.storageBytes, countStyle: .file))
            Button("Manage Review Storage…") { showsStorageManagement = true }
        }
    }

    private var accessibilitySection: some View {
        Section("Accessibility & Nonvisual") {
            Picker("Nonvisual presentation detail", selection: $preferences.nonvisualProfile) {
                Text("Speech (Concise narrative)").tag("Speech")
                Text("Braille (Formatted code lines)").tag("Braille")
                Text("Developer (Full provenance & IDs)").tag("Developer")
            }
            Toggle("Announce review phase changes in VoiceOver", isOn: $preferences.announcePhaseChanges)
            Toggle("Differentiate overlays without color", isOn: $preferences.differentiateWithoutColor)
            HStack(spacing: 16) {
                Label("Error · solid", systemImage: "xmark.octagon.fill").foregroundStyle(.red)
                Label("Warning · dashed", systemImage: "exclamationmark.triangle.fill").foregroundStyle(.orange)
                Label("Info · dotted", systemImage: "info.circle.fill").foregroundStyle(.blue)
            }.accessibilityElement(children: .combine).accessibilityLabel("Overlay palette: error solid, warning dashed, information dotted")
            Text("VoiceOver users can use the custom 'Findings', 'Interactive Controls', and 'Regions' rotors inside the Nonvisual Outline.")
                .font(.caption).foregroundStyle(.secondary)
            Button("Reset Panel Layout") { model.showOverlays = true; model.showElementLabels = true; model.showSafeAreaGuides = true }
        }
    }

    private var diagnosticsSection: some View {
        Section("Diagnostics") {
            LabeledContent("Persistence", value: model.reviewStore.persistenceState.displayName)
            LabeledContent("Build", value: Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "Development")
            HStack {
                Button { model.runDoctorCheck() } label: { Label("Run Checks", systemImage: "stethoscope") }.disabled(model.isRunningDoctor)
                Button("Open Diagnostics…") { showsDiagnostics = true }
            }
        }
    }

    private var confidenceIsValid: Bool { (0.05...0.95).contains(preferences.detectorConfidence) }
}

struct DiagnosticsSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Bindable var model: AppModel
    @State private var copied = false

    var body: some View {
        VStack(spacing: 0) {
            HStack { Text("ViewLens Diagnostics").font(.title2.bold()); Spacer(); Button("Done") { dismiss() }.keyboardShortcut(.cancelAction) }.padding(16)
            Divider()
            if let report = model.doctorReport {
                List {
                    Section("System") { LabeledContent("Status", value: report.status); LabeledContent("MCP", value: model.mcpStatus); LabeledContent("Persistence", value: model.reviewStore.persistenceState.displayName) }
                    Section("Checks") {
                        ForEach(Array(report.checks.enumerated()), id: \.offset) { _, check in
                            HStack(alignment: .top) {
                                Image(systemName: check.status == "confirmed" ? "checkmark.circle.fill" : "exclamationmark.triangle.fill").foregroundStyle(check.status == "confirmed" ? .green : .orange).accessibilityHidden(true)
                                VStack(alignment: .leading) { Text(check.name).fontWeight(.semibold); Text(check.detail).font(.caption).foregroundStyle(.secondary).textSelection(.enabled) }
                            }.accessibilityElement(children: .combine)
                        }
                    }
                }
            } else { ContentUnavailableView("Diagnostics Not Run", systemImage: "stethoscope", description: Text("Run the doctor probe to inspect model and detector readiness.")) }
            Divider()
            HStack {
                Button { model.runDoctorCheck() } label: { Label("Run Again", systemImage: "arrow.clockwise") }.disabled(model.isRunningDoctor)
                Button { copyDiagnostics() } label: { Label(copied ? "Copied" : "Copy Diagnostics", systemImage: copied ? "checkmark" : "doc.on.doc") }
                Spacer()
                if let url = model.reviewStore.storageURL { Button("Reveal Storage") { NSWorkspace.shared.activateFileViewerSelecting([url]) } }
            }.padding(16)
        }.frame(minWidth: 620, minHeight: 520)
    }

    private func copyDiagnostics() {
        let checks = model.doctorReport?.checks.map { "\($0.name): \($0.status) — \($0.detail)" }.joined(separator: "\n") ?? "Doctor probe not run"
        let text = "ViewLens diagnostics\nMCP: \(model.mcpStatus)\nPersistence: \(model.reviewStore.persistenceState.displayName)\n\(checks)"
        NSPasteboard.general.clearContents(); NSPasteboard.general.setString(text, forType: .string); copied = true
    }
}

private struct StorageManagementSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Bindable var model: AppModel
    @State private var confirmsDeletion = false
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack { Text("Review Storage").font(.title2.bold()); Spacer(); Button("Done") { dismiss() }.keyboardShortcut(.cancelAction) }
            Text("ViewLens stores review metadata and preview images locally so History survives relaunch.").foregroundStyle(.secondary)
            GroupBox {
                VStack(alignment: .leading, spacing: 8) {
                    LabeledContent("Reviews", value: "\(model.reviewStore.reviews.count)")
                    LabeledContent("Disk usage", value: ByteCountFormatter.string(fromByteCount: model.reviewStore.storageBytes, countStyle: .file))
                    LabeledContent("Location", value: model.reviewStore.storageURL?.path ?? "Unavailable")
                }.padding(8)
            }
            Spacer()
            Button("Delete All Review History…", role: .destructive) { confirmsDeletion = true }.disabled(model.reviewStore.reviews.isEmpty)
        }
        .padding(20).frame(minWidth: 560, minHeight: 330)
        .confirmationDialog("Delete all review history?", isPresented: $confirmsDeletion, titleVisibility: .visible) {
            Button("Delete All Reviews", role: .destructive) { model.reviewStore.deleteAllReviews() }
            Button("Cancel", role: .cancel) {}
        } message: { Text("All persisted review records and preview images will be permanently removed. This cannot be undone.") }
    }
}
