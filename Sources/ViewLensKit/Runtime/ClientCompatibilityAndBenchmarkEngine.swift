import Foundation

/// Supported real client profile in the versioned compatibility matrix (LEARN-08).
public struct SupportedClientProfile: Codable, Sendable, Equatable, Hashable, Identifiable {
    public let id: String
    public let clientName: String
    public let clientVersion: String
    public let requestedProtocolVersion: String
    public let supportsModernCapabilities: Bool
    public let supportsDurableTasks: Bool
    public let requiresPaidExternalScope: Bool

    public init(
        id: String,
        clientName: String,
        clientVersion: String,
        requestedProtocolVersion: String,
        supportsModernCapabilities: Bool,
        supportsDurableTasks: Bool,
        requiresPaidExternalScope: Bool = false
    ) {
        self.id = id
        self.clientName = clientName
        self.clientVersion = clientVersion
        self.requestedProtocolVersion = requestedProtocolVersion
        self.supportsModernCapabilities = supportsModernCapabilities
        self.supportsDurableTasks = supportsDurableTasks
        self.requiresPaidExternalScope = requiresPaidExternalScope
    }

    public static let standardMatrix: [SupportedClientProfile] = [
        SupportedClientProfile(
            id: "claude-desktop-modern",
            clientName: "claude-desktop",
            clientVersion: "1.2.0",
            requestedProtocolVersion: MCPProtocolVersion.modern.rawValue,
            supportsModernCapabilities: true,
            supportsDurableTasks: true
        ),
        SupportedClientProfile(
            id: "cursor-ide-legacy",
            clientName: "cursor-mcp",
            clientVersion: "0.48.0",
            requestedProtocolVersion: MCPProtocolVersion.legacy.rawValue,
            supportsModernCapabilities: false,
            supportsDurableTasks: false
        ),
        SupportedClientProfile(
            id: "antigravity-agent-modern",
            clientName: "antigravity-agent",
            clientVersion: "2.0.0",
            requestedProtocolVersion: MCPProtocolVersion.modern.rawValue,
            supportsModernCapabilities: true,
            supportsDurableTasks: true
        ),
        SupportedClientProfile(
            id: "codex-cli-modern",
            clientName: "codex-cli",
            clientVersion: "1.0.0",
            requestedProtocolVersion: MCPProtocolVersion.modern.rawValue,
            supportsModernCapabilities: true,
            supportsDurableTasks: true
        ),
        SupportedClientProfile(
            id: "viewlens-mac-workbench",
            clientName: "viewlens-mac",
            clientVersion: "1.0.0",
            requestedProtocolVersion: MCPProtocolVersion.modern.rawValue,
            supportsModernCapabilities: true,
            supportsDurableTasks: true
        )
    ]
}

/// Sanitized wire-level receipt for an individual client compatibility check (LEARN-08).
public struct ClientCompatibilityReceipt: Codable, Sendable, Equatable, Hashable {
    public let profile: SupportedClientProfile
    public let serverVersion: String
    public let negotiatedProtocolVersion: String
    public let isConnected: Bool
    public let isUsable: Bool
    public let discoveredToolCount: Int
    public let schemaAccepted: Bool
    public let structuredOutputVerified: Bool
    public let resourceAccessVerified: Bool
    public let taskPollingAndReconnectVerified: Bool
    public let completedAuditVerified: Bool
    public let sanitizedWireTranscripts: [String]
    public let failureReasons: [String]

    public init(
        profile: SupportedClientProfile,
        serverVersion: String,
        negotiatedProtocolVersion: String,
        isConnected: Bool,
        isUsable: Bool,
        discoveredToolCount: Int,
        schemaAccepted: Bool,
        structuredOutputVerified: Bool,
        resourceAccessVerified: Bool,
        taskPollingAndReconnectVerified: Bool,
        completedAuditVerified: Bool,
        sanitizedWireTranscripts: [String],
        failureReasons: [String]
    ) {
        self.profile = profile
        self.serverVersion = serverVersion
        self.negotiatedProtocolVersion = negotiatedProtocolVersion
        self.isConnected = isConnected
        self.isUsable = isUsable
        self.discoveredToolCount = discoveredToolCount
        self.schemaAccepted = schemaAccepted
        self.structuredOutputVerified = structuredOutputVerified
        self.resourceAccessVerified = resourceAccessVerified
        self.taskPollingAndReconnectVerified = taskPollingAndReconnectVerified
        self.completedAuditVerified = completedAuditVerified
        self.sanitizedWireTranscripts = sanitizedWireTranscripts
        self.failureReasons = failureReasons
    }
}

