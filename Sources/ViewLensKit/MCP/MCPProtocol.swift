import Foundation

// MARK: - JSON-RPC 2.0 Base Protocol

public struct JSONRPCRequest: Codable, Sendable {
    public let jsonrpc: String
    public let id: RequestID?
    public let method: String
    public let params: JSONValue?

    public init(jsonrpc: String = "2.0", id: RequestID?, method: String, params: JSONValue? = nil) {
        self.jsonrpc = jsonrpc
        self.id = id
        self.method = method
        self.params = params
    }

    public enum RequestID: Codable, Sendable, Equatable, Hashable {
        case string(String)
        case int(Int)

        public init(from decoder: Decoder) throws {
            let container = try decoder.singleValueContainer()
            if let intVal = try? container.decode(Int.self) {
                self = .int(intVal)
            } else if let strVal = try? container.decode(String.self) {
                self = .string(strVal)
            } else {
                throw DecodingError.typeMismatch(RequestID.self, DecodingError.Context(codingPath: decoder.codingPath, debugDescription: "Expected Int or String ID"))
            }
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.singleValueContainer()
            switch self {
            case .string(let str):
                try container.encode(str)
            case .int(let num):
                try container.encode(num)
            }
        }
    }
}

public struct JSONRPCResponse<T: Encodable & Sendable>: Encodable, Sendable {
    public let jsonrpc: String = "2.0"
    public let id: JSONRPCRequest.RequestID?
    public let result: T?
    public let error: JSONRPCError?

    public init(id: JSONRPCRequest.RequestID?, result: T) {
        self.id = id
        self.result = result
        self.error = nil
    }

    public init(id: JSONRPCRequest.RequestID?, error: JSONRPCError) {
        self.id = id
        self.result = nil
        self.error = error
    }
}

public struct JSONRPCError: Codable, Sendable {
    public let code: Int
    public let message: String
    public let data: JSONValue?

    public init(code: Int, message: String, data: JSONValue? = nil) {
        self.code = code
        self.message = message
        self.data = data
    }
}

// MARK: - MCP Domain Schemas

public enum MCPProtocolVersion: String, Codable, CaseIterable, Sendable {
    case modern = "2026-07-28"
    case legacy = "2024-11-05"

    public static let supported: [MCPProtocolVersion] = [.modern, .legacy]
    public static let legacySupported: [MCPProtocolVersion] = [.legacy]
}

public struct MCPImplementation: Codable, Sendable, Equatable {
    public let name: String
    public let version: String

    public init(name: String, version: String) {
        self.name = name
        self.version = version
    }

    public static let viewLens = MCPImplementation(name: "viewlens", version: "0.2.0")
}

public struct MCPServerCapabilities: Codable, Sendable, Equatable {
    public struct ToolsCapability: Codable, Sendable, Equatable {
        public let listChanged: Bool

        public init(listChanged: Bool = false) {
            self.listChanged = listChanged
        }
    }

    public struct ResourcesCapability: Codable, Sendable, Equatable {
        public let listChanged: Bool
        public let subscribe: Bool

        public init(listChanged: Bool = false, subscribe: Bool = false) {
            self.listChanged = listChanged
            self.subscribe = subscribe
        }
    }

    public struct PromptsCapability: Codable, Sendable, Equatable {
        public let listChanged: Bool

        public init(listChanged: Bool = false) {
            self.listChanged = listChanged
        }
    }

    public let tools: ToolsCapability
    public let resources: ResourcesCapability?
    public let prompts: PromptsCapability?
    public let extensions: [String: JSONValue]?

    public init(
        tools: ToolsCapability = .init(),
        includeResources: Bool = false,
        includePrompts: Bool = false,
        includeTasks: Bool = false
    ) {
        self.tools = tools
        self.resources = includeResources ? ResourcesCapability() : nil
        self.prompts = includePrompts ? PromptsCapability() : nil
        self.extensions = includeTasks ? ["io.modelcontextprotocol/tasks": .object([:])] : nil
    }
}

