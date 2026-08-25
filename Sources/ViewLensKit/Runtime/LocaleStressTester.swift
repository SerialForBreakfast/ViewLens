import Foundation

/// Stress profile for evaluating internationalization, localization expansion, and script directions.
public enum LocaleStressProfile: String, Codable, Sendable, Equatable {
    case pseudolocalization = "pseudo_loc"
    case cjkExpansion = "cjk_expansion"
    case germanCompound = "german_compound"
    case rtlMirroring = "rtl_mirroring"
}

/// A localized string transformation test case.
public struct LocaleStressResult: Codable, Sendable, Equatable {
    public let originalText: String
    public let transformedText: String
    public let lengthExpansionRatio: Double
    public let isRTL: Bool

    public init(
        originalText: String,
        transformedText: String,
        lengthExpansionRatio: Double,
        isRTL: Bool = false
    ) {
        self.originalText = originalText
        self.transformedText = transformedText
        self.lengthExpansionRatio = lengthExpansionRatio
        self.isRTL = isRTL
    }
}

/// Engine generating localization stress permutations, string expansion, and RTL shifts (MCP-16.12).
public enum LocaleStressTester {

    /// Transforms a plain text string into a pseudolocalized string with +35% length expansion and diacritics.
    public static func pseudolocalize(_ text: String) -> String {
        guard !text.isEmpty else { return text }

        let mapping: [Character: String] = [
            "a": "á", "e": "é", "i": "í", "o": "ó", "u": "ú",
            "A": "Á", "E": "É", "I": "Í", "O": "Ó", "U": "Ú",
            "c": "ç", "C": "Ç", "n": "ñ", "N": "Ñ"
        ]

        var expanded = ""
        for char in text {
            if let replaced = mapping[char] {
                expanded.append(replaced)
            } else {
                expanded.append(char)
            }
        }

        // Add 35% trailing expansion padding to stress button and label boundaries
        let paddingLength = max(1, Int(Double(text.count) * 0.35))
        let padding = String(repeating: "~", count: paddingLength)

        return "[!!! \(expanded) \(padding) !!!]"
    }

    /// Evaluates text stress under a specified internationalization profile.
    public static func generateStressCase(
        text: String,
        profile: LocaleStressProfile
    ) -> LocaleStressResult {
        switch profile {
        case .pseudolocalization:
            let pseudo = pseudolocalize(text)
            let ratio = text.isEmpty ? 1.0 : Double(pseudo.count) / Double(text.count)
            return LocaleStressResult(originalText: text, transformedText: pseudo, lengthExpansionRatio: ratio, isRTL: false)

        case .germanCompound:
            let transformed = text + " (Benutzerkontoeinstellungen)"
            let ratio = text.isEmpty ? 1.0 : Double(transformed.count) / Double(text.count)
            return LocaleStressResult(originalText: text, transformedText: transformed, lengthExpansionRatio: ratio, isRTL: false)

        case .cjkExpansion:
            let transformed = "\(text) [繁體中文測試]"
            let ratio = text.isEmpty ? 1.0 : Double(transformed.count) / Double(text.count)
            return LocaleStressResult(originalText: text, transformedText: transformed, lengthExpansionRatio: ratio, isRTL: false)

        case .rtlMirroring:
            let transformed = "مرحبا: \(text)"
            let ratio = text.isEmpty ? 1.0 : Double(transformed.count) / Double(text.count)
            return LocaleStressResult(originalText: text, transformedText: transformed, lengthExpansionRatio: ratio, isRTL: true)
        }
    }
}
