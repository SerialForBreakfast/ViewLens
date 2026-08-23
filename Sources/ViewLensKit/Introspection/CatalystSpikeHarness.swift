import Foundation
import CoreGraphics

#if canImport(UIKit)
import UIKit

/// Empirical test harness validating Mac Catalyst offscreen Auto Layout introspection and rasterization.
@MainActor
public final class CatalystSpikeHarness {
    public struct SpikeResult: Sendable {
        public let wellConstrainedIsAmbiguous: Bool
        public let underConstrainedIsAmbiguous: Bool
        public let rasterizationSucceeded: Bool
        public let averagePassLatencyMs: Double
        public let isCatalystValidated: Bool

        public init(
            wellConstrainedIsAmbiguous: Bool,
            underConstrainedIsAmbiguous: Bool,
            rasterizationSucceeded: Bool,
            averagePassLatencyMs: Double,
            isCatalystValidated: Bool
        ) {
            self.wellConstrainedIsAmbiguous = wellConstrainedIsAmbiguous
            self.underConstrainedIsAmbiguous = underConstrainedIsAmbiguous
            self.rasterizationSucceeded = rasterizationSucceeded
            self.averagePassLatencyMs = averagePassLatencyMs
            self.isCatalystValidated = isCatalystValidated
        }
    }

    public static func runValidationSpike() -> SpikeResult {
        let windowFrame = CGRect(x: 0, y: 0, width: 393, height: 852)
        let window = UIWindow(frame: windowFrame)

        // Case A: Well-Constrained Layout
        let wellVC = UIViewController()
        let wellChild = UIView()
        wellChild.translatesAutoresizingMaskIntoConstraints = false
        wellVC.view.addSubview(wellChild)
        NSLayoutConstraint.activate([
            wellChild.leadingAnchor.constraint(equalTo: wellVC.view.leadingAnchor, constant: 16),
            wellChild.trailingAnchor.constraint(equalTo: wellVC.view.trailingAnchor, constant: -16),
            wellChild.topAnchor.constraint(equalTo: wellVC.view.topAnchor, constant: 50),
            wellChild.heightAnchor.constraint(equalToConstant: 44)
        ])
        window.rootViewController = wellVC
        window.makeKeyAndVisible()
        wellVC.view.layoutIfNeeded()
        let wellAmbiguous = wellChild.hasAmbiguousLayout

        // Case B: Under-Constrained Layout (Missing width and height)
        let underVC = UIViewController()
        let underChild = UIView()
        underChild.translatesAutoresizingMaskIntoConstraints = false
        underVC.view.addSubview(underChild)
        NSLayoutConstraint.activate([
            underChild.leadingAnchor.constraint(equalTo: underVC.view.leadingAnchor, constant: 16),
            underChild.topAnchor.constraint(equalTo: underVC.view.topAnchor, constant: 50)
            // Intentionally missing width and height constraints
        ])
        window.rootViewController = underVC
        underVC.view.layoutIfNeeded()
        let underAmbiguous = underChild.hasAmbiguousLayout

        // Case C: Offscreen Rasterization via UIGraphicsImageRenderer
        let renderer = UIGraphicsImageRenderer(size: windowFrame.size)
        let renderedImage = renderer.image { ctx in
            underVC.view.layer.render(in: ctx.cgContext)
        }
        let rasterSuccess = renderedImage.cgImage != nil

        // Case D: Benchmark 50 layout passes
        let start = DispatchTime.now()
        for _ in 0..<50 {
            wellVC.view.setNeedsLayout()
            wellVC.view.layoutIfNeeded()
        }
        let end = DispatchTime.now()
        let elapsedMs = Double(end.uptimeNanoseconds - start.uptimeNanoseconds) / 1_000_000.0
        let avgLatencyMs = elapsedMs / 50.0

        let isValidated = (!wellAmbiguous) && underAmbiguous && rasterSuccess

        return SpikeResult(
            wellConstrainedIsAmbiguous: wellAmbiguous,
            underConstrainedIsAmbiguous: underAmbiguous,
            rasterizationSucceeded: rasterSuccess,
            averagePassLatencyMs: avgLatencyMs,
            isCatalystValidated: isValidated
        )
    }
}
#endif
