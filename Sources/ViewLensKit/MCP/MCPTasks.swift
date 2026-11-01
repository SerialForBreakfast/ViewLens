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

/// Detailed execution phase extending MCPTaskStatus without breaking handle/TTL wire contracts (LEARN-06).
public enum MCPTaskExecutionPhase: String, Codable, Sendable, Equatable, Hashable {
    case queued
    case running
    case inputRequired = "input_required"
    case cleanupPending = "cleanup_pending"
    case completed
    case failed
    case cancelled
    case expired
}

/// Receipt recording cleanup outcome and explicitly prohibiting automatic replay on timeout/interruption (LEARN-06).
public struct MCPTaskCleanupReceipt: Codable, Sendable, Equatable, Hashable {
    public let cleanupRequired: Bool
    public let cleanupCompleted: Bool
    public let cleanupFailureReason: String?
    public let providerConfirmedStopped: Bool
    public let automaticReplayAuthorized: Bool
    public let recordedAt: String

    public init(
        cleanupRequired: Bool,
        cleanupCompleted: Bool,
        cleanupFailureReason: String? = nil,
        providerConfirmedStopped: Bool,
        automaticReplayAuthorized: Bool = false,
        recordedAt: String
    ) {
        self.cleanupRequired = cleanupRequired
        self.cleanupCompleted = cleanupCompleted
        self.cleanupFailureReason = cleanupFailureReason
        self.providerConfirmedStopped = providerConfirmedStopped
        self.automaticReplayAuthorized = automaticReplayAuthorized
        self.recordedAt = recordedAt
    }
}

/// Terminal and mid-flight evidence preserving operation/generation identity, late callback rejections, and original failure (LEARN-06).
public struct MCPTaskTerminalEvidence: Codable, Sendable, Equatable, Hashable {
    public let operationID: String
    public let generationID: UInt64
    public let targetKey: String?
    public let phase: MCPTaskExecutionPhase
    public let originalFailureReason: String?
    public let timedOut: Bool
    public let lateCallbacksRejected: Int
    public let cleanupReceipt: MCPTaskCleanupReceipt?

    public init(
        operationID: String,
        generationID: UInt64,
        targetKey: String? = nil,
        phase: MCPTaskExecutionPhase,
        originalFailureReason: String? = nil,
        timedOut: Bool = false,
        lateCallbacksRejected: Int = 0,
        cleanupReceipt: MCPTaskCleanupReceipt? = nil
    ) {
        self.operationID = operationID
        self.generationID = generationID
        self.targetKey = targetKey
        self.phase = phase
        self.originalFailureReason = originalFailureReason
        self.timedOut = timedOut
        self.lateCallbacksRejected = lateCallbacksRejected
        self.cleanupReceipt = cleanupReceipt
    }
}

public struct MCPTaskSnapshot: Encodable, Sendable {
    public let resultType: String
    public let taskId: String
    public let status: MCPTaskStatus
    public let phase: MCPTaskExecutionPhase
    public let operationID: String
    public let generationID: UInt64
    public let targetKey: String?
    public let statusMessage: String?
    public let createdAt: String
    public let lastUpdatedAt: String
    public let ttlMs: Int?
    public let pollIntervalMs: Int
    public let inputRequests: [String: JSONValue]?
    public let result: JSONValue?
    public let error: JSONRPCError?
    public let terminalEvidence: MCPTaskTerminalEvidence
    public let metadata: MCPResultMetadata

    enum CodingKeys: String, CodingKey {
        case resultType, taskId, status
        case statusMessage, createdAt, lastUpdatedAt
        case ttlMs, pollIntervalMs, inputRequests, result, error
        case metadata = "_meta"
    }

