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
                        .fill(Color(NSColor.underPageBackgroundColor))
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
                            // 1. Base Rendered / Screenshot Image
                            Image(decorative: cgImage, scale: 1.0)
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(width: displayWidth, height: displayHeight)
                                .cornerRadius(model.selectedDevice.cornerRadius * fitScale)
                                .shadow(color: .black.opacity(0.35), radius: 16, x: 0, y: 8)

                            // 2. Safe Area Visual Guides (Clean Top & Bottom Banners)
                            if model.showSafeAreaGuides {
                                let topPt = model.selectedDevice.safeAreaInsets.top
                                let bottomPt = model.selectedDevice.safeAreaInsets.bottom
                                let topPadding = topPt * model.selectedDevice.scale * fitScale
                                let bottomPadding = bottomPt * model.selectedDevice.scale * fitScale

                                VStack(spacing: 0) {
                                    if topPadding > 0 {
                                        VStack(alignment: .leading, spacing: 0) {
                                            HStack {
                                                Text("Top Safe Area (\(Int(topPt))pt)")
                                                    .font(.system(size: 9, weight: .bold))
                                                    .foregroundStyle(.cyan)
                                                Spacer()
                                            }
                                            .padding(.horizontal, 8)
                                            .padding(.top, 4)
                                            Spacer()
                                            // Dashed boundary divider
                                            Rectangle()
                                                .fill(Color.cyan.opacity(0.6))
                                                .frame(height: 1)
                                        }
                                        .frame(width: displayWidth, height: topPadding)
                                        .background(Color.cyan.opacity(0.08))
                                    }

                                    Spacer()

                                    if bottomPadding > 0 {
                                        VStack(alignment: .leading, spacing: 0) {
                                            Rectangle()
                                                .fill(Color.cyan.opacity(0.6))
                                                .frame(height: 1)
                                            Spacer()
                                            HStack {
                                                Text("Bottom Safe Area (\(Int(bottomPt))pt)")
                                                    .font(.system(size: 9, weight: .bold))
                                                    .foregroundStyle(.cyan)
                                                Spacer()
                                            }
                                            .padding(.horizontal, 8)
                                            .padding(.bottom, 4)
                                        }
                                        .frame(width: displayWidth, height: bottomPadding)
                                        .background(Color.cyan.opacity(0.08))
                                    }
                                }
                                .frame(width: displayWidth, height: displayHeight)
                                .allowsHitTesting(false)
                            }

                            // 3. Interactive Bounding Box Overlays
                            if model.showOverlays {
                                ForEach(Array(model.currentElements.enumerated()), id: \.offset) { index, element in
                                    let box = element.boundingBox
                                    let boxX = box.x * displayWidth
                                    let boxY = box.y * displayHeight
                                    let boxW = box.width * displayWidth
                                    let boxH = box.height * displayHeight

                                    let ptWidth = Int((box.width * imgSize.width) / model.selectedDevice.scale)
                                    let ptHeight = Int((box.height * imgSize.height) / model.selectedDevice.scale)

                                    let issues = model.currentIssues.filter { $0.elementIndex == index }
                                    let hasError = issues.contains { $0.severity == .error }
                                    let hasWarning = issues.contains { $0.severity == .warning }
                                    let isSelected = model.selectedElementIndex == index
                                    let isHovered = hoveredElementIndex == index

                                    let boxColor: Color = hasError ? .red : (hasWarning ? .orange : .green)

                                    ZStack(alignment: .topLeading) {
                                        // Fill & Stroke
                                        Rectangle()
                                            .fill(boxColor.opacity(isSelected || isHovered ? 0.22 : 0.08))
                                            .border(boxColor, width: isSelected ? 3.0 : (hasError ? 2.5 : 1.5))

                                        // Enhanced Label Badge
                                        if model.showElementLabels || isHovered || isSelected {
                                            HStack(spacing: 4) {
                                                if hasError {
                                                    Image(systemName: "exclamationmark.triangle.fill")
                                                        .font(.system(size: 9))
                                                }
                                                Text("\(element.type)")
                                                    .fontWeight(.bold)
                                                Text("• \(ptWidth)×\(ptHeight)pt")
                                                    .opacity(0.85)
                                                Text("• \(Int(element.confidence * 100))%")
                                                    .opacity(0.75)
                                            }
                                            .font(.system(size: 9))
                                            .padding(.horizontal, 6)
                                            .padding(.vertical, 3)
                                            .background(boxColor)
                                            .foregroundColor(.white)
                                            .cornerRadius(4)
                                            .shadow(color: .black.opacity(0.3), radius: 3, y: 1)
                                            // Place badge inside if near the top edge, otherwise place above
                                            .offset(y: boxY < 24 ? 4 : -20)
                                            .offset(x: boxY < 24 ? 4 : 0)
                                        }
                                    }
                                    .frame(width: max(4, boxW), height: max(4, boxH))
                                    .position(x: boxX + boxW / 2, y: boxY + boxH / 2)
                                    .onHover { isHovered in
                                        hoveredElementIndex = isHovered ? index : nil
                                    }
                                    .onTapGesture {
                                        model.selectedElementIndex = (model.selectedElementIndex == index) ? nil : index
                                        model.selectedIssue = issues.first
                                    }
                                }
                            }
                        }
                        .frame(width: displayWidth, height: displayHeight)
                    } else {
                        // Empty Canvas Dropzone Placeholder
                        VStack(spacing: 16) {
                            Image(systemName: "photo.on.rectangle.angled")
                                .font(.system(size: 54))
                                .foregroundStyle(.secondary)

                            Text("No UI Rendered")
                                .font(.headline)

                            Text("Select a template on the left and click 'Render & Audit Canvas',\nor drag and drop a screenshot here.")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)
                        }
                        .padding(40)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .onDrop(of: [UTType.fileURL], isTargeted: nil) { providers in
                    guard let provider = providers.first else { return false }
                    _ = provider.loadObject(ofClass: URL.self) { url, _ in
                        guard let url = url else { return }
                        Task { @MainActor in
                            model.auditDroppedImage(url: url)
                        }
                    }
                    return true
                }
            }
        }
    }
}
