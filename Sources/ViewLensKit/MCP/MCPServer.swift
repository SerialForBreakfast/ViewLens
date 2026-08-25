import Foundation
import CoreGraphics
import ImageIO

private struct ScreenshotAuditExecution: Sendable {
    let jsonText: String
    let success: Bool
    let report: AuditReport?
    let error: MCPStructuredError?
    let artifacts: [MCPEvidenceEnvelope.Artifact]
    let warnings: [String]
}

private struct MatrixAuditExecution: Sendable {
    let jsonText: String
    let passed: Bool
    let report: MatrixAuditReport?
    let error: MCPStructuredError?
}

/// Pure Swift Model Context Protocol (MCP) Server operating over standard input/output (stdio).
public final class MCPServer: Sendable {
    private let resourceStore: MCPResourceStore
    private let protocolRuntime: MCPProtocolRuntime
    private let taskStore: MCPTaskStore
    private let sessionStore: RuntimeSessionStore

    public init() {
        self.resourceStore = MCPResourceStore()
        self.protocolRuntime = MCPProtocolRuntime()
        self.taskStore = MCPTaskStore()
        self.sessionStore = RuntimeSessionStore()
    }

    init(
        resourceStore: MCPResourceStore,
        protocolRuntime: MCPProtocolRuntime = MCPProtocolRuntime(),
        taskStore: MCPTaskStore = MCPTaskStore(),
        sessionStore: RuntimeSessionStore = RuntimeSessionStore()
    ) {
        self.resourceStore = resourceStore
        self.protocolRuntime = protocolRuntime
        self.taskStore = taskStore
        self.sessionStore = sessionStore
    }

    /// Starts the blocking stdio JSON-RPC request loop.
    public func start() async {
        let inputHandle = FileHandle.standardInput
        let writer = MCPOutputWriter(handle: .standardOutput)
        await protocolRuntime.setNotificationSink { data in
            await writer.write(data)
        }

        await withTaskGroup(of: Void.self) { group in
            while true {
                guard let lineData = readLineData(from: inputHandle) else {
                    break // EOF on stdin (parent agent closed connection)
                }

                guard !lineData.isEmpty else { continue }

                do {
                    let request = try JSONDecoder().decode(JSONRPCRequest.self, from: lineData)
                    group.addTask { [self] in
                        if let responseData = await handleRequest(request) {
                            await writer.write(responseData)
                        }
                    }
                } catch {
                    let errResponse = JSONRPCResponse<String>(
                        id: nil,
                        error: JSONRPCError(code: -32700, message: "Parse error: \(error.localizedDescription)")
                    )
                    if let data = try? JSONEncoder().encode(errResponse) {
                        await writer.write(data)
                    }
                }
            }
        }
        await protocolRuntime.setNotificationSink(nil)
    }

    private func readLineData(from handle: FileHandle) -> Data? {
        var buffer = Data()
        while true {
            let chunk = handle.readData(ofLength: 1)
            guard !chunk.isEmpty else {
                return buffer.isEmpty ? nil : buffer
            }
            if chunk[0] == UInt8(ascii: "\n") {
                return buffer
            }
            buffer.append(chunk)
        }
    }

    func handleRequest(_ request: JSONRPCRequest) async -> Data? {
        if request.method == "notifications/cancelled" {
            guard let requestIDValue = request.params?.objectValue?["requestId"],
                  let requestID = requestID(from: requestIDValue) else {
                return nil
            }
            let reason = request.params?.objectValue?["reason"]?.stringValue
            await protocolRuntime.cancel(requestID: requestID, reason: reason)
            return nil
        }

        let modernRequest: Bool

        if let metadata = request.params?.objectValue?["_meta"]?.objectValue {
            guard let protocolVersion = metadata["io.modelcontextprotocol/protocolVersion"]?.stringValue else {
                return encodeInvalidParamsResponse(
                    message: "Modern MCP requests require io.modelcontextprotocol/protocolVersion in _meta",
                    requestID: request.id
                )
            }
            guard protocolVersion == MCPProtocolVersion.modern.rawValue else {
                return encodeUnsupportedVersionResponse(requested: protocolVersion, requestID: request.id)
            }
            guard metadata["io.modelcontextprotocol/clientCapabilities"]?.objectValue != nil else {
                return encodeInvalidParamsResponse(
                    message: "Modern MCP requests require io.modelcontextprotocol/clientCapabilities in _meta",
                    requestID: request.id
                )
            }
            modernRequest = true
        } else if request.method == "server/discover" {
            return encodeInvalidParamsResponse(
                message: "server/discover requires modern MCP _meta with protocolVersion and clientCapabilities",
                requestID: request.id
            )
        } else {
            modernRequest = false
        }

        switch request.method {
        case "initialize":
            guard !modernRequest else {
                let response = JSONRPCResponse<String>(
                    id: request.id,
                    error: JSONRPCError(code: -32601, message: "initialize is only available to legacy MCP clients")
                )
                return try? JSONEncoder().encode(response)
            }
            guard let requestedVersion = request.params?.objectValue?["protocolVersion"]?.stringValue else {
                return encodeInvalidParamsResponse(message: "initialize requires protocolVersion", requestID: request.id)
            }
            guard let version = MCPProtocolVersion(rawValue: requestedVersion),
                  MCPProtocolVersion.legacySupported.contains(version) else {
                return encodeUnsupportedVersionResponse(
                    requested: requestedVersion,
                    supported: MCPProtocolVersion.legacySupported,
                    requestID: request.id
                )
            }
            let result = MCPInitializeResult(protocolVersion: version)
            let response = JSONRPCResponse(id: request.id, result: result)
            return try? JSONEncoder().encode(response)

        case "server/discover":
            let response = JSONRPCResponse(id: request.id, result: MCPDiscoverResult())
            return try? JSONEncoder().encode(response)

        case "notifications/initialized":
            // Notifications do not receive a response
            return nil

        case "ping":
            let response = JSONRPCResponse(id: request.id, result: MCPPingResult(modern: modernRequest))
            return try? JSONEncoder().encode(response)

        case "tools/list":
            let tools = defineTools(modern: modernRequest)
            let response = JSONRPCResponse(id: request.id, result: MCPToolsListResult(tools: tools, modern: modernRequest))
            return try? JSONEncoder().encode(response)

        case "tools/call":
            if modernRequest,
               supportsTasks(request),
               let toolName = request.params?.objectValue?["name"]?.stringValue,
               isTaskEligibleTool(toolName) {
                guard request.id != nil else {
                    return encodeInvalidParamsResponse(message: "tools/call requires a request ID", requestID: nil)
                }
                let arguments = request.params?.objectValue?["arguments"]?.objectValue ?? [:]
                do {
                    let task = try await taskStore.create(toolName: toolName, arguments: arguments)
                    let response = try? JSONEncoder().encode(JSONRPCResponse(id: request.id, result: task))
                    scheduleTask(taskID: task.taskId)
                    return response
                } catch MCPTaskStore.PersistenceError.sensitiveInput {
                    let response = JSONRPCResponse<String>(
                        id: request.id,
                        error: JSONRPCError(
                            code: -32602,
                            message: "Sensitive values cannot be persisted in task arguments",
                            data: .object(["errorCode": .string(MCPToolErrorCode.permissionDenied.rawValue)])
                        )
                    )
                    return try? JSONEncoder().encode(response)
                } catch {
                    let response = JSONRPCResponse<String>(
                        id: request.id,
                        error: JSONRPCError(code: -32603, message: "Unable to durably create ViewLens task")
                    )
                    return try? JSONEncoder().encode(response)
                }
            }

            let progressTokenValue = request.params?.objectValue?["_meta"]?.objectValue?["progressToken"]
            let progressToken: MCPProgressToken?
            if let progressTokenValue {
                guard let parsed = MCPProgressToken(jsonValue: progressTokenValue) else {
                    return encodeInvalidParamsResponse(
                        message: "progressToken must be a string or integer",
                        requestID: request.id
                    )
                }
                progressToken = parsed
            } else {
                progressToken = nil
            }

            guard let requestID = request.id else {
                return encodeInvalidParamsResponse(message: "tools/call requires a request ID", requestID: nil)
            }
            if let beginError = await protocolRuntime.begin(requestID: requestID, progressToken: progressToken) {
                let message = beginError == .duplicateRequestID
                    ? "Request ID is already active"
                    : "Progress token is already active"
                return encodeInvalidParamsResponse(message: message, requestID: request.id)
            }
            let context = MCPExecutionContext(requestID: requestID, runtime: protocolRuntime)
            let response = await handleToolCall(request, modern: modernRequest, execution: context)
            let cancelled = await protocolRuntime.finish(requestID: requestID)
            return cancelled ? nil : response

        case "tasks/get":
            guard supportsTasks(request) else {
                return encodeMissingTaskCapability(requestID: request.id)
            }
            guard let taskID = request.params?.objectValue?["taskId"]?.stringValue else {
                return encodeInvalidParamsResponse(message: "tasks/get requires taskId", requestID: request.id)
            }
            do {
                let task = try await taskStore.snapshot(taskID: taskID)
                if task.status == .working { scheduleTask(taskID: taskID) }
                return try? JSONEncoder().encode(JSONRPCResponse(id: request.id, result: task))
            } catch {
                return encodeTaskLookupError(error, taskID: taskID, requestID: request.id)
            }

        case "tasks/update":
            guard supportsTasks(request) else {
                return encodeMissingTaskCapability(requestID: request.id)
            }
            guard let taskID = request.params?.objectValue?["taskId"]?.stringValue,
                  let responses = request.params?.objectValue?["inputResponses"]?.objectValue else {
                return encodeInvalidParamsResponse(
                    message: "tasks/update requires taskId and inputResponses",
                    requestID: request.id
                )
            }
            do {
                try await taskStore.update(taskID: taskID, responses: responses)
                scheduleTask(taskID: taskID)
                return try? JSONEncoder().encode(JSONRPCResponse(id: request.id, result: MCPTaskAcknowledgement()))
            } catch {
                return encodeTaskLookupError(error, taskID: taskID, requestID: request.id)
            }

        case "tasks/cancel":
            guard supportsTasks(request) else {
                return encodeMissingTaskCapability(requestID: request.id)
            }
            guard let taskID = request.params?.objectValue?["taskId"]?.stringValue else {
                return encodeInvalidParamsResponse(message: "tasks/cancel requires taskId", requestID: request.id)
            }
            do {
                try await taskStore.cancel(taskID: taskID)
                return try? JSONEncoder().encode(JSONRPCResponse(id: request.id, result: MCPTaskAcknowledgement()))
            } catch {
                return encodeTaskLookupError(error, taskID: taskID, requestID: request.id)
            }

        case "resources/list":
            let resources = await resourceStore.resources()
            guard let page = paginate(resources, request: request) else {
                return encodeInvalidParamsResponse(message: "Invalid resource pagination cursor", requestID: request.id)
            }
            let result = MCPResourcesListResult(
                resources: page.values,
                nextCursor: page.nextCursor,
                modern: modernRequest
            )
            return try? JSONEncoder().encode(JSONRPCResponse(id: request.id, result: result))

        case "resources/templates/list":
            guard let page = paginate(MCPResourceStore.templates, request: request) else {
                return encodeInvalidParamsResponse(message: "Invalid resource-template pagination cursor", requestID: request.id)
            }
            let result = MCPResourceTemplatesListResult(
                resourceTemplates: page.values,
                nextCursor: page.nextCursor,
                modern: modernRequest
            )
            return try? JSONEncoder().encode(JSONRPCResponse(id: request.id, result: result))

        case "resources/read":
            guard let uri = request.params?.objectValue?["uri"]?.stringValue else {
                return encodeInvalidParamsResponse(message: "resources/read requires uri", requestID: request.id)
            }
            do {
                let content = try await resourceStore.read(uri: uri)
                let result = MCPResourceReadResult(contents: [content], modern: modernRequest)
                return try? JSONEncoder().encode(JSONRPCResponse(id: request.id, result: result))
            } catch MCPResourceStore.ReadError.notFound {
                return encodeResourceError(
                    code: -32602,
                    message: "Resource not found",
                    uri: uri,
                    errorCode: .invalidInput,
                    requestID: request.id
                )
            } catch MCPResourceStore.ReadError.artifactTooLarge {
                return encodeResourceError(
                    code: -32603,
                    message: "Resource exceeds the 10 MB read limit",
                    uri: uri,
                    errorCode: .permissionDenied,
                    requestID: request.id
                )
            } catch {
                return encodeResourceError(
                    code: -32603,
                    message: "Resource is unavailable",
                    uri: uri,
                    errorCode: .unavailableEvidence,
                    requestID: request.id
                )
            }

        case "prompts/list":
            guard modernRequest else {
                return encodeModernCapabilityRequired(method: request.method, requestID: request.id)
            }
            guard let page = paginate(MCPPromptRegistry.prompts, request: request) else {
                return encodeInvalidParamsResponse(message: "Invalid prompt pagination cursor", requestID: request.id)
            }
            let result = MCPPromptsListResult(prompts: page.values, nextCursor: page.nextCursor)
            return try? JSONEncoder().encode(JSONRPCResponse(id: request.id, result: result))

        case "prompts/get":
            guard modernRequest else {
                return encodeModernCapabilityRequired(method: request.method, requestID: request.id)
            }
            guard let name = request.params?.objectValue?["name"]?.stringValue else {
                return encodeInvalidParamsResponse(message: "prompts/get requires name", requestID: request.id)
            }
            let arguments: [String: JSONValue]
            if let rawArguments = request.params?.objectValue?["arguments"] {
                guard let object = rawArguments.objectValue else {
                    return encodePromptError(
                        message: "Prompt arguments must be an object of string values",
                        prompt: name,
                        argument: nil,
                        requestID: request.id
                    )
                }
                arguments = object
            } else {
                arguments = [:]
            }
            do {
                let result = try MCPPromptRegistry.resolve(name: name, arguments: arguments)
                return try? JSONEncoder().encode(JSONRPCResponse(id: request.id, result: result))
            } catch MCPPromptRegistry.ResolutionError.invalidName {
                return encodePromptError(
                    message: "Unknown prompt: \(name)",
                    prompt: name,
                    argument: nil,
                    requestID: request.id
                )
            } catch MCPPromptRegistry.ResolutionError.missingArgument(let argument) {
                return encodePromptError(
                    message: "Missing required prompt argument: \(argument)",
                    prompt: name,
                    argument: argument,
                    requestID: request.id
                )
            } catch MCPPromptRegistry.ResolutionError.invalidArgument(let argument) {
                return encodePromptError(
                    message: "Invalid prompt argument: \(argument)",
                    prompt: name,
                    argument: argument,
                    requestID: request.id
                )
            } catch {
                let response = JSONRPCResponse<String>(
                    id: request.id,
                    error: JSONRPCError(code: -32603, message: "Unable to resolve prompt")
                )
                return try? JSONEncoder().encode(response)
            }

        default:
            let response = JSONRPCResponse<String>(
                id: request.id,
                error: JSONRPCError(code: -32601, message: "Method not found: \(request.method)")
            )
            return try? JSONEncoder().encode(response)
        }
    }

