import Foundation
import CoreGraphics

/// Formal IPC protocol between the standalone `viewlens` CLI and a Mac Catalyst app harness.
public enum CatalystIPC {
    public struct Request: Codable, Sendable {
        public let command: String // "render", "introspect", "health"
        public let template: String
        public let device: DeviceProfile
        public let dynamicTypeSize: String
        public let colorScheme: String

        public init(
            command: String,
            template: String,
            device: DeviceProfile,
            dynamicTypeSize: String = "large",
            colorScheme: String = "light"
        ) {
            self.command = command
            self.template = template
            self.device = device
            self.dynamicTypeSize = dynamicTypeSize
            self.colorScheme = colorScheme
        }
    }

    public struct Response: Codable, Sendable {
        public let success: Bool
        public let template: String
        public let imagePath: String?
        public let hasAmbiguousLayout: Bool
        public let ambiguousViews: [String]
        public let error: String?

        public init(
            success: Bool,
            template: String,
            imagePath: String? = nil,
            hasAmbiguousLayout: Bool = false,
            ambiguousViews: [String] = [],
            error: String? = nil
        ) {
            self.success = success
            self.template = template
            self.imagePath = imagePath
            self.hasAmbiguousLayout = hasAmbiguousLayout
            self.ambiguousViews = ambiguousViews
            self.error = error
        }
    }
}
