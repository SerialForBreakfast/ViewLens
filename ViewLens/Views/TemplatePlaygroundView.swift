import SwiftUI
import ViewLensKit

public struct TemplatePlaygroundView: View {
    @Bindable var model: AppModel

    public init(model: AppModel) {
        self.model = model
    }

    public var body: some View {
        Form {
            Section(header: Text("SwiftUI Template")) {
                Picker("Template", selection: $model.selectedTemplateName) {
                    ForEach(TemplateRegistry.shared.availableTemplates, id: \.self) { name in
                        Text(name).tag(name)
                    }
                }
                .pickerStyle(.menu)
            }

            Section(header: Text("Device & Hardware Shape")) {
                Picker("Target Device", selection: $model.selectedDevice) {
                    ForEach(DeviceProfile.allPresets, id: \.id) { preset in
                        Text("\(preset.name) (\(Int(preset.pointWidth))×\(Int(preset.pointHeight))pt @\(Int(preset.scale))x)").tag(preset)
                    }
                }
                .pickerStyle(.menu)
            }

            Section(header: Text("Accessibility & Environment")) {
                Picker("Dynamic Type", selection: $model.selectedDynamicType) {
                    Group {
                        Text("xSmall (80% • 14pt)").tag(DynamicTypeSize.xSmall)
                        Text("Small (88% • 15pt)").tag(DynamicTypeSize.small)
                        Text("Medium (94% • 16pt)").tag(DynamicTypeSize.medium)
                        Text("Large (100% • 17pt Default)").tag(DynamicTypeSize.large)
                        Text("xLarge (112% • 19pt)").tag(DynamicTypeSize.xLarge)
                        Text("xxLarge (124% • 21pt)").tag(DynamicTypeSize.xxLarge)
                        Text("xxxLarge (135% • 23pt)").tag(DynamicTypeSize.xxxLarge)
                    }
                    Divider()
                    Group {
                        Text("AX 1 (165% • 28pt Min Accessibility)").tag(DynamicTypeSize.accessibility1)
                        Text("AX 2 (194% • 33pt)").tag(DynamicTypeSize.accessibility2)
                        Text("AX 3 (235% • 40pt Standard Audit)").tag(DynamicTypeSize.accessibility3)
                        Text("AX 4 (276% • 47pt)").tag(DynamicTypeSize.accessibility4)
                        Text("AX 5 (312% • 53pt Max Accessibility)").tag(DynamicTypeSize.accessibility5)
                    }
                }
                .pickerStyle(.menu)

                Picker("Color Scheme", selection: $model.selectedColorScheme) {
                    Text("Light").tag(ColorScheme.light)
                    Text("Dark").tag(ColorScheme.dark)
                }
                .pickerStyle(.segmented)
            }

            Section {
                Button(action: {
                    model.renderPlaygroundTemplate()
                }) {
                    HStack {
                        Spacer()
                        if model.isRenderingPlayground {
                            ProgressView()
                                .controlSize(.small)
                        } else {
                            Image(systemName: "arrow.clockwise")
                        }
                        Text("Re-Audit Canvas")
                            .fontWeight(.semibold)
                        Spacer()
                    }
                }
                .buttonStyle(.bordered)
                .controlSize(.regular)
            }
        }
        .formStyle(.grouped)
        .padding(8)
        // Reactive Live Auto-Update on any property change
        .onChange(of: model.selectedTemplateName) { _, _ in
            model.renderPlaygroundTemplate()
        }
        .onChange(of: model.selectedDevice) { _, _ in
            model.renderPlaygroundTemplate()
        }
        .onChange(of: model.selectedDynamicType) { _, _ in
            model.renderPlaygroundTemplate()
        }
        .onChange(of: model.selectedColorScheme) { _, _ in
            model.renderPlaygroundTemplate()
        }
    }
}
