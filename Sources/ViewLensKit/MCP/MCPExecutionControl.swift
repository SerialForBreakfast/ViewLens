import Foundation

enum MCPProgressToken: Codable, Sendable, Equatable, Hashable {
    case string(String)
    case int(Int)

    init?(jsonValue: JSONValue) {
        if let string = jsonValue.stringValue {
            self = .string(string)
        } else if let number = jsonValue.doubleValue,
                  number.isFinite,
                  number.rounded() == number,
                  number >= Double(Int.min),
                  number <= Double(Int.max) {
            self = .int(Int(number))
        } else {
            return nil
        }
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let value = try? container.decode(Int.self) {
            self = .int(value)
        } else if let value = try? container.decode(String.self) {
            self = .string(value)
        } else {
            throw DecodingError.typeMismatch(
                MCPProgressToken.self,
                DecodingError.Context(codingPath: decoder.codingPath, debugDescription: "Expected an integer or string progress token")
            )
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .string(let value): try container.encode(value)
        case .int(let value): try container.encode(value)
        }
    }
}

private struct MCPProgressNotification: Encodable, Sendable {
    struct Parameters: Encodable, Sendable {
        let progressToken: MCPProgressToken
        let progress: Double
        let total: Double?
        let message: String?
    }

    let jsonrpc = "2.0"
    let method = "notifications/progress"
    let params: Parameters
}

actor MCPProtocolRuntime {
    typealias NotificationSink = @Sendable (Data) async -> Void

    enum BeginError: Error, Sendable, Equatable {
        case duplicateRequestID
        case duplicateProgressToken
    }

    private struct Operation: Sendable {
        let progressToken: MCPProgressToken?
        var lastProgress: Double?
        var cancelled = false
        var cancellationReason: String?
    }

    private let maximumBufferedNotifications = 512
    private var operations: [JSONRPCRequest.RequestID: Operation] = [:]
    private var progressTokenOwners: [MCPProgressToken: JSONRPCRequest.RequestID] = [:]
    private var bufferedNotifications: [Data] = []
    private var notificationSink: NotificationSink?

    func setNotificationSink(_ sink: NotificationSink?) {
        notificationSink = sink
    }

    func begin(requestID: JSONRPCRequest.RequestID, progressToken: MCPProgressToken?) -> BeginError? {
        guard operations[requestID] == nil else { return .duplicateRequestID }
        if let progressToken, progressTokenOwners[progressToken] != nil {
            return .duplicateProgressToken
        }
        operations[requestID] = Operation(progressToken: progressToken)
        if let progressToken { progressTokenOwners[progressToken] = requestID }
        return nil
    }

    func cancel(requestID: JSONRPCRequest.RequestID, reason: String?) {
        guard var operation = operations[requestID] else { return }
        operation.cancelled = true
        operation.cancellationReason = reason
        operations[requestID] = operation
    }

    func isCancelled(requestID: JSONRPCRequest.RequestID) -> Bool {
        operations[requestID]?.cancelled ?? false
    }

    @discardableResult
    func report(
        requestID: JSONRPCRequest.RequestID,
        progress: Double,
        total: Double?,
        message: String?
    ) async -> Bool {
        guard var operation = operations[requestID], !operation.cancelled else { return false }
        guard let token = operation.progressToken else { return true }
        guard progress.isFinite,
              total?.isFinite != false,
              operation.lastProgress.map({ progress > $0 }) ?? true else {
            return true
        }

        operation.lastProgress = progress
        operations[requestID] = operation
        let notification = MCPProgressNotification(
            params: .init(progressToken: token, progress: progress, total: total, message: message)
        )
        guard let data = try? JSONEncoder().encode(notification) else { return true }
        bufferedNotifications.append(data)
        if bufferedNotifications.count > maximumBufferedNotifications {
            bufferedNotifications.removeFirst(bufferedNotifications.count - maximumBufferedNotifications)
        }
        if let notificationSink { await notificationSink(data) }
        return !(operations[requestID]?.cancelled ?? true)
    }

    func finish(requestID: JSONRPCRequest.RequestID) -> Bool {
        guard let operation = operations.removeValue(forKey: requestID) else { return false }
        if let token = operation.progressToken { progressTokenOwners.removeValue(forKey: token) }
        return operation.cancelled
    }

    func drainNotifications() -> [Data] {
        defer { bufferedNotifications.removeAll(keepingCapacity: true) }
        return bufferedNotifications
    }
}

struct MCPExecutionContext: Sendable {
    private let requestID: JSONRPCRequest.RequestID?
    private let runtime: MCPProtocolRuntime?
    private let taskID: String?
    private let taskStore: MCPTaskStore?

    init(requestID: JSONRPCRequest.RequestID, runtime: MCPProtocolRuntime) {
        self.requestID = requestID
        self.runtime = runtime
        self.taskID = nil
        self.taskStore = nil
    }

    init(taskID: String, taskStore: MCPTaskStore) {
        self.requestID = nil
        self.runtime = nil
        self.taskID = taskID
        self.taskStore = taskStore
    }

    func checkpoint() async -> Bool {
        guard !Task.isCancelled else { return false }
        if let requestID, let runtime {
            return !(await runtime.isCancelled(requestID: requestID))
        }
        if let taskID, let taskStore {
            return !(await taskStore.isCancellationRequested(taskID: taskID))
        }
        return false
    }

    func report(progress: Double, total: Double = 100, message: String) async -> Bool {
        guard await checkpoint() else { return false }
        if let requestID, let runtime {
            return await runtime.report(
                requestID: requestID,
                progress: progress,
                total: total,
                message: message
            )
        }
        if let taskID, let taskStore {
            return await taskStore.report(taskID: taskID, progress: progress, message: message)
        }
        return false
    }
}

actor MCPOutputWriter {
    private let handle: FileHandle

    init(handle: FileHandle) {
        self.handle = handle
    }

    func write(_ data: Data) {
        handle.write(data)
        handle.write(Data("\n".utf8))
    }
}