    public init(
        resultType: String,
        taskId: String,
        status: MCPTaskStatus,
        phase: MCPTaskExecutionPhase? = nil,
        operationID: String = "op-default",
        generationID: UInt64 = 1,
        targetKey: String? = nil,
        statusMessage: String? = nil,
        createdAt: String,
        lastUpdatedAt: String,
        ttlMs: Int? = nil,
        pollIntervalMs: Int,
        inputRequests: [String: JSONValue]? = nil,
        result: JSONValue? = nil,
        error: JSONRPCError? = nil,
        terminalEvidence: MCPTaskTerminalEvidence? = nil,
        metadata: MCPResultMetadata = MCPResultMetadata()
    ) {
        let resolvedPhase = phase ?? (status == .working ? .running : MCPTaskExecutionPhase(rawValue: status.rawValue) ?? .running)
        self.resultType = resultType
        self.taskId = taskId
        self.status = status
        self.phase = resolvedPhase
        self.operationID = operationID
        self.generationID = generationID
        self.targetKey = targetKey
        self.statusMessage = statusMessage
        self.createdAt = createdAt
        self.lastUpdatedAt = lastUpdatedAt
        self.ttlMs = ttlMs
        self.pollIntervalMs = pollIntervalMs
        self.inputRequests = inputRequests
        self.result = result
        self.error = error
        self.terminalEvidence = terminalEvidence ?? MCPTaskTerminalEvidence(
            operationID: operationID,
            generationID: generationID,
            targetKey: targetKey,
            phase: resolvedPhase
        )
        self.metadata = metadata
    }

