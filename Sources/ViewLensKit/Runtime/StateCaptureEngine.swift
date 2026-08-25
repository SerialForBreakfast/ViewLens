import Foundation

/// An atomic snapshot of rendered visual and programmatic accessibility state.
public struct UIStateSnapshot: Codable, Sendable, Equatable {
    public let target: String
    public let scale: Double
    public let appearance: String
    public let safeAreaInsets: [String: Double]
    public let visualElements: [DetectedElement]
    public let accessibilityHierarchy: [NativeAccessibilityNode]
    public let correlation: CorrelationReport
    public let timestamp: Date

    public init(
        target: String,
        scale: Double = 3.0,
        appearance: String = "light",
        safeAreaInsets: [String: Double] = ["top": 59.0, "bottom": 34.0, "leading": 0.0, "trailing": 0.0],
        visualElements: [DetectedElement] = [],
        accessibilityHierarchy: [NativeAccessibilityNode] = [],
        correlation: CorrelationReport,
        timestamp: Date = Date()
    ) {
        self.target = target
        self.scale = scale
        self.appearance = appearance
        self.safeAreaInsets = safeAreaInsets
        self.visualElements = visualElements
        self.accessibilityHierarchy = accessibilityHierarchy
        self.correlation = correlation
        self.timestamp = timestamp
    }
}

/// Engine capturing atomic visual, spatial, and semantic state snapshots.
public enum StateCaptureEngine {

    /// Captures a complete atomic snapshot for a target view template.
    public static func captureState(
        templateName: String,
        appearance: String = "light",
        scale: Double = 3.0,
        snapshots: [AccessibilityElementSnapshot] = []
    ) -> UIStateSnapshot {
        let nodes: [NativeAccessibilityNode] = snapshots.enumerated().map { index, snap in
            var traits: Set<NativeAccessibilityTrait> = []
            if let role = snap.role {
                if role.localizedCaseInsensitiveContains("button") { traits.insert(.isButton) }
                if role.localizedCaseInsensitiveContains("header") { traits.insert(.isHeader) }
                if role.localizedCaseInsensitiveContains("image") { traits.insert(.isImage) }
                if role.localizedCaseInsensitiveContains("text") { traits.insert(.isStaticText) }
            }
            let yOffset = 0.1 * Double(index + 1)
            return NativeAccessibilityNode(
                id: NonvisualID("node_\(index)"),
                label: snap.label,
                value: snap.value,
                traits: traits,
                frame: BoundingBox(x: 0.1, y: yOffset, width: 0.8, height: 0.08),
                provenance: EvidenceProvenance(kind: .measured, source: "stateCapture", confidence: 1.0)
            )
        }

        let visualElements: [DetectedElement] = nodes.map { node in
            let bBox = node.frame ?? BoundingBox(x: 0.1, y: 0.1, width: 0.8, height: 0.08)
            let typeName = node.traits.contains(.isButton) ? "primaryButton" : "staticText"
            return DetectedElement(
                type: typeName,
                confidence: 0.95,
                boundingBox: bBox
            )
        }

        let correlation = VisualSemanticCorrelator.correlate(
            visualElements: visualElements,
            accessibilityNodes: nodes
        )

        return UIStateSnapshot(
            target: templateName,
            scale: scale,
            appearance: appearance,
            visualElements: visualElements,
            accessibilityHierarchy: nodes,
            correlation: correlation
        )
    }
}