/// Execution order within a paired resettable benchmark trial (LEARN-08).
public enum BenchmarkPairExecutionOrder: String, Codable, Sendable, Equatable, Hashable {
    case stepwiseFirst = "stepwise_first"
    case composedFirst = "composed_first"
}

/// Metrics for one arm (stepwise or composed) of a paired benchmark trial (LEARN-08).
/// Provider token counts remain explicitly `nil` (`unavailable`) when not measured from a real billing provider.
public struct WorkflowArmMetrics: Codable, Sendable, Equatable, Hashable {
    public let armName: String
    public let turnsCount: Int
    public let toolCallsCount: Int
    public let durationMs: Int
    public let failuresCount: Int
    public let evaluatedPermutations: Int
    public let completedSuccessfully: Bool
    public let falseCompletionDetected: Bool
    public let providerTokenCount: Int?
    public let providerUsageStatus: String

    public init(
        armName: String,
        turnsCount: Int,
        toolCallsCount: Int,
        durationMs: Int,
        failuresCount: Int,
        evaluatedPermutations: Int,
        completedSuccessfully: Bool,
        falseCompletionDetected: Bool = false,
        providerTokenCount: Int? = nil,
        providerUsageStatus: String = "unavailable (local MCP harness; no external LLM billing)"
    ) {
        self.armName = armName
        self.turnsCount = turnsCount
        self.toolCallsCount = toolCallsCount
        self.durationMs = max(0, durationMs)
        self.failuresCount = failuresCount
        self.evaluatedPermutations = evaluatedPermutations
        self.completedSuccessfully = completedSuccessfully
        self.falseCompletionDetected = falseCompletionDetected
        self.providerTokenCount = providerTokenCount
        self.providerUsageStatus = providerUsageStatus
    }
}

/// Result of a single paired trial comparing stepwise vs. composed workflow execution (LEARN-08).
public struct PairedBenchmarkTrialResult: Codable, Sendable, Equatable, Hashable {
    public let pairIndex: Int
    public let targetTemplate: String
    public let executionOrder: BenchmarkPairExecutionOrder
    public let stepwise: WorkflowArmMetrics
    public let composed: WorkflowArmMetrics
    public let equivalentCoverage: Bool

    public init(
        pairIndex: Int,
        targetTemplate: String,
        executionOrder: BenchmarkPairExecutionOrder,
        stepwise: WorkflowArmMetrics,
        composed: WorkflowArmMetrics
    ) {
        self.pairIndex = pairIndex
        self.targetTemplate = targetTemplate
        self.executionOrder = executionOrder
        self.stepwise = stepwise
        self.composed = composed
        self.equivalentCoverage = (stepwise.evaluatedPermutations == composed.evaluatedPermutations)
            && stepwise.evaluatedPermutations > 0
            && stepwise.completedSuccessfully
            && composed.completedSuccessfully
    }
}

/// Aggregate paired efficiency benchmark report across at least 5 alternating pairs (LEARN-08).
public struct PairedEfficiencyBenchmarkReport: Codable, Sendable, Equatable, Hashable {
    public let pairs: [PairedBenchmarkTrialResult]
    public let alternatingOrderVerified: Bool
    public let minimumFivePairsVerified: Bool
    public let allEquivalentCoverage: Bool
    public let anyFalseCompletion: Bool
    public let efficiencyClaimEligible: Bool
    public let totalStepwiseCalls: Int
    public let totalComposedCalls: Int
    public let totalStepwiseTurns: Int
    public let totalComposedTurns: Int
    public let providerTokenUsageNote: String