    public func nonvisualStatus(profile: NonvisualPresentationProfile = .speech) -> String {
        if phase == .cleanupPending {
            return statusMessage ?? "Task cleanup is pending; underlying provider has not confirmed stop."
        }
        if phase == .queued {
            return statusMessage ?? "Task is queued for execution."
        }
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

public actor MCPTaskStore {
    public struct ExecutionDescriptor: Codable, Sendable, Equatable {
        public let toolName: String
        public let arguments: [String: JSONValue]
        public let operationID: String
        public let generationID: UInt64
        public let targetKey: String?

        public init(
            toolName: String,
            arguments: [String: JSONValue],
            operationID: String = UUID().uuidString.lowercased(),
            generationID: UInt64 = 1,
            targetKey: String? = nil
        ) {
            self.toolName = toolName
            self.arguments = arguments
            self.operationID = operationID
            self.generationID = generationID
            self.targetKey = targetKey
        }
    }

    public enum LookupError: Error, Sendable, Equatable {
        case notFound
        case expired
    }

    public enum PersistenceError: Error, Sendable, Equatable {
        case unavailable
        case resultTooLarge
        case sensitiveInput
    }

    /// Distinguishes target/renderer contention and resource limits from a stalled target (LEARN-06).
    public enum AdmissionError: Error, Sendable, Equatable {
        case targetContention(targetKey: String, ownerTaskID: String)
        case pendingCleanup(targetKey: String, taskID: String)
        case resourceLimitReached(activeCount: Int, limit: Int)
    }

    private struct Record: Codable, Sendable {
        let taskID: String
        var status: MCPTaskStatus
        var phase: MCPTaskExecutionPhase
        var operationID: String
        var generationID: UInt64
        var targetKey: String?
        var requiresCleanup: Bool
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
        var originalFailureReason: String?
        var timedOut: Bool
        var lateCallbacksRejected: Int
        var cleanupReceipt: MCPTaskCleanupReceipt?

        enum CodingKeys: String, CodingKey {
            case taskID, status, phase, operationID, generationID, targetKey, requiresCleanup
            case statusMessage, createdAt, lastUpdatedAt, ttlMs, pollIntervalMs, execution
            case progress, inputRequests, issuedInputKeys, result, error, cancellationRequested
            case originalFailureReason, timedOut, lateCallbacksRejected, cleanupReceipt
        }

        init(
            taskID: String,
            status: MCPTaskStatus,
            phase: MCPTaskExecutionPhase,
            operationID: String,
            generationID: UInt64,
            targetKey: String?,
            requiresCleanup: Bool,
            statusMessage: String?,
            createdAt: Date,
            lastUpdatedAt: Date,
            ttlMs: Int?,
            pollIntervalMs: Int,
            execution: ExecutionDescriptor,
            progress: Double,
            inputRequests: [String: JSONValue],
            issuedInputKeys: Set<String>,
            result: JSONValue?,
            error: JSONRPCError?,
            cancellationRequested: Bool,
            originalFailureReason: String? = nil,
            timedOut: Bool = false,
            lateCallbacksRejected: Int = 0,
            cleanupReceipt: MCPTaskCleanupReceipt? = nil
        ) {
            self.taskID = taskID
            self.status = status
            self.phase = phase
            self.operationID = operationID
            self.generationID = generationID
            self.targetKey = targetKey
            self.requiresCleanup = requiresCleanup
            self.statusMessage = statusMessage
            self.createdAt = createdAt
            self.lastUpdatedAt = lastUpdatedAt
            self.ttlMs = ttlMs
            self.pollIntervalMs = pollIntervalMs
            self.execution = execution
            self.progress = progress
            self.inputRequests = inputRequests
            self.issuedInputKeys = issuedInputKeys
            self.result = result
            self.error = error
            self.cancellationRequested = cancellationRequested
            self.originalFailureReason = originalFailureReason
            self.timedOut = timedOut
            self.lateCallbacksRejected = lateCallbacksRejected
            self.cleanupReceipt = cleanupReceipt
        }

        init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            self.taskID = try c.decode(String.self, forKey: .taskID)
            let decodedStatus = try c.decode(MCPTaskStatus.self, forKey: .status)
            self.status = decodedStatus
            self.phase = try c.decodeIfPresent(MCPTaskExecutionPhase.self, forKey: .phase) ?? (decodedStatus == .working ? .queued : MCPTaskExecutionPhase(rawValue: decodedStatus.rawValue) ?? .queued)
            self.operationID = try c.decodeIfPresent(String.self, forKey: .operationID) ?? UUID().uuidString.lowercased()
            self.generationID = try c.decodeIfPresent(UInt64.self, forKey: .generationID) ?? 1
            self.targetKey = try c.decodeIfPresent(String.self, forKey: .targetKey)
            self.requiresCleanup = try c.decodeIfPresent(Bool.self, forKey: .requiresCleanup) ?? false
            self.statusMessage = try c.decodeIfPresent(String.self, forKey: .statusMessage)
            self.createdAt = try c.decode(Date.self, forKey: .createdAt)
            self.lastUpdatedAt = try c.decode(Date.self, forKey: .lastUpdatedAt)
            self.ttlMs = try c.decodeIfPresent(Int.self, forKey: .ttlMs)
            self.pollIntervalMs = try c.decode(Int.self, forKey: .pollIntervalMs)
            self.execution = try c.decode(ExecutionDescriptor.self, forKey: .execution)
            self.progress = try c.decode(Double.self, forKey: .progress)
            self.inputRequests = try c.decode([String: JSONValue].self, forKey: .inputRequests)
            self.issuedInputKeys = try c.decode(Set<String>.self, forKey: .issuedInputKeys)
            self.result = try c.decodeIfPresent(JSONValue.self, forKey: .result)
            self.error = try c.decodeIfPresent(JSONRPCError.self, forKey: .error)
            self.cancellationRequested = try c.decode(Bool.self, forKey: .cancellationRequested)
            self.originalFailureReason = try c.decodeIfPresent(String.self, forKey: .originalFailureReason)
            self.timedOut = try c.decodeIfPresent(Bool.self, forKey: .timedOut) ?? false
            self.lateCallbacksRejected = try c.decodeIfPresent(Int.self, forKey: .lateCallbacksRejected) ?? 0
            self.cleanupReceipt = try c.decodeIfPresent(MCPTaskCleanupReceipt.self, forKey: .cleanupReceipt)
        }
    }

    private let directory: URL
    private let defaultTTLms: Int
    private let pollIntervalMs: Int
    private let maximumTasks: Int
    private let maximumConcurrentActiveTasks: Int
    private let maximumRecordBytes: Int
    private let now: @Sendable () -> Date
    private var records: [String: Record]
    private var claimedExecutions: Set<String> = []
    private var expiredTaskIDs: Set<String> = []
    private var targetOwners: [String: String] = [:]
    private var pendingCleanupTargets: [String: String] = [:]

    public init(
        directory: URL = MCPTaskStore.defaultDirectory,
        ttlMs: Int = 3_600_000,
        pollIntervalMs: Int = 250,
        maximumTasks: Int = 100,
        maximumConcurrentActiveTasks: Int = 16,
        maximumRecordBytes: Int = 5 * 1_024 * 1_024,
        now: @escaping @Sendable () -> Date = Date.init
    ) {
        self.directory = directory
        self.defaultTTLms = max(1_000, ttlMs)
        self.pollIntervalMs = max(100, pollIntervalMs)
        self.maximumTasks = max(1, maximumTasks)
        self.maximumConcurrentActiveTasks = max(1, maximumConcurrentActiveTasks)
        self.maximumRecordBytes = max(1_024, maximumRecordBytes)
        self.now = now
        self.records = Self.loadRecords(from: directory, maximumRecordBytes: maximumRecordBytes)
    }

    public static var defaultDirectory: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        return base.appendingPathComponent("ViewLens/MCPTasks", isDirectory: true)
    }

