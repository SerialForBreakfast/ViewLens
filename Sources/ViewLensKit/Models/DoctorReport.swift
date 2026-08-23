import Foundation

public struct DiagnosticCheck: Codable, Sendable, Equatable, Hashable {
    public let name: String
    public let status: String // "confirmed", "failed", "skipped"
    public let detail: String

    public init(name: String, status: String, detail: String) {
        self.name = name
        self.status = status
        self.detail = detail
    }
}

public struct DoctorReport: Codable, Sendable, Equatable, Hashable {
    public let status: String // "ready" or "not_ready"
    public let checks: [DiagnosticCheck]
    public let recommendedNextCommand: String

    public init(status: String, checks: [DiagnosticCheck], recommendedNextCommand: String) {
        self.status = status
        self.checks = checks
        self.recommendedNextCommand = recommendedNextCommand
    }
}
