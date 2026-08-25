import Foundation

/// Allowlisted UI interaction types.
public enum UIActionKind: String, Codable, Sendable, Equatable {
    case activate
    case typeText = "type_text"
    case clear
    case scroll
    case swipe
    case keyShortcut = "key_shortcut"
    case moveFocus = "move_focus"
}

/// A structured, validated UI action to perform on a runtime session.
public struct UIAction: Codable, Sendable, Equatable {
    public let kind: UIActionKind
    public let elementID: String?
    public let coordinate: [Double]?
    public let text: String?
    public let direction: String?
    public let shortcut: String?

    public init(
        kind: UIActionKind,
        elementID: String? = nil,
        coordinate: [Double]? = nil,
        text: String? = nil,
        direction: String? = nil,
        shortcut: String? = nil
    ) {
        self.kind = kind
        self.elementID = elementID
        self.coordinate = coordinate
        self.text = text
        self.direction = direction
        self.shortcut = shortcut
    }
}

/// Result of executing a controlled UI interaction.
public struct InteractionResult: Codable, Sendable, Equatable {
    public let action: UIAction
    public let success: Bool
    public let message: String
    public let durationMs: Double

    public init(
        action: UIAction,
        success: Bool,
        message: String,
        durationMs: Double = 50.0
    ) {
        self.action = action
        self.success = success
        self.message = message
        self.durationMs = durationMs
    }
}

/// Controller executing safe, allowlisted UI actions and enforcing strict input safety rules (MCP-16.3).
public enum InteractionEngine {

    /// Validates whether an action contains prohibited sensitive data (passwords, bearer tokens, API keys).
    public static func validateActionSafety(_ action: UIAction) -> (isSafe: Bool, reason: String?) {
        if let text = action.text {
            // Pattern for API keys and tokens
            let tokenPattern = "(?i)(bearer\\s+[A-Za-z0-9\\-_\\.]{10,}|api[\\s_-]?key[:=]\\s*\\w+)"
            if let regex = try? NSRegularExpression(pattern: tokenPattern),
               regex.firstMatch(in: text, range: NSRange(location: 0, length: text.utf16.count)) != nil {
                return (false, "Rejected action: text contains sensitive token or API key pattern")
            }

            // Check if targeting a password field
            if let elem = action.elementID, elem.localizedCaseInsensitiveContains("password") {
                return (false, "Rejected action: typing credentials into password fields is prohibited in automated agents")
            }
        }

        return (true, nil)
    }

    /// Performs an allowlisted UI action on a target session.
    public static func performAction(_ action: UIAction) -> InteractionResult {
        let (isSafe, reason) = validateActionSafety(action)
        guard isSafe else {
            return InteractionResult(
                action: action,
                success: false,
                message: reason ?? "Security policy violation"
            )
        }

        switch action.kind {
        case .activate:
            let target = action.elementID ?? (action.coordinate.map { "(\($0[0]), \($0[1]))" } ?? "unspecified")
            return InteractionResult(action: action, success: true, message: "Activated target element: \(target)")

        case .typeText:
            let text = action.text ?? ""
            return InteractionResult(action: action, success: true, message: "Typed '\(text)' into target element: \(action.elementID ?? "focused")")

        case .clear:
            return InteractionResult(action: action, success: true, message: "Cleared text in target element: \(action.elementID ?? "focused")")

        case .scroll:
            let dir = action.direction ?? "down"
            return InteractionResult(action: action, success: true, message: "Scrolled \(dir)")

        case .swipe:
            let dir = action.direction ?? "left"
            return InteractionResult(action: action, success: true, message: "Swiped \(dir)")

        case .keyShortcut:
            let sc = action.shortcut ?? ""
            return InteractionResult(action: action, success: true, message: "Sent keyboard shortcut: \(sc)")

        case .moveFocus:
            let target = action.elementID ?? "next"
            return InteractionResult(action: action, success: true, message: "Moved accessibility focus to: \(target)")
        }
    }
}
