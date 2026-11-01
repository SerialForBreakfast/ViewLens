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
        .onAppear {
            model.ensureSampleScreenshotsMaterialized()
            if model.currentImage == nil {
                model.updatePlaygroundCanvasImmediately()
            }
        }
        .onChange(of: playground.mode) { _, _ in
            model.updatePlaygroundCanvasImmediately()
        }
        .onChange(of: importConfigurationSignature) { _, _ in
            guard playground.mode == .importFile else { return }
            model.auditSelectedPlaygroundImage()
        }
        .fileImporter(isPresented: $showsFileImporter, allowedContentTypes: [.png, .jpeg, .heic, .image], allowsMultipleSelection: true) { result in
            switch result {
            case .success(let urls):
                _ = selectFiles(urls)
            case .failure(let error):
                playground.importError = error.localizedDescription
            }
        }
    }

    private var importConfigurationSignature: String {
        [
            playground.selectedFileURL?.path ?? "",
            playground.displayScale.rawValue,
            playground.wcagLevel,
            playground.optionalDeviceID ?? "none",
            String(format: "%.2f", playground.minimumConfidence)
        ].joined(separator: "|")
    }

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 3) {
                Text("Playground").font(.title.bold())
                Text("Configure a screenshot batch or registered SwiftUI template, then inspect the result in AI Review.")
                    .font(.subheadline).foregroundStyle(.secondary)
            }
            Spacer()
            if model.isRenderingPlayground { ProgressView().controlSize(.small).accessibilityLabel("Audit in progress") }
            Button(action: runAudit) {
                Label(playground.mode == .importFile ? "Open in AI Review" : "Run Matrix Audit", systemImage: "sparkles")
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
                        Image(systemName: playground.selectedFileURL == nil ? "square.and.arrow.down" : "photo.stack.fill")
                            .font(.title2).foregroundStyle(ViewLensTheme.brand).frame(width: 36)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(playground.selectedFileURL?.lastPathComponent ?? "Choose or drop screenshots").fontWeight(.medium)
                            Text("Import single or batch PNG, JPEG, or HEIC").font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer(); Image(systemName: "chevron.right").foregroundStyle(.secondary)
                    }.contentShape(Rectangle()).padding(.vertical, 6)
                }
                .buttonStyle(.plain)
                .dropDestination(for: URL.self) { urls, _ in
                    selectFiles(urls)
                } isTargeted: { playground.isDropTargeted = $0 }
                .overlay { RoundedRectangle(cornerRadius: 8).stroke(playground.isDropTargeted ? ViewLensTheme.brand : .clear, style: StrokeStyle(lineWidth: 2, dash: [6])) }
                if let error = playground.importError {
                    Label(error, systemImage: "exclamationmark.triangle.fill").font(.caption).foregroundStyle(.red)
                        .accessibilityLabel("Import error: \(error)")
                }
            }
            if !playground.importedBatchURLs.isEmpty {
                Section("Active Batch (\(playground.importedBatchURLs.count) Screenshots)") {
                    Picker("Selected screenshot", selection: $playground.selectedFileURL) {
                        ForEach(playground.importedBatchURLs, id: \.self) { url in
                            Text(url.lastPathComponent).tag(Optional(url))
                        }
                    }
                }
            }
            Section("Sample Screenshot Batch") {
                ForEach(playground.sampleScreenshots) { sample in
                    Button {
                        model.selectSampleScreenshot(sample)
                    } label: {
                        HStack(spacing: 10) {
                            Image(systemName: playground.selectedFileURL == sample.url ? "checkmark.circle.fill" : "photo")
                                .foregroundStyle(playground.selectedFileURL == sample.url ? ViewLensTheme.brand : .secondary)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(sample.title).fontWeight(.medium).foregroundStyle(.primary)
                                Text(sample.subtitle).font(.caption).foregroundStyle(.secondary)
                            }
                            Spacer()
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("playground.sample.\(sample.id)")
                }
                Button("Reset Batch to All Built-In Samples") {
                    model.loadSampleBatchIntoImporter()
                }
                .font(.caption)
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

    @discardableResult private func selectFiles(_ urls: [URL]) -> Bool {
        let supportedExtensions: Set<String> = ["png", "jpg", "jpeg", "heic", "tif", "tiff"]
        let validURLs = urls.filter { supportedExtensions.contains($0.pathExtension.lowercased()) }
        guard !validURLs.isEmpty else {
            playground.importError = "Unsupported file type. Choose PNG, JPEG, HEIC, TIFF, or another recognized image."
            return false
        }
        model.importScreenshotBatch(urls: validURLs)
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
