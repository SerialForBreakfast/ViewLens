import Foundation

/// An atomic snapshot of rendered visual and programmatic accessibility state.
public struct UIStateSnapshot: Codable, Sendable, Equatable {
    public let captureIdentity: CaptureIdentity
    public let target: String
    public let scale: Double?
    public let appearance: String
    public let safeAreaInsets: [String: Double]
    public let visualElements: [DetectedElement]
    public let accessibilityHierarchy: [NativeAccessibilityNode]
    public let correlation: CorrelationReport
    public let timestamp: Date?
    public let deviceMetricsEvidence: EvidenceProvenance
    public let captureTimingEvidence: EvidenceProvenance
    public let readingOrderEvidence: EvidenceProvenance
    public let focusState: SeparatedFocusState
    public let eligibility: EvidenceEligibilityDecision
    public let conformanceEligible: Bool

    public init(
        captureIdentity: CaptureIdentity? = nil,
        target: String,
        scale: Double? = nil,
        appearance: String = "light",
        safeAreaInsets: [String: Double] = [:],
        visualElements: [DetectedElement] = [],
        accessibilityHierarchy: [NativeAccessibilityNode] = [],
        correlation: CorrelationReport,
        timestamp: Date? = nil,
        deviceMetricsEvidence: EvidenceProvenance? = nil,
        captureTimingEvidence: EvidenceProvenance? = nil,
        readingOrderEvidence: EvidenceProvenance? = nil,
        focusState: SeparatedFocusState = SeparatedFocusState(),
        eligibility: EvidenceEligibilityDecision? = nil
    ) {
        let resolvedIdentity = captureIdentity ?? CaptureIdentity(
            target: target,
            capturedAt: timestamp,
            environmentKey: "\(appearance)_\(scale.map { String(format: "%.1fx", $0) } ?? "unmeasured")"
        )
        self.captureIdentity = resolvedIdentity
        self.target = target
        self.scale = scale
        self.appearance = appearance
        self.safeAreaInsets = safeAreaInsets
        self.visualElements = visualElements
        self.accessibilityHierarchy = accessibilityHierarchy
        self.correlation = correlation
        self.timestamp = timestamp

        if let deviceMetricsEvidence {
            self.deviceMetricsEvidence = deviceMetricsEvidence
        } else if scale != nil && !safeAreaInsets.isEmpty {
            self.deviceMetricsEvidence = EvidenceProvenance(
                kind: .measured,
                source: "deviceMetrics",
                confidence: 1.0,
                detail: "Measured scale and safe area insets."
            )
        } else {
            self.deviceMetricsEvidence = .unavailable(
                source: "deviceMetrics",
                detail: "Device scale or safe-area insets were not measured during capture."
            )
        }

        if let captureTimingEvidence {
            self.captureTimingEvidence = captureTimingEvidence
        } else if timestamp != nil {
            self.captureTimingEvidence = EvidenceProvenance(
                kind: .measured,
                source: "captureClock",
                confidence: 1.0,
                detail: "Recorded runtime capture timestamp."
            )
        } else {
            self.captureTimingEvidence = .unavailable(
                source: "captureClock",
                detail: "Runtime capture timing was not measured."
            )
        }

        if let readingOrderEvidence {
            self.readingOrderEvidence = readingOrderEvidence
        } else {
            self.readingOrderEvidence = .unavailable(
                source: "accessibility.readingOrder",
                detail: "Assistive reading-order sequence was not independently observed."
            )
        }

        self.focusState = focusState

        if let eligibility {
            self.eligibility = eligibility
        } else {
            var required: [String: EvidenceProvenance] = [
                "correlation": correlation.provenance,
                "deviceMetrics": self.deviceMetricsEvidence,
                "readingOrder": self.readingOrderEvidence
            ]
            if accessibilityHierarchy.isEmpty {
                required["accessibilityHierarchy"] = .unavailable(
                    source: "accessibilityHierarchy",
                    detail: "No accessibility nodes were captured."
                )
            } else {
                for node in accessibilityHierarchy {
                    required["node.\(node.id.rawValue).semantics"] = node.provenance
                    required["node.\(node.id.rawValue).geometry"] = node.frameProvenance
                }
            }
            self.eligibility = EvidenceEligibilityPolicy.evaluate(
                consumer: .qualityGate,
                requiredEvidence: required,
                captureIdentity: resolvedIdentity
            )
        }

        self.conformanceEligible = self.eligibility.canPass && correlation.isAvailable
    }
}

