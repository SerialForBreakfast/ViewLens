import Foundation

/// Fast Greedy Non-Maximum Suppression for detected bounding boxes.
public struct NonMaximumSuppression: Sendable {
    /// Performs class-aware or class-agnostic NMS on candidate elements.
    public static func suppress(
        elements: [DetectedElement],
        iouThreshold: Double = 0.30,
        classAware: Bool = true
    ) -> [DetectedElement] {
        guard !elements.isEmpty else { return [] }

        if classAware {
            // Group by element type
            let grouped = Dictionary(grouping: elements, by: { $0.type })
            var results: [DetectedElement] = []

            for (_, classElements) in grouped {
                results.append(contentsOf: suppressSingleClass(elements: classElements, iouThreshold: iouThreshold))
            }

            // Return sorted by confidence descending
            return results.sorted(by: { $0.confidence > $1.confidence })
        } else {
            return suppressSingleClass(elements: elements, iouThreshold: iouThreshold)
        }
    }

    private static func suppressSingleClass(
        elements: [DetectedElement],
        iouThreshold: Double
    ) -> [DetectedElement] {
        var candidates = elements.sorted(by: { $0.confidence > $1.confidence })
        var selected: [DetectedElement] = []

        while !candidates.isEmpty {
            let best = candidates.removeFirst()
            selected.append(best)

            candidates.removeAll { candidate in
                best.boundingBox.iou(with: candidate.boundingBox) > iouThreshold
            }
        }

        return selected
    }
}