public struct MCPResultMetadata: Codable, Sendable, Equatable {
    public let serverInfo: MCPImplementation

    enum CodingKeys: String, CodingKey {
        case serverInfo = "io.modelcontextprotocol/serverInfo"
    }

    public init(serverInfo: MCPImplementation = .viewLens) {
        self.serverInfo = serverInfo
    }
}

public struct MCPInitializeResult: Encodable, Sendable {
    public let protocolVersion: String
    public let capabilities: MCPServerCapabilities
    public let serverInfo: MCPImplementation

    public init(protocolVersion: MCPProtocolVersion = .legacy) {
        self.protocolVersion = protocolVersion.rawValue
        self.capabilities = MCPServerCapabilities()
        self.serverInfo = .viewLens
    }
}

public struct MCPDiscoverResult: Encodable, Sendable {
    public let resultType = "complete"
    public let supportedVersions: [String]
    public let capabilities: MCPServerCapabilities
    public let metadata: MCPResultMetadata
    public let instructions: String
    public let ttlMs: Int
    public let cacheScope: String

    enum CodingKeys: String, CodingKey {
        case resultType, supportedVersions, capabilities, instructions, ttlMs, cacheScope
        case metadata = "_meta"
    }

    public init() {
        self.supportedVersions = MCPProtocolVersion.supported.map(\.rawValue)
        self.capabilities = MCPServerCapabilities(includeResources: true, includePrompts: true, includeTasks: true)
        self.metadata = MCPResultMetadata()
        self.instructions = "Use ViewLens tools for deterministic Apple UI visual, HIG, WCAG 2.2, and design verification evidence."
        self.ttlMs = 3_600_000
        self.cacheScope = "public"
    }
}

public struct MCPPingResult: Encodable, Sendable {
    public let resultType: String?
    public let metadata: MCPResultMetadata?

    enum CodingKeys: String, CodingKey {
        case resultType
        case metadata = "_meta"
    }

    public init(modern: Bool) {
        self.resultType = modern ? "complete" : nil
        self.metadata = modern ? MCPResultMetadata() : nil
    }
}

public struct MCPTool: Encodable, Sendable {
    public struct Icon: Encodable, Sendable {
        public let source: String
        public let mimeType: String

        enum CodingKeys: String, CodingKey {
            case source = "src"
            case mimeType
        }

        public init(source: String, mimeType: String = "image/svg+xml") {
            self.source = source
            self.mimeType = mimeType
        }
    }

    public struct Annotations: Encodable, Sendable {
        public let readOnlyHint: Bool
        public let destructiveHint: Bool
        public let idempotentHint: Bool
        public let openWorldHint: Bool

        public init(
            readOnlyHint: Bool = true,
            destructiveHint: Bool = false,
            idempotentHint: Bool = true,
            openWorldHint: Bool = false
        ) {
            self.readOnlyHint = readOnlyHint
            self.destructiveHint = destructiveHint
            self.idempotentHint = idempotentHint
            self.openWorldHint = openWorldHint
        }
    }

    public let name: String
    public let title: String?
    public let description: String
    public let inputSchema: JSONValue
    public let outputSchema: JSONValue?
    public let icons: [Icon]?
    public let annotations: Annotations?

    public init(
        name: String,
        title: String? = nil,
        description: String,
        inputSchema: JSONValue,
        outputSchema: JSONValue? = nil,
        icons: [Icon]? = nil,
        annotations: Annotations? = nil
    ) {
        self.name = name
        self.title = title
        self.description = description
        self.inputSchema = inputSchema
        self.outputSchema = outputSchema
        self.icons = icons
        self.annotations = annotations
    }
}

public struct MCPToolsListResult: Encodable, Sendable {
    public let resultType: String?
    public let tools: [MCPTool]
    public let metadata: MCPResultMetadata?

