import Foundation

/// Represents a detected UI element with semantic classification, confidence, and normalized bounding box.
public struct DetectedElement: Codable, Sendable, Equatable, Hashable {
    /// Semantic element type (e.g. "navigationBar", "primaryButton", "tabBar", "textField", "toggle")
    public let type: String
    /// Detection confidence score [0.0, 1.0]
    public let confidence: Float
    /// Normalized bounding box in top-left space [0.0, 1.0]
    public let boundingBox: BoundingBox
    /// Active tvOS / remote focus state if resolved
    public let isFocused: Bool?
    /// Confidence score of resolved focus state [0.0, 1.0]
    public let focusConfidence: Double?
    /// Flag indicating whether focus assignment was ambiguous between competing candidates
    public let isAmbiguousFocus: Bool?

    public init(
        type: String,
        confidence: Float,
        boundingBox: BoundingBox,
        isFocused: Bool? = nil,
        focusConfidence: Double? = nil,
        isAmbiguousFocus: Bool? = nil
    ) {
        self.type = type
        self.confidence = confidence
        self.boundingBox = boundingBox
        self.isFocused = isFocused
        self.focusConfidence = focusConfidence
        self.isAmbiguousFocus = isAmbiguousFocus
    }
}