    public func create(toolName: String, arguments: [String: JSONValue]) throws -> MCPTaskSnapshot {
        try createInternal(
            toolName: toolName,
            arguments: arguments,
            targetKey: nil,
            requiresCleanup: false,
            enforceAdmission: false
        )
    }

    /// Admits work through shared renderer/target ownership and active concurrency limits (LEARN-06).
    public func admitAndCreate(
        toolName: String,
        arguments: [String: JSONValue],
        targetKey: String?,
        requiresCleanup: Bool = false
    ) throws -> MCPTaskSnapshot {
        try createInternal(
            toolName: toolName,
            arguments: arguments,
            targetKey: targetKey,
            requiresCleanup: requiresCleanup,
            enforceAdmission: true
        )
    }

    private func createInternal(
        toolName: String,
        arguments: [String: JSONValue],
        targetKey: String?,
        requiresCleanup: Bool,
        enforceAdmission: Bool
    ) throws -> MCPTaskSnapshot {
        guard !Self.containsSensitiveInput(arguments) else {
            throw PersistenceError.sensitiveInput
        }
        try prepareDirectory()
        purgeExpired()

        if enforceAdmission {
            if let targetKey {
                if let cleanupOwner = pendingCleanupTargets[targetKey] {
                    throw AdmissionError.pendingCleanup(targetKey: targetKey, taskID: cleanupOwner)
                }
                if let activeOwner = targetOwners[targetKey],
                   let ownerRecord = records[activeOwner],
                   !ownerRecord.status.isTerminal {
                    throw AdmissionError.targetContention(targetKey: targetKey, ownerTaskID: activeOwner)
                }
            }
            let activeCount = records.values.filter { !$0.status.isTerminal }.count
            if activeCount >= maximumConcurrentActiveTasks {
                throw AdmissionError.resourceLimitReached(activeCount: activeCount, limit: maximumConcurrentActiveTasks)
            }
        }

        evictIfNeeded(adding: 1)

        let timestamp = now()
        let taskID = UUID().uuidString.lowercased()
        let opID = UUID().uuidString.lowercased()
        let descriptor = ExecutionDescriptor(
            toolName: toolName,
            arguments: arguments,
            operationID: opID,
            generationID: 1,
            targetKey: targetKey
        )
        let record = Record(
            taskID: taskID,
            status: .working,
            phase: .queued,
            operationID: opID,
            generationID: 1,
            targetKey: targetKey,
            requiresCleanup: requiresCleanup,
            statusMessage: "ViewLens task is queued for execution.",
            createdAt: timestamp,
            lastUpdatedAt: timestamp,
            ttlMs: defaultTTLms,
            pollIntervalMs: pollIntervalMs,
            execution: descriptor,
            progress: 0,
            inputRequests: [:],
            issuedInputKeys: [],
            result: nil,
            error: nil,
            cancellationRequested: false
        )
        records[taskID] = record
        if let targetKey {
            targetOwners[targetKey] = taskID
        }
        do {
            try persist(record)
        } catch {
            records.removeValue(forKey: taskID)
            if let targetKey, targetOwners[targetKey] == taskID {
                targetOwners.removeValue(forKey: targetKey)
            }
            throw error
        }
        return snapshot(record, resultType: "task")
    }

