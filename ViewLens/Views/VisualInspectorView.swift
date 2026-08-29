import SwiftUI
import ViewLensKit

public struct VisualInspectorView: View {
    @Bindable var model: AppModel

    public var body: some View {
        ReviewCanvasView(model: model)
    }
}

/// A reusable screenshot canvas with semantic overlays, keyboard navigation,
/// zooming, panning, and selection reveal.
public struct ReviewCanvasView: View {
    @Bindable var model: AppModel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.viewLensUITestAccommodations) private var uiTestAccommodations
    @State private var zoom: CGFloat = 1
    @State private var panOffset: CGSize = .zero
    @State private var hoveredElement: Int?
    @State private var isDropTargeted = false
    @GestureState private var gestureScale: CGFloat = 1
    @GestureState private var gestureTranslation: CGSize = .zero

    private var effectiveZoom: CGFloat { zoom * gestureScale }
    private var shouldReduceMotion: Bool { reduceMotion || uiTestAccommodations.contains("reduce-motion") }
    private var effectiveOffset: CGSize {
        CGSize(width: panOffset.width + gestureTranslation.width, height: panOffset.height + gestureTranslation.height)
    }

    public var body: some View {
        VStack(spacing: 0) {
            canvasToolbar
            Divider()

            GeometryReader { proxy in
                if let image = model.currentImage {
                    canvas(image: image, availableSize: proxy.size)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(Color(nsColor: .underPageBackgroundColor))
                        .contentShape(Rectangle())
                        .focusable()
                        .focusEffectDisabled()
                        .onKeyPress(.leftArrow) {
                            model.moveElementSelection(by: -1)
                            return .handled
                        }
                        .onKeyPress(.rightArrow) {
                            model.moveElementSelection(by: 1)
                            return .handled
                        }
                        .onKeyPress(.escape) {
                            model.selectElement(at: nil)
                            return .handled
                        }
                        .onChange(of: model.selectedElementIndex) { _, index in
                            reveal(index, image: image, availableSize: proxy.size)
                        }
                } else {
                    ContentUnavailableView(
                        "No Preview",
                        systemImage: "photo.on.rectangle.angled",
                        description: Text("Import a screenshot or run a template to populate the review canvas.")
                    )
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
        }
        .overlay {
            RoundedRectangle(cornerRadius: 8)
                .stroke(isDropTargeted ? ViewLensTheme.brand : .clear, style: StrokeStyle(lineWidth: 3, dash: [8, 5]))
                .padding(4)
                .allowsHitTesting(false)
        }
        .dropDestination(for: URL.self) { urls, _ in
            guard let url = urls.first, isSupportedImage(url) else { return false }
            model.auditDroppedImage(url: url)
            return true
        } isTargeted: { isDropTargeted = $0 }
        .accessibilityLabel("Review canvas")
        .accessibilityIdentifier("review.canvas")
        .accessibilityHint("Use Left and Right Arrow to navigate detected elements. Drag to pan and pinch to zoom.")
        .accessibilityAction(named: "Previous element") { model.moveElementSelection(by: -1) }
        .accessibilityAction(named: "Next element") { model.moveElementSelection(by: 1) }
    }

    private var canvasToolbar: some View {
        HStack(spacing: 8) {
            Label("Visual Inspector", systemImage: "viewfinder")
                .font(.headline)
            Spacer()
            Button { model.moveElementSelection(by: -1) } label: {
                Label("Previous Element", systemImage: "chevron.left")
                    .labelStyle(.iconOnly)
                    .frame(minWidth: 28, minHeight: 28)
            }
            .disabled(model.currentElements.isEmpty)
            .help("Previous element (Left Arrow)")
            Button { model.moveElementSelection(by: 1) } label: {
                Label("Next Element", systemImage: "chevron.right")
                    .labelStyle(.iconOnly)
                    .frame(minWidth: 28, minHeight: 28)
            }
            .disabled(model.currentElements.isEmpty)
            .help("Next element (Right Arrow)")

            Divider().frame(height: 22)
            Button { setZoom(zoom - 0.2) } label: {
                Label("Zoom Out", systemImage: "minus.magnifyingglass").labelStyle(.iconOnly).frame(minWidth: 28, minHeight: 28)
            }
            Button { resetViewport() } label: {
                Text("\(Int(zoom * 100))%").monospacedDigit().frame(minWidth: 46, minHeight: 28)
            }
            .help("Reset zoom and pan")
            Button { setZoom(zoom + 0.2) } label: {
                Label("Zoom In", systemImage: "plus.magnifyingglass").labelStyle(.iconOnly).frame(minWidth: 28, minHeight: 28)
            }

            Divider().frame(height: 22)
            Toggle("Overlays", isOn: $model.showOverlays).toggleStyle(.button)
            Toggle("Labels", isOn: $model.showElementLabels).toggleStyle(.button)
            Toggle("Safe Area", isOn: $model.showSafeAreaGuides).toggleStyle(.button)
        }
        .controlSize(.small)
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(ViewLensTheme.elevatedBackground)
    }

    private func canvas(image: CGImage, availableSize: CGSize) -> some View {
        let imageSize = CGSize(width: image.width, height: image.height)
        let scale = min((availableSize.width - 48) / imageSize.width, (availableSize.height - 48) / imageSize.height)
        let fittedSize = CGSize(width: imageSize.width * max(scale, 0.01), height: imageSize.height * max(scale, 0.01))

        return ZStack {
            ZStack(alignment: .topLeading) {
                Image(decorative: image, scale: 1)
                    .resizable()
                    .frame(width: fittedSize.width, height: fittedSize.height)
                    .accessibilityHidden(true)

                if model.showSafeAreaGuides {
                    SafeAreaGuideOverlay()
                        .frame(width: fittedSize.width, height: fittedSize.height)
                        .allowsHitTesting(false)
                }

                if model.showOverlays {
                    ForEach(Array(model.currentElements.enumerated()), id: \.offset) { index, element in
                        elementOverlay(index: index, element: element, canvasSize: fittedSize)
                    }
                }
            }
            .frame(width: fittedSize.width, height: fittedSize.height)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .shadow(color: .black.opacity(0.18), radius: 14, y: 6)
            .scaleEffect(effectiveZoom)
            .offset(effectiveOffset)
            .gesture(
                MagnificationGesture()
                    .updating($gestureScale) { value, state, _ in state = value }
                    .onEnded { value in setZoom(zoom * value) }
                    .simultaneously(with:
                        DragGesture()
                            .updating($gestureTranslation) { value, state, _ in state = value.translation }
                            .onEnded { value in
                                panOffset.width += value.translation.width
                                panOffset.height += value.translation.height
                            }
                    )
            )
        }
    }

    private func elementOverlay(index: Int, element: DetectedElement, canvasSize: CGSize) -> some View {
        let box = element.boundingBox
        let rect = CGRect(
            x: CGFloat(box.x) * canvasSize.width,
            y: CGFloat(box.y) * canvasSize.height,
            width: CGFloat(box.width) * canvasSize.width,
            height: CGFloat(box.height) * canvasSize.height
        )
        let severity = severityForElement(index)
        let selected = model.selectedElementIndex == index
        let hovered = hoveredElement == index

        return Button {
            model.selectElement(at: index)
        } label: {
            ZStack(alignment: .topLeading) {
                PatternedFindingOverlay(severity: severity, emphasized: selected || hovered)
                if model.showElementLabels {
                    HStack(spacing: 4) {
                        Image(systemName: severity.symbol)
                        Text("#\(index) \(element.type)")
                    }
                    .font(.caption2.weight(.semibold))
                    .padding(.horizontal, 5)
                    .padding(.vertical, 3)
                    .foregroundStyle(.white)
                    .background(severity.color, in: Capsule())
                    .fixedSize()
                    .offset(y: -24)
                }
            }
            .frame(width: max(rect.width, 4), height: max(rect.height, 4))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .position(x: rect.midX, y: rect.midY)
        .onHover { hoveredElement = $0 ? index : nil }
        .accessibilityLabel("Element \(index + 1), \(element.type), \(severity.label)")
        .accessibilityValue("Confidence \(Int(element.confidence * 100)) percent, width \(Int(box.width * 100)) percent, height \(Int(box.height * 100)) percent")
        .accessibilityIdentifier("review.canvas.element.\(index)")
        .accessibilityAddTraits(selected ? .isSelected : [])
        .accessibilityHint("Selects this element and its first associated finding")
    }

    private func severityForElement(_ index: Int) -> CanvasFindingSeverity {
        let severities = model.reviewStore.activeReview?.findings
            .filter { $0.issue.elementIndex == index }
            .map(\.issue.severity) ?? []
        if severities.contains(.error) { return .error }
        if severities.contains(.warning) { return .warning }
        if severities.contains(.info) { return .info }
        return .none
    }

    private func setZoom(_ proposed: CGFloat) {
        zoom = min(max(proposed, 0.5), 4)
    }

    private func resetViewport() {
        withAnimation(shouldReduceMotion ? nil : .easeOut(duration: 0.2)) {
            zoom = 1
            panOffset = .zero
        }
    }

    private func reveal(_ index: Int?, image: CGImage, availableSize: CGSize) {
        guard let index, model.currentElements.indices.contains(index) else { return }
        let imageSize = CGSize(width: image.width, height: image.height)
        let fit = min((availableSize.width - 48) / imageSize.width, (availableSize.height - 48) / imageSize.height)
        let box = model.currentElements[index].boundingBox
        let x = (CGFloat(box.x + box.width / 2) - 0.5) * imageSize.width * fit * zoom
        let y = (CGFloat(box.y + box.height / 2) - 0.5) * imageSize.height * fit * zoom
        withAnimation(shouldReduceMotion ? nil : .easeOut(duration: 0.2)) {
            panOffset = CGSize(width: -x, height: -y)
        }
    }

    private func isSupportedImage(_ url: URL) -> Bool {
        ["png", "jpg", "jpeg", "heic", "tif", "tiff"].contains(url.pathExtension.lowercased())
    }
}

private enum CanvasFindingSeverity {
    case error, warning, info, none

    var color: Color {
        switch self {
        case .error: return .red
        case .warning: return .orange
        case .info: return .blue
        case .none: return .secondary
        }
    }
    var symbol: String {
        switch self {
        case .error: return "xmark.octagon.fill"
        case .warning: return "exclamationmark.triangle.fill"
        case .info: return "info.circle.fill"
        case .none: return "viewfinder.circle"
        }
    }
    var label: String {
        switch self {
        case .error: return "error"
        case .warning: return "warning"
        case .info: return "informational"
        case .none: return "no finding"
        }
    }
    var dash: [CGFloat] {
        switch self {
        case .error: return []
        case .warning: return [7, 4]
        case .info: return [2, 3]
        case .none: return [5, 5]
        }
    }
}

private struct PatternedFindingOverlay: View {
    let severity: CanvasFindingSeverity
    let emphasized: Bool

    var body: some View {
        Canvas { context, size in
            let spacing: CGFloat = severity == .error ? 7 : 10
            var hatch = Path()
            for start in stride(from: -size.height, through: size.width, by: spacing) {
                hatch.move(to: CGPoint(x: start, y: size.height))
                hatch.addLine(to: CGPoint(x: start + size.height, y: 0))
            }
            context.stroke(hatch, with: .color(severity.color.opacity(emphasized ? 0.32 : 0.18)), lineWidth: 1)
        }
        .background(severity.color.opacity(emphasized ? 0.16 : 0.08))
        .overlay {
            Rectangle().stroke(
                severity.color,
                style: StrokeStyle(lineWidth: emphasized ? 3 : 2, dash: severity.dash)
            )
        }
    }
}

private struct SafeAreaGuideOverlay: View {
    var body: some View {
        GeometryReader { proxy in
            let inset = min(proxy.size.width, proxy.size.height) * 0.05
            Rectangle()
                .inset(by: inset)
                .stroke(.white.opacity(0.9), style: StrokeStyle(lineWidth: 1, dash: [5, 4]))
                .shadow(color: .black.opacity(0.7), radius: 1)
        }
        .accessibilityHidden(true)
    }
}