    private func encodeInvalidParamsResponse(message: String, requestID: JSONRPCRequest.RequestID?) -> Data? {
        let response = JSONRPCResponse<String>(
            id: requestID,
            error: JSONRPCError(code: -32602, message: message)
        )
        return try? JSONEncoder().encode(response)
    }

    private func requestID(from value: JSONValue) -> JSONRPCRequest.RequestID? {
        if let string = value.stringValue { return .string(string) }
        if let number = value.doubleValue,
           number.isFinite,
           number.rounded() == number,
           number >= Double(Int.min),
           number <= Double(Int.max) {
            return .int(Int(number))
        }
        return nil
    }

    private func supportsTasks(_ request: JSONRPCRequest) -> Bool {
        guard let metadata = request.params?.objectValue?["_meta"]?.objectValue,
              let capabilities = metadata["io.modelcontextprotocol/clientCapabilities"]?.objectValue,
              let extensions = capabilities["extensions"]?.objectValue else {
            return false
        }
        return extensions["io.modelcontextprotocol/tasks"]?.objectValue != nil
    }

    private func isTaskEligibleTool(_ name: String) -> Bool {
        [
            "viewlens_audit_screenshot",
            "viewlens_audit_view",
            "viewlens_accessibility_audit",
            "viewlens_design_diff"
        ].contains(name)
    }

    private func encodeMissingTaskCapability(requestID: JSONRPCRequest.RequestID?) -> Data? {
        let response = JSONRPCResponse<String>(
            id: requestID,
            error: JSONRPCError(
                code: -32021,
                message: "Missing required client capability",
                data: .object([
                    "requiredCapabilities": .object([
                        "extensions": .object([
                            "io.modelcontextprotocol/tasks": .object([:])
                        ])
                    ])
                ])
            )
        )
        return try? JSONEncoder().encode(response)
    }

    private func encodeTaskLookupError(
        _ error: Error,
        taskID: String,
        requestID: JSONRPCRequest.RequestID?
    ) -> Data? {
        let message: String
        let errorCode: MCPToolErrorCode
        if error as? MCPTaskStore.LookupError == .expired {
            message = "Task has expired"
            errorCode = .expiredHandle
        } else if error is MCPTaskStore.LookupError {
            message = "Task not found"
            errorCode = .invalidInput
        } else {
            let response = JSONRPCResponse<String>(
                id: requestID,
                error: JSONRPCError(code: -32603, message: "Task storage is unavailable")
            )
            return try? JSONEncoder().encode(response)
        }
        let response = JSONRPCResponse<String>(
            id: requestID,
            error: JSONRPCError(
                code: -32602,
                message: message,
                data: .object(["taskId": .string(taskID), "errorCode": .string(errorCode.rawValue)])
            )
        )
        return try? JSONEncoder().encode(response)
    }

    private func scheduleTask(taskID: String) {
        Task { [self] in
            await executeTask(taskID: taskID)
        }
    }

    private func executeTask(taskID: String) async {
        let descriptor: MCPTaskStore.ExecutionDescriptor
        do {
            guard let claimed = try await taskStore.claimExecution(taskID: taskID) else { return }
            descriptor = claimed
        } catch {
            return
        }

        let request = JSONRPCRequest(
            id: .string("task-\(taskID)"),
            method: "tools/call",
            params: .object([
                "name": .string(descriptor.toolName),
                "arguments": .object(descriptor.arguments)
            ])
        )
        let execution = MCPExecutionContext(taskID: taskID, taskStore: taskStore)
        guard let responseData = await handleToolCall(request, modern: true, execution: execution) else {
            if await taskStore.isCancellationRequested(taskID: taskID) {
                try? await taskStore.cancel(taskID: taskID)
            } else {
                try? await taskStore.fail(
                    taskID: taskID,
                    error: JSONRPCError(code: -32603, message: "Task execution ended without a result")
                )
            }
            return
        }

        do {
            let root = try JSONDecoder().decode(JSONValue.self, from: responseData)
            guard let object = root.objectValue else {
                throw NSError(domain: "ViewLensMCPTask", code: 1)
            }
            if let result = object["result"] {
                do {
                    try await taskStore.complete(taskID: taskID, result: result)
                } catch MCPTaskStore.PersistenceError.resultTooLarge {
                    try await taskStore.fail(
                        taskID: taskID,
                        error: JSONRPCError(code: -32603, message: "Task result exceeds the 5 MB storage limit")
                    )
                }
            } else if let errorValue = object["error"] {
                let errorData = try JSONEncoder().encode(errorValue)
                let error = try JSONDecoder().decode(JSONRPCError.self, from: errorData)
                try await taskStore.fail(taskID: taskID, error: error)
            } else {
                throw NSError(domain: "ViewLensMCPTask", code: 2)
            }
        } catch {
            try? await taskStore.fail(
                taskID: taskID,
                error: JSONRPCError(code: -32603, message: "Unable to persist task result")
            )
        }
    }

