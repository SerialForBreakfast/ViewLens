import Foundation
import CoreGraphics

/// An issue identified during Voice Control and speech trigger analysis.
public struct VoiceControlIssue: Codable, Sendable, Equatable {
    public enum Kind: String, Codable, Sendable, Equatable {
        case nameCollision = "name_collision"
        case labelMismatch = "label_mismatch"
        case activationPointOutside = "activation_point_outside"
        case missingTrigger = "missing_trigger"
    }

    public let kind: Kind
    public let elementID: String
    public let message: String
    public let severity: ViewLensSeverity

    public init(
        kind: Kind,
        elementID: String,
        message: String,
        severity: ViewLensSeverity = .error
    ) {
        self.kind = kind
        self.elementID = elementID
        self.message = message
        self.severity = severity
    }
}

/// Comprehensive report of Voice Control speech trigger consistency and collision analysis.
public struct VoiceControlReport: Codable, Sendable, Equatable {
    public let issues: [VoiceControlIssue]
    public let passed: Bool

    public init(issues: [VoiceControlIssue]) {
        self.issues = issues
        self.passed = issues.filter { $0.severity == .error }.isEmpty
    }
}

/// Engine validating Voice Control speech triggers, name collisions, and activation points (MCP-16.7).
public enum VoiceControlValidator {

    /// Validates Voice Control compliance across a collection of accessibility nodes and visual elements.
    public static func validate(
        nodes: [NativeAccessibilityNode],
        visualElements: [DetectedElement] = []
    ) -> VoiceControlReport {
        var issues: [VoiceControlIssue] = []
        var nameMap: [String: [String]] = [:]

        for node in nodes {
            guard node.traits.contains(.isButton) || node.traits.contains(.isLink) else { continue }
            guard let label = node.label, !label.isEmpty else {
                issues.append(VoiceControlIssue(
                    kind: .missingTrigger,
                    elementID: node.id.rawValue,
                    message: "Interactive control has no speech trigger label for Voice Control",
                    severity: .error
                ))
                continue
            }

            let normalized = label.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            nameMap[normalized, default: []].append(node.id.rawValue)

            // Check activation point containment. Only evaluated when an explicit override was
            // reported; a missing activationPoint means "unavailable", not "matches the frame".
            if let frame = node.frame, let activationPoint = node.activationPoint,
               !frame.contains(point: activationPoint) {
                issues.append(VoiceControlIssue(
                    kind: .activationPointOutside,
                    elementID: node.id.rawValue,
                    message: "Activation point is outside the bounds of interactive control",
                    severity: .error
                ))
            }
        }

        // Check for name collisions
        for (name, ids) in nameMap where ids.count > 1 {
            for id in ids {
                issues.append(VoiceControlIssue(
                    kind: .nameCollision,
                    elementID: id,
                    message: "Voice Control name collision: multiple interactive controls share the trigger '\(name)'",
                    severity: .warning
                ))
            }
        }

        return VoiceControlReport(issues: issues)
    }
}
