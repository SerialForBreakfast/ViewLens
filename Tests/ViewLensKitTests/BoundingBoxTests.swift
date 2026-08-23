import Testing
import CoreGraphics
@testable import ViewLensKit

@Suite("BoundingBox Unit Tests")
struct BoundingBoxTests {
    @Test("YOLO center to top-left coordinate conversion")
    func testCenterConversion() {
        // Given a box at center (0.5, 0.5) with width 0.2 and height 0.4
        let box = BoundingBox(centerX: 0.5, centerY: 0.5, width: 0.2, height: 0.4)

        // Then left edge = 0.5 - 0.1 = 0.4, top edge = 0.5 - 0.2 = 0.3
        #expect(abs(box.x - 0.4) < 0.0001)
        #expect(abs(box.y - 0.3) < 0.0001)
        #expect(abs(box.width - 0.2) < 0.0001)
        #expect(abs(box.height - 0.4) < 0.0001)
        #expect(abs(box.minX - 0.4) < 0.0001)
        #expect(abs(box.maxX - 0.6) < 0.0001)
        #expect(abs(box.minY - 0.3) < 0.0001)
        #expect(abs(box.maxY - 0.7) < 0.0001)
    }

    @Test("Intersection over Union (IoU) calculation")
    func testIoU() {
        let box1 = BoundingBox(x: 0.0, y: 0.0, width: 0.5, height: 0.5) // Area = 0.25
        let box2 = BoundingBox(x: 0.0, y: 0.0, width: 0.5, height: 0.5) // Identical -> IoU = 1.0
        #expect(abs(box1.iou(with: box2) - 1.0) < 0.0001)

        let disjoint = BoundingBox(x: 0.6, y: 0.6, width: 0.2, height: 0.2) // No overlap -> IoU = 0.0
        #expect(box1.iou(with: disjoint) == 0.0)

        // Partial overlap: box1 (0,0, 0.5, 0.5) and box3 (0.25, 0.0, 0.5, 0.5)
        // Intersection = 0.25 * 0.5 = 0.125
        // Union = 0.25 + 0.25 - 0.125 = 0.375
        // IoU = 0.125 / 0.375 = 1/3 ~ 0.3333
        let box3 = BoundingBox(x: 0.25, y: 0.0, width: 0.5, height: 0.5)
        #expect(abs(box1.iou(with: box3) - (1.0 / 3.0)) < 0.0001)
    }

    @Test("Conversion to pixel coordinates")
    func testPixelRectConversion() {
        let box = BoundingBox(x: 0.1, y: 0.2, width: 0.5, height: 0.4)
        let imageSize = CGSize(width: 1000, height: 2000)

        let pixelRect = box.toPixelRect(imageSize: imageSize)
        #expect(pixelRect.origin.x == 100)
        #expect(pixelRect.origin.y == 400)
        #expect(pixelRect.size.width == 500)
        #expect(pixelRect.size.height == 800)
    }
}
