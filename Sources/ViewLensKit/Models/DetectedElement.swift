import Foundation

/// Represents a detected UI element with semantic classification, confidence, and normalized bounding box.
public struct DetectedElement: Codable, Sendable, Equatable, Hashable {
    /// Semantic element type (e.g. "navigationBar", "primaryButton", "tabBar", "textField", "toggle")
    public let type: String
    /// Detection confidence score [0.0, 1.0]
    public let confidence: Float
    /// Normalized bounding box in top-left space [0.0, 1.0]
    public let boundingBox: BoundingBox

    public init(type: String, confidence: Float, boundingBox: BoundingBox) {
        self.type = type
        self.confidence = confidence
        self.boundingBox = boundingBox
    }
}
