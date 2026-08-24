import CoreGraphics
import Foundation
import ImageIO
import SwiftUI
import Testing
@testable import ViewLensKit

@Suite("Desktop Workbench Visual Baselines")
struct DesktopBaselineTests {
    private struct Case: Sendable {
        let name: String
        let width: Double
        let height: Double
        let colorScheme: ColorScheme
    }

    private let cases = [
        Case(name: "compact-light", width: 820, height: 680, colorScheme: .light),
        Case(name: "compact-dark", width: 820, height: 680, colorScheme: .dark),
        Case(name: "standard-light", width: 1_180, height: 760, colorScheme: .light),
        Case(name: "standard-dark", width: 1_180, height: 760, colorScheme: .dark),
        Case(name: "wide-light", width: 1_440, height: 900, colorScheme: .light),
        Case(name: "wide-dark", width: 1_440, height: 900, colorScheme: .dark)
    ]

    @Test("Compact, standard, and wide Light/Dark renders match approved references")
    @MainActor
    func baselines() throws {
        let baselineDirectory = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("ReferenceImages/Desktop", isDirectory: true)
        let recordsBaselines = ProcessInfo.processInfo.environment["VIEWLENS_RECORD_BASELINES"] == "1"

        if recordsBaselines {
            try FileManager.default.createDirectory(at: baselineDirectory, withIntermediateDirectories: true)
        }

        for testCase in cases {
            let profile = DeviceProfile(
                id: testCase.name,
                name: testCase.name,
                deviceClass: .mac,
                pointWidth: testCase.width,
                pointHeight: testCase.height,
                scale: 1,
                safeAreaInsets: .init(),
                cornerRadius: 0
            )
            let candidate = try #require(InProcessCanvasRenderer.render(
                profile: profile,
                colorScheme: testCase.colorScheme
            ) { DesktopReviewWorkbenchTemplate() })
            let baselineURL = baselineDirectory.appendingPathComponent("\(testCase.name).png")

            if recordsBaselines {
                try OverlayRenderer.write(image: candidate, to: baselineURL)
                continue
            }

            let source = try #require(CGImageSourceCreateWithURL(baselineURL as CFURL, nil))
            let reference = try #require(CGImageSourceCreateImageAtIndex(source, 0, nil))
            let result = VisualDiffEngine.compare(
                reference: reference,
                candidate: candidate,
                thresholdSSIM: 0.995,
                pixelTolerance: 0.01
            )
            #expect(result.passed, "\(testCase.name): SSIM \(result.ssimScore), mismatch \(result.mismatchPercentage)%")
        }
    }
}