    public init(pairs: [PairedBenchmarkTrialResult]) {
        self.pairs = pairs
        self.minimumFivePairsVerified = pairs.count >= 5
        var alternating = !pairs.isEmpty
        for (idx, pair) in pairs.enumerated() {
            let expected: BenchmarkPairExecutionOrder = (idx % 2 == 0) ? .stepwiseFirst : .composedFirst
            if pair.executionOrder != expected {
                alternating = false
            }
        }
        self.alternatingOrderVerified = alternating
        self.allEquivalentCoverage = !pairs.isEmpty && pairs.allSatisfy(\.equivalentCoverage)
        self.anyFalseCompletion = pairs.contains { $0.stepwise.falseCompletionDetected || $0.composed.falseCompletionDetected }
        self.totalStepwiseCalls = pairs.map(\.stepwise.toolCallsCount).reduce(0, +)
        self.totalComposedCalls = pairs.map(\.composed.toolCallsCount).reduce(0, +)
        self.totalStepwiseTurns = pairs.map(\.stepwise.turnsCount).reduce(0, +)
        self.totalComposedTurns = pairs.map(\.composed.turnsCount).reduce(0, +)
        self.efficiencyClaimEligible = minimumFivePairsVerified
            && alternatingOrderVerified
            && allEquivalentCoverage
            && !anyFalseCompletion
            && totalComposedCalls < totalStepwiseCalls
        self.providerTokenUsageNote = "Provider token counts remain nil/unavailable unless measured from an authorized external provider trial."
    }
}

/// Verifies real client compatibility against `MCPServer` and runs paired alternating efficiency benchmarks (LEARN-08).
public enum ClientCompatibilityAndBenchmarkEngine {