    func drainProtocolNotifications() async -> [Data] {
        await protocolRuntime.drainNotifications()
    }

    private func encodeModernCapabilityRequired(
        method: String,
        requestID: JSONRPCRequest.RequestID?
    ) -> Data? {
        let response = JSONRPCResponse<String>(
            id: requestID,
            error: JSONRPCError(
                code: -32601,
                message: "Method not available in the negotiated legacy capability set: \(method)"
            )
        )
        return try? JSONEncoder().encode(response)
    }

    private func encodePromptError(
        message: String,
        prompt: String,
        argument: String?,
        requestID: JSONRPCRequest.RequestID?
    ) -> Data? {
        var data: [String: JSONValue] = [
            "prompt": .string(prompt),
            "errorCode": .string(MCPToolErrorCode.invalidInput.rawValue)
        ]
        if let argument { data["argument"] = .string(argument) }
        let response = JSONRPCResponse<String>(
            id: requestID,
            error: JSONRPCError(code: -32602, message: message, data: .object(data))
        )
        return try? JSONEncoder().encode(response)
    }

    private func encodeUnsupportedVersionResponse(
        requested: String,
        supported: [MCPProtocolVersion] = MCPProtocolVersion.supported,
        requestID: JSONRPCRequest.RequestID?
    ) -> Data? {
        let data: JSONValue = .object([
            "supported": .array(supported.map { .string($0.rawValue) }),
            "requested": .string(requested)
        ])
        let response = JSONRPCResponse<String>(
            id: requestID,
            error: JSONRPCError(code: -32022, message: "Unsupported protocol version", data: data)
        )
        return try? JSONEncoder().encode(response)
    }

    private func encodeResourceError(
        code: Int,
        message: String,
        uri: String,
        errorCode: MCPToolErrorCode,
        requestID: JSONRPCRequest.RequestID?
    ) -> Data? {
        let response = JSONRPCResponse<String>(
            id: requestID,
            error: JSONRPCError(
                code: code,
                message: message,
                data: .object(["uri": .string(uri), "errorCode": .string(errorCode.rawValue)])
            )
        )
        return try? JSONEncoder().encode(response)
    }

    private func paginate<T>(_ values: [T], request: JSONRPCRequest, pageSize: Int = 50) -> (values: [T], nextCursor: String?)? {
        let cursorValue = request.params?.objectValue?["cursor"]
        let offset: Int
        if let cursorValue {
            guard let cursor = cursorValue.stringValue,
                  let parsed = Int(cursor), parsed >= 0, parsed <= values.count else {
                return nil
            }
            offset = parsed
        } else {
            offset = 0
        }
        let end = min(offset + pageSize, values.count)
        let nextCursor = end < values.count ? String(end) : nil
        return (Array(values[offset..<end]), nextCursor)
    }

    func defineTools(modern: Bool = false) -> [MCPTool] {
        let doctorSchema: JSONValue = .object([
            "type": .string("object"),
            "properties": .object([
                "model_path": .object([
                    "type": .string("string"),
                    "description": .string("Optional path to override default CoreML model discovery.")
                ])
            ])
        ])

        let screenshotSchema: JSONValue = .object([
            "type": .string("object"),
            "properties": .object([
                "image_path": .object([
                    "type": .string("string"),
                    "description": .string("Path to the screenshot image file (PNG/JPEG) to audit.")
                ]),
                "min_confidence": .object([
                    "type": .string("number"),
                    "description": .string("Minimum detection confidence threshold (default 0.10).")
                ]),
                "scale": .object([
                    "type": .string("number"),
                    "description": .string("Display scale override (@2x = 2.0, @3x = 3.0). Auto-inferred if omitted.")
                ]),
                "overlay_path": .object([
                    "type": .string("string"),
                    "description": .string("Optional path to write an annotated PNG image with color-coded bounding boxes.")
                ]),
                "model_path": .object([
                    "type": .string("string"),
                    "description": .string("Optional path to override default CoreML model.")
                ])
            ]),
            "required": .array([.string("image_path")])
        ])

        let viewSchema: JSONValue = .object([
            "type": .string("object"),
            "properties": .object([
                "template": .object([
                    "type": .string("string"),
                    "description": .string("Name of the registered SwiftUI/UIKit template.")
                ]),
                "devices": .object([
                    "type": .string("array"),
                    "items": .object(["type": .string("string")]),
                    "description": .string("List of device profiles (e.g. ['iPhoneSE', 'iPhone16Pro']).")
                ]),
                "dynamic_type_sizes": .object([
                    "type": .string("array"),
                    "items": .object(["type": .string("string")]),
                    "description": .string("List of Dynamic Type sizes (e.g. ['large', 'accessibility3']).")
                ]),
                "color_schemes": .object([
                    "type": .string("array"),
                    "items": .object(["type": .string("string")]),
                    "description": .string("List of color schemes ('light', 'dark').")
                ])
            ]),
            "required": .array([.string("template")])
        ])

        let a11ySchema: JSONValue = .object([
            "type": .string("object"),
            "properties": .object([
                "template": .object([
                    "type": .string("string"),
                    "description": .string("Name of the registered SwiftUI/UIKit template to audit (e.g. 'LoginForm', 'CheckoutView').")
                ]),
                "image_path": .object([
                    "type": .string("string"),
                    "description": .string("Optional path to screenshot image if auditing an existing file instead of template.")
                ]),
                "wcag_level": .object([
                    "type": .string("string"),
                    "description": .string("Target WCAG compliance level ('A', 'AA', or 'AAA'; default 'AA')."),
                    "enum": .array([.string("A"), .string("AA"), .string("AAA")])
                ])
            ])
        ])

        let designDiffSchema: JSONValue = .object([
            "type": .string("object"),
            "properties": .object([
                "reference_image": .object([
                    "type": .string("string"),
                    "description": .string("Path to the reference design image file (from Figma or baseline design).")
                ]),
                "template": .object([
                    "type": .string("string"),
                    "description": .string("Name of the registered SwiftUI/UIKit template to verify.")
                ]),
                "device": .object([
                    "type": .string("string"),
                    "description": .string("Target device profile (default 'iPhone16Pro').")
                ]),
                "ssim_threshold": .object([
                    "type": .string("number"),
                    "description": .string("Minimum Structural Similarity Index (SSIM) to pass (default 0.98).")
                ]),
                "heatmap_path": .object([
                    "type": .string("string"),
                    "description": .string("Optional path to output an annotated visual diff heatmap image.")
                ]),
                "check_accessibility": .object([
                    "type": .string("boolean"),
                    "description": .string("Whether to run WCAG accessibility checks concurrently (default true).")
                ])
            ]),
            "required": .array([.string("reference_image"), .string("template")])
        ])

        let destinationsListSchema: JSONValue = .object([
            "type": .string("object"),
            "properties": .object([
                "workspace_root": .object([
                    "type": .string("string"),
                    "description": .string("Optional workspace root directory to scan for local app targets.")
                ])
            ])
        ])

        let sessionCreateSchema: JSONValue = .object([
            "type": .string("object"),
            "properties": .object([
                "destination_id": .object([
                    "type": .string("string"),
                    "description": .string("Target destination identifier (e.g. 'macos_host' or 'sim_iphone_16_pro').")
                ]),
                "workspace_root": .object([
                    "type": .string("string"),
                    "description": .string("Absolute path to workspace root.")
                ]),
                "bundle_identifier": .object([
                    "type": .string("string"),
                    "description": .string("Optional bundle identifier of target application.")
                ]),
                "ttl_seconds": .object([
                    "type": .string("number"),
                    "description": .string("Session lease time-to-live in seconds (default 1800s / 30m).")
                ])
            ]),
            "required": .array([.string("workspace_root")])
        ])

        let sessionGetSchema: JSONValue = .object([
            "type": .string("object"),
            "properties": .object([
                "session_id": .object([
                    "type": .string("string"),
                    "description": .string("Unique session handle.")
                ])
            ]),
            "required": .array([.string("session_id")])
        ])

        let sessionCloseSchema: JSONValue = .object([
            "type": .string("object"),
            "properties": .object([
                "session_id": .object([
                    "type": .string("string"),
                    "description": .string("Unique session handle to close.")
                ])
            ]),
            "required": .array([.string("session_id")])
        ])

        var tools = [
            MCPTool(
                name: "viewlens_doctor",
                title: modern ? "Check ViewLens Readiness" : nil,
                description: "Reports environment readiness: verifies CoreML model path, file size, and performs cold-load latency check. Call this first. See .agents/skills/viewlens/SKILL.md.",
                inputSchema: modern ? strictInputSchema(doctorSchema) : doctorSchema,
                outputSchema: modern ? evidenceOutputSchema(dataSchema: doctorOutputDataSchema()) : nil,
                icons: modern ? viewLensToolIcons() : nil,
                annotations: modern ? MCPTool.Annotations() : nil
            ),
            MCPTool(
                name: "viewlens_audit_screenshot",
                title: modern ? "Audit Screenshot" : nil,
                description: "Audits a screenshot image using YOLO11n CoreML vision detection and HIG rules. Returns structured JSON coordinates [x, y, w, h] in normalized top-left space and classified layout issues.",
                inputSchema: modern ? strictInputSchema(screenshotSchema) : screenshotSchema,
                outputSchema: modern ? evidenceOutputSchema(dataSchema: screenshotOutputDataSchema()) : nil,
                icons: modern ? viewLensToolIcons() : nil,
                annotations: modern ? MCPTool.Annotations() : nil
            ),
            MCPTool(
                name: "viewlens_audit_view",
                title: modern ? "Audit Native View Matrix" : nil,
                description: "Renders and audits a registered SwiftUI/UIKit view template across a matrix of device profiles and accessibility traits (Milestone 2).",
                inputSchema: modern ? strictInputSchema(viewSchema) : viewSchema,
                outputSchema: modern ? evidenceOutputSchema(dataSchema: reportOutputDataSchema(required: [
                    "sourceMode", "template", "passed", "summary", "permutations"
                ])) : nil,
                icons: modern ? viewLensToolIcons() : nil,
                annotations: modern ? MCPTool.Annotations() : nil
            ),
            MCPTool(
                name: "viewlens_accessibility_audit",
                title: modern ? "Run WCAG 2.2 Audit" : nil,
                description: "Performs WCAG 2.2 mobile accessibility auditing across programmatic Name/Role/Value (4.1.2), level-aware Target Size (2.5.8 AA / 2.5.5 AAA), Light/Dark contrast, AX1/AX3/AX5 reflow, and portrait/landscape orientation. Reports unavailable checks as not evaluated.",
                inputSchema: modern ? strictInputSchema(a11ySchema) : a11ySchema,
                outputSchema: modern ? evidenceOutputSchema(dataSchema: reportOutputDataSchema(required: [
                    "target", "targetLevel", "overallComplianceScore", "passed", "complete",
                    "criteria", "issues", "metrics", "timestamp"
                ])) : nil,
                icons: modern ? viewLensToolIcons() : nil,
                annotations: modern ? MCPTool.Annotations() : nil
            ),
            MCPTool(
                name: "viewlens_design_diff",
                title: modern ? "Verify Design Fidelity" : nil,
                description: "Performs Design-to-Code verification comparing a Figma reference design image against a rendered native SwiftUI view using SSIM perceptual diffing and WCAG checks.",
                inputSchema: modern ? strictInputSchema(designDiffSchema) : designDiffSchema,
                outputSchema: modern ? evidenceOutputSchema(dataSchema: reportOutputDataSchema(required: [
                    "referenceSource", "candidateTemplate", "visualDiff", "tokenMismatches",
                    "geometryDeltas", "passed", "timestamp"
                ])) : nil,
                icons: modern ? viewLensToolIcons() : nil,
                annotations: modern ? MCPTool.Annotations() : nil
            )
        ]

        if modern {
            let sessionObjectSchema: JSONValue = .object([
                "$schema": .string("https://json-schema.org/draft/2020-12/schema"),
                "type": .string("object"),
                "additionalProperties": .bool(true)
            ])

            tools.append(contentsOf: [
                MCPTool(
                    name: "viewlens_destinations_list",
                    title: "List Inspection Destinations",
                    description: "Discovers available macOS running host applications and Apple iOS Simulators.",
                    inputSchema: strictInputSchema(destinationsListSchema),
                    outputSchema: sessionObjectSchema,
                    icons: viewLensToolIcons(),
                    annotations: MCPTool.Annotations()
                ),
                MCPTool(
                    name: "viewlens_session_create",
                    title: "Create Runtime Review Session",
                    description: "Creates an isolated, bounded review session on a macOS app or iOS Simulator destination with an expiring lease.",
                    inputSchema: strictInputSchema(sessionCreateSchema),
                    outputSchema: sessionObjectSchema,
                    icons: viewLensToolIcons(),
                    annotations: MCPTool.Annotations()
                ),
                MCPTool(
                    name: "viewlens_session_get",
                    title: "Get Runtime Session Status",
                    description: "Queries the active status and TTL lease of a runtime review session.",
                    inputSchema: strictInputSchema(sessionGetSchema),
                    outputSchema: sessionObjectSchema,
                    icons: viewLensToolIcons(),
                    annotations: MCPTool.Annotations()
                ),
                MCPTool(
                    name: "viewlens_session_close",
                    title: "Close Runtime Session",
                    description: "Terminates and releases an active runtime review session.",
                    inputSchema: strictInputSchema(sessionCloseSchema),
                    outputSchema: sessionObjectSchema,
                    icons: viewLensToolIcons(),
                    annotations: MCPTool.Annotations()
                )
            ])
        }

        return tools
    }

