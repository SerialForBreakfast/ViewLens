import SwiftUI

enum ViewLensTheme {
    static let panelCornerRadius: CGFloat = 12
    static let controlCornerRadius: CGFloat = 8
    static let compactSpacing: CGFloat = 8
    static let standardSpacing: CGFloat = 16
    static let sectionSpacing: CGFloat = 24

    static let brand = Color(
        light: NSColor(srgbRed: 0.03, green: 0.50, blue: 0.51, alpha: 1),
        dark: NSColor(srgbRed: 0.33, green: 0.78, blue: 0.76, alpha: 1)
    )

    static let focus = Color(
        light: NSColor(srgbRed: 0.09, green: 0.41, blue: 0.88, alpha: 1),
        dark: NSColor(srgbRed: 0.30, green: 0.55, blue: 1.0, alpha: 1)
    )

    static let panelBackground = Color(
        light: NSColor.white,
        dark: NSColor(srgbRed: 0.10, green: 0.13, blue: 0.16, alpha: 1)
    )

    static let elevatedBackground = Color(
        light: NSColor(srgbRed: 0.97, green: 0.98, blue: 0.99, alpha: 1),
        dark: NSColor(srgbRed: 0.13, green: 0.17, blue: 0.20, alpha: 1)
    )

    static let panelBorder = Color.primary.opacity(0.10)
}

private extension Color {
    init(light: NSColor, dark: NSColor) {
        self.init(nsColor: NSColor(name: nil) { appearance in
            let match = appearance.bestMatch(from: [.aqua, .darkAqua])
            return match == .darkAqua ? dark : light
        })
    }
}

struct ViewLensPanelModifier: ViewModifier {
    var padding: CGFloat = ViewLensTheme.standardSpacing

    func body(content: Content) -> some View {
        content
            .padding(padding)
            .background(ViewLensTheme.panelBackground)
            .clipShape(RoundedRectangle(cornerRadius: ViewLensTheme.panelCornerRadius, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: ViewLensTheme.panelCornerRadius, style: .continuous)
                    .stroke(ViewLensTheme.panelBorder)
            }
    }
}

extension View {
    func viewLensPanel(padding: CGFloat = ViewLensTheme.standardSpacing) -> some View {
        modifier(ViewLensPanelModifier(padding: padding))
    }
}