    public func snapshot(taskID: String) throws -> MCPTaskSnapshot {
        let record = try activeRecord(taskID: taskID)
        return snapshot(record, resultType: "complete")
    }

    public func claimExecution(taskID: String) throws -> ExecutionDescriptor? {
        var record = try activeRecord(taskID: taskID)
        guard record.status == .working,
              record.phase != .cleanupPending,
              !record.cancellationRequested,
              !record.timedOut,
              !claimedExecutions.contains(taskID) else { return nil }
        claimedExecutions.insert(taskID)
        record.phase = .running
        record.statusMessage = "ViewLens task is running."
        record.lastUpdatedAt = now()
        records[taskID] = record
        try? persist(record)
        return ExecutionDescriptor(
            toolName: record.execution.toolName,
            arguments: record.execution.arguments,
            operationID: record.operationID,
            generationID: record.generationID,
            targetKey: record.targetKey
        )
    }

    public func report(
        taskID: String,
        generationID: UInt64? = nil,
        progress: Double,
        message: String
    ) async -> Bool {
        guard var record = records[taskID] else { return false }
        if let generationID, generationID != record.generationID {
            record.lateCallbacksRejected += 1
            records[taskID] = record
            try? persist(record)
            return false
        }
        guard record.status == .working,
              record.phase != .cleanupPending,
              !record.cancellationRequested,
              !record.timedOut else {
            record.lateCallbacksRejected += 1
            records[taskID] = record
            try? persist(record)
            return false
        }
        guard progress.isFinite, progress > record.progress else { return true }
        record.phase = .running
        record.progress = min(progress, 100)
        record.statusMessage = "\(message) (\(Int(record.progress.rounded()))%)"
        record.lastUpdatedAt = now()
        records[taskID] = record
        try? persist(record)
        return true
    }

    public func isCancellationRequested(taskID: String) -> Bool {
        guard let record = records[taskID] else { return true }
        return record.cancellationRequested || record.status == .cancelled || record.timedOut || record.phase == .cleanupPending
    }

    @discardableResult
    public func complete(taskID: String, generationID: UInt64? = nil, result: JSONValue) throws -> Bool {
        guard var record = records[taskID] else {
            claimedExecutions.remove(taskID)
            return false
        }
        if let generationID, generationID != record.generationID {
            record.lateCallbacksRejected += 1
            try persist(record)
            records[taskID] = record
            return false
        }
        if record.status.isTerminal || record.timedOut || record.phase == .cleanupPending {
            record.lateCallbacksRejected += 1
            try persist(record)
            records[taskID] = record
            claimedExecutions.remove(taskID)
            return false
        }
        if record.cancellationRequested {
            try markCancelled(&record)
            return false
        }
        record.status = .completed
        record.phase = .completed
        record.statusMessage = "ViewLens task completed."
        record.lastUpdatedAt = now()
        record.progress = 100
        record.result = result
        record.error = nil
        record.inputRequests = [:]
        releaseOwnership(for: record)
        try persist(record)
        records[taskID] = record
        claimedExecutions.remove(taskID)
        return true
    }

