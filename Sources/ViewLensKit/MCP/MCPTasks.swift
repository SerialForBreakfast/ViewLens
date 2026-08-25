import Foundation

public enum MCPTaskStatus: String, Codable, Sendable, Equatable {
    case working
    case inputRequired = "input_required"
    case completed
    case failed
    case cancelled

    var isTerminal: Bool {
        self == .completed || self == .failed || self == .cancelled
    }
}

public struct MCPTaskSnapshot: Encodable, Sendable {
    public let resultType: String
    public let taskId: String
    public let status: MCPTaskStatus
    public let statusMessage: String?
    public let createdAt: String
    public let lastUpdatedAt: String
    public let ttlMs: Int?
    public let pollIntervalMs: Int
    public let inputRequests: [String: JSONValue]?
    public let result: JSONValue?
    public let error: JSONRPCError?
    public let metadata: MCPResultMetadata

    enum CodingKeys: String, CodingKey {
        case resultType, taskId, status, statusMessage, createdAt, lastUpdatedAt
        case ttlMs, pollIntervalMs, inputRequests, result, error
        case metadata = "_meta"
    }

    public func nonvisualStatus(profile: NonvisualPresentationProfile = .speech) -> String {
        switch status {
        case .working:
            return statusMessage ?? "Task in progress."
        case .inputRequired:
            if let reqs = inputRequests, !reqs.isEmpty {
                let keys = reqs.keys.sorted().joined(separator: ", ")
                let detail = statusMessage.map { " \($0)" } ?? ""
                return "Input required for \(keys).\(detail)"
            }
            return "Input required: \(statusMessage ?? "Awaiting client decision.")"
        case .completed:
            let detail = statusMessage.map { " \($0)" } ?? ""
            return "Task completed.\(detail)"
        case .failed:
            return "Task failed: \(error?.message ?? statusMessage ?? "Unknown error.")"
        case .cancelled:
            return "Task was cancelled."
        }
    }
}

public struct MCPTaskAcknowledgement: Encodable, Sendable {
    public let resultType = "complete"
    public let metadata = MCPResultMetadata()

    enum CodingKeys: String, CodingKey {
        case resultType
        case metadata = "_meta"
    }

    public init() {}
}

