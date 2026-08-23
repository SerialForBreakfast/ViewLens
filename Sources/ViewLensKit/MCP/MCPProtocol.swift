import Foundation

// MARK: - JSON-RPC 2.0 Base Protocol

public struct JSONRPCRequest: Codable, Sendable {
    public let jsonrpc: String
    public let id: RequestID?
    public let method: String
    public let params: JSONValue?

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

public struct MCPInitializeResult: Encodable, Sendable {
    public let protocolVersion: String = "2024-11-05"
    public let capabilities: ServerCapabilities
    public let serverInfo: ServerInfo

    public struct ServerCapabilities: Encodable, Sendable {
        public let tools: ToolsCapability
        public struct ToolsCapability: Encodable, Sendable {
            public let listChanged: Bool = false
        }
    }

    public struct ServerInfo: Encodable, Sendable {
        public let name: String = "viewlens"
        public let version: String = "0.1.0"
    }

    public init() {
        self.capabilities = ServerCapabilities(tools: .init())
        self.serverInfo = ServerInfo()
    }
}

public struct MCPTool: Encodable, Sendable {
    public let name: String
    public let description: String
    public let inputSchema: JSONValue

    public init(name: String, description: String, inputSchema: JSONValue) {
        self.name = name
        self.description = description
        self.inputSchema = inputSchema
    }
}

public struct MCPToolsListResult: Encodable, Sendable {
    public let tools: [MCPTool]

    public init(tools: [MCPTool]) {
        self.tools = tools
    }
}

public struct MCPToolCallResult: Encodable, Sendable {
    public struct ContentItem: Encodable, Sendable {
        public let type: String = "text"
        public let text: String

        public init(text: String) {
            self.text = text
        }
    }

    public let content: [ContentItem]
    public let isError: Bool

    public init(text: String, isError: Bool = false) {
        self.content = [ContentItem(text: text)]
        self.isError = isError
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

    public var objectValue: [String: JSONValue]? {
        if case .object(let o) = self { return o }
        return nil
    }
}
