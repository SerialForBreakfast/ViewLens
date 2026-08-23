import Foundation
import CoreGraphics

#if canImport(SwiftUI)
import SwiftUI

/// A SwiftUI container that simulates physical Apple device dimensions, safe areas,
/// Dynamic Type sizes, and color schemes entirely in-process on macOS without a simulator.
public struct VirtualDeviceContainer<Content: View>: View {
    public let profile: DeviceProfile
    public let dynamicTypeSize: DynamicTypeSize
    public let colorScheme: ColorScheme
    public let layoutDirection: LayoutDirection
    public let content: Content

    public init(
        profile: DeviceProfile,
        dynamicTypeSize: DynamicTypeSize = .large,
        colorScheme: ColorScheme = .light,
        layoutDirection: LayoutDirection = .leftToRight,
        @ViewBuilder content: () -> Content
    ) {
        self.profile = profile
        self.dynamicTypeSize = dynamicTypeSize
        self.colorScheme = colorScheme
        self.layoutDirection = layoutDirection
        self.content = content()
    }

    public var body: some View {
        ZStack {
            // Simulated device background fill
            colorScheme == .dark ? Color.black : Color.white

            content
                .dynamicTypeSize(dynamicTypeSize)
                .environment(\.dynamicTypeSize, dynamicTypeSize)
                .padding(.top, profile.safeAreaInsets.top)
                .padding(.bottom, profile.safeAreaInsets.bottom)
                .padding(.leading, profile.safeAreaInsets.leading)
                .padding(.trailing, profile.safeAreaInsets.trailing)
        }
        .frame(width: profile.pointWidth, height: profile.pointHeight)
        .clipped()
        .dynamicTypeSize(dynamicTypeSize)
        .environment(\.dynamicTypeSize, dynamicTypeSize)
        .environment(\.colorScheme, colorScheme)
        .environment(\.layoutDirection, layoutDirection)
        .preferredColorScheme(colorScheme)
    }
}

public struct InProcessCanvasRenderer: Sendable {
    /// Renders any SwiftUI view inside a virtual device container to a CGImage in-process on macOS.
    @MainActor
    public static func render<Content: View>(
        profile: DeviceProfile,
        dynamicTypeSize: DynamicTypeSize = .large,
        colorScheme: ColorScheme = .light,
        layoutDirection: LayoutDirection = .leftToRight,
        @ViewBuilder content: () -> Content
    ) -> CGImage? {
        let container = VirtualDeviceContainer(
            profile: profile,
            dynamicTypeSize: dynamicTypeSize,
            colorScheme: colorScheme,
            layoutDirection: layoutDirection,
            content: content
        )

        let renderer = ImageRenderer(content: container)
        renderer.scale = profile.scale
        renderer.isOpaque = true
        return renderer.cgImage
    }
}
#endif
