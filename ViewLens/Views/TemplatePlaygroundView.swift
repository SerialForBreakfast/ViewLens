import SwiftUI
import ViewLensKit

public struct TemplatePlaygroundView: View {
    @Bindable var model: AppModel
    @Bindable var playground: PlaygroundStore
    @Bindable var preferences: PreferenceStore

    public init(model: AppModel) {
        self.model = model
        self.playground = model.playgroundStore
        self.preferences = model.preferenceStore
    }

    public var body: some View {
        Form {
            Section("SwiftUI Template") {
                Picker("Template", selection: $model.selectedTemplateName) {
                    ForEach(TemplateRegistry.shared.availableTemplates, id: \.self) { Text($0).tag($0) }
                }.pickerStyle(.menu)
            }
            Section("Evaluation Matrix") {
                matrixMenu(title: "Devices", summary: "\(playground.selectedDeviceIDs.count) selected", choices: DeviceProfile.allPresets.map { ($0.id, $0.name) }, selection: $playground.selectedDeviceIDs)
                matrixMenu(title: "Dynamic Type", summary: "\(playground.selectedDynamicTypeNames.count) selected", choices: [("large", "Large"), ("accessibility1", "AX 1"), ("accessibility3", "AX 3"), ("accessibility5", "AX 5")], selection: $playground.selectedDynamicTypeNames)
                matrixMenu(title: "Appearance", summary: "\(playground.selectedAppearanceNames.count) selected", choices: [("light", "Light"), ("dark", "Dark")], selection: $playground.selectedAppearanceNames)
                Picker("WCAG target", selection: $playground.wcagLevel) {
                    Text("Level A").tag("A"); Text("Level AA").tag("AA"); Text("Level AAA").tag("AAA")
                }
                VStack(alignment: .leading, spacing: 4) {
                    LabeledContent("Detector confidence", value: playground.minimumConfidence.formatted(.percent.precision(.fractionLength(0))))
                    Slider(value: $playground.minimumConfidence, in: 0.05...0.95, step: 0.05)
                }
            }
            Section("Run Behavior") {
                Toggle("Auto-run when configuration changes", isOn: $preferences.autoRunPlayground)
                Text("The matrix contains \(permutationCount) permutation\(permutationCount == 1 ? "" : "s"). Auto-run is off by default.")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .onChange(of: configurationSignature) { _, _ in
            guard preferences.autoRunPlayground, !model.isRenderingPlayground else { return }
            model.renderPlaygroundTemplate()
        }
    }

    private var permutationCount: Int {
        max(1, playground.selectedDeviceIDs.count) * max(1, playground.selectedDynamicTypeNames.count) * max(1, playground.selectedAppearanceNames.count)
    }
    private var configurationSignature: String {
        [model.selectedTemplateName, playground.selectedDeviceIDs.sorted().joined(), playground.selectedDynamicTypeNames.sorted().joined(), playground.selectedAppearanceNames.sorted().joined(), playground.wcagLevel].joined(separator: "|")
    }

    private func matrixMenu(title: String, summary: String, choices: [(String, String)], selection: Binding<Set<String>>) -> some View {
        LabeledContent(title) {
            Menu(summary) {
                ForEach(choices, id: \.0) { id, label in
                    Button {
                        var updated = selection.wrappedValue
                        if updated.contains(id) { if updated.count > 1 { updated.remove(id) } } else { updated.insert(id) }
                        selection.wrappedValue = updated
                    } label: { Label(label, systemImage: selection.wrappedValue.contains(id) ? "checkmark" : "circle") }
                }
            }
        }
    }
}