actor MCPTaskStore {
    struct ExecutionDescriptor: Codable, Sendable, Equatable {
        let toolName: String
        let arguments: [String: JSONValue]
    }

    enum LookupError: Error, Sendable, Equatable {
        case notFound
        case expired
    }

    enum PersistenceError: Error, Sendable, Equatable {
        case unavailable
        case resultTooLarge
        case sensitiveInput
    }

    private struct Record: Codable, Sendable {
        let taskID: String
        var status: MCPTaskStatus
        var statusMessage: String?
        let createdAt: Date
        var lastUpdatedAt: Date
        let ttlMs: Int?
        let pollIntervalMs: Int
        let execution: ExecutionDescriptor
        var progress: Double
        var inputRequests: [String: JSONValue]
        var issuedInputKeys: Set<String>
        var result: JSONValue?
        var error: JSONRPCError?
        var cancellationRequested: Bool
    }

    private let directory: URL
    private let defaultTTLms: Int
    private let pollIntervalMs: Int
    private let maximumTasks: Int
    private let maximumRecordBytes: Int
    private let now: @Sendable () -> Date
    private var records: [String: Record]
    private var claimedExecutions: Set<String> = []
    private var expiredTaskIDs: Set<String> = []

    init(
        directory: URL = MCPTaskStore.defaultDirectory,
        ttlMs: Int = 3_600_000,
        pollIntervalMs: Int = 250,
        maximumTasks: Int = 100,
        maximumRecordBytes: Int = 5 * 1_024 * 1_024,
        now: @escaping @Sendable () -> Date = Date.init
    ) {
        self.directory = directory
        self.defaultTTLms = max(1_000, ttlMs)
        self.pollIntervalMs = max(100, pollIntervalMs)
        self.maximumTasks = max(1, maximumTasks)
        self.maximumRecordBytes = max(1_024, maximumRecordBytes)
        self.now = now
        self.records = Self.loadRecords(from: directory, maximumRecordBytes: maximumRecordBytes)
    }

    static var defaultDirectory: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        return base.appendingPathComponent("ViewLens/MCPTasks", isDirectory: true)
    }

    func create(toolName: String, arguments: [String: JSONValue]) throws -> MCPTaskSnapshot {
        guard !Self.containsSensitiveInput(arguments) else {
            throw PersistenceError.sensitiveInput
        }
        try prepareDirectory()
        purgeExpired()
        evictIfNeeded(adding: 1)

        let timestamp = now()
        let taskID = UUID().uuidString.lowercased()
        let record = Record(
            taskID: taskID,
            status: .working,
            statusMessage: "ViewLens task is queued for execution.",
            createdAt: timestamp,
            lastUpdatedAt: timestamp,
            ttlMs: defaultTTLms,
            pollIntervalMs: pollIntervalMs,
            execution: ExecutionDescriptor(toolName: toolName, arguments: arguments),
            progress: 0,
            inputRequests: [:],
            issuedInputKeys: [],
            result: nil,
            error: nil,
            cancellationRequested: false
        )
        records[taskID] = record
        do {
            try persist(record)
        } catch {
            records.removeValue(forKey: taskID)
            throw error
        }
        return snapshot(record, resultType: "task")
    }

    func snapshot(taskID: String) throws -> MCPTaskSnapshot {
        let record = try activeRecord(taskID: taskID)
        return snapshot(record, resultType: "complete")
    }

    func claimExecution(taskID: String) throws -> ExecutionDescriptor? {
        let record = try activeRecord(taskID: taskID)
        guard record.status == .working,
              !record.cancellationRequested,
              !claimedExecutions.contains(taskID) else { return nil }
        claimedExecutions.insert(taskID)
        return record.execution
    }

    func report(taskID: String, progress: Double, message: String) async -> Bool {
        guard var record = records[taskID],
              record.status == .working,
              !record.cancellationRequested else { return false }
        guard progress.isFinite, progress > record.progress else { return true }
        record.progress = min(progress, 100)
        record.statusMessage = "\(message) (\(Int(record.progress.rounded()))%)"
        record.lastUpdatedAt = now()
        records[taskID] = record
        try? persist(record)
        return true
    }

    func isCancellationRequested(taskID: String) -> Bool {
        guard let record = records[taskID] else { return true }
        return record.cancellationRequested || record.status == .cancelled
    }

    func complete(taskID: String, result: JSONValue) throws {
        guard var record = records[taskID], !record.status.isTerminal else {
            claimedExecutions.remove(taskID)
            return
        }
        if record.cancellationRequested {
            try markCancelled(&record)
            return
        }
        record.status = .completed
        record.statusMessage = "ViewLens task completed."
        record.lastUpdatedAt = now()
        record.progress = 100
        record.result = result
        record.error = nil
        record.inputRequests = [:]
        try persist(record)
        records[taskID] = record
        claimedExecutions.remove(taskID)
    }

    func fail(taskID: String, error: JSONRPCError) throws {
        guard var record = records[taskID], !record.status.isTerminal else {
            claimedExecutions.remove(taskID)
            return
        }
        if record.cancellationRequested {
            try markCancelled(&record)
            return
        }
        record.status = .failed
        record.statusMessage = error.message
        record.lastUpdatedAt = now()
        record.error = error
        record.result = nil
        record.inputRequests = [:]
        try persist(record)
        records[taskID] = record
        claimedExecutions.remove(taskID)
    }

    func requireInput(
        taskID: String,
        requests: [String: JSONValue],
        statusMessage: String
    ) throws {
        guard var record = records[taskID], !record.status.isTerminal else { return }
        let newKeys = Set(requests.keys)
        guard !newKeys.isEmpty,
              newKeys.isDisjoint(with: record.issuedInputKeys) else { return }
        record.status = .inputRequired
        record.statusMessage = statusMessage
        record.lastUpdatedAt = now()
        record.inputRequests.merge(requests) { existing, _ in existing }
        record.issuedInputKeys.formUnion(newKeys)
        try persist(record)
        records[taskID] = record
        claimedExecutions.remove(taskID)
    }

    func update(taskID: String, responses: [String: JSONValue]) throws {
        var record = try activeRecord(taskID: taskID)
        guard record.status == .inputRequired else { return }
        for key in responses.keys where record.inputRequests[key] != nil {
            record.inputRequests.removeValue(forKey: key)
        }
        if record.inputRequests.isEmpty {
            record.status = .working
            record.statusMessage = "Required input was accepted; execution may resume."
        }
        record.lastUpdatedAt = now()
        try persist(record)
        records[taskID] = record
    }

    func cancel(taskID: String) throws {
        var record = try activeRecord(taskID: taskID)
        guard !record.status.isTerminal else { return }
        record.cancellationRequested = true
        try markCancelled(&record)
    }

    private func markCancelled(_ record: inout Record) throws {
        record.status = .cancelled
        record.statusMessage = "ViewLens task was cancelled."
        record.lastUpdatedAt = now()
        record.result = nil
        record.error = nil
        record.inputRequests = [:]
        try persist(record)
        records[record.taskID] = record
        claimedExecutions.remove(record.taskID)
    }

    private func activeRecord(taskID: String) throws -> Record {
        purgeExpired()
        if expiredTaskIDs.contains(taskID) { throw LookupError.expired }
        guard let record = records[taskID] else { throw LookupError.notFound }
        return record
    }

    private func purgeExpired() {
        let current = now()
        for (taskID, record) in records {
            guard let ttlMs = record.ttlMs,
                  current.timeIntervalSince(record.createdAt) * 1_000 >= Double(ttlMs) else { continue }
            records.removeValue(forKey: taskID)
            claimedExecutions.remove(taskID)
            expiredTaskIDs.insert(taskID)
            try? FileManager.default.removeItem(at: fileURL(for: taskID))
        }
        if expiredTaskIDs.count > maximumTasks {
            expiredTaskIDs = Set(expiredTaskIDs.sorted().suffix(maximumTasks))
        }
    }

    private func evictIfNeeded(adding count: Int) {
        let overflow = max(0, records.count + count - maximumTasks)
        let evictions = records.values.sorted { $0.createdAt < $1.createdAt }.prefix(overflow)
        for record in evictions {
            records.removeValue(forKey: record.taskID)
            claimedExecutions.remove(record.taskID)
            try? FileManager.default.removeItem(at: fileURL(for: record.taskID))
        }
    }

    private func prepareDirectory() throws {
        do {
            if FileManager.default.fileExists(atPath: directory.path) {
                let values = try directory.resourceValues(forKeys: [.isDirectoryKey, .isSymbolicLinkKey])
                guard values.isDirectory == true, values.isSymbolicLink != true else {
                    throw PersistenceError.unavailable
                }
            }
            try FileManager.default.createDirectory(
                at: directory,
                withIntermediateDirectories: true,
                attributes: [.posixPermissions: 0o700]
            )
            try FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: directory.path)
        } catch let error as PersistenceError {
            throw error
        } catch {
            throw PersistenceError.unavailable
        }
    }

    private func persist(_ record: Record) throws {
        try prepareDirectory()
        let data = try JSONEncoder().encode(record)
        guard data.count <= maximumRecordBytes else { throw PersistenceError.resultTooLarge }
        do {
            let url = fileURL(for: record.taskID)
            try data.write(to: url, options: [.atomic])
            try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: url.path)
        } catch {
            throw PersistenceError.unavailable
        }
    }

    private func fileURL(for taskID: String) -> URL {
        directory.appendingPathComponent(taskID, isDirectory: false).appendingPathExtension("json")
    }

    private func snapshot(_ record: Record, resultType: String) -> MCPTaskSnapshot {
        MCPTaskSnapshot(
            resultType: resultType,
            taskId: record.taskID,
            status: record.status,
            statusMessage: record.statusMessage,
            createdAt: Self.dateString(record.createdAt),
            lastUpdatedAt: Self.dateString(record.lastUpdatedAt),
            ttlMs: record.ttlMs,
            pollIntervalMs: record.pollIntervalMs,
            inputRequests: record.status == .inputRequired ? record.inputRequests : nil,
            result: record.status == .completed ? record.result : nil,
            error: record.status == .failed ? record.error : nil,
            metadata: MCPResultMetadata()
        )
    }

    private static func dateString(_ date: Date) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter.string(from: date)
    }

    private static func loadRecords(from directory: URL, maximumRecordBytes: Int) -> [String: Record] {
        guard let directoryValues = try? directory.resourceValues(forKeys: [.isDirectoryKey, .isSymbolicLinkKey]),
              directoryValues.isDirectory == true,
              directoryValues.isSymbolicLink != true else { return [:] }
        guard let urls = try? FileManager.default.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: [.fileSizeKey],
            options: [.skipsHiddenFiles]
        ) else { return [:] }
        var loaded: [String: Record] = [:]
        for url in urls where url.pathExtension == "json" {
            let size = (try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? Int.max
            guard size <= maximumRecordBytes,
                  let data = try? Data(contentsOf: url),
                  let record = try? JSONDecoder().decode(Record.self, from: data),
                  UUID(uuidString: record.taskID) != nil else { continue }
            loaded[record.taskID] = record
        }
        return loaded
    }

    private static func containsSensitiveInput(_ arguments: [String: JSONValue]) -> Bool {
        let blockedFragments = ["authorization", "credential", "password", "secret", "api_key", "apikey", "access_token", "refresh_token"]
        for (key, value) in arguments {
            let normalized = key.lowercased()
            if blockedFragments.contains(where: normalized.contains) { return true }
            if case .object(let nested) = value, containsSensitiveInput(nested) { return true }
            if case .array(let values) = value,
               values.contains(where: { element in
                   guard case .object(let nested) = element else { return false }
                   return containsSensitiveInput(nested)
               }) { return true }
        }
        return false
    }
}