    private func strictInputSchema(_ schema: JSONValue) -> JSONValue {
        guard var object = schema.objectValue else { return schema }
        object["$schema"] = .string("https://json-schema.org/draft/2020-12/schema")
        object["additionalProperties"] = .bool(false)
        return .object(object)
    }

    private func viewLensToolIcons() -> [MCPTool.Icon] {
        [MCPTool.Icon(source: "data:image/svg+xml,%3Csvg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 24 24'%3E%3Cpath fill='%236C5CE7' d='M12 3C6.5 3 2.1 7.1 1 12c1.1 4.9 5.5 9 11 9s9.9-4.1 11-9c-1.1-4.9-5.5-9-11-9Zm0 14a5 5 0 1 1 0-10 5 5 0 0 1 0 10Zm0-3a2 2 0 1 1 0-4 2 2 0 0 1 0 4Z'/%3E%3C/svg%3E")]
    }

    private func evidenceOutputSchema(dataSchema: JSONValue) -> JSONValue {
        let stringArray: JSONValue = .object([
            "type": .string("array"),
            "items": .object(["type": .string("string")])
        ])
        let openObject: JSONValue = .object([
            "type": .string("object"),
            "additionalProperties": .bool(true)
        ])

        return .object([
            "$schema": .string("https://json-schema.org/draft/2020-12/schema"),
            "type": .string("object"),
            "additionalProperties": .bool(false),
            "properties": .object([
                "schemaVersion": .object(["type": .string("string"), "const": .string("1.0")]),
                "reviewId": .object(["type": .string("string")]),
                "sourceMode": .object(["type": .string("string")]),
                "target": .object([
                    "type": .string("object"),
                    "additionalProperties": .bool(false),
                    "properties": .object([
                        "type": .object(["type": .string("string")]),
                        "identifier": .object(["type": .string("string")])
                    ]),
                    "required": .array([.string("type"), .string("identifier")])
                ]),
                "environment": .object([
                    "type": .string("object"),
                    "additionalProperties": .bool(false),
                    "properties": .object([
                        "platform": .object(["type": .string("string")]),
                        "server": .object([
                            "type": .string("object"),
                            "additionalProperties": .bool(false),
                            "properties": .object([
                                "name": .object(["type": .string("string")]),
                                "version": .object(["type": .string("string")])
                            ]),
                            "required": .array([.string("name"), .string("version")])
                        ])
                    ]),
                    "required": .array([.string("platform"), .string("server")])
                ]),
                "completeness": .object([
                    "type": .string("object"),
                    "additionalProperties": .bool(false),
                    "properties": .object([
                        "status": .object([
                            "type": .string("string"),
                            "enum": .array([.string("complete"), .string("partial"), .string("unavailable")])
                        ]),
                        "evaluated": stringArray,
                        "notEvaluated": stringArray
                    ]),
                    "required": .array([.string("status"), .string("evaluated"), .string("notEvaluated")])
                ]),
                "findings": .object(["type": .string("array"), "items": openObject]),
                "artifacts": .object([
                    "type": .string("array"),
                    "items": .object([
                        "type": .string("object"),
                        "additionalProperties": .bool(false),
                        "properties": .object([
                            "kind": .object(["type": .string("string")]),
                            "path": .object(["type": .string("string")]),
                            "mediaType": .object(["type": .string("string")])
                        ]),
                        "required": .array([.string("kind"), .string("path"), .string("mediaType")])
                    ])
                ]),
                "timing": .object([
                    "type": .string("object"),
                    "additionalProperties": .bool(false),
                    "properties": .object(["durationMs": .object(["type": .string("number"), "minimum": .number(0)])]),
                    "required": .array([.string("durationMs")])
                ]),
                "warnings": stringArray,
                "recoveryActions": stringArray,
                "data": dataSchema,
                "error": .object([
                    "type": .string("object"),
                    "additionalProperties": .bool(false),
                    "properties": .object([
                        "code": .object([
                            "type": .string("string"),
                            "enum": .array(MCPToolErrorCode.allCases.map { .string($0.rawValue) })
                        ]),
                        "message": .object(["type": .string("string")]),
                        "recoverable": .object(["type": .string("boolean")])
                    ]),
                    "required": .array([.string("code"), .string("message"), .string("recoverable")])
                ])
            ]),
            "required": .array([
                .string("schemaVersion"), .string("reviewId"), .string("sourceMode"),
                .string("target"), .string("environment"), .string("completeness"),
                .string("findings"), .string("artifacts"), .string("timing"),
                .string("warnings"), .string("recoveryActions"), .string("data")
            ])
        ])
    }

    private func doctorOutputDataSchema() -> JSONValue {
        .object([
            "type": .string("object"),
            "additionalProperties": .bool(false),
            "properties": .object([
                "status": .object(["type": .string("string"), "enum": .array([.string("ready"), .string("not_ready")])]),
                "checks": .object([
                    "type": .string("array"),
                    "items": .object([
                        "type": .string("object"),
                        "additionalProperties": .bool(false),
                        "properties": .object([
                            "name": .object(["type": .string("string")]),
                            "status": .object(["type": .string("string")]),
                            "detail": .object(["type": .string("string")])
                        ]),
                        "required": .array([.string("name"), .string("status"), .string("detail")])
                    ])
                ]),
                "recommendedNextCommand": .object(["type": .string("string")])
            ]),
            "required": .array([.string("status"), .string("checks"), .string("recommendedNextCommand")])
        ])
    }

