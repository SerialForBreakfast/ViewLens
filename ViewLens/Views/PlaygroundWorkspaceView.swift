import SwiftUI

struct PlaygroundWorkspaceView: View {
    @Bindable var model: AppModel
    let onOpenReview: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Playground")
                        .font(.title.bold())
                    Text("Configure a registered SwiftUI template and validate it with ViewLens.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button {
                    model.renderPlaygroundTemplate()
                    onOpenReview()
                } label: {
                    Label("Run AI Review", systemImage: "sparkles")
                }
                .buttonStyle(.borderedProminent)
                .disabled(model.isRenderingPlayground)
            }
            .padding(20)
            .background(ViewLensTheme.elevatedBackground)

            Divider()

            HSplitView {
                TemplatePlaygroundView(model: model)
                    .frame(minWidth: 300, idealWidth: 340, maxWidth: 420)
                VisualInspectorView(model: model)
                    .frame(minWidth: 520)
            }
        }
        .navigationTitle("Playground")
    }
}