    enum CodingKeys: String, CodingKey {
        case resultType, tools
        case metadata = "_meta"
    }

    public init(tools: [MCPTool], modern: Bool = false) {
        self.resultType = modern ? "complete" : nil
        self.tools = tools
        self.metadata = modern ? MCPResultMetadata() : nil
    }
}

public struct MCPToolCallResult: Encodable, Sendable {
    public struct ContentItem: Encodable, Sendable {
        public let type: String
        public let text: String?
        public let name: String?
        public let uri: String?
        public let description: String?
        public let mimeType: String?

        public init(text: String) {
            self.type = "text"
            self.text = text
            self.name = nil
            self.uri = nil
            self.description = nil
            self.mimeType = nil
        }

        public init(artifact: MCPEvidenceEnvelope.Artifact, index: Int, reviewID: String?) {
            self.type = "resource_link"
            self.text = nil
            self.name = artifact.kind
            self.uri = reviewID.map { "viewlens://reviews/\($0)/artifacts/\(index)" }
                ?? URL(fileURLWithPath: artifact.path).absoluteString
            self.description = "ViewLens \(artifact.kind) artifact"
            self.mimeType = artifact.mediaType
        }
    }

    public let resultType: String?
    public let content: [ContentItem]
    public let structuredContent: JSONValue?
    public let isError: Bool
    public let metadata: MCPResultMetadata?

    enum CodingKeys: String, CodingKey {
        case resultType, content, structuredContent, isError
        case metadata = "_meta"
    }

    public init(
        text: String,
        structuredContent: JSONValue? = nil,
        artifacts: [MCPEvidenceEnvelope.Artifact] = [],
        artifactReviewID: String? = nil,
        isError: Bool = false,
        modern: Bool = false
    ) {
        self.resultType = modern ? "complete" : nil
        self.content = [ContentItem(text: text)] + (modern ? artifacts.enumerated().map {
            ContentItem(artifact: $0.element, index: $0.offset, reviewID: artifactReviewID)
        } : [])
        self.structuredContent = modern ? structuredContent : nil
        self.isError = isError
        self.metadata = modern ? MCPResultMetadata() : nil
    }
}

// MARK: - Arbitrary JSON Dynamic Value

public enum JSONValue: Codable, Sendable, Equatable {
    case string(String)
    case number(Double)
    case bool(Bool)
    case object([String: JSONValue])
    case array([JSONValue])
    case null

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let boolVal = try? container.decode(Bool.self) {
            self = .bool(boolVal)
        } else if let numVal = try? container.decode(Double.self) {
            self = .number(numVal)
        } else if let strVal = try? container.decode(String.self) {
            self = .string(strVal)
        } else if let objVal = try? container.decode([String: JSONValue].self) {
            self = .object(objVal)
        } else if let arrVal = try? container.decode([JSONValue].self) {
            self = .array(arrVal)
        } else if container.decodeNil() {
            self = .null
        } else {
            throw DecodingError.typeMismatch(JSONValue.self, DecodingError.Context(codingPath: decoder.codingPath, debugDescription: "Unsupported JSON type"))
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .string(let s): try container.encode(s)
        case .number(let n): try container.encode(n)
        case .bool(let b): try container.encode(b)
        case .object(let o): try container.encode(o)
        case .array(let a): try container.encode(a)
        case .null: try container.encodeNil()
        }
    }

    public var stringValue: String? {
        if case .string(let s) = self { return s }
        return nil
    }

    public var doubleValue: Double? {
        if case .number(let n) = self { return n }
        return nil
    }

    public var boolValue: Bool? {
        if case .bool(let b) = self { return b }
        return nil
    }

    public var objectValue: [String: JSONValue]? {
        if case .object(let o) = self { return o }
        return nil
    }

    public var arrayValue: [JSONValue]? {
        if case .array(let a) = self { return a }
        return nil
    }
}
