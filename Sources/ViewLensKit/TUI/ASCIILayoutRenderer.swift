import Foundation

/// Renders detected UI elements and HIG layout issues as an ASCII/Unicode wireframe canvas for terminal displays.
public struct ASCIILayoutRenderer: Sendable {
    public static func renderWireframe(
        device: DeviceProfile,
        elements: [DetectedElement],
        issues: [ViewLensIssue],
        canvasWidth: Int = 42,
        canvasHeight: Int = 20
    ) -> [String] {
        var grid = Array(repeating: Array(repeating: " ", count: canvasWidth), count: canvasHeight)

        // Draw outer device boundary
        for x in 0..<canvasWidth {
            grid[0][x] = "─"
            grid[canvasHeight - 1][x] = "─"
        }
        for y in 0..<canvasHeight {
            grid[y][0] = "│"
            grid[y][canvasWidth - 1] = "│"
        }
        grid[0][0] = "┌"
        grid[0][canvasWidth - 1] = "┐"
        grid[canvasHeight - 1][0] = "└"
        grid[canvasHeight - 1][canvasWidth - 1] = "┘"

        // Draw Dynamic Island / Top Safe Area Header
        let islandText = "● Dynamic Island"
        let islandStart = max(1, (canvasWidth - islandText.count) / 2)
        if canvasHeight > 4 {
            for (i, ch) in islandText.enumerated() {
                if islandStart + i < canvasWidth - 1 {
                    grid[1][islandStart + i] = String(ch)
                }
            }
        }

        // Draw Home Bar / Bottom Safe Area
        if canvasHeight > 3 {
            let bar = "━━━━━━"
            let barStart = max(1, (canvasWidth - bar.count) / 2)
            for (i, ch) in bar.enumerated() {
                if barStart + i < canvasWidth - 1 {
                    grid[canvasHeight - 2][barStart + i] = String(ch)
                }
            }
        }

        // Map elements into grid
        let innerWidth = canvasWidth - 2
        let innerHeight = canvasHeight - 4 // excluding top and bottom bars

        for (index, elem) in elements.enumerated() {
            let box = elem.boundingBox
            let gx = 1 + Int(box.x * Double(innerWidth))
            let gy = 2 + Int(box.y * Double(innerHeight))
            let gw = max(6, Int(box.width * Double(innerWidth)))
            let gh = max(2, Int(box.height * Double(innerHeight)))

            let right = min(canvasWidth - 2, gx + gw - 1)
            let bottom = min(canvasHeight - 3, gy + gh - 1)

            guard gx < right && gy <= bottom else { continue }

            // Draw box corners & borders
            for x in gx...right {
                grid[gy][x] = "─"
                grid[bottom][x] = "─"
            }
            for y in gy...bottom {
                grid[y][gx] = "│"
                grid[y][right] = "│"
            }
            grid[gy][gx] = "┌"
            grid[gy][right] = "┐"
            grid[bottom][gx] = "└"
            grid[bottom][right] = "┘"

            // Label text embedded in the top border: ┌─[❌ primaryButton]──┐
            let elemIssues = issues.filter { $0.elementIndex == index }
            let hasError = elemIssues.contains { $0.severity == .error }
            let statusIcon = hasError ? "❌" : "✅"
            let label = "[\(statusIcon)\(elem.type)]"

            let labelX = gx + 1
            if labelX < right {
                for (i, ch) in label.prefix(right - labelX).enumerated() {
                    grid[gy][labelX + i] = String(ch)
                }
            }
        }

        return grid.map { $0.joined() }
    }

    /// Colorizes the ASCII wireframe based on issues
    public static func formatCanvasWithColors(
        device: DeviceProfile,
        elements: [DetectedElement],
        issues: [ViewLensIssue],
        canvasWidth: Int = 42,
        canvasHeight: Int = 20
    ) -> String {
        let lines = renderWireframe(
            device: device,
            elements: elements,
            issues: issues,
            canvasWidth: canvasWidth,
            canvasHeight: canvasHeight
        )

        var coloredOutput: [String] = []
        for line in lines {
            if line.contains("❌") {
                coloredOutput.append(TerminalCanvas.styled(line, color: .red))
            } else if line.contains("⚠️") {
                coloredOutput.append(TerminalCanvas.styled(line, color: .yellow))
            } else if line.contains("✅") {
                coloredOutput.append(TerminalCanvas.styled(line, color: .green))
            } else if line.contains("Dynamic Island") || line.contains("━━━━━━") {
                coloredOutput.append(TerminalCanvas.styled(line, color: .cyan))
            } else {
                coloredOutput.append(TerminalCanvas.styled(line, color: .gray))
            }
        }

        return coloredOutput.joined(separator: "\n")
    }
}
