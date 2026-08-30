import SwiftUI
import AppKit

public enum ViewLensTheme {
    // MARK: - Spacing & Sizing Tokens (Section 7.3)
    public static let microSpacing: CGFloat = 4
    public static let compactSpacing: CGFloat = 8
    public static let cardPadding: CGFloat = 12
    public static let standardSpacing: CGFloat = 16
    public static let sectionSpacing: CGFloat = 24
    public static let majorSpacing: CGFloat = 32

    // MARK: - Shape & Corner Radii (Section 7.4)
    public static let controlCornerRadius: CGFloat = 6
    public static let buttonCornerRadius: CGFloat = 8
    public static let panelCornerRadius: CGFloat = 12
    public static let dropZoneCornerRadius: CGFloat = 16

    // MARK: - Core Color Tokens (Section 7.1)
    public static let windowBackground = Color(
        light: NSColor(srgbRed: 0.96, green: 0.96, blue: 0.97, alpha: 1), // #F5F6F8
        dark: NSColor(srgbRed: 0.07, green: 0.09, blue: 0.11, alpha: 1)   // #11161C
    )

    public static let sidebarBackground = Color(
        light: NSColor.windowBackgroundColor,
        dark: NSColor(srgbRed: 0.08, green: 0.11, blue: 0.13, alpha: 1)   // #151B22
    )

    public static let panelBackground = Color(
        light: NSColor.white,                                             // #FFFFFF
        dark: NSColor(srgbRed: 0.10, green: 0.13, blue: 0.16, alpha: 1)   // #1A2129
    )

    public static let elevatedBackground = Color(
        light: NSColor(srgbRed: 0.97, green: 0.98, blue: 0.99, alpha: 1), // #F8FAFC
        dark: NSColor(srgbRed: 0.13, green: 0.16, blue: 0.20, alpha: 1)   // #202A33
    )

    public static let brand = Color(
        light: NSColor(srgbRed: 0.03, green: 0.50, blue: 0.51, alpha: 1), // #087F83
        dark: NSColor(srgbRed: 0.33, green: 0.78, blue: 0.76, alpha: 1)   // #55C7C2
    )

    public static let focus = Color(
        light: NSColor(srgbRed: 0.09, green: 0.41, blue: 0.88, alpha: 1), // #1769E0
        dark: NSColor(srgbRed: 0.30, green: 0.55, blue: 1.0, alpha: 1)    // #4C8DFF
    )

    public static let safeAreaGuide = Color(
        light: NSColor(srgbRed: 0.00, green: 0.49, blue: 0.60, alpha: 1), // #007C99
        dark: NSColor(srgbRed: 0.22, green: 0.78, blue: 0.90, alpha: 1)   // #39C6E6
    )

    public static let panelBorder = Color.primary.opacity(0.10)
}

public extension Color {
    init(light: NSColor, dark: NSColor) {
        self.init(nsColor: NSColor(name: nil) { appearance in
            let match = appearance.bestMatch(from: [.aqua, .darkAqua])
            return match == .darkAqua ? dark : light
        })
    }
}

public struct ViewLensPanelModifier: ViewModifier {
    @Environment(\.colorSchemeContrast) private var colorSchemeContrast
    public var padding: CGFloat = ViewLensTheme.standardSpacing

    public func body(content: Content) -> some View {
        content
            .padding(padding)
            .background(ViewLensTheme.panelBackground)
            .clipShape(RoundedRectangle(cornerRadius: ViewLensTheme.panelCornerRadius, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: ViewLensTheme.panelCornerRadius, style: .continuous)
                    .stroke(
                        colorSchemeContrast == .increased ? Color.primary.opacity(0.45) : ViewLensTheme.panelBorder,
                        lineWidth: colorSchemeContrast == .increased ? 2 : 1
                    )
            }
    }
}

public extension View {
    func viewLensPanel(padding: CGFloat = ViewLensTheme.standardSpacing) -> some View {
        modifier(ViewLensPanelModifier(padding: padding))
    }
}
