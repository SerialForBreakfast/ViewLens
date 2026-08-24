import SwiftUI
import UniformTypeIdentifiers
import ViewLensKit

struct PlaygroundWorkspaceView: View {
    @Bindable var model: AppModel
    @Bindable var playground: PlaygroundStore
    let onOpenReview: () -> Void
    @State private var showsFileImporter = false

    init(model: AppModel, onOpenReview: @escaping () -> Void) {
        self.model = model
        self.playground = model.playgroundStore
        self.onOpenReview = onOpenReview
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            HSplitView {
                VStack(spacing: 0) {
                    Picker("Playground Mode", selection: $playground.mode) {
                        ForEach(PlaygroundStore.Mode.allCases) { Text($0.rawValue).tag($0) }
                    }
                    .pickerStyle(.segmented).labelsHidden().padding(16)
                    Divider()
                    if playground.mode == .importFile { importConfiguration } else { TemplatePlaygroundView(model: model) }
                }
                .frame(minWidth: 340, idealWidth: 380, maxWidth: 460)
                VisualInspectorView(model: model).frame(minWidth: 520)
            }
        }
        .navigationTitle("Playground")
        .accessibilityIdentifier("screen.playground")
        .fileImporter(isPresented: $showsFileImporter, allowedContentTypes: [.png, .jpeg, .heic, .image], allowsMultipleSelection: false) { result in
            switch result {
            case .success(let urls): if let url = urls.first { selectFile(url) }
            case .failure(let error): playground.importError = error.localizedDescription
            }
        }
    }

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 3) {
                Text("Playground").font(.title.bold())
                Text("Configure a screenshot or registered SwiftUI template, then inspect the result in AI Review.")
                    .font(.subheadline).foregroundStyle(.secondary)
            }
            Spacer()
            if model.isRenderingPlayground { ProgressView().controlSize(.small).accessibilityLabel("Audit in progress") }
            Button(action: runAudit) {
                Label(playground.mode == .importFile ? "Run Audit" : "Run Matrix Audit", systemImage: "sparkles")
            }
            .buttonStyle(.borderedProminent)
            .disabled(model.isRenderingPlayground || (playground.mode == .importFile && playground.selectedFileURL == nil))
            .keyboardShortcut(.return, modifiers: [.command])
            .accessibilityIdentifier("playground.run")
        }
        .padding(20).background(ViewLensTheme.elevatedBackground)
    }

    private var importConfiguration: some View {
        Form {
            Section("Source") {
                Button { showsFileImporter = true } label: {
                    HStack(spacing: 12) {
                        Image(systemName: playground.selectedFileURL == nil ? "square.and.arrow.down" : "photo.fill")
                            .font(.title2).foregroundStyle(ViewLensTheme.brand).frame(width: 36)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(playground.selectedFileURL?.lastPathComponent ?? "Choose or drop an image").fontWeight(.medium)
                            Text("PNG, JPEG, or HEIC").font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer(); Image(systemName: "chevron.right").foregroundStyle(.secondary)
                    }.contentShape(Rectangle()).padding(.vertical, 6)
                }
                .buttonStyle(.plain)
                .dropDestination(for: URL.self) { urls, _ in
                    guard let url = urls.first else { return false }
                    return selectFile(url)
                } isTargeted: { playground.isDropTargeted = $0 }
                .overlay { RoundedRectangle(cornerRadius: 8).stroke(playground.isDropTargeted ? ViewLensTheme.brand : .clear, style: StrokeStyle(lineWidth: 2, dash: [6])) }
                if let error = playground.importError {
                    Label(error, systemImage: "exclamationmark.triangle.fill").font(.caption).foregroundStyle(.red)
                        .accessibilityLabel("Import error: \(error)")
                }
            }
            Section("Audit Configuration") {
                Picker("Display scale", selection: $playground.displayScale) {
                    ForEach(PlaygroundStore.DisplayScale.allCases) { Text($0.rawValue).tag($0) }
                }
                Picker("WCAG target", selection: $playground.wcagLevel) {
                    Text("Level A").tag("A"); Text("Level AA").tag("AA"); Text("Level AAA").tag("AAA")
                }
                Picker("Device profile", selection: $playground.optionalDeviceID) {
                    Text("Not specified").tag(nil as String?)
                    ForEach(DeviceProfile.allPresets, id: \.id) { Text($0.name).tag(Optional($0.id)) }
                }
                VStack(alignment: .leading, spacing: 4) {
                    LabeledContent("Minimum confidence", value: playground.minimumConfidence.formatted(.percent.precision(.fractionLength(0))))
                    Slider(value: $playground.minimumConfidence, in: 0.05...0.95, step: 0.05)
                }
            }
            Section {
                Text("Static screenshots evaluate visual criteria only. Programmatic name, role, state, and value remain explicitly unevaluated.")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }.formStyle(.grouped)
    }

    @discardableResult private func selectFile(_ url: URL) -> Bool {
        guard ["png", "jpg", "jpeg", "heic", "tif", "tiff"].contains(url.pathExtension.lowercased()) else {
            playground.importError = "Unsupported file type. Choose PNG, JPEG, HEIC, TIFF, or another recognized image."
            return false
        }
        playground.selectedFileURL = url
        playground.importError = nil
        return true
    }

    private func runAudit() {
        switch playground.mode {
        case .importFile:
            guard let url = playground.selectedFileURL else { return }
            model.auditDroppedImage(url: url, configuration: ScreenshotAuditConfiguration(
                displayScale: playground.displayScale.value,
                wcagLevel: playground.wcagLevel,
                device: playground.optionalDeviceID.flatMap(DeviceProfile.named),
                minimumConfidence: playground.minimumConfidence
            ))
        case .template: model.renderPlaygroundTemplate()
        }
        onOpenReview()
    }
}
