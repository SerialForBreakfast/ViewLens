import Foundation
import CoreGraphics

#if canImport(SwiftUI)
import SwiftUI
#endif

/// Represents an Apple hardware device display profile with physical and logical dimensions.
public struct DeviceProfile: Codable, Sendable, Equatable, Hashable {
    public enum DeviceClass: String, Codable, Sendable {
        case phone
        case pad
        case watch
        case mac
    }

    public struct Insets: Codable, Sendable, Equatable, Hashable {
        public let top: Double
        public let leading: Double
        public let bottom: Double
        public let trailing: Double

        public init(top: Double = 0, leading: Double = 0, bottom: Double = 0, trailing: Double = 0) {
            self.top = top
            self.leading = leading
            self.bottom = bottom
            self.trailing = trailing
        }
    }

    public let id: String
    public let name: String
    public let deviceClass: DeviceClass
    public let pointWidth: Double
    public let pointHeight: Double
    public let scale: Double
    public let safeAreaInsets: Insets
    public let cornerRadius: Double

    public init(
        id: String,
        name: String,
        deviceClass: DeviceClass,
        pointWidth: Double,
        pointHeight: Double,
        scale: Double,
        safeAreaInsets: Insets,
        cornerRadius: Double
    ) {
        self.id = id
        self.name = name
        self.deviceClass = deviceClass
        self.pointWidth = pointWidth
        self.pointHeight = pointHeight
        self.scale = scale
        self.safeAreaInsets = safeAreaInsets
        self.cornerRadius = cornerRadius
    }

    public var pointSize: CGSize {
        CGSize(width: pointWidth, height: pointHeight)
    }

    public var pixelWidth: Double {
        pointWidth * scale
    }

    public var pixelHeight: Double {
        pointHeight * scale
    }

    public var pixelSize: CGSize {
        CGSize(width: pixelWidth, height: pixelHeight)
    }

    public var aspectRatio: Double {
        pointHeight > 0 ? pointWidth / pointHeight : 0
    }
}

// MARK: - Standard Apple Device Presets
public extension DeviceProfile {
    /// iPhone SE (3rd generation) - 4.7" display with Home button
    static let iPhoneSE = DeviceProfile(
        id: "iPhoneSE",
        name: "iPhone SE (3rd gen)",
        deviceClass: .phone,
        pointWidth: 375,
        pointHeight: 667,
        scale: 2.0,
        safeAreaInsets: Insets(top: 20, leading: 0, bottom: 0, trailing: 0),
        cornerRadius: 0
    )

    /// iPhone 16 / iPhone 15 / iPhone 14 Pro - 6.1" display with Dynamic Island
    static let iPhone16Pro = DeviceProfile(
        id: "iPhone16Pro",
        name: "iPhone 16 Pro",
        deviceClass: .phone,
        pointWidth: 393,
        pointHeight: 852,
        scale: 3.0,
        safeAreaInsets: Insets(top: 59, leading: 0, bottom: 34, trailing: 0),
        cornerRadius: 55
    )

    /// iPhone 16 Pro Max - 6.9" display with Dynamic Island
    static let iPhone16ProMax = DeviceProfile(
        id: "iPhone16ProMax",
        name: "iPhone 16 Pro Max",
        deviceClass: .phone,
        pointWidth: 440,
        pointHeight: 956,
        scale: 3.0,
        safeAreaInsets: Insets(top: 59, leading: 0, bottom: 34, trailing: 0),
        cornerRadius: 55
    )

    /// iPad Pro 11-inch (M4)
    static let iPadPro11 = DeviceProfile(
        id: "iPadPro11",
        name: "iPad Pro 11-inch",
        deviceClass: .pad,
        pointWidth: 834,
        pointHeight: 1210,
        scale: 2.0,
        safeAreaInsets: Insets(top: 24, leading: 0, bottom: 20, trailing: 0),
        cornerRadius: 18
    )

    /// iPad Pro 13-inch (M4)
    static let iPadPro13 = DeviceProfile(
        id: "iPadPro13",
        name: "iPad Pro 13-inch",
        deviceClass: .pad,
        pointWidth: 1024,
        pointHeight: 1366,
        scale: 2.0,
        safeAreaInsets: Insets(top: 24, leading: 0, bottom: 20, trailing: 0),
        cornerRadius: 18
    )

    /// All standard default device presets
    static let allPresets: [DeviceProfile] = [
        .iPhoneSE,
        .iPhone16Pro,
        .iPhone16ProMax,
        .iPadPro11,
        .iPadPro13
    ]

    /// Lookup a device profile by ID or substring name match (case-insensitive)
    static func named(_ query: String) -> DeviceProfile? {
        let cleaned = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return allPresets.first { preset in
            preset.id.lowercased() == cleaned ||
            preset.name.lowercased() == cleaned ||
            preset.id.lowercased().contains(cleaned) ||
            preset.name.lowercased().contains(cleaned)
        }
    }
}
