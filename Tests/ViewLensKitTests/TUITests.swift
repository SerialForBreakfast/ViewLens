import Testing
import Foundation
@testable import ViewLensKit

@Suite("Terminal User Interface (TUI) & ASCII Wireframe Tests")
struct TUITests {
    @Test("ANSI color styling wraps escape codes correctly")
    func testANSIColorStyling() {
        let text = "Hello ViewLens"
        let styled = TerminalCanvas.styled(text, color: .green, bold: true)
        #expect(styled.contains("\u{001B}[1m")) // Bold
        #expect(styled.contains("\u{001B}[32m")) // Green
        #expect(styled.contains("\u{001B}[0m"))  // Reset
    }

    @Test("ASCIILayoutRenderer renders bounding boxes with Dynamic Island and Home Bar")
    func testASCIIRenderer() {
        let box = BoundingBox(x: 0.1, y: 0.2, width: 0.8, height: 0.15)
        let element = DetectedElement(type: "primaryButton", confidence: 0.95, boundingBox: box)
        let issue = ViewLensIssue(
            kind: .tappableTargetTooSmall,
            severity: .error,
            description: "Button height below 44pt",
            confidence: 0.95,
            elementIndex: 0
        )

        let lines = ASCIILayoutRenderer.renderWireframe(
            device: .iPhone16Pro,
            elements: [element],
            issues: [issue],
            canvasWidth: 38,
            canvasHeight: 16
        )

        #expect(lines.count == 16)
        let fullOutput = lines.joined(separator: "\n")
        #expect(fullOutput.contains("Dynamic Island"))
        #expect(fullOutput.contains("━━━━━━"))
        #expect(fullOutput.contains("primaryButton"))
        #expect(fullOutput.contains("❌"))
    }

    @Test("ASCIILayoutRenderer renders compliant elements with checkmark")
    func testASCIICompliantRenderer() {
        let box = BoundingBox(x: 0.1, y: 0.2, width: 0.8, height: 0.2)
        let element = DetectedElement(type: "primaryButton", confidence: 0.98, boundingBox: box)

        let lines = ASCIILayoutRenderer.renderWireframe(
            device: .iPhone16Pro,
            elements: [element],
            issues: [],
            canvasWidth: 38,
            canvasHeight: 16
        )

        let fullOutput = lines.joined(separator: "\n")
        #expect(fullOutput.contains("✅primaryButton"))
    }
}