    private func screenshotOutputDataSchema() -> JSONValue {
        .object([
            "type": .string("object"),
            "additionalProperties": .bool(true),
            "properties": .object([
                "sourceMode": .object(["type": .string("string"), "const": .string("screenshot")]),
                "image": .object(["type": .string("string")]),
                "elements": .object(["type": .string("array")]),
                "issues": .object(["type": .string("array")]),
                "passed": .object(["type": .string("boolean")]),
                "summary": .object(["type": .string("object")])
            ]),
            "required": .array([.string("sourceMode"), .string("elements"), .string("issues"), .string("passed"), .string("summary")])
        ])
    }

    private func reportOutputDataSchema(required: [String]) -> JSONValue {
        .object([
            "type": .string("object"),
            "additionalProperties": .bool(true),
            "required": .array(required.map(JSONValue.string))
        ])
    }

    private func handleToolCall(
        _ request: JSONRPCRequest,
        modern: Bool,
        execution: MCPExecutionContext
    ) async -> Data? {
        guard let paramsObj = request.params?.objectValue,
              let toolName = paramsObj["name"]?.stringValue else {
            let response = JSONRPCResponse<String>(
                id: request.id,
                error: JSONRPCError(code: -32602, message: "Invalid params for tools/call")
            )
            return try? JSONEncoder().encode(response)
        }

        let arguments = paramsObj["arguments"]?.objectValue ?? [:]

        switch toolName {
        case "viewlens_doctor":
            let started = DispatchTime.now()
            let modelPath = arguments["model_path"]?.stringValue
            let report = runDoctor(customPath: modelPath)
            let jsonText = JSONFormatter.encode(report)
            let unavailableChecks = report.checks.filter { $0.status != "confirmed" }
            let evidence = MCPEvidenceEnvelope(
                sourceMode: "environment",
                target: .init(type: "coremlModel", identifier: modelPath ?? "auto-discovery"),
                completeness: .init(
                    status: report.status == "ready" ? .complete : .partial,
                    evaluated: report.checks.filter { $0.status != "skipped" }.map(\.name),
                    notEvaluated: report.checks.filter { $0.status == "skipped" }.map(\.name)
                ),
                findings: unavailableChecks.compactMap { try? JSONValue.fromEncodable($0) },
                durationMs: elapsedMilliseconds(since: started),
                recoveryActions: report.status == "ready" ? [] : [report.recommendedNextCommand],
                data: (try? JSONValue.fromEncodable(report)) ?? .object([:]),
                error: report.status == "ready" ? nil : MCPStructuredError(
                    code: .unavailableEvidence,
                    message: "ViewLens environment is not ready"
                )
            )
            let result = MCPToolCallResult(
                text: jsonText,
                structuredContent: await retainedStructuredContent(evidence, modern: modern),
                isError: report.status != "ready",
                modern: modern
            )
            let response = JSONRPCResponse(id: request.id, result: result)
            return try? JSONEncoder().encode(response)

        case "viewlens_audit_screenshot":
            guard let imagePath = arguments["image_path"]?.stringValue else {
                let message = "Missing required 'image_path' parameter"
                let evidence = screenshotErrorEvidence(
                    imagePath: "unspecified",
                    error: MCPStructuredError(code: .invalidInput, message: message),
                    recoveryActions: ["Provide an absolute PNG or JPEG path in image_path"]
                )
                let result = MCPToolCallResult(
                    text: JSONFormatter.errorJSON(message: message),
                    structuredContent: await retainedStructuredContent(evidence, modern: modern),
                    isError: true,
                    modern: modern
                )
                let response = JSONRPCResponse(id: request.id, result: result)
                return try? JSONEncoder().encode(response)
            }

            guard await execution.report(progress: 5, message: "Validated screenshot audit request") else {
                return nil
            }

            let minConfidence = Float(arguments["min_confidence"]?.doubleValue ?? 0.10)
            let scale = arguments["scale"]?.doubleValue
            let overlayPath = arguments["overlay_path"]?.stringValue
            let modelPath = arguments["model_path"]?.stringValue

            let started = DispatchTime.now()
            guard let auditResult = await runAuditScreenshot(
                imagePath: imagePath,
                minConfidence: minConfidence,
                scale: scale,
                overlayPath: overlayPath,
                modelPath: modelPath,
                execution: execution
            ) else { return nil }

            let structuredContent: JSONValue?
            var artifactReviewID: String?
            if let report = auditResult.report {
                let evidence = MCPEvidenceEnvelope(
                    sourceMode: "screenshot",
                    target: .init(type: "image", identifier: imagePath),
                    completeness: .init(
                        status: .partial,
                        evaluated: ["visualDetection", "layoutRules"],
                        notEvaluated: [
                            "programmaticSemantics",
                            "dynamicTypeReflow",
                            "orientationVariants",
                            "darkModeContrast"
                        ]
                    ),
                    findings: report.issues.compactMap { try? JSONValue.fromEncodable($0) },
                    artifacts: auditResult.artifacts,
                    durationMs: elapsedMilliseconds(since: started),
                    warnings: auditResult.warnings,
                    recoveryActions: report.passed ? [] : ["Review findings and rerun the audit after remediation"],
                    data: (try? JSONValue.fromEncodable(report)) ?? .object([:])
                )
                artifactReviewID = evidence.reviewID
                structuredContent = await retainedStructuredContent(evidence, modern: modern)
            } else {
                let evidence = screenshotErrorEvidence(
                    imagePath: imagePath,
                    error: auditResult.error ?? MCPStructuredError(
                        code: .runtimeFailure,
                        message: "Screenshot audit failed"
                    ),
                    durationMs: elapsedMilliseconds(since: started),
                    warnings: auditResult.warnings,
                    recoveryActions: auditResult.error?.code == .unavailableEvidence
                        ? ["Run viewlens_doctor and resolve the reported model issue"]
                        : ["Verify the image path and rerun the audit"]
                )
                structuredContent = await retainedStructuredContent(evidence, modern: modern)
            }

            let result = MCPToolCallResult(
                text: auditResult.jsonText,
                structuredContent: structuredContent,
                artifacts: auditResult.artifacts,
                artifactReviewID: artifactReviewID,
                isError: !auditResult.success,
                modern: modern
            )
            guard await execution.report(progress: 100, message: "Screenshot audit complete") else { return nil }
            let response = JSONRPCResponse(id: request.id, result: result)
            return try? JSONEncoder().encode(response)

        case "viewlens_audit_view":
            guard let templateName = arguments["template"]?.stringValue else {
                let message = "Missing required 'template' parameter"
                let evidence = operationalErrorEvidence(
                    sourceMode: "rendered",
                    targetType: "template",
                    targetIdentifier: "unspecified",
                    error: MCPStructuredError(code: .invalidInput, message: message),
                    recoveryActions: ["Provide a registered template name in template"],
                    data: matrixFailureData(template: "unspecified")
                )
                let result = MCPToolCallResult(
                    text: JSONFormatter.errorJSON(message: message),
                    structuredContent: await retainedStructuredContent(evidence, modern: modern),
                    isError: true,
                    modern: modern
                )
                let response = JSONRPCResponse(id: request.id, result: result)
                return try? JSONEncoder().encode(response)
            }

            guard await execution.report(progress: 5, message: "Validated render matrix request") else {
                return nil
            }

            let devicesArray: [String]
            if case .array(let arr) = arguments["devices"] {
                devicesArray = arr.compactMap { $0.stringValue }
            } else {
                devicesArray = ["iPhoneSE", "iPhone16Pro"]
            }

            let dtArray: [String]
            if case .array(let arr) = arguments["dynamic_type_sizes"] {
                dtArray = arr.compactMap { $0.stringValue }
            } else {
                dtArray = ["large", "accessibility3"]
            }

            let schemeArray: [String]
            if case .array(let arr) = arguments["color_schemes"] {
                schemeArray = arr.compactMap { $0.stringValue }
            } else {
                schemeArray = ["light", "dark"]
            }

            let started = DispatchTime.now()
            guard let auditResult = await runAuditView(
                templateName: templateName,
                deviceNames: devicesArray,
                dtSizes: dtArray,
                schemes: schemeArray,
                execution: execution
            ) else { return nil }

            let structuredContent: JSONValue?
            if let report = auditResult.report {
                let findings = report.permutations.values
                    .flatMap(\.issues)
                    .compactMap { try? JSONValue.fromEncodable($0) }
                let missingCount = max(0, report.summary.totalPermutations - report.permutations.count)
                let evidence = MCPEvidenceEnvelope(
                    sourceMode: "rendered",
                    target: .init(type: "template", identifier: templateName),
                    completeness: .init(
                        status: missingCount == 0 ? .complete : .partial,
                        evaluated: report.permutations.keys.sorted(),
                        notEvaluated: missingCount == 0 ? [] : ["\(missingCount) render permutation(s)"]
                    ),
                    findings: findings,
                    durationMs: elapsedMilliseconds(since: started),
                    warnings: missingCount == 0 ? [] : ["One or more requested render permutations were unavailable"],
                    recoveryActions: report.passed ? [] : ["Inspect failed permutations and rerun after remediation"],
                    data: (try? JSONValue.fromEncodable(report)) ?? matrixFailureData(template: templateName),
                    error: missingCount == 0 ? nil : MCPStructuredError(
                        code: .unavailableEvidence,
                        message: "The complete render matrix could not be evaluated"
                    )
                )
                structuredContent = await retainedStructuredContent(evidence, modern: modern)
            } else {
                let evidence = operationalErrorEvidence(
                    sourceMode: "rendered",
                    targetType: "template",
                    targetIdentifier: templateName,
                    error: auditResult.error ?? MCPStructuredError(code: .runtimeFailure, message: "Template audit failed"),
                    recoveryActions: ["Verify the template name and requested matrix values"],
                    data: matrixFailureData(template: templateName),
                    durationMs: elapsedMilliseconds(since: started)
                )
                structuredContent = await retainedStructuredContent(evidence, modern: modern)
            }
            let result = MCPToolCallResult(
                text: auditResult.jsonText,
                structuredContent: structuredContent,
                isError: !auditResult.passed,
                modern: modern
            )
            guard await execution.report(progress: 100, message: "Render matrix audit complete") else { return nil }
            let response = JSONRPCResponse(id: request.id, result: result)
            return try? JSONEncoder().encode(response)

        case "viewlens_accessibility_audit":
            let templateName = arguments["template"]?.stringValue
            let imagePath = arguments["image_path"]?.stringValue
            let targetLevel = arguments["wcag_level"]?.stringValue ?? "AA"

            guard WCAGConformanceLevel(input: targetLevel) != nil else {
                let message = "Invalid 'wcag_level'. Expected A, AA, or AAA"
                let evidence = operationalErrorEvidence(
                    sourceMode: templateName == nil ? "screenshot" : "rendered",
                    targetType: templateName == nil ? "image" : "template",
                    targetIdentifier: templateName ?? imagePath ?? "unspecified",
                    error: MCPStructuredError(code: .invalidInput, message: message),
                    recoveryActions: ["Use A, AA, or AAA for wcag_level"],
                    data: accessibilityFailureData(target: templateName ?? imagePath ?? "unspecified", level: targetLevel)
                )
                let result = MCPToolCallResult(
                    text: JSONFormatter.errorJSON(message: message),
                    structuredContent: await retainedStructuredContent(evidence, modern: modern),
                    isError: true,
                    modern: modern
                )
                let response = JSONRPCResponse(id: request.id, result: result)
                return try? JSONEncoder().encode(response)
            }

            guard (templateName == nil) != (imagePath == nil) else {
                let message = "Specify exactly one of 'template' or 'image_path'"
                let evidence = operationalErrorEvidence(
                    sourceMode: "accessibility",
                    targetType: "auditTarget",
                    targetIdentifier: "ambiguous",
                    error: MCPStructuredError(code: .invalidInput, message: message),
                    recoveryActions: ["Provide exactly one accessibility audit target"],
                    data: accessibilityFailureData(target: "ambiguous", level: targetLevel)
                )
                let result = MCPToolCallResult(
                    text: JSONFormatter.errorJSON(message: message),
                    structuredContent: await retainedStructuredContent(evidence, modern: modern),
                    isError: true,
                    modern: modern
                )
                let response = JSONRPCResponse(id: request.id, result: result)
                return try? JSONEncoder().encode(response)
            }

            guard await execution.report(progress: 5, message: "Validated accessibility audit request") else {
                return nil
            }

            if let templateName = templateName {
                let started = DispatchTime.now()
                let report = await AccessibilityAuditor.auditTemplate(
                    named: templateName,
                    targetLevel: targetLevel,
                    progress: { value, message in
                        await execution.report(progress: value, message: message)
                    }
                )
                let jsonText = JSONFormatter.encode(report)
                let evidence = accessibilityEvidence(
                    report: report,
                    sourceMode: "rendered",
                    targetType: "template",
                    targetIdentifier: templateName,
                    durationMs: elapsedMilliseconds(since: started)
                )
                let result = MCPToolCallResult(
                    text: jsonText,
                    structuredContent: await retainedStructuredContent(evidence, modern: modern),
                    isError: !report.passed,
                    modern: modern
                )
                guard await execution.report(progress: 100, message: "Accessibility audit complete") else { return nil }
                let response = JSONRPCResponse(id: request.id, result: result)
                return try? JSONEncoder().encode(response)
            } else if let imagePath = imagePath {
                guard let source = CGImageSourceCreateWithURL(URL(fileURLWithPath: imagePath) as CFURL, nil),
                      let image = CGImageSourceCreateImageAtIndex(source, 0, nil) else {
                    let message = "Failed to load image at \(imagePath)"
                    let evidence = operationalErrorEvidence(
                        sourceMode: "screenshot",
                        targetType: "image",
                        targetIdentifier: imagePath,
                        error: MCPStructuredError(code: .invalidInput, message: message),
                        recoveryActions: ["Provide a readable PNG or JPEG image path"],
                        data: accessibilityFailureData(target: imagePath, level: targetLevel)
                    )
                    let result = MCPToolCallResult(
                        text: JSONFormatter.errorJSON(message: message),
                        structuredContent: await retainedStructuredContent(evidence, modern: modern),
                        isError: true,
                        modern: modern
                    )
                    let response = JSONRPCResponse(id: request.id, result: result)
                    return try? JSONEncoder().encode(response)
                }
                let started = DispatchTime.now()
                let report = await AccessibilityAuditor.auditScreenshot(
                    image: image,
                    imageName: (imagePath as NSString).lastPathComponent,
                    targetLevel: targetLevel,
                    progress: { value, message in
                        await execution.report(progress: value, message: message)
                    }
                )
                let jsonText = JSONFormatter.encode(report)
                let evidence = accessibilityEvidence(
                    report: report,
                    sourceMode: "screenshot",
                    targetType: "image",
                    targetIdentifier: imagePath,
                    durationMs: elapsedMilliseconds(since: started)
                )
                let result = MCPToolCallResult(
                    text: jsonText,
                    structuredContent: await retainedStructuredContent(evidence, modern: modern),
                    isError: !report.passed,
                    modern: modern
                )
                guard await execution.report(progress: 100, message: "Accessibility audit complete") else { return nil }
                let response = JSONRPCResponse(id: request.id, result: result)
                return try? JSONEncoder().encode(response)
            } else {
                let result = MCPToolCallResult(text: JSONFormatter.errorJSON(message: "Either 'template' or 'image_path' must be specified for accessibility audit"), isError: true, modern: modern)
                let response = JSONRPCResponse(id: request.id, result: result)
                return try? JSONEncoder().encode(response)
            }

        case "viewlens_design_diff":
            guard let refPath = arguments["reference_image"]?.stringValue,
                  let templateName = arguments["template"]?.stringValue else {
                let message = "Missing required 'reference_image' or 'template' parameter"
                let evidence = operationalErrorEvidence(
                    sourceMode: "designDiff",
                    targetType: "template",
                    targetIdentifier: arguments["template"]?.stringValue ?? "unspecified",
                    error: MCPStructuredError(code: .invalidInput, message: message),
                    recoveryActions: ["Provide reference_image and a registered template"],
                    data: designFailureData(
                        reference: arguments["reference_image"]?.stringValue ?? "unspecified",
                        template: arguments["template"]?.stringValue ?? "unspecified"
                    )
                )
                let result = MCPToolCallResult(
                    text: JSONFormatter.errorJSON(message: message),
                    structuredContent: await retainedStructuredContent(evidence, modern: modern),
                    isError: true,
                    modern: modern
                )
                let response = JSONRPCResponse(id: request.id, result: result)
                return try? JSONEncoder().encode(response)
            }

            guard await execution.report(progress: 5, message: "Validated design verification request") else {
                return nil
            }

            guard let source = CGImageSourceCreateWithURL(URL(fileURLWithPath: refPath) as CFURL, nil),
                  let refImage = CGImageSourceCreateImageAtIndex(source, 0, nil) else {
                let message = "Failed to load reference image at \(refPath)"
                let evidence = operationalErrorEvidence(
                    sourceMode: "designDiff",
                    targetType: "template",
                    targetIdentifier: templateName,
                    error: MCPStructuredError(code: .invalidInput, message: message),
                    recoveryActions: ["Provide a readable PNG or JPEG reference image"],
                    data: designFailureData(reference: refPath, template: templateName)
                )
                let result = MCPToolCallResult(
                    text: JSONFormatter.errorJSON(message: message),
                    structuredContent: await retainedStructuredContent(evidence, modern: modern),
                    isError: true,
                    modern: modern
                )
                let response = JSONRPCResponse(id: request.id, result: result)
                return try? JSONEncoder().encode(response)
            }

            let deviceName = arguments["device"]?.stringValue ?? "iPhone16Pro"
            let profile = DeviceProfile.named(deviceName) ?? .iPhone16Pro
            let ssimThresh = arguments["ssim_threshold"]?.doubleValue ?? 0.98
            let heatmapPath = arguments["heatmap_path"]?.stringValue
            let checkA11y = arguments["check_accessibility"]?.boolValue ?? true

            let started = DispatchTime.now()
            let report = await DesignVerifier.verify(
                referenceImage: refImage,
                referenceSource: (refPath as NSString).lastPathComponent,
                templateName: templateName,
                device: profile,
                thresholdSSIM: ssimThresh,
                includeAccessibility: checkA11y,
                heatmapOutputPath: heatmapPath,
                progress: { value, message in
                    await execution.report(progress: value, message: message)
                }
            )

            let jsonText = JSONFormatter.encode(report)
            var artifacts: [MCPEvidenceEnvelope.Artifact] = []
            var warnings: [String] = []
            if let heatmapPath {
                let expandedPath = (heatmapPath as NSString).expandingTildeInPath
                if FileManager.default.fileExists(atPath: expandedPath) {
                    artifacts.append(.init(kind: "heatmap", path: expandedPath, mediaType: "image/png"))
                } else {
                    warnings.append("Requested heatmap could not be generated")
                }
            }
            var findings = report.tokenMismatches.compactMap { try? JSONValue.fromEncodable($0) }
            findings.append(contentsOf: report.geometryDeltas.compactMap { try? JSONValue.fromEncodable($0) })
            findings.append(contentsOf: report.accessibilityReport?.issues.compactMap { try? JSONValue.fromEncodable($0) } ?? [])
            let visualEvidenceAvailable = report.visualDiff.totalPixelsCount > 0
            let accessibilityComplete = !checkA11y || report.accessibilityReport?.complete == true
            let complete = visualEvidenceAvailable && accessibilityComplete
            var evaluated = visualEvidenceAvailable ? ["visualSimilarity", "pixelDifference"] : []
            if checkA11y, report.accessibilityReport != nil {
                evaluated.append("accessibility")
            }
            var notEvaluated: [String] = []
            if !visualEvidenceAvailable { notEvaluated.append("visualComparison") }
            if !checkA11y { notEvaluated.append("accessibility (not requested)") }
            if checkA11y, report.accessibilityReport?.complete != true { notEvaluated.append("complete accessibility matrix") }
            let evidence = MCPEvidenceEnvelope(
                sourceMode: "designDiff",
                target: .init(type: "template", identifier: templateName),
                completeness: .init(
                    status: complete ? .complete : .partial,
                    evaluated: evaluated,
                    notEvaluated: notEvaluated
                ),
                findings: findings,
                artifacts: artifacts,
                durationMs: elapsedMilliseconds(since: started),
                warnings: warnings,
                recoveryActions: report.passed ? [] : ["Review design and accessibility findings, then rerun verification"],
                data: (try? JSONValue.fromEncodable(report)) ?? designFailureData(reference: refPath, template: templateName),
                error: visualEvidenceAvailable ? nil : MCPStructuredError(
                    code: .unavailableEvidence,
                    message: "The candidate template could not produce visual comparison evidence"
                )
            )
            let result = MCPToolCallResult(
                text: jsonText,
                structuredContent: await retainedStructuredContent(evidence, modern: modern),
                artifacts: artifacts,
                artifactReviewID: evidence.reviewID,
                isError: !report.passed,
                modern: modern
            )
            guard await execution.report(progress: 100, message: "Design verification complete") else { return nil }
            let response = JSONRPCResponse(id: request.id, result: result)
            return try? JSONEncoder().encode(response)

        case "viewlens_destinations_list":
            let workspaceRoot = arguments["workspace_root"]?.stringValue
            let destinations = DestinationDiscovery.discoverDestinations(workspaceRoot: workspaceRoot)
            let destJSON = (try? JSONValue.fromEncodable(destinations)) ?? .array([])
            let jsonText = (try? String(data: JSONEncoder().encode(destinations), encoding: .utf8)) ?? "[]"
            let result = MCPToolCallResult(
                text: jsonText,
                structuredContent: modern ? .object(["destinations": destJSON]) : nil,
                isError: false,
                modern: modern
            )
            let response = JSONRPCResponse(id: request.id, result: result)
            return try? JSONEncoder().encode(response)

        case "viewlens_session_create":
            let workspaceRoot = arguments["workspace_root"]?.stringValue ?? FileManager.default.currentDirectoryPath
            let destID = arguments["destination_id"]?.stringValue
            let bundleID = arguments["bundle_identifier"]?.stringValue
            let ttl = arguments["ttl_seconds"]?.doubleValue ?? RuntimeSessionStore.defaultTTL

            let destinations = DestinationDiscovery.discoverDestinations(workspaceRoot: workspaceRoot)
            guard let destination = DestinationDiscovery.resolveDestination(id: destID, in: destinations) else {
                let message = "Destination '\(destID ?? "default")' not found or unavailable"
                let result = MCPToolCallResult(
                    text: JSONFormatter.errorJSON(message: message),
                    structuredContent: nil,
                    isError: true,
                    modern: modern
                )
                let response = JSONRPCResponse(id: request.id, result: result)
                return try? JSONEncoder().encode(response)
            }

            let session = await sessionStore.createSession(
                destination: destination,
                workspaceRoot: workspaceRoot,
                bundleIdentifier: bundleID,
                ttlSeconds: ttl
            )
            let sessionJSON = (try? JSONValue.fromEncodable(session)) ?? .object([:])
            let jsonText = (try? String(data: JSONEncoder().encode(session), encoding: .utf8)) ?? "{}"
            let result = MCPToolCallResult(
                text: jsonText,
                structuredContent: modern ? sessionJSON : nil,
                isError: false,
                modern: modern
            )
            let response = JSONRPCResponse(id: request.id, result: result)
            return try? JSONEncoder().encode(response)

        case "viewlens_session_get":
            guard let sessionID = arguments["session_id"]?.stringValue else {
                let message = "Missing required 'session_id' parameter"
                let result = MCPToolCallResult(
                    text: JSONFormatter.errorJSON(message: message),
                    structuredContent: nil,
                    isError: true,
                    modern: modern
                )
                let response = JSONRPCResponse(id: request.id, result: result)
                return try? JSONEncoder().encode(response)
            }
            guard let session = await sessionStore.getSession(id: sessionID) else {
                let message = "Session '\(sessionID)' not found or expired"
                let result = MCPToolCallResult(
                    text: JSONFormatter.errorJSON(message: message),
                    structuredContent: nil,
                    isError: true,
                    modern: modern
                )
                let response = JSONRPCResponse(id: request.id, result: result)
                return try? JSONEncoder().encode(response)
            }
            let sessionJSON = (try? JSONValue.fromEncodable(session)) ?? .object([:])
            let jsonText = (try? String(data: JSONEncoder().encode(session), encoding: .utf8)) ?? "{}"
            let result = MCPToolCallResult(
                text: jsonText,
                structuredContent: modern ? sessionJSON : nil,
                isError: false,
                modern: modern
            )
            let response = JSONRPCResponse(id: request.id, result: result)
            return try? JSONEncoder().encode(response)

        case "viewlens_session_close":
            guard let sessionID = arguments["session_id"]?.stringValue else {
                let message = "Missing required 'session_id' parameter"
                let result = MCPToolCallResult(
                    text: JSONFormatter.errorJSON(message: message),
                    structuredContent: nil,
                    isError: true,
                    modern: modern
                )
                let response = JSONRPCResponse(id: request.id, result: result)
                return try? JSONEncoder().encode(response)
            }
            let closed = await sessionStore.closeSession(id: sessionID)
            let status = closed != nil ? "closed" : "not_found"
            let jsonText = "{\"status\": \"\(status)\", \"session_id\": \"\(sessionID)\"}"
            let result = MCPToolCallResult(
                text: jsonText,
                structuredContent: modern ? .object(["status": .string(status), "session_id": .string(sessionID)]) : nil,
                isError: closed == nil,
                modern: modern
            )
            let response = JSONRPCResponse(id: request.id, result: result)
            return try? JSONEncoder().encode(response)

        default:
            let response = JSONRPCResponse<String>(
                id: request.id,
                error: JSONRPCError(code: -32601, message: "Unknown tool: \(toolName)")
            )
            return try? JSONEncoder().encode(response)
        }
    }

