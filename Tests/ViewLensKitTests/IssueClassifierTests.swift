import Testing
import CoreGraphics
@testable import ViewLensKit

@Suite("IssueClassifier HIG Rules Tests")
struct IssueClassifierTests {
    @Test("Flags primaryButton when height is under 44pt touch target minimum")
    func testTouchTargetTooSmall() {
        // Given an iPhone 16 Pro screenshot (1179 x 2556, scale = 3.0)
        // 44pt at @3x is 132px.
        // A button with height 90px (30pt) is under minimum.
        let imageSize = CGSize(width: 1179, height: 2556)
        let smallButtonBox = BoundingBox(x: 0.1, y: 0.8, width: 0.8, height: 90.0 / 2556.0)

        let element = DetectedElement(
            type: "primaryButton",
            confidence: 0.95,
            boundingBox: smallButtonBox
        )

        let issues = IssueClassifier.classify(elements: [element], imageSize: imageSize, scale: 3.0)
        #expect(!issues.isEmpty)
        #expect(issues.contains { $0.kind == .tappableTargetTooSmall })
        #expect(issues.first?.severity == .error)
    }

    @Test("Passes primaryButton when height meets 44pt minimum")
    func testCompliantTouchTarget() {
        let imageSize = CGSize(width: 1179, height: 2556)
        // 50pt at @3x is 150px
        let compliantBox = BoundingBox(x: 0.1, y: 0.8, width: 0.8, height: 150.0 / 2556.0)

        let element = DetectedElement(
            type: "primaryButton",
            confidence: 0.95,
            boundingBox: compliantBox
        )

        let issues = IssueClassifier.classify(elements: [element], imageSize: imageSize, scale: 3.0)
        let touchTargetIssues = issues.filter { $0.kind == .tappableTargetTooSmall }
        #expect(touchTargetIssues.isEmpty)
    }

    @Test("Flags cross-element collisions when IoU > 0.30")
    func testOverlappingElements() {
        let imageSize = CGSize(width: 1179, height: 2556)
        // Two buttons that overlap heavily
        let box1 = BoundingBox(x: 0.1, y: 0.5, width: 0.6, height: 0.1)
        let box2 = BoundingBox(x: 0.2, y: 0.52, width: 0.6, height: 0.1)

        let elem1 = DetectedElement(type: "primaryButton", confidence: 0.9, boundingBox: box1)
        let elem2 = DetectedElement(type: "textField", confidence: 0.88, boundingBox: box2)

        let issues = IssueClassifier.classify(elements: [elem1, elem2], imageSize: imageSize, scale: 3.0)
        #expect(issues.contains { $0.kind == .overlappingElements })
    }

    @Test("Infers display scale factor accurately from width")
    func testScaleInference() {
        #expect(IssueClassifier.inferDisplayScale(imageWidth: 1179) == 3.0)
        #expect(IssueClassifier.inferDisplayScale(imageWidth: 1290) == 3.0)
        #expect(IssueClassifier.inferDisplayScale(imageWidth: 750) == 2.0)
        #expect(IssueClassifier.inferDisplayScale(imageWidth: 828) == 2.0)
        #expect(IssueClassifier.inferDisplayScale(imageWidth: 1668) == 2.0)
    }
}
