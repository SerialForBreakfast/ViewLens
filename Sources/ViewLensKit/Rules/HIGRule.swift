import Foundation
import CoreGraphics

/// Protocol for deterministic Apple Human Interface Guidelines layout rules.
public protocol HIGRule: Sendable {
    var id: String { get }
    var name: String { get }
    var higReferenceURL: String? { get }

    func evaluate(
        elements: [DetectedElement],
        imageSize: CGSize,
        scale: Double
    ) -> [ViewLensIssue]
}