    public func fail(taskID: String, generationID: UInt64? = nil, error: JSONRPCError) throws {
        guard var record = records[taskID] else {
            claimedExecutions.remove(taskID)
            return
        }
        if let generationID, generationID != record.generationID {
            record.lateCallbacksRejected += 1
            try persist(record)
            records[taskID] = record
            return
        }
        if record.status.isTerminal {
            record.lateCallbacksRejected += 1
            try persist(record)
            records[taskID] = record
            claimedExecutions.remove(taskID)
            return
        }
        if record.cancellationRequested {
            try markCancelled(&record)
            return
        }
        if record.originalFailureReason == nil {
            record.originalFailureReason = error.message
        }
        record.status = .failed
        record.phase = .failed
        record.statusMessage = error.message
        record.lastUpdatedAt = now()
        record.error = error
        record.result = nil
        record.inputRequests = [:]
        releaseOwnership(for: record)
        try persist(record)
        records[taskID] = record
        claimedExecutions.remove(taskID)
    }

    /// Records a timeout without assuming the underlying build/render/provider stopped and without authorizing automatic replay (LEARN-06).
    public func recordTimeout(
        taskID: String,
        reason: String = "Operation timed out; underlying build/render/provider is not assumed stopped and automatic action replay is prohibited."
    ) throws -> MCPTaskSnapshot {
        var record = try activeRecord(taskID: taskID)
        record.generationID += 1
        record.timedOut = true
        if record.originalFailureReason == nil {
            record.originalFailureReason = reason
        }
        record.phase = .cleanupPending
        record.statusMessage = reason
        record.lastUpdatedAt = now()
        record.cleanupReceipt = MCPTaskCleanupReceipt(
            cleanupRequired: true,
            cleanupCompleted: false,
            cleanupFailureReason: nil,
            providerConfirmedStopped: false,
            automaticReplayAuthorized: false,
            recordedAt: Self.dateString(record.lastUpdatedAt)
        )
        if let targetKey = record.targetKey {
            pendingCleanupTargets[targetKey] = taskID
        }
        claimedExecutions.remove(taskID)
        try persist(record)
        records[taskID] = record
        return snapshot(record, resultType: "complete")
    }

    /// Completes or records failure of pending cleanup while preserving the original failure reason and receipt (LEARN-06).
    public func completeCleanup(
        taskID: String,
        succeeded: Bool,
        cleanupFailureReason: String? = nil
    ) throws -> MCPTaskSnapshot {
        var record = try activeRecord(taskID: taskID)
        let timestamp = now()
        record.lastUpdatedAt = timestamp
        record.cleanupReceipt = MCPTaskCleanupReceipt(
            cleanupRequired: true,
            cleanupCompleted: succeeded,
            cleanupFailureReason: cleanupFailureReason,
            providerConfirmedStopped: succeeded,
            automaticReplayAuthorized: false,
            recordedAt: Self.dateString(timestamp)
        )

        if succeeded {
            if let targetKey = record.targetKey {
                if pendingCleanupTargets[targetKey] == taskID {
                    pendingCleanupTargets.removeValue(forKey: targetKey)
                }
                if targetOwners[targetKey] == taskID {
                    targetOwners.removeValue(forKey: targetKey)
                }
            }
            if record.cancellationRequested {
                record.status = .cancelled
                record.phase = .cancelled
                record.statusMessage = "ViewLens task was cancelled and cleanup completed."
            } else {
                let msg = record.originalFailureReason ?? "Operation failed and cleanup completed."
                record.status = .failed
                record.phase = .failed
                record.statusMessage = msg
                record.error = JSONRPCError(code: -32000, message: msg)
            }
        } else {
            let orig = record.originalFailureReason ?? "Operation interrupted"
            let cleanErr = cleanupFailureReason ?? "Cleanup failed"
            let combined = "\(orig) (Cleanup failed: \(cleanErr))"
            record.status = .failed
            record.phase = .cleanupPending
            record.statusMessage = combined
            record.error = JSONRPCError(code: -32000, message: combined)
        }

        try persist(record)
        records[taskID] = record
        return snapshot(record, resultType: "complete")
    }