    private func retainedStructuredContent(_ evidence: MCPEvidenceEnvelope, modern: Bool) async -> JSONValue? {
        guard modern else { return nil }
        await resourceStore.record(evidence)
        return evidence.jsonValue
    }

    private func elapsedMilliseconds(since start: DispatchTime) -> Double {
        let nanoseconds = DispatchTime.now().uptimeNanoseconds - start.uptimeNanoseconds
        return Double(nanoseconds) / 1_000_000
    }

    private func operationalErrorEvidence(
        sourceMode: String,
        targetType: String,
        targetIdentifier: String,
        error: MCPStructuredError,
        recoveryActions: [String],
        data: JSONValue,
        durationMs: Double = 0
    ) -> MCPEvidenceEnvelope {
        MCPEvidenceEnvelope(
            sourceMode: sourceMode,
            target: .init(type: targetType, identifier: targetIdentifier),
            completeness: .init(status: .unavailable, evaluated: [], notEvaluated: ["requestedEvidence"]),
            durationMs: durationMs,
            recoveryActions: recoveryActions,
            data: data,
            error: error
        )
    }

    private func matrixFailureData(template: String) -> JSONValue {
        .object([
            "sourceMode": .string("rendered"),
            "template": .string(template),
            "passed": .bool(false),
            "summary": .object([
                "totalPermutations": .number(0),
                "passedCount": .number(0),
                "failedCount": .number(0),
                "worstIssue": .null,
                "failedPermutations": .array([])
            ]),
            "permutations": .object([:])
        ])
    }