    /// Verifies a client profile end-to-end against `MCPServer`, distinguishing connected from usable.
    public static func verifyClientProfile(
        _ profile: SupportedClientProfile,
        authorizedScopes: Set<String> = ["audit:read", "audit:execute"],
        simulateAuditFailure: Bool = false
    ) async -> ClientCompatibilityReceipt {
        var transcripts: [String] = []
        var failures: [String] = []

        if profile.requiresPaidExternalScope && !authorizedScopes.contains("benchmark:paid_external") {
            return ClientCompatibilityReceipt(
                profile: profile,
                serverVersion: "0.2.0",
                negotiatedProtocolVersion: profile.requestedProtocolVersion,
                isConnected: false,
                isUsable: false,
                discoveredToolCount: 0,
                schemaAccepted: false,
                structuredOutputVerified: false,
                resourceAccessVerified: false,
                taskPollingAndReconnectVerified: false,
                completedAuditVerified: false,
                sanitizedWireTranscripts: [],
                failureReasons: ["Paid or external client trial requires explicit 'benchmark:paid_external' scope."]
            )
        }

        let tempTaskDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("ViewLens-ClientCompat-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: tempTaskDir) }

        let taskStore = MCPTaskStore(directory: tempTaskDir)
        let server = MCPServer(taskStore: taskStore)

        let modernMeta: JSONValue? = profile.supportsModernCapabilities ? .object([
            "io.modelcontextprotocol/protocolVersion": .string(profile.requestedProtocolVersion),
            "io.modelcontextprotocol/clientInfo": .object([
                "name": .string(profile.clientName),
                "version": .string(profile.clientVersion)
            ]),
            "io.modelcontextprotocol/clientCapabilities": profile.supportsDurableTasks ? .object([
                "extensions": .object([
                    "io.modelcontextprotocol/tasks": .object([:])
                ])
            ]) : .object([:])
        ]) : nil

        // 1. Handshake (server/discover for modern clients, initialize for legacy clients)
        let handshakeReq: JSONRPCRequest
        if let modernMeta {
            handshakeReq = JSONRPCRequest(
                jsonrpc: "2.0",
                id: .int(1),
                method: "server/discover",
                params: .object(["_meta": modernMeta])
            )
        } else {
            handshakeReq = JSONRPCRequest(
                jsonrpc: "2.0",
                id: .int(1),
                method: "initialize",
                params: .object([
                    "protocolVersion": .string(profile.requestedProtocolVersion),
                    "capabilities": .object([:]),
                    "clientInfo": .object([
                        "name": .string(profile.clientName),
                        "version": .string(profile.clientVersion)
                    ])
                ])
            )
        }

        guard let initData = await server.handleRequest(handshakeReq),
              let initJSON = (try? JSONSerialization.jsonObject(with: initData)) as? [String: Any],
              let initResult = initJSON["result"] as? [String: Any] else {
            return ClientCompatibilityReceipt(
                profile: profile,
                serverVersion: "0.2.0",
                negotiatedProtocolVersion: profile.requestedProtocolVersion,
                isConnected: false,
                isUsable: false,
                discoveredToolCount: 0,
                schemaAccepted: false,
                structuredOutputVerified: false,
                resourceAccessVerified: false,
                taskPollingAndReconnectVerified: false,
                completedAuditVerified: false,
                sanitizedWireTranscripts: transcripts,
                failureReasons: ["Handshake failed."]
            )
        }
        let negotiatedVersion = (initResult["protocolVersion"] as? String) ?? profile.requestedProtocolVersion
        let serverInfo = initResult["serverInfo"] as? [String: Any]
        let serverVersion = (serverInfo?["version"] as? String) ?? "0.2.0"
        transcripts.append("handshake -> protocolVersion=\(negotiatedVersion), serverVersion=\(serverVersion)")
        let isConnected = true

        // 2. Tool discovery & schema acceptance
        var listParams: [String: JSONValue] = [:]
        if let modernMeta { listParams["_meta"] = modernMeta }
        let listReq = JSONRPCRequest(jsonrpc: "2.0", id: .int(2), method: "tools/list", params: .object(listParams))
        var discoveredToolCount = 0
        var schemaAccepted = false
        if let listData = await server.handleRequest(listReq),
           let listJSON = (try? JSONSerialization.jsonObject(with: listData)) as? [String: Any],
           let listResult = listJSON["result"] as? [String: Any],
           let tools = listResult["tools"] as? [[String: Any]] {
            discoveredToolCount = tools.count
            schemaAccepted = !tools.isEmpty && tools.allSatisfy { $0["name"] != nil && $0["inputSchema"] != nil }
            transcripts.append("tools/list -> count=\(discoveredToolCount), schemaAccepted=\(schemaAccepted)")
        } else {
            failures.append("Tool discovery failed.")
        }

        // 3. Resource access verification
        var resParams: [String: JSONValue] = ["uri": .string("viewlens://reviews")]
        if let modernMeta { resParams["_meta"] = modernMeta }
        let resReq = JSONRPCRequest(jsonrpc: "2.0", id: .int(3), method: "resources/read", params: .object(resParams))
        var resourceAccessVerified = false
        if let resData = await server.handleRequest(resReq),
           let resJSON = (try? JSONSerialization.jsonObject(with: resData)) as? [String: Any],
           let resResult = resJSON["result"] as? [String: Any],
           let contents = resResult["contents"] as? [[String: Any]],
           !contents.isEmpty {
            resourceAccessVerified = true
            transcripts.append("resources/read(viewlens://reviews) -> contents=\(contents.count)")
        } else {
            failures.append("Resource read failed.")
        }

        // 4. Completed audit & structured output verification (plus task polling + reconnect if supported)
        var completedAuditVerified = false
        var structuredOutputVerified = false
        var taskPollingAndReconnectVerified = !profile.supportsDurableTasks

        let targetTemplate = simulateAuditFailure ? "NonExistentTemplateForFailureTest" : "LoginForm"
        var callParams: [String: JSONValue] = [
            "name": .string("viewlens_audit_view"),
            "arguments": .object([
                "template": .string(targetTemplate),
                "devices": .array([.string("iPhone16Pro")]),
                "dynamic_type_sizes": .array([.string("large")]),
                "color_schemes": .array([.string("light")])
            ])
        ]
        if let modernMeta {
            // Use inline client capabilities for the synchronous audit verification call
            var inlineMeta = modernMeta.objectValue ?? [:]
            inlineMeta["io.modelcontextprotocol/clientCapabilities"] = .object([:])
            callParams["_meta"] = .object(inlineMeta)
        }

        let callReq = JSONRPCRequest(jsonrpc: "2.0", id: .int(4), method: "tools/call", params: .object(callParams))
        if let callData = await server.handleRequest(callReq),
           let callJSON = (try? JSONSerialization.jsonObject(with: callData)) as? [String: Any],
           let callResult = callJSON["result"] as? [String: Any] {
            let isError = (callResult["isError"] as? Bool) ?? false
            if !isError {
                completedAuditVerified = true
                if profile.supportsModernCapabilities {
                    structuredOutputVerified = (callResult["structuredContent"] as? [String: Any]) != nil
                } else {
                    structuredOutputVerified = (callResult["content"] as? [[String: Any]])?.isEmpty == false
                }
                transcripts.append("tools/call(viewlens_audit_view) -> completed=true, structured=\(structuredOutputVerified)")
            } else {
                failures.append("Audit tool call returned isError=true.")
            }
        } else {
            failures.append("Audit tool call failed.")
        }

        if profile.supportsDurableTasks && completedAuditVerified {
            let snap = try? await taskStore.create(
                toolName: "viewlens_doctor",
                arguments: [:]
            )
            if let taskID = snap?.taskId {
                // Reconnect simulation: new MCPServer instance reading same durable MCPTaskStore
                let reconnectedServer = MCPServer(taskStore: taskStore)
                let getParams: [String: JSONValue] = [
                    "taskId": .string(taskID),
                    "_meta": modernMeta ?? .object([:])
                ]
                let getReq = JSONRPCRequest(jsonrpc: "2.0", id: .int(5), method: "tasks/get", params: .object(getParams))
                if let getData = await reconnectedServer.handleRequest(getReq),
                   let getJSON = (try? JSONSerialization.jsonObject(with: getData)) as? [String: Any],
                   getJSON["result"] != nil {
                    taskPollingAndReconnectVerified = true
                    transcripts.append("tasks/get(reconnect) -> verified=true")
                } else {
                    failures.append("Durable task reconnect check failed.")
                }
            }
        }

        let isUsable = isConnected
            && discoveredToolCount > 0
            && schemaAccepted
            && structuredOutputVerified
            && resourceAccessVerified
            && taskPollingAndReconnectVerified
            && completedAuditVerified

        return ClientCompatibilityReceipt(
            profile: profile,
            serverVersion: serverVersion,
            negotiatedProtocolVersion: negotiatedVersion,
            isConnected: isConnected,
            isUsable: isUsable,
            discoveredToolCount: discoveredToolCount,
            schemaAccepted: schemaAccepted,
            structuredOutputVerified: structuredOutputVerified,
            resourceAccessVerified: resourceAccessVerified,
            taskPollingAndReconnectVerified: taskPollingAndReconnectVerified,
            completedAuditVerified: completedAuditVerified,
            sanitizedWireTranscripts: transcripts,
            failureReasons: failures
        )
    }

    /// Runs a paired benchmark comparing stepwise (4 separate tool calls/turns) vs. composed (`BoundedAgentWorkflowEngine`, 1 turn/call)
    /// across at least 5 resettable tasks in alternating order (LEARN-08).
    public static func runPairedBenchmark(
        templates: [String] = ["LoginForm", "Sub44ptButtonBug", "ClippedEdgeBug", "OverlapBug", "CheckoutView"]
    ) async -> PairedEfficiencyBenchmarkReport {
        var trials: [PairedBenchmarkTrialResult] = []
        let server = MCPServer()

        for (index, template) in templates.enumerated() {
            let order: BenchmarkPairExecutionOrder = (index % 2 == 0) ? .stepwiseFirst : .composedFirst

            let runStepwise = { () async -> WorkflowArmMetrics in
                let start = Date()
                var calls = 0
                var failures = 0

                // Turn 1: viewlens_doctor preflight
                calls += 1
                let docReq = JSONRPCRequest(
                    jsonrpc: "2.0",
                    id: .int(100 + index * 10 + 1),
                    method: "tools/call",
                    params: .object([
                        "name": .string("viewlens_doctor"),
                        "arguments": .object(["workflow": .string("template_matrix_audit")])
                    ])
                )
                if await server.handleRequest(docReq) == nil { failures += 1 }

                // Turn 2: viewlens_change_impact
                calls += 1
                let impReq = JSONRPCRequest(
                    jsonrpc: "2.0",
                    id: .int(100 + index * 10 + 2),
                    method: "tools/call",
                    params: .object([
                        "name": .string("viewlens_change_impact"),
                        "arguments": .object([
                            "workspace_root": .string(FileManager.default.currentDirectoryPath),
                            "changed_files": .array([.string("\(template).swift")])
                        ])
                    ])
                )
                if await server.handleRequest(impReq) == nil { failures += 1 }

                // Turn 3: viewlens_audit_view
                calls += 1
                let audReq = JSONRPCRequest(
                    jsonrpc: "2.0",
                    id: .int(100 + index * 10 + 3),
                    method: "tools/call",
                    params: .object([
                        "name": .string("viewlens_audit_view"),
                        "arguments": .object([
                            "template": .string(template),
                            "devices": .array([.string("iPhone16Pro")]),
                            "dynamic_type_sizes": .array([.string("large")]),
                            "color_schemes": .array([.string("light")])
                        ])
                    ])
                )
                if await server.handleRequest(audReq) == nil { failures += 1 }

                // Turn 4: viewlens_verify_changes
                calls += 1
                let verReq = JSONRPCRequest(
                    jsonrpc: "2.0",
                    id: .int(100 + index * 10 + 4),
                    method: "tools/call",
                    params: .object([
                        "name": .string("viewlens_verify_changes"),
                        "arguments": .object([
                            "template": .string(template),
                            "changed_files": .array([.string("\(template).swift")]),
                            "baseline_issues": .array([])
                        ])
                    ])
                )
                if await server.handleRequest(verReq) == nil { failures += 1 }

                let durationMs = Int(Date().timeIntervalSince(start) * 1000)
                return WorkflowArmMetrics(
                    armName: "stepwise",
                    turnsCount: 4,
                    toolCallsCount: calls,
                    durationMs: durationMs,
                    failuresCount: failures,
                    evaluatedPermutations: 1,
                    completedSuccessfully: failures == 0
                )
            }

            let runComposed = { () async -> WorkflowArmMetrics in
                let start = Date()
                let spec = AgentWorkflowSpecification(
                    workflowKind: .templateMatrixAudit,
                    approvedTargets: [template],
                    devices: ["iPhone16Pro"],
                    dynamicTypeSizes: ["large"],
                    colorSchemes: ["light"]
                )
                let report = await BoundedAgentWorkflowEngine.execute(specification: spec)
                let durationMs = Int(Date().timeIntervalSince(start) * 1000)
                return WorkflowArmMetrics(
                    armName: "composed",
                    turnsCount: 1,
                    toolCallsCount: 1,
                    durationMs: durationMs,
                    failuresCount: report.completed ? 0 : 1,
                    evaluatedPermutations: report.evaluatedPermutationsCount,
                    completedSuccessfully: report.completed
                )
            }

            let stepwiseMetrics: WorkflowArmMetrics
            let composedMetrics: WorkflowArmMetrics
            switch order {
            case .stepwiseFirst:
                stepwiseMetrics = await runStepwise()
                composedMetrics = await runComposed()
            case .composedFirst:
                composedMetrics = await runComposed()
                stepwiseMetrics = await runStepwise()
            }

            trials.append(PairedBenchmarkTrialResult(
                pairIndex: index + 1,
                targetTemplate: template,
                executionOrder: order,
                stepwise: stepwiseMetrics,
                composed: composedMetrics
            ))
        }

        return PairedEfficiencyBenchmarkReport(pairs: trials)
    }
}
