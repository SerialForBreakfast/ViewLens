import Foundation
import CoreGraphics
#if canImport(SwiftUI)
import SwiftUI

/// An individual environmental variant in an accessibility test matrix.
public struct AccessibilityMatrixVariant: Sendable, Equatable, Identifiable {
    public var id: String { name }
    public let name: String
    public let device: DeviceProfile
    public let dynamicTypeSize: DynamicTypeSize
    public let colorScheme: ColorScheme
    public let increaseContrast: Bool
    public let reduceMotion: Bool
    public let isRightToLeft: Bool

    public init(
        name: String,
        device: DeviceProfile = .iPhone16Pro,
        dynamicTypeSize: DynamicTypeSize = .large,
        colorScheme: ColorScheme = .light,
        increaseContrast: Bool = false,
        reduceMotion: Bool = false,
        isRightToLeft: Bool = false
    ) {
        self.name = name
        self.device = device
        self.dynamicTypeSize = dynamicTypeSize
        self.colorScheme = colorScheme
        self.increaseContrast = increaseContrast
        self.reduceMotion = reduceMotion
        self.isRightToLeft = isRightToLeft
    }
}

/// Result of evaluating a single accessibility matrix variant.
public struct AccessibilityMatrixVariantResult: Sendable, Equatable, Identifiable {
    public var id: String { variant.id }
    public let variant: AccessibilityMatrixVariant
    public let issues: [ViewLensIssue]
    public let passed: Bool

    public init(
        variant: AccessibilityMatrixVariant,
        issues: [ViewLensIssue] = [],
        passed: Bool
    ) {
        self.variant = variant
        self.issues = issues
        self.passed = passed
    }
}

/// Summary report across all accessibility matrix variants.
public struct AccessibilityMatrixReport: Sendable, Equatable {
    public let componentName: String
    public let results: [AccessibilityMatrixVariantResult]

    public init(
        componentName: String,
        results: [AccessibilityMatrixVariantResult] = []
    ) {
        self.componentName = componentName
        self.results = results
    }

    public var totalVariants: Int { results.count }
    public var passingVariants: Int { results.filter(\.passed).count }
    public var allPassed: Bool { passingVariants == totalVariants && totalVariants > 0 }

    public func formattedSpeech() -> String {
        "Matrix audit for '\(componentName)': \(passingVariants) of \(totalVariants) variants passed. \(allPassed ? "All accessibility variants passed!" : "Regressions detected in some variants.")"
    }
}

/// Engine to generate standard accessibility matrix permutations and evaluate UI variants.
public enum AccessibilityMatrixRunner {

    public static func standardVariants(device: DeviceProfile = .iPhone16Pro) -> [AccessibilityMatrixVariant] {
        return [
            AccessibilityMatrixVariant(
                name: "Standard Light (Large)",
                device: device,
                dynamicTypeSize: .large,
                colorScheme: .light
            ),
            AccessibilityMatrixVariant(
                name: "Standard Dark (Large)",
                device: device,
                dynamicTypeSize: .large,
                colorScheme: .dark
            ),
            AccessibilityMatrixVariant(
                name: "Dynamic Type AX5 (Accessibility XXL)",
                device: device,
                dynamicTypeSize: .accessibility5,
                colorScheme: .light
            ),
            AccessibilityMatrixVariant(
                name: "High Contrast Light",
                device: device,
                dynamicTypeSize: .large,
                colorScheme: .light,
                increaseContrast: true
            ),
            AccessibilityMatrixVariant(
                name: "Right-to-Left (RTL)",
                device: device,
                dynamicTypeSize: .large,
                colorScheme: .light,
                isRightToLeft: true
            )
        ]
    }
}
#endif
