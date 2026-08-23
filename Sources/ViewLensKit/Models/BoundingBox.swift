import Foundation
import CoreGraphics

/// BoundingBox represents a rectangular boundary normalized to [0.0, 1.0] coordinates.
/// Origin is at the Top-Left corner (0,0), matching SwiftUI .frame() and UIKit conventions directly.
public struct BoundingBox: Codable, Sendable, Equatable, Hashable {
    /// Left edge position [0.0, 1.0]
    public let x: Double
    /// Top edge position [0.0, 1.0]
    public let y: Double
    /// Width normalized to image width [0.0, 1.0]
    public let width: Double
    /// Height normalized to image height [0.0, 1.0]
    public let height: Double

    public init(x: Double, y: Double, width: Double, height: Double) {
        self.x = x
        self.y = y
        self.width = max(0, width)
        self.height = max(0, height)
    }

    /// Initializes a BoundingBox from YOLO center-based coordinates (centerX, centerY, width, height)
    /// and converts it to Top-Left origin coordinates.
    public init(centerX: Double, centerY: Double, width: Double, height: Double) {
        let w = max(0, width)
        let h = max(0, height)
        let x = centerX - (w / 2.0)
        let y = centerY - (h / 2.0)
        self.init(x: x, y: y, width: w, height: h)
    }

    public var minX: Double { x }
    public var maxX: Double { x + width }
    public var minY: Double { y }
    public var maxY: Double { y + height }
    public var midX: Double { x + (width / 2.0) }
    public var midY: Double { y + (height / 2.0) }
    public var area: Double { width * height }

    /// Converts normalized [0,1] coordinates to absolute pixel coordinates for an image of given size.
    public func toPixelRect(imageSize: CGSize) -> CGRect {
        CGRect(
            x: x * imageSize.width,
            y: y * imageSize.height,
            width: width * imageSize.width,
            height: height * imageSize.height
        )
    }

    /// Calculates Intersection over Union (IoU) with another bounding box.
    public func iou(with other: BoundingBox) -> Double {
        let interMinX = max(minX, other.minX)
        let interMinY = max(minY, other.minY)
        let interMaxX = min(maxX, other.maxX)
        let interMaxY = min(maxY, other.maxY)

        let interWidth = max(0.0, interMaxX - interMinX)
        let interHeight = max(0.0, interMaxY - interMinY)
        let intersectionArea = interWidth * interHeight

        if intersectionArea <= 0 {
            return 0.0
        }

        let unionArea = area + other.area - intersectionArea
        return unionArea > 0 ? intersectionArea / unionArea : 0.0
    }

    /// Calculates the intersection bounding box if any overlap exists.
    public func intersection(with other: BoundingBox) -> BoundingBox? {
        let interMinX = max(minX, other.minX)
        let interMinY = max(minY, other.minY)
        let interMaxX = min(maxX, other.maxX)
        let interMaxY = min(maxY, other.maxY)

        let interWidth = interMaxX - interMinX
        let interHeight = interMaxY - interMinY

        guard interWidth > 0 && interHeight > 0 else { return nil }
        return BoundingBox(x: interMinX, y: interMinY, width: interWidth, height: interHeight)
    }
}
