import Testing
import Foundation
@testable import ViewLensKit

// Serialized: every test redirects the shared `AuditLogger.shared` singleton to a scratch
// temp-directory logger to stay hermetic, which would race under Swift Testing's default
// parallel execution since `.shared` is process-global mutable state.
@Suite("Audit Log Tests (MCP-15.15)", .serialized)
struct AuditLogTests {

    private func withScratchLogger<T>(_ body: (AuditLogger, URL) async throws -> T) async rethrows -> T {
        let original = AuditLogger.shared
        defer { AuditLogger.shared = original }

        let scratchURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("viewlens-audit-tests-\(UUID().uuidString)")
            .appendingPathComponent("audit.jsonl")
        let logger = AuditLogger(fileURL: scratchURL)
        AuditLogger.shared = logger
        defer { try? FileManager.default.removeItem(at: scratchURL.deletingLastPathComponent()) }

        return try await body(logger, scratchURL)
    }

    @Test("Audit logger never persists typed action text")
    func testAuditLoggerNeverPersistsTypedActionText() async throws {
        try await withScratchLogger { logger, _ in
            let server = MCPServer()
            let request = JSONRPCRequest(
                id: .string("req-secret"),
                method: "tools/call",
                params: .object([
                    "name": .string("viewlens_ui_perform"),
                    "arguments": .object([
                        "action": .string("type_text"),
                        "element_id": .string("account_password"),
                        "text": .string("super secret input")
                    ])
                ])
            )
            _ = try #require(await server.handleRequest(request))

            let entries = await logger.recentEntries(limit: 10)
            #expect(!entries.isEmpty)
            let encoded = try JSONEncoder().encode(entries)
            let text = try #require(String(data: encoded, encoding: .utf8))
            #expect(!text.contains("super secret input"))
        }
    }

    @Test("Only allowlisted runtime-mutating tools are audited")
    func testOnlyAllowlistedToolsAreAudited() async throws {
        try await withScratchLogger { logger, _ in
            let server = MCPServer()

            // Read-only query: must not be audited.
            let readOnlyRequest = JSONRPCRequest(
                id: .string("req-readonly"),
                method: "tools/call",
                params: .object([
                    "name": .string("viewlens_doctor"),
                    "arguments": .object([:])
                ])
            )
            _ = try #require(await server.handleRequest(readOnlyRequest))
            #expect(await logger.recentEntries(limit: 10).isEmpty)

            // Runtime-mutating tool: must be audited exactly once.
            let sessionRequest = JSONRPCRequest(
                id: .string("req-session"),
                method: "tools/call",
                params: .object([
                    "name": .string("viewlens_session_create"),
                    "arguments": .object([
                        "destination_id": .string("sim_iphone_16_pro"),
                        "workspace_root": .string("/private/tmp"),
                        "bundle_identifier": .string("com.test.app")
                    ])
                ])
            )
            _ = try #require(await server.handleRequest(sessionRequest))
            let entries = await logger.recentEntries(limit: 10)
            #expect(entries.count == 1)
            #expect(entries.first?.operation == "viewlens_session_create")
        }
    }

    @Test("Audit log survives a write, then reload from disk")
    func testAuditLogSurvivesFlushAndReload() async {
        await withScratchLogger { logger, _ in
            let entry = AuditLogEntry(
                id: "audit_test1",
                timestamp: Date(),
                operation: "viewlens_ui_perform",
                resolvedTarget: .init(type: "element", identifier: "submit_button"),
                scopeDecision: "allowed",
                durationMs: 12.5,
                terminationReason: "completed",
                sessionID: "sess_1"
            )
            await logger.record(entry)

            let reloaded = await logger.recentEntries(limit: 10)
            #expect(reloaded.count == 1)
            #expect(reloaded.first?.id == "audit_test1")
            #expect(reloaded.first?.operation == "viewlens_ui_perform")
        }
    }

    @Test("Default file URL resolves under the current directory's .viewlens folder")
    func testDefaultFileURLResolvesUnderCurrentDirectory() {
        let url = AuditLogger.resolveDefaultFileURL()
        #expect(url.path.hasSuffix(".viewlens/audit.jsonl"))
    }
}
