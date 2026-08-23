import SwiftUI
import CoreGraphics
import UniformTypeIdentifiers
import ViewLensKit

public struct VisualInspectorView: View {
    @Bindable var model: AppModel
    @State private var hoveredElementIndex: Int? = nil

    public init(model: AppModel) {
        self.model = model
    }

    public var body: some View {
        VStack(spacing: 0) {
            // Toolbar Controls
            HStack(spacing: 16) {
                Label("Visual Inspector Canvas", systemImage: "eye.fill")
                    .font(.headline)

                Spacer()

                Toggle("Overlays", isOn: $model.showOverlays)
                    .toggleStyle(.checkbox)
                    .controlSize(.small)

                Toggle("Labels", isOn: $model.showElementLabels)
                    .toggleStyle(.checkbox)
                    .controlSize(.small)

                Toggle("Safe Areas", isOn: $model.showSafeAreaGuides)
                    .toggleStyle(.checkbox)
                    .controlSize(.small)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(Color(NSColor.controlBackgroundColor))

            Divider()

            // Main Canvas Area
            GeometryReader { geo in
                ZStack {
                    // Dark checkered background for alpha contrast
                    Rectangle()
                        .fill(Color.black.opacity(0.85))
                        .ignoresSafeArea()

                    if let cgImage = model.currentImage {
                        let imgSize = CGSize(width: cgImage.width, height: cgImage.height)
                        let fitScale = min(
                            (geo.size.width - 48) / imgSize.width,
                            (geo.size.height - 48) / imgSize.height
                        )
                        let displayWidth = imgSize.width * fitScale
                        let displayHeight = imgSize.height * fitScale

                        ZStack(alignment: .topLeading) {
                            // Base Rendered / Screenshot Image
                            Image(decorative: cgImage, scale: 1.0)
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(width: displayWidth, height: displayHeight)
                                .cornerRadius(model.selectedDevice.cornerRadius * fitScale)
                                .shadow(color: .black.opacity(0.4), radius: 16, x: 0, y: 8)

                            // Safe Area Visual Guides
                            if model.showSafeAreaGuides {
                                let topPadding = model.selectedDevice.safeAreaInsets.top * model.selectedDevice.scale * fitScale
                                let bottomPadding = model.selectedDevice.safeAreaInsets.bottom * model.selectedDevice.scale * fitScale

                                if topPadding > 0 {
                                    Rectangle()
                                        .fill(Color.cyan.opacity(0.12))
                                        .frame(width: displayWidth, height: topPadding)
                                        .overlay(
                                            Text("Top Safe Area (\(Int(model.selectedDevice.safeAreaInsets.top))pt)")
                                                .font(.system(size: 9, weight: .bold))
                                                .foregroundStyle(.cyan)
                                                .padding(2),
                                            alignment: .bottomLeading
                                        )
                                }

                                if bottomPadding > 0 {
                                    Rectangle()
                                        .fill(Color.cyan.opacity(0.12))
                                        .frame(width: displayWidth, height: bottomPadding)
                                        .offset(y: displayHeight - bottomPadding)
                                        .overlay(
                                            Text("Bottom Safe Area (\(Int(model.selectedDevice.safeAreaInsets.bottom))pt)")
                                                .font(.system(size: 9, weight: .bold))
                                                .foregroundStyle(.cyan)
                                                .padding(2),
                                            alignment: .topLeading
                                        )
                                }
                            }

                            // Interactive Bounding Box Overlays
                            if model.showOverlays {
                                ForEach(Array(model.currentElements.enumerated()), id: \.offset) { index, element in
                                    let box = element.boundingBox
                                    let boxX = box.x * displayWidth
                                    let boxY = box.y * displayHeight
                                    let boxW = box.width * displayWidth
                                    let boxH = box.height * displayHeight

                                    let issues = model.currentIssues.filter { $0.elementIndex == index }
                                    let hasError = issues.contains { $0.severity == .error }
                                    let hasWarning = issues.contains { $0.severity == .warning }
                                    let isSelected = model.selectedElementIndex == index
                                    let isHovered = hoveredElementIndex == index

                                    let boxColor: Color = hasError ? .red : (hasWarning ? .orange : .green)

                                    ZStack(alignment: .topLeading) {
                                        // Fill & Stroke
                                        Rectangle()
                                            .fill(boxColor.opacity(isSelected || isHovered ? 0.25 : 0.10))
                                            .border(boxColor, width: isSelected ? 3.0 : (hasError ? 2.5 : 1.5))

                                        // Label Chip
                                        if model.showElementLabels || isHovered || isSelected {
                                            HStack(spacing: 4) {
                                                if hasError {
                                                    Image(systemName: "exclamationmark.triangle.fill")
                                                        .font(.system(size: 9))
                                                }
                                                Text("\(element.type) \(Int(element.confidence * 100))%")
                                                    .font(.system(size: 9, weight: .bold))
                                            }
                                            .padding(.horizontal, 4)
                                            .padding(.vertical, 2)
                                            .background(boxColor)
                                            .foregroundColor(.white)
                                            .cornerRadius(3)
                                            .offset(y: -16)
                                        }
                                    }
                                    .frame(width: boxW, height: boxH)
                                    .offset(x: boxX, y: boxY)
                                    .onHover { hovering in
                                        hoveredElementIndex = hovering ? index : nil
                                    }
                                    .onTapGesture {
                                        model.selectedElementIndex = index
                                        model.selectedIssue = issues.first
                                    }
                                }
                            }
                        }
                        .frame(width: displayWidth, height: displayHeight)
                    } else {
                        VStack(spacing: 12) {
                            Image(systemName: "photo.on.rectangle.angled")
                                .font(.system(size: 48))
                                .foregroundStyle(.secondary)
                            Text("No Active Image or Rendered View")
                                .font(.headline)
                                .foregroundStyle(.secondary)
                            Text("Drop a screenshot here or select a template in the playground to begin visual audit.")
                                .font(.subheadline)
                                .foregroundStyle(.tertiary)
                        }
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .onDrop(of: [.fileURL], isTargeted: nil) { providers in
                    guard let provider = providers.first else { return false }
                    _ = provider.loadObject(ofClass: URL.self) { url, _ in
                        if let url = url {
                            Task { @MainActor in
                                model.auditDroppedImage(url: url)
                            }
                        }
                    }
                    return true
                }
            }
        }
    }
}