/// Engine capturing atomic visual, spatial, and semantic state snapshots.
public enum StateCaptureEngine {

    /// Captures an atomic state snapshot for a target view template without fabricating geometry, visual detections, or device metrics.
    public static func captureState(
        templateName: String,
        appearance: String = "light",
        scale: Double? = nil,
        safeAreaInsets: [String: Double] = [:],
        snapshots: [AccessibilityElementSnapshot] = [],
        visualElements: [DetectedElement] = [],
        visualProvenance: EvidenceProvenance? = nil,
        measuredTimestamp: Date? = nil,
        readingOrderEvidence: EvidenceProvenance? = nil,
        focusState: SeparatedFocusState = SeparatedFocusState()
    ) -> UIStateSnapshot {
        let captureIdentity = CaptureIdentity(
            target: templateName,
            capturedAt: measuredTimestamp,
            environmentKey: "\(appearance)_\(scale.map { String(format: "%.1fx", $0) } ?? "unmeasured")"
        )

        let nodes: [NativeAccessibilityNode] = snapshots.enumerated().map { index, snap in
            var traits: Set<NativeAccessibilityTrait> = []
            if let role = snap.role {
                if role.localizedCaseInsensitiveContains("button") { traits.insert(.isButton) }
                if role.localizedCaseInsensitiveContains("header") { traits.insert(.isHeader) }
                if role.localizedCaseInsensitiveContains("image") { traits.insert(.isImage) }
                if role.localizedCaseInsensitiveContains("text") { traits.insert(.isStaticText) }
            }

            let semanticProvenance = EvidenceProvenance(
                kind: .derived,
                source: snap.origin,
                detail: "Preserved supplied accessibility snapshot attributes from \(snap.origin)."
            )

            let resolvedFrameProvenance: EvidenceProvenance
            if let explicitFrameProv = snap.frameProvenance {
                resolvedFrameProvenance = explicitFrameProv
            } else if snap.frame != nil {
                resolvedFrameProvenance = EvidenceProvenance(
                    kind: .measured,
                    source: snap.origin,
                    confidence: 1.0,
                    detail: "Measured frame supplied by \(snap.origin)."
                )
            } else {
                resolvedFrameProvenance = .unavailable(
                    source: "stateCapture.geometry",
                    detail: "Absent native frame in snapshot; geometry was not fabricated."
                )
            }

            let nodeID = snap.identifier.flatMap { $0.isEmpty ? nil : NonvisualID($0) } ?? NonvisualID("node_\(index)")

            return NativeAccessibilityNode(
                id: nodeID,
                label: snap.label,
                value: snap.value,
                traits: traits,
                frame: snap.frame,
                provenance: semanticProvenance,
                frameProvenance: resolvedFrameProvenance,
                origin: snap.origin
            )
        }

        // Do NOT derive visualElements from accessibility nodes. Only correlate independently supplied visual observations.
        let correlation = VisualSemanticCorrelator.correlate(
            visualElements: visualElements,
            accessibilityNodes: nodes,
            visualProvenance: visualProvenance,
            captureIdentity: captureIdentity
        )

        return UIStateSnapshot(
            captureIdentity: captureIdentity,
            target: templateName,
            scale: scale,
            appearance: appearance,
            safeAreaInsets: safeAreaInsets,
            visualElements: visualElements,
            accessibilityHierarchy: nodes,
            correlation: correlation,
            timestamp: measuredTimestamp,
            readingOrderEvidence: readingOrderEvidence,
            focusState: focusState
        )
    }
}
