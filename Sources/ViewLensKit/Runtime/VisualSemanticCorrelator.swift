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

/// A conflict where spatial overlap is high but visual class and programmatic role disagree.
public struct CorrelationConflict: Codable, Sendable, Equatable {
    public let visualElement: DetectedElement
    public let accessibilityNode: NativeAccessibilityNode
    public let reason: String

    public init(
        visualElement: DetectedElement,
        accessibilityNode: NativeAccessibilityNode,
        reason: String
    ) {
        self.visualElement = visualElement
        self.accessibilityNode = accessibilityNode
        self.reason = reason
    }
}

/// Comprehensive report of bi-directional correlation between visual detection and accessibility hierarchy.
public struct CorrelationReport: Codable, Sendable, Equatable {
    public let matchedPairs: [VisualSemanticPair]
    public let unmatchedVisualElements: [DetectedElement]
    public let unmatchedAccessibilityNodes: [NativeAccessibilityNode]
    public let conflicts: [CorrelationConflict]
    public let matchRate: Double

    public init(
        matchedPairs: [VisualSemanticPair],
        unmatchedVisualElements: [DetectedElement],
        unmatchedAccessibilityNodes: [NativeAccessibilityNode],
        conflicts: [CorrelationConflict]
    ) {
        self.matchedPairs = matchedPairs
        self.unmatchedVisualElements = unmatchedVisualElements
        self.unmatchedAccessibilityNodes = unmatchedAccessibilityNodes
        self.conflicts = conflicts

        let total = matchedPairs.count + unmatchedVisualElements.count
        self.matchRate = total > 0 ? Double(matchedPairs.count) / Double(total) : 1.0
    }
}

/// Engine correlating computer vision element detections with native accessibility hierarchy nodes.
public enum VisualSemanticCorrelator {

    /// Correlates vision detections with accessibility nodes based on bounding box IoU and role heuristics.
    public static func correlate(
        visualElements: [DetectedElement],
        accessibilityNodes: [NativeAccessibilityNode],
        minIoUThreshold: Double = 0.20
    ) -> CorrelationReport {
        var matchedPairs: [VisualSemanticPair] = []
        var conflicts: [CorrelationConflict] = []
        var matchedVisualIndices = Set<Int>()
        var matchedNodeIndices = Set<Int>()

        for (vIdx, visual) in visualElements.enumerated() {
            var bestMatch: (nodeIdx: Int, node: NativeAccessibilityNode, iou: Double)?

            for (nIdx, node) in accessibilityNodes.enumerated() {
                guard let nodeFrame = node.frame else { continue }
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
                        reason: "Visual element appears to be a button, but accessibility node lacks .isButton trait"
                    ))
                }
            }
        }

        let unmatchedVisual = visualElements.enumerated()
            .filter { !matchedVisualIndices.contains($0.offset) }
            .map(\.element)

        let unmatchedNodes = accessibilityNodes.enumerated()
            .filter { !matchedNodeIndices.contains($0.offset) }
            .map(\.element)

        return CorrelationReport(
            matchedPairs: matchedPairs,
            unmatchedVisualElements: unmatchedVisual,
            unmatchedAccessibilityNodes: unmatchedNodes,
            conflicts: conflicts
        )
    }
}
