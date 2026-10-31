import Foundation

/// A correlated match between a computer-vision detected element and a programmatic accessibility node.
public struct VisualSemanticPair: Codable, Sendable, Equatable {
    public let visualElement: DetectedElement
    public let accessibilityNode: NativeAccessibilityNode
    public let confidence: Double
    public let iou: Double

    public init(
        visualElement: DetectedElement,
        accessibilityNode: NativeAccessibilityNode,
        confidence: Double,
        iou: Double
    ) {
        self.visualElement = visualElement
        self.accessibilityNode = accessibilityNode
        self.confidence = confidence
        self.iou = iou
    }
}

/// Classification of correlation conflicts between visual detections and accessibility nodes.
public enum CorrelationConflictKind: String, Codable, Sendable, Equatable {
    case roleMismatch = "roleMismatch"
    case focusDesynchronization = "focusDesynchronization"
    case ambiguousFocus = "ambiguousFocus"
}

/// A conflict where spatial overlap is high but visual class, programmatic role, or focus state disagree.
public struct CorrelationConflict: Codable, Sendable, Equatable {
    public let visualElement: DetectedElement
    public let accessibilityNode: NativeAccessibilityNode
    public let reason: String
    public let kind: CorrelationConflictKind

    public init(
        visualElement: DetectedElement,
        accessibilityNode: NativeAccessibilityNode,
        reason: String,
        kind: CorrelationConflictKind = .roleMismatch
    ) {
        self.visualElement = visualElement
        self.accessibilityNode = accessibilityNode
        self.reason = reason
        self.kind = kind
    }
}

/// Availability and eligibility status of a visual-semantic correlation report.
public enum CorrelationStatus: String, Codable, Sendable, Equatable, Hashable {
    case evaluated
    case unavailable
    case ineligible
}

/// Comprehensive report of bi-directional correlation between visual detection and accessibility hierarchy.
public struct CorrelationReport: Codable, Sendable, Equatable {
    public let status: CorrelationStatus
    public let isAvailable: Bool
    public let matchedPairs: [VisualSemanticPair]
    public let unmatchedVisualElements: [DetectedElement]
    public let unmatchedAccessibilityNodes: [NativeAccessibilityNode]
    public let conflicts: [CorrelationConflict]
    public let matchRate: Double
    public let evaluatedMatchRate: Double?
    public let unavailableReason: String?
    public let provenance: EvidenceProvenance
    public let eligibility: EvidenceEligibilityDecision

    public init(
        status: CorrelationStatus = .evaluated,
        matchedPairs: [VisualSemanticPair],
        unmatchedVisualElements: [DetectedElement],
        unmatchedAccessibilityNodes: [NativeAccessibilityNode],
        conflicts: [CorrelationConflict],
        unavailableReason: String? = nil,
        provenance: EvidenceProvenance? = nil,
        eligibility: EvidenceEligibilityDecision? = nil
    ) {
        self.status = status
        self.isAvailable = (status == .evaluated)
        self.matchedPairs = matchedPairs
        self.unmatchedVisualElements = unmatchedVisualElements
        self.unmatchedAccessibilityNodes = unmatchedAccessibilityNodes
        self.conflicts = conflicts
        self.unavailableReason = unavailableReason

        let total = matchedPairs.count + unmatchedVisualElements.count
        if status == .evaluated && total > 0 {
            let computed = Double(matchedPairs.count) / Double(total)
            self.evaluatedMatchRate = computed
            self.matchRate = computed
        } else {
            self.evaluatedMatchRate = nil
            self.matchRate = 0.0
        }

        if let provenance {
            self.provenance = provenance
        } else if status == .evaluated {
            self.provenance = EvidenceProvenance(kind: .derived, source: "visualSemanticCorrelator", detail: "Spatial IoU correlation across independent visual and accessibility observations.")
        } else {
            self.provenance = .unavailable(source: "visualSemanticCorrelator", detail: unavailableReason ?? "Independent visual and semantic observations are unavailable.")
        }

        if let eligibility {
            self.eligibility = eligibility
        } else {
            self.eligibility = EvidenceEligibilityDecision(
                consumer: .visualSemanticCorrelation,
                status: status == .evaluated ? .eligible : (status == .ineligible ? .ineligible : .notEvaluated),
                isEligible: status == .evaluated,
                canPass: status == .evaluated && conflicts.isEmpty,
                reasons: unavailableReason.map { [$0] } ?? []
            )
        }
    }
}