    private func accessibilityFailureData(target: String, level: String) -> JSONValue {
        .object([
            "target": .string(target),
            "targetLevel": .string(level),
            "overallComplianceScore": .number(0),
            "passed": .bool(false),
            "complete": .bool(false),
            "criteria": .array([]),
            "issues": .array([]),
            "metrics": .object([:]),
            "timestamp": .string(ISO8601DateFormatter().string(from: Date()))
        ])
    }

    private func designFailureData(reference: String, template: String) -> JSONValue {
        .object([
            "referenceSource": .string(reference),
            "candidateTemplate": .string(template),
            "visualDiff": .object([
                "ssimScore": .number(0),
                "mismatchPercentage": .number(100),
                "differingPixelsCount": .number(0),
                "totalPixelsCount": .number(0),
                "passed": .bool(false),
                "tolerance": .number(0.05)
            ]),
            "tokenMismatches": .array([]),
            "geometryDeltas": .array([]),
            "passed": .bool(false),
            "timestamp": .string(ISO8601DateFormatter().string(from: Date()))
        ])
    }

    private func accessibilityEvidence(
        report: AccessibilityReport,
        sourceMode: String,
        targetType: String,
        targetIdentifier: String,
        durationMs: Double
    ) -> MCPEvidenceEnvelope {
        let evaluated = report.criteria.filter(\.evaluated).map(\.criterion)
        let notEvaluated = report.criteria.filter { !$0.evaluated }.map(\.criterion)
        return MCPEvidenceEnvelope(
            sourceMode: sourceMode,
            target: .init(type: targetType, identifier: targetIdentifier),
            completeness: .init(
                status: report.complete ? .complete : .partial,
                evaluated: evaluated,
                notEvaluated: notEvaluated
            ),
            findings: report.issues.compactMap { try? JSONValue.fromEncodable($0) },
            durationMs: durationMs,
            recoveryActions: report.passed ? [] : ["Apply the supplied remediation and rerun the WCAG audit"],
            data: (try? JSONValue.fromEncodable(report)) ?? accessibilityFailureData(
                target: targetIdentifier,
                level: report.targetLevel
            ),
            error: report.complete ? nil : MCPStructuredError(
                code: .unavailableEvidence,
                message: "One or more requested accessibility criteria could not be evaluated"
            )
        )
    }

