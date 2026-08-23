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
                        Text("\(preset.name) (\(Int(preset.pointWidth))x\(Int(preset.pointHeight))pt @\(Int(preset.scale))x)").tag(preset)
                    }
                }
                .pickerStyle(.menu)
            }

            Section(header: Text("Accessibility & Environment")) {
                Picker("Dynamic Type", selection: $model.selectedDynamicType) {
                    Text("xSmall").tag(DynamicTypeSize.xSmall)
                    Text("Small").tag(DynamicTypeSize.small)
                    Text("Medium").tag(DynamicTypeSize.medium)
                    Text("Large (Default)").tag(DynamicTypeSize.large)
                    Text("xLarge").tag(DynamicTypeSize.xLarge)
                    Text("xxLarge").tag(DynamicTypeSize.xxLarge)
                    Text("xxxLarge").tag(DynamicTypeSize.xxxLarge)
                    Text("Accessibility 1").tag(DynamicTypeSize.accessibility1)
                    Text("Accessibility 3").tag(DynamicTypeSize.accessibility3)
                    Text("Accessibility 5").tag(DynamicTypeSize.accessibility5)
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
                            Image(systemName: "play.fill")
                        }
                        Text("Render & Audit Canvas")
                            .fontWeight(.semibold)
                        Spacer()
                    }
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
            }
        }
        .formStyle(.grouped)
        .padding(8)
    }
}