    public func requireInput(
        taskID: String,
        requests: [String: JSONValue],
        statusMessage: String
    ) throws {
        guard var record = records[taskID], !record.status.isTerminal else { return }
        let newKeys = Set(requests.keys)
        guard !newKeys.isEmpty,
              newKeys.isDisjoint(with: record.issuedInputKeys) else { return }
        record.status = .inputRequired
        record.phase = .inputRequired
        record.statusMessage = statusMessage
        record.lastUpdatedAt = now()
        record.inputRequests.merge(requests) { existing, _ in existing }
        record.issuedInputKeys.formUnion(newKeys)
        try persist(record)
        records[taskID] = record
        claimedExecutions.remove(taskID)
    }

    public func update(taskID: String, responses: [String: JSONValue]) throws {
        var record = try activeRecord(taskID: taskID)
        guard record.status == .inputRequired else { return }
        for key in responses.keys where record.inputRequests[key] != nil {
            record.inputRequests.removeValue(forKey: key)
        }
        if record.inputRequests.isEmpty {
            record.status = .working
            record.phase = .queued
            record.generationID += 1
            record.statusMessage = "Required input was accepted; execution may resume."
        }
        record.lastUpdatedAt = now()
        try persist(record)
        records[taskID] = record
    }

    public func cancel(taskID: String) throws {
        var record = try activeRecord(taskID: taskID)
        guard !record.status.isTerminal else { return }
        record.cancellationRequested = true
        record.generationID += 1
        if record.requiresCleanup && record.phase == .running {
            record.phase = .cleanupPending
            record.statusMessage = "Cancellation requested; awaiting target cleanup."
            record.lastUpdatedAt = now()
            record.cleanupReceipt = MCPTaskCleanupReceipt(
                cleanupRequired: true,
                cleanupCompleted: false,
                cleanupFailureReason: nil,
                providerConfirmedStopped: false,
                automaticReplayAuthorized: false,
                recordedAt: Self.dateString(record.lastUpdatedAt)
            )
            if let targetKey = record.targetKey {
                pendingCleanupTargets[targetKey] = taskID
            }
            claimedExecutions.remove(taskID)
            try persist(record)
            records[taskID] = record
        } else {
            try markCancelled(&record)
        }
    }

    private func markCancelled(_ record: inout Record) throws {
        record.status = .cancelled
        record.phase = .cancelled
        record.statusMessage = "ViewLens task was cancelled."
        record.lastUpdatedAt = now()
        record.result = nil
        record.error = nil
        record.inputRequests = [:]
        releaseOwnership(for: record)
        try persist(record)
        records[record.taskID] = record
        claimedExecutions.remove(record.taskID)
    }

    private func releaseOwnership(for record: Record) {
        guard let targetKey = record.targetKey else { return }
        if targetOwners[targetKey] == record.taskID {
            targetOwners.removeValue(forKey: targetKey)
        }
        if pendingCleanupTargets[targetKey] == record.taskID && record.cleanupReceipt?.cleanupCompleted != false {
            pendingCleanupTargets.removeValue(forKey: targetKey)
        }
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
            releaseOwnership(for: record)
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
            releaseOwnership(for: record)
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
        let evidence = MCPTaskTerminalEvidence(
            operationID: record.operationID,
            generationID: record.generationID,
            targetKey: record.targetKey,
            phase: record.phase,
            originalFailureReason: record.originalFailureReason,
            timedOut: record.timedOut,
            lateCallbacksRejected: record.lateCallbacksRejected,
            cleanupReceipt: record.cleanupReceipt
        )
        return MCPTaskSnapshot(
            resultType: resultType,
            taskId: record.taskID,
            status: record.status,
            phase: record.phase,
            operationID: record.operationID,
            generationID: record.generationID,
            targetKey: record.targetKey,
            statusMessage: record.statusMessage,
            createdAt: Self.dateString(record.createdAt),
            lastUpdatedAt: Self.dateString(record.lastUpdatedAt),
            ttlMs: record.ttlMs,
            pollIntervalMs: record.pollIntervalMs,
            inputRequests: record.status == .inputRequired ? record.inputRequests : nil,
            result: record.status == .completed ? record.result : nil,
            error: record.status == .failed ? record.error : nil,
            terminalEvidence: evidence,
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