    private func screenshotErrorEvidence(
        imagePath: String,
        error: MCPStructuredError,
        durationMs: Double = 0,
        warnings: [String] = [],
        recoveryActions: [String]
    ) -> MCPEvidenceEnvelope {
        let failureData: JSONValue = .object([
            "sourceMode": .string("screenshot"),
            "image": .string(imagePath),
            "elements": .array([]),
            "issues": .array([]),
            "passed": .bool(false),
            "summary": .object([
                "totalElements": .number(0),
                "totalIssues": .number(0),
                "errorCount": .number(0),
                "warningCount": .number(0),
                "worstIssue": .null
            ])
        ])

        return MCPEvidenceEnvelope(
            sourceMode: "screenshot",
            target: .init(type: "image", identifier: imagePath),
            completeness: .init(
                status: .unavailable,
                evaluated: [],
                notEvaluated: ["visualDetection", "layoutRules"]
            ),
            durationMs: durationMs,
            warnings: warnings,
            recoveryActions: recoveryActions,
            data: failureData,
            error: error
        )
    }

    private func runDoctor(customPath: String?) -> DoctorReport {
        var checks: [DiagnosticCheck] = []
        var allPassed = true

        let modelResult = ModelLocator.resolve(customPath: customPath)
        let resolvedURL: URL?

        switch modelResult {
        case .success(let url):
            resolvedURL = url
            checks.append(DiagnosticCheck(name: "model_found", status: "confirmed", detail: url.path))
        case .failure(let error):
            resolvedURL = nil
            allPassed = false
            checks.append(DiagnosticCheck(name: "model_found", status: "failed", detail: error.localizedDescription))
        }

        if let url = resolvedURL {
            do {
                let sizeBytes = try ModelLocator.calculateSize(at: url)
                let sizeMB = Double(sizeBytes) / (1024.0 * 1024.0)
                let formattedMB = String(format: "%.1fMB", sizeMB)

                if sizeMB <= ModelLocator.maxExpectedSizeMB && sizeMB > 0.1 {
                    checks.append(DiagnosticCheck(name: "model_size", status: "confirmed", detail: "\(formattedMB) (< \(Int(ModelLocator.maxExpectedSizeMB))MB)"))
                } else {
                    allPassed = false
                    checks.append(DiagnosticCheck(name: "model_size", status: "failed", detail: "\(formattedMB) exceeds expectation"))
                }
            } catch {
                allPassed = false
                checks.append(DiagnosticCheck(name: "model_size", status: "failed", detail: error.localizedDescription))
            }
        } else {
            checks.append(DiagnosticCheck(name: "model_size", status: "skipped", detail: "Model not found"))
        }

        if let url = resolvedURL {
            let start = DispatchTime.now()
            do {
                _ = try YOLODetector(modelURL: url)
                let end = DispatchTime.now()
                let elapsedSeconds = Double(end.uptimeNanoseconds - start.uptimeNanoseconds) / 1_000_000_000.0
                checks.append(DiagnosticCheck(name: "model_loads", status: "confirmed", detail: String(format: "Cold load: %.2fs", elapsedSeconds)))
            } catch {
                allPassed = false
                checks.append(DiagnosticCheck(name: "model_loads", status: "failed", detail: error.localizedDescription))
            }
        } else {
            checks.append(DiagnosticCheck(name: "model_loads", status: "skipped", detail: "Model not found"))
        }

        let overallStatus = allPassed ? "ready" : "not_ready"
        let nextCommand = allPassed ? "viewlens scan <image-path>" : "export VIEWLENS_MODEL_PATH=/path/to/best.mlpackage"

        return DoctorReport(status: overallStatus, checks: checks, recommendedNextCommand: nextCommand)
    }

    private func runAuditScreenshot(
        imagePath: String,
        minConfidence: Float,
        scale: Double?,
        overlayPath: String?,
        modelPath: String?,
        execution: MCPExecutionContext
    ) async -> ScreenshotAuditExecution? {
        let expanded = (imagePath as NSString).expandingTildeInPath
        let imageURL = URL(fileURLWithPath: expanded)

        guard let imageSource = CGImageSourceCreateWithURL(imageURL as CFURL, nil),
              let cgImage = CGImageSourceCreateImageAtIndex(imageSource, 0, nil) else {
            let message = "Cannot load image at '\(imagePath)'"
            return ScreenshotAuditExecution(
                jsonText: JSONFormatter.errorJSON(message: message),
                success: false,
                report: nil,
                error: MCPStructuredError(code: .invalidInput, message: message),
                artifacts: [],
                warnings: []
            )
        }
        guard await execution.report(progress: 15, message: "Loaded screenshot image") else { return nil }

        let modelURL: URL
        switch ModelLocator.resolve(customPath: modelPath) {
        case .success(let url):
            modelURL = url
        case .failure(let error):
            return ScreenshotAuditExecution(
                jsonText: JSONFormatter.errorJSON(message: error.localizedDescription, nextCommand: "viewlens doctor"),
                success: false,
                report: nil,
                error: MCPStructuredError(code: .unavailableEvidence, message: error.localizedDescription),
                artifacts: [],
                warnings: []
            )
        }
        guard await execution.report(progress: 30, message: "Resolved CoreML model") else { return nil }

        let detector: YOLODetector
        do {
            detector = try YOLODetector(modelURL: modelURL)
        } catch {
            let message = "Failed to initialize detector: \(error.localizedDescription)"
            return ScreenshotAuditExecution(
                jsonText: JSONFormatter.errorJSON(message: message),
                success: false,
                report: nil,
                error: MCPStructuredError(code: .runtimeFailure, message: message),
                artifacts: [],
                warnings: []
            )
        }
        guard await execution.report(progress: 40, message: "Initialized visual detector") else { return nil }

        let imgWidth = Double(cgImage.width)
        let imgHeight = Double(cgImage.height)
        let imgSize = CGSize(width: imgWidth, height: imgHeight)
        let resolvedScale = scale ?? IssueClassifier.inferDisplayScale(imageWidth: imgWidth)

        let detectedElements: [DetectedElement]
        do {
            guard await execution.report(progress: 50, message: "Running visual inference") else { return nil }
            detectedElements = try await detector.detect(image: cgImage, minConfidence: minConfidence)
        } catch {
            let message = "Inference failed: \(error.localizedDescription)"
            return ScreenshotAuditExecution(
                jsonText: JSONFormatter.errorJSON(message: message),
                success: false,
                report: nil,
                error: MCPStructuredError(code: .runtimeFailure, message: message),
                artifacts: [],
                warnings: []
            )
        }
        guard await execution.report(progress: 72, message: "Visual inference complete") else { return nil }

        let issues = IssueClassifier.classify(elements: detectedElements, imageSize: imgSize, scale: resolvedScale)
        guard await execution.report(progress: 84, message: "Classified HIG and WCAG findings") else { return nil }
        let report = AuditReport(
            sourceMode: .screenshot,
            image: imagePath,
            dimensions: AuditDimensions(width: imgWidth, height: imgHeight, scale: resolvedScale),
            elements: detectedElements,
            issues: issues
        )

        var artifacts: [MCPEvidenceEnvelope.Artifact] = []
        var warnings: [String] = []
        if let overlayPath = overlayPath {
            guard await execution.report(progress: 90, message: "Rendering audit overlay") else { return nil }
            if let annotated = OverlayRenderer.render(image: cgImage, elements: detectedElements, issues: issues) {
                let outURL = URL(fileURLWithPath: (overlayPath as NSString).expandingTildeInPath)
                do {
                    try OverlayRenderer.write(image: annotated, to: outURL)
                    artifacts.append(.init(kind: "overlay", path: outURL.path, mediaType: "image/png"))
                } catch {
                    warnings.append("Overlay could not be written: \(error.localizedDescription)")
                }
            } else {
                warnings.append("Overlay could not be rendered")
            }
        }
        guard await execution.report(progress: 96, message: "Assembling screenshot evidence") else { return nil }

        return ScreenshotAuditExecution(
            jsonText: JSONFormatter.encode(report),
            success: report.passed,
            report: report,
            error: nil,
            artifacts: artifacts,
            warnings: warnings
        )
    }

    private func runAuditView(
        templateName: String,
        deviceNames: [String],
        dtSizes: [String],
        schemes: [String],
        execution: MCPExecutionContext
    ) async -> MatrixAuditExecution? {
        var detector: YOLODetector? = nil
        if let modelURL = try? ModelLocator.resolve().get() {
            detector = try? YOLODetector(modelURL: modelURL)
        }
        guard await execution.report(progress: 10, message: "Prepared render matrix detector") else { return nil }

        do {
            let matrixReport = try await MatrixRenderer.auditNamedTemplate(
                templateName: templateName,
                deviceNames: deviceNames,
                dtSizes: dtSizes,
                schemes: schemes,
                detector: detector,
                progress: { completed, total, key in
                    let fraction = total == 0 ? 1 : Double(completed) / Double(total)
                    return await execution.report(
                        progress: 10 + (fraction * 84),
                        message: "Audited render permutation \(key) (\(completed)/\(total))"
                    )
                }
            )
            return MatrixAuditExecution(
                jsonText: JSONFormatter.encode(matrixReport),
                passed: matrixReport.passed,
                report: matrixReport,
                error: nil
            )
        } catch {
            let available = await MainActor.run {
                TemplateRegistry.shared.availableTemplates.joined(separator: ", ")
            }
            return MatrixAuditExecution(
                jsonText: JSONFormatter.errorJSON(
                    message: error.localizedDescription,
                    detail: "Available templates: \(available)",
                    nextCommand: "viewlens render --list-templates"
                ),
                passed: false,
                report: nil,
                error: MCPStructuredError(code: .invalidInput, message: error.localizedDescription)
            )
        }
    }
}
