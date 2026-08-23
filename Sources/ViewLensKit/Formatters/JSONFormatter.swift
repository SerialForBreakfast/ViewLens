import Foundation

public struct CLIErrorPayload: Codable, Sendable {
    public let error: String
    public let detail: String?
    public let recommendedNextCommand: String?

    public init(error: String, detail: String? = nil, recommendedNextCommand: String? = nil) {
        self.error = error
        self.detail = detail
        self.recommendedNextCommand = recommendedNextCommand
    }
}

public struct JSONFormatter: Sendable {
    private static let encoder: JSONEncoder = {
        let enc = JSONEncoder()
        enc.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        return enc
    }()

    public static func encode<T: Encodable>(_ value: T) -> String {
        guard let data = try? encoder.encode(value),
              let string = String(data: data, encoding: .utf8) else {
            return "{}"
        }
        return string
    }

    public static func errorJSON(message: String, detail: String? = nil, nextCommand: String? = nil) -> String {
        let payload = CLIErrorPayload(error: message, detail: detail, recommendedNextCommand: nextCommand)
        return encode(payload)
    }
}