/// Engine correlating computer vision element detections with native accessibility hierarchy nodes.
public enum VisualSemanticCorrelator {

    /// Correlates independently acquired vision detections with accessibility nodes based on bounding box IoU and role heuristics.
    public static func correlate(
        visualElements: [DetectedElement],
        accessibilityNodes: [NativeAccessibilityNode],
        minIoUThreshold: Double = 0.20,
        visualProvenance: EvidenceProvenance? = nil,
        captureIdentity: CaptureIdentity? = nil,
        expectedCaptureIdentity: CaptureIdentity? = nil
    ) -> CorrelationReport {
        let effectiveVisualProvenance: EvidenceProvenance
        if let visualProvenance {
            effectiveVisualProvenance = visualProvenance
        } else if visualElements.isEmpty {
            effectiveVisualProvenance = .unavailable(
                source: "visualDetector",
                detail: "No independent visual observations were provided."
            )
        } else {
            effectiveVisualProvenance = EvidenceProvenance(
                kind: .measured,
                source: "visualDetector",
                confidence: Double(visualElements.map(\.confidence).reduce(0, +)) / Double(visualElements.count),
                detail: "Visual detector observations"
            )
        }

        // Reject correlation if visual observations were derived from accessibility nodes rather than acquired independently.
        let loweredSource = effectiveVisualProvenance.source.lowercased()
        if loweredSource.contains("accessibility") || loweredSource.contains("synthetic_from_ax") {
            let reason = "Correlation requires independently acquired visual observations; visual elements derived from accessibility nodes are ineligible."
            let decision = EvidenceEligibilityDecision(
                consumer: .visualSemanticCorrelation,
                status: .ineligible,
                isEligible: false,
                canPass: false,
                reasons: [reason],
                captureIdentity: captureIdentity
            )
            return CorrelationReport(
                status: .ineligible,
                matchedPairs: [],
                unmatchedVisualElements: visualElements,
                unmatchedAccessibilityNodes: accessibilityNodes,
                conflicts: [],
                unavailableReason: reason,
                provenance: .unavailable(source: "visualSemanticCorrelator", detail: reason),
                eligibility: decision
            )
        }

        if visualElements.isEmpty {
            let reason = "Independent visual observations are unavailable; correlation cannot be evaluated."
            let decision = EvidenceEligibilityPolicy.evaluate(
                consumer: .visualSemanticCorrelation,
                requiredEvidence: ["visualObservations": effectiveVisualProvenance],
                captureIdentity: captureIdentity,
                expectedCaptureIdentity: expectedCaptureIdentity
            )
            return CorrelationReport(
                status: .unavailable,
                matchedPairs: [],
                unmatchedVisualElements: [],
                unmatchedAccessibilityNodes: accessibilityNodes,
                conflicts: [],
                unavailableReason: reason,
                provenance: .unavailable(source: "visualSemanticCorrelator", detail: reason),
                eligibility: decision
            )
        }

        if accessibilityNodes.isEmpty {
            let reason = "Programmatic accessibility hierarchy observations are unavailable; correlation cannot be evaluated."
            let decision = EvidenceEligibilityPolicy.evaluate(
                consumer: .visualSemanticCorrelation,
                requiredEvidence: [
                    "visualObservations": effectiveVisualProvenance,
                    "accessibilityNodes": .unavailable(source: "accessibilityHierarchy", detail: reason)
                ],
                captureIdentity: captureIdentity,
                expectedCaptureIdentity: expectedCaptureIdentity
            )
            return CorrelationReport(
                status: .unavailable,
                matchedPairs: [],
                unmatchedVisualElements: visualElements,
                unmatchedAccessibilityNodes: [],
                conflicts: [],
                unavailableReason: reason,
                provenance: .unavailable(source: "visualSemanticCorrelator", detail: reason),
                eligibility: decision
            )
        }

        let eligibleGeometryNodes = accessibilityNodes.filter { node in
            guard node.frame != nil else { return false }
            switch node.frameProvenance.kind {
            case .measured, .derived, .humanConfirmed:
                return node.provenance.kind != .synthetic && node.provenance.kind != .unavailable
            case .inferred, .synthetic, .unavailable:
                return false
            }
        }

        if eligibleGeometryNodes.isEmpty {
            let hasSyntheticFrames = accessibilityNodes.contains { $0.frameProvenance.kind == .synthetic || $0.provenance.kind == .synthetic }
            let status: CorrelationStatus = hasSyntheticFrames ? .ineligible : .unavailable
            let reason = hasSyntheticFrames
                ? "Accessibility nodes only have synthetic placeholder geometry; spatial correlation is ineligible."
                : "Accessibility nodes lack measured or derived native geometry frames; spatial correlation is unavailable."
            let frameEv: EvidenceProvenance = hasSyntheticFrames
                ? .synthetic(source: "accessibility.frame", detail: reason)
                : .unavailable(source: "accessibility.frame", detail: reason)
            let decision = EvidenceEligibilityPolicy.evaluate(
                consumer: .visualSemanticCorrelation,
                requiredEvidence: [
                    "visualObservations": effectiveVisualProvenance,
                    "accessibilityGeometry": frameEv
                ],
                captureIdentity: captureIdentity,
                expectedCaptureIdentity: expectedCaptureIdentity
            )
            return CorrelationReport(
                status: status,
                matchedPairs: [],
                unmatchedVisualElements: visualElements,
                unmatchedAccessibilityNodes: accessibilityNodes,
                conflicts: [],
                unavailableReason: reason,
                provenance: .unavailable(source: "visualSemanticCorrelator", detail: reason),
                eligibility: decision
            )
        }

        let eligibility = EvidenceEligibilityPolicy.evaluate(
            consumer: .visualSemanticCorrelation,
            requiredEvidence: [
                "visualObservations": effectiveVisualProvenance,
                "accessibilityGeometry": eligibleGeometryNodes[0].frameProvenance
            ],
            captureIdentity: captureIdentity,
            expectedCaptureIdentity: expectedCaptureIdentity
        )

        if !eligibility.isEligible {
            let status: CorrelationStatus = (eligibility.status == .ineligible) ? .ineligible : .unavailable
            let reason = eligibility.reasons.joined(separator: " ")
            return CorrelationReport(
                status: status,
                matchedPairs: [],
                unmatchedVisualElements: visualElements,
                unmatchedAccessibilityNodes: accessibilityNodes,
                conflicts: [],
                unavailableReason: reason,
                provenance: .unavailable(source: "visualSemanticCorrelator", detail: reason),
                eligibility: eligibility
            )
        }

        var matchedPairs: [VisualSemanticPair] = []
        var conflicts: [CorrelationConflict] = []
        var matchedVisualIndices = Set<Int>()
        var matchedNodeIndices = Set<Int>()

        for (vIdx, visual) in visualElements.enumerated() {
            var bestMatch: (nodeIdx: Int, node: NativeAccessibilityNode, iou: Double)?

            for (nIdx, node) in accessibilityNodes.enumerated() {
                guard let nodeFrame = node.frame else { continue }
                guard node.frameProvenance.kind == .measured || node.frameProvenance.kind == .derived || node.frameProvenance.kind == .humanConfirmed else {
                    continue
                }
                guard node.provenance.kind != .synthetic && node.provenance.kind != .unavailable else {
                    continue
                }
                let iou = visual.boundingBox.iou(with: nodeFrame)

                if iou >= minIoUThreshold {
                    if bestMatch == nil || iou > bestMatch!.iou {
                        bestMatch = (nIdx, node, iou)
                    }
                }
            }

            if let match = bestMatch {
                matchedVisualIndices.insert(vIdx)
                matchedNodeIndices.insert(match.nodeIdx)

                let score = min(1.0, (Double(visual.confidence) + match.iou) / 2.0)
                let pair = VisualSemanticPair(
                    visualElement: visual,
                    accessibilityNode: match.node,
                    confidence: score,
                    iou: match.iou
                )
                matchedPairs.append(pair)

                // Check for potential role/trait conflicts
                if visual.type.lowercased().contains("button") && !match.node.traits.contains(.isButton) {
                    conflicts.append(CorrelationConflict(
                        visualElement: visual,
                        accessibilityNode: match.node,
                        reason: "Visual element appears to be a button, but accessibility node lacks .isButton trait",
                        kind: .roleMismatch
                    ))
                }

                // Check for unannounced or mislabeled badge indicators
                if visual.type.lowercased() == "badge" && (match.node.label == nil || match.node.label?.isEmpty == true) && (match.node.value == nil || match.node.value?.isEmpty == true) {
                    conflicts.append(CorrelationConflict(
                        visualElement: visual,
                        accessibilityNode: match.node,
                        reason: "Visual element displays a badge indicator, but matched accessibility node has neither label nor value to announce badge content",
                        kind: .roleMismatch
                    ))
                }

                // Check for focus desynchronization (ADR-0007 Focus Alignment)
                if visual.isFocused == true && !match.node.traits.contains(.isSelected) {
                    conflicts.append(CorrelationConflict(
                        visualElement: visual,
                        accessibilityNode: match.node,
                        reason: "Visual element displays an active focus ring, but matched accessibility node lacks .isSelected / focus state (ADR-0007 Focus Desynchronization)",
                        kind: .focusDesynchronization
                    ))
                } else if visual.isFocused == false && match.node.traits.contains(.isSelected) {
                    conflicts.append(CorrelationConflict(
                        visualElement: visual,
                        accessibilityNode: match.node,
                        reason: "Accessibility node claims focus (.isSelected), but visual element lacks an active focus ring (ADR-0007 Focus Desynchronization)",
                        kind: .focusDesynchronization
                    ))
                }

                // Check for ambiguous focus
                if visual.isAmbiguousFocus == true {
                    conflicts.append(CorrelationConflict(
                        visualElement: visual,
                        accessibilityNode: match.node,
                        reason: "Visual element has ambiguous focus ring assignment with competing candidates",
                        kind: .ambiguousFocus
                    ))
                }
            }
        }

        let unmatchedVisuals = visualElements.enumerated()
            .filter { !matchedVisualIndices.contains($0.offset) }
            .map(\.element)

        let unmatchedNodes = accessibilityNodes.enumerated()
            .filter { !matchedNodeIndices.contains($0.offset) }
            .map(\.element)

        return CorrelationReport(
            status: .evaluated,
            matchedPairs: matchedPairs,
            unmatchedVisualElements: unmatchedVisuals,
            unmatchedAccessibilityNodes: unmatchedNodes,
            conflicts: conflicts,
            unavailableReason: nil,
            provenance: EvidenceProvenance(
                kind: .derived,
                source: "visualSemanticCorrelator",
                confidence: matchedPairs.isEmpty ? nil : matchedPairs.map(\.confidence).reduce(0, +) / Double(matchedPairs.count),
                detail: "Correlated \(matchedPairs.count) pair(s) from \(visualElements.count) visual and \(eligibleGeometryNodes.count) geometry-backed accessibility observations."
            ),
            eligibility: eligibility
        )
    }
}
