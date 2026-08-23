import Foundation

/// Audit purposes supported by ViewLens quality gates.
public enum AuditPurpose: String, Codable, Sendable, CaseIterable {
    case touchTargets = "touch_targets"
    case clipping = "clipping"
    case accessibility = "accessibility"
    case darkMode = "dark_mode"
    case autolayout = "autolayout"
}

/// Severity threshold that triggers quality gate failure.
public enum FailureThreshold: String, Codable, Sendable {
    case error = "error"
    case warning = "warning"
    case none = "none"
}

/// Configuration for a specific Git Hook or CI Quality Gate.
public struct GateConfig: Codable, Sendable, Equatable {
    public var failOn: FailureThreshold
    public var purposes: [AuditPurpose]
    public var devices: [String]
    public var dynamicTypeSizes: [String]
    public var colorSchemes: [String]
    public var autoDetectStagedViews: Bool
    public var outputMarkdown: String?
    public var strict: Bool

    public init(
        failOn: FailureThreshold = .error,
        purposes: [AuditPurpose] = [.touchTargets, .clipping, .accessibility],
        devices: [String] = ["iPhoneSE", "iPhone16Pro"],
        dynamicTypeSizes: [String] = ["large", "accessibility3"],
        colorSchemes: [String] = ["light", "dark"],
        autoDetectStagedViews: Bool = true,
        outputMarkdown: String? = nil,
        strict: Bool = false
    ) {
        self.failOn = failOn
        self.purposes = purposes
        self.devices = devices
        self.dynamicTypeSizes = dynamicTypeSizes
        self.colorSchemes = colorSchemes
        self.autoDetectStagedViews = autoDetectStagedViews
        self.outputMarkdown = outputMarkdown
        self.strict = strict
    }
}

/// Master ViewLens configuration file (.viewlens.yml / .viewlens.json)
public struct ViewLensConfig: Codable, Sendable, Equatable {
    public var version: Int
    public var gates: [String: GateConfig]

    public init(
        version: Int = 1,
        gates: [String: GateConfig] = [
            "pre-commit": GateConfig(failOn: .error, devices: ["iPhoneSE", "iPhone16Pro"], dynamicTypeSizes: ["large", "accessibility3"]),
            "pre-push": GateConfig(failOn: .warning, devices: ["iPhoneSE", "iPhone16Pro", "iPadPro11"], dynamicTypeSizes: ["large", "accessibility3"]),
            "pull-request": GateConfig(failOn: .warning, devices: ["iPhoneSE", "iPhone16Pro", "iPadPro11"], dynamicTypeSizes: ["large", "accessibility3"], outputMarkdown: "reports/viewlens_pr_summary.md", strict: true)
        ]
    ) {
        self.version = version
        self.gates = gates
    }

    /// Loads configuration from file with fallback to default settings.
    public static func load(from url: URL? = nil) -> ViewLensConfig {
        if let customURL = url, let data = try? Data(contentsOf: customURL) {
            if let decoded = try? JSONDecoder().decode(ViewLensConfig.self, from: data) {
                return decoded
            }
        }

        // Search repository root for .viewlens.json or .viewlens.yml
        let currentDir = FileManager.default.currentDirectoryPath
        let jsonPath = URL(fileURLWithPath: currentDir).appendingPathComponent(".viewlens.json")
        if let data = try? Data(contentsOf: jsonPath),
           let decoded = try? JSONDecoder().decode(ViewLensConfig.self, from: data) {
            return decoded
        }

        return ViewLensConfig()
    }

    /// Generates sample JSON representation of the configuration.
    public func toJSONString() -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        if let data = try? encoder.encode(self),
           let str = String(data: data, encoding: .utf8) {
            return str
        }
        return "{}"
    }
}
