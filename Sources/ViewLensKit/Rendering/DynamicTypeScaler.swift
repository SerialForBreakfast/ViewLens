import Foundation
import CoreGraphics

#if canImport(SwiftUI)
import SwiftUI

extension DynamicTypeSize {
    /// Apple HIG font scale multiplier relative to default `large` (1.0).
    public var scaleFactor: CGFloat {
        switch self {
        case .xSmall: return 0.82
        case .small: return 0.88
        case .medium: return 0.94
        case .large: return 1.00
        case .xLarge: return 1.12
        case .xxLarge: return 1.24
        case .xxxLarge: return 1.35
        case .accessibility1: return 1.65
        case .accessibility2: return 1.94
        case .accessibility3: return 2.35
        case .accessibility4: return 2.76
        case .accessibility5: return 3.12
        @unknown default: return 1.00
        }
    }

    /// User-friendly descriptive label with percentage multiplier and body point size.
    public var displayLabel: String {
        switch self {
        case .xSmall: return "xSmall (82% • 14pt)"
        case .small: return "Small (88% • 15pt)"
        case .medium: return "Medium (94% • 16pt)"
        case .large: return "Large (100% • 17pt Default)"
        case .xLarge: return "xLarge (112% • 19pt)"
        case .xxLarge: return "xxLarge (124% • 21pt)"
        case .xxxLarge: return "xxxLarge (135% • 23pt)"
        case .accessibility1: return "AX 1 (165% • 28pt Min Accessibility)"
        case .accessibility2: return "AX 2 (194% • 33pt)"
        case .accessibility3: return "AX 3 (235% • 40pt Standard Audit)"
        case .accessibility4: return "AX 4 (276% • 47pt)"
        case .accessibility5: return "AX 5 (312% • 53pt Max Accessibility)"
        @unknown default: return "Standard (100%)"
        }
    }
}

/// Dynamic Typography Helper that dynamically scales fonts across macOS ImageRenderer
/// to accurately simulate iOS accessibility text enlargement and layout reflow.
public struct ScaledFont: ViewModifier {
    @Environment(\.dynamicTypeSize) var dynamicTypeSize
    public let baseSize: CGFloat
    public let weight: Font.Weight
    public let design: Font.Design

    public init(baseSize: CGFloat, weight: Font.Weight = .regular, design: Font.Design = .default) {
        self.baseSize = baseSize
        self.weight = weight
        self.design = design
    }

    public func body(content: Content) -> some View {
        content.font(.system(size: baseSize * dynamicTypeSize.scaleFactor, weight: weight, design: design))
    }
}

extension View {
    /// Applies an iOS Dynamic Type scaled font that accurately scales in macOS ImageRenderer.
    public func dynamicFont(size: CGFloat, weight: Font.Weight = .regular, design: Font.Design = .default) -> some View {
        modifier(ScaledFont(baseSize: size, weight: weight, design: design))
    }

    public func dynamicLargeTitle(weight: Font.Weight = .bold) -> some View {
        dynamicFont(size: 34, weight: weight)
    }

    public func dynamicTitle(weight: Font.Weight = .bold) -> some View {
        dynamicFont(size: 28, weight: weight)
    }

    public func dynamicTitle2(weight: Font.Weight = .bold) -> some View {
        dynamicFont(size: 22, weight: weight)
    }

    public func dynamicTitle3(weight: Font.Weight = .semibold) -> some View {
        dynamicFont(size: 20, weight: weight)
    }

    public func dynamicHeadline() -> some View {
        dynamicFont(size: 17, weight: .semibold)
    }

    public func dynamicBody() -> some View {
        dynamicFont(size: 17, weight: .regular)
    }

    public func dynamicCallout() -> some View {
        dynamicFont(size: 16, weight: .regular)
    }

    public func dynamicSubheadline() -> some View {
        dynamicFont(size: 15, weight: .regular)
    }

    public func dynamicFootnote() -> some View {
        dynamicFont(size: 13, weight: .regular)
    }

    public func dynamicCaption() -> some View {
        dynamicFont(size: 12, weight: .regular)
    }

    public func dynamicCaption2() -> some View {
        dynamicFont(size: 11, weight: .regular)
    }
}
#endif
