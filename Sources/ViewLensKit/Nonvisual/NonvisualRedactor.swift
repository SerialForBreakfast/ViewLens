import Foundation

/// Automated redaction engine to strip sensitive credentials, passwords, and private data from nonvisual models.
public enum NonvisualRedactor {
    public static let redactedMask = "[REDACTED_SECRET]"

    private static let sensitiveKeywords: [String] = [
        "password", "passwd", "secret", "token", "apikey", "api_key",
        "bearer", "authorization", "ssn", "creditcard", "cvv"
    ]

    public static func redact(_ model: NonvisualScreenModel) -> NonvisualScreenModel {
        let redactedElements = model.elements.map(redact(element:))
        return NonvisualScreenModel(
            schemaVersion: model.schemaVersion,
            id: model.id,
            title: model.title.map(redactText(_:)),
            sourceMode: model.sourceMode,
            regions: model.regions,
            elements: redactedElements,
            relationships: model.relationships,
            navigationSequences: model.navigationSequences,
            mismatches: model.mismatches
        )
    }

    public static func redact(element: NonvisualElement) -> NonvisualElement {
        let isSecure = isSecureField(element)

        let redactedVisibleLabel: String?
        if isSecure {
            redactedVisibleLabel = element.visibleLabel != nil ? "••••••••" : nil
        } else {
            redactedVisibleLabel = element.visibleLabel.map(redactText(_:))
        }

        let redactedSemantics: NonvisualSemantics?
        if let s = element.semantics {
            let redactedVal: String?
            if isSecure {
                redactedVal = s.value != nil ? "••••••••" : nil
            } else {
                redactedVal = s.value.map(redactText(_:))
            }

            redactedSemantics = NonvisualSemantics(
                runtimeIdentifier: s.runtimeIdentifier,
                accessibleName: isSecure ? (s.accessibleName ?? "Secure field") : s.accessibleName.map(redactText(_:)),
                role: s.role,
                value: redactedVal,
                states: s.states,
                actions: s.actions,
                hint: s.hint.map(redactText(_:)),
                isHeading: s.isHeading
            )
        } else {
            redactedSemantics = nil
        }

        return NonvisualElement(
            id: element.id,
            visualIndex: element.visualIndex,
            type: element.type,
            visibleLabel: redactedVisibleLabel,
            bounds: element.bounds,
            regionID: element.regionID,
            findingIDs: element.findingIDs,
            semantics: redactedSemantics,
            isInteractive: element.isInteractive,
            requiresValueOrState: element.requiresValueOrState,
            requiresAction: element.requiresAction,
            visualEvidence: element.visualEvidence,
            semanticEvidence: element.semanticEvidence
        )
    }

    public static func redactText(_ text: String) -> String {
        var result = text

        // Bearer token patterns
        if let regex = try? NSRegularExpression(pattern: "Bearer\\s+[A-Za-z0-9\\-_\\.]+", options: [.caseInsensitive]) {
            let range = NSRange(result.startIndex..., in: result)
            result = regex.stringByReplacingMatches(in: result, options: [], range: range, withTemplate: "Bearer \(redactedMask)")
        }

        // Generic API Key / Secret assignments
        if let regex = try? NSRegularExpression(pattern: "(?i)(api[\\s_-]?key|secret|password|token)\\s*[:=]\\s*['\"]?([A-Za-z0-9\\-_\\.]{6,})['\"]?", options: []) {
            let range = NSRange(result.startIndex..., in: result)
            result = regex.stringByReplacingMatches(in: result, options: [], range: range, withTemplate: "$1: \(redactedMask)")
        }

        return result
    }

    private static func isSecureField(_ element: NonvisualElement) -> Bool {
        if element.type == "secureTextField" || element.semantics?.role == "secureTextField" {
            return true
        }
        // Only classify as secure input field if it is an interactive input or field
        if element.type.contains("Field") || element.type.contains("Input") || element.isInteractive {
            let name = (element.visibleLabel ?? element.semantics?.accessibleName ?? "").lowercased()
            return name.contains("password") || name.contains("passwd") || name.contains("pin")
        }
        return false
    }
}
