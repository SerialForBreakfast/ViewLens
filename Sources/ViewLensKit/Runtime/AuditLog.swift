import Foundation

/// A single audit-trail record of a runtime-mutating ViewLens MCP operation (MCP-15.15).
///
/// Deliberately structured so no field can hold arbitrary caller-supplied text (typed fixture
/// input, image bytes, raw accessibility labels): this is a type-level guarantee that typed
/// user content is never persisted, not a redaction filter that could be bypassed.
public struct AuditLogEntry: Codable, Sendable, Equatable {
    public let id: String
    public let timestamp: Date
    public let operation: String
    public let resolvedTarget: MCPEvidenceEnvelope.Target?
    public let scopeDecision: String
    public let durationMs: Double?
    public let artifactPaths: [String]
    public let terminationReason: String?
    public let sessionID: String?

    public init(
        id: String,
        timestamp: Date,
        operation: String,
        resolvedTarget: MCPEvidenceEnvelope.Target?,
        scopeDecision: String,
        durationMs: Double?,
        artifactPaths: [String] = [],
        terminationReason: String?,
        sessionID: String?
    ) {
        self.id = id
        self.timestamp = timestamp
        self.operation = operation
        self.resolvedTarget = resolvedTarget
        self.scopeDecision = scopeDecision
        self.durationMs = durationMs
        self.artifactPaths = artifactPaths
        self.terminationReason = terminationReason
        self.sessionID = sessionID
    }
}

/// Appends ``AuditLogEntry`` records as JSON-Lines to a local, per-workspace log file.
///
/// No third-party dependency (SQLite, logging framework) is introduced — an append-only
/// JSON-Lines file is sufficient for an audit trail and matches the project's zero-dependency
/// philosophy.
public actor AuditLogger {
    /// Swappable so tests can inject a scratch-directory logger instead of writing to the
    /// real per-workspace/home location. Only ever reassigned serially by tests, never
    /// concurrently in production, so the unchecked-Sendable escape hatch is safe here.
    nonisolated(unsafe) public static var shared = AuditLogger()

    /// Rotate the active log once it exceeds this size, keeping exactly one prior rotation.
    static let rotationThresholdBytes: UInt64 = 10 * 1024 * 1024

    public let fileURL: URL
    private let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }()
    private let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }()

    /// - Parameter fileURL: explicit log file location. When `nil`, resolves to
    ///   `<currentDirectory>/.viewlens/audit.jsonl`, falling back to
    ///   `~/.viewlens/audit.jsonl` if the current directory is not writable.
    public init(fileURL: URL? = nil) {
        self.fileURL = fileURL ?? Self.resolveDefaultFileURL()
    }

    static func resolveDefaultFileURL() -> URL {
        let cwd = FileManager.default.currentDirectoryPath
        if FileManager.default.isWritableFile(atPath: cwd) {
            return URL(fileURLWithPath: cwd).appendingPathComponent(".viewlens/audit.jsonl")
        }
        let home = FileManager.default.homeDirectoryForCurrentUser
        return home.appendingPathComponent(".viewlens/audit.jsonl")
    }

    /// Appends one entry to the log file, creating the parent directory and rotating the file
    /// if it has grown past ``rotationThresholdBytes``.
    public func record(_ entry: AuditLogEntry) {
        let directory = fileURL.deletingLastPathComponent()
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

        rotateIfNeeded()

        guard let line = try? encoder.encode(entry), var lineWithNewline = String(data: line, encoding: .utf8) else {
            return
        }
        lineWithNewline += "\n"
        guard let data = lineWithNewline.data(using: .utf8) else { return }

        if !FileManager.default.fileExists(atPath: fileURL.path) {
            FileManager.default.createFile(atPath: fileURL.path, contents: nil)
        }
        guard let handle = try? FileHandle(forWritingTo: fileURL) else { return }
        defer { try? handle.close() }
        handle.seekToEndOfFile()
        handle.write(data)
    }

    /// No-op placeholder retained for API symmetry; ``record(_:)`` writes durably and
    /// immediately rather than buffering, so there is nothing to flush.
    public func flush() {}

    /// Reads the most recent `limit` entries back from disk, oldest of the returned set first.
    public func recentEntries(limit: Int) -> [AuditLogEntry] {
        guard let data = try? Data(contentsOf: fileURL), let text = String(data: data, encoding: .utf8) else {
            return []
        }
        let lines = text.split(separator: "\n", omittingEmptySubsequences: true)
        let entries = lines.compactMap { line -> AuditLogEntry? in
            guard let lineData = line.data(using: .utf8) else { return nil }
            return try? decoder.decode(AuditLogEntry.self, from: lineData)
        }
        return Array(entries.suffix(limit))
    }

    private func rotateIfNeeded() {
        guard let attributes = try? FileManager.default.attributesOfItem(atPath: fileURL.path),
              let size = attributes[.size] as? UInt64,
              size >= Self.rotationThresholdBytes else {
            return
        }
        let rotatedURL = fileURL.appendingPathExtension("1")
        try? FileManager.default.removeItem(at: rotatedURL)
        try? FileManager.default.moveItem(at: fileURL, to: rotatedURL)
    }
}
