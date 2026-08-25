import Testing
import Foundation
@testable import ViewLensKit

@Suite("Runtime Session & Destination Discovery Tests (M15.1 - M15.5)")
struct RuntimeSessionTests {

    @Test("RuntimeSessionStore manages creation, lease renewal, and expiry")
    func testRuntimeSessionStore() async {
        let store = RuntimeSessionStore()

        let destination = RuntimeDestination(
            id: "sim_iphone_16_pro",
            name: "iPhone 16 Pro",
            kind: .simulator,
            platform: "iOS"
        )

        // 1. Create Session
        let session = await store.createSession(
            destination: destination,
            workspaceRoot: "/path/to/project",
            bundleIdentifier: "com.example.app",
            ttlSeconds: 100
        )

        #expect(session.id.starts(with: "session_"))
        #expect(session.state == .active)
        #expect(!session.isExpired())

        // 2. Query Session
        let fetched = await store.getSession(id: session.id)
        #expect(fetched?.id == session.id)
        #expect(fetched?.bundleIdentifier == "com.example.app")

        // 3. Renew Lease
        let renewed = await store.renewLease(id: session.id, extensionSeconds: 500)
        #expect(renewed != nil)
        #expect(renewed!.expiresAt > session.expiresAt)

        // 4. Close Session
        let closed = await store.closeSession(id: session.id)
        #expect(closed?.state == .closed)

        let active = await store.allActiveSessions()
        #expect(!active.contains { $0.id == session.id })
    }

    @Test("DestinationDiscovery returns macOS host and standard Apple simulators")
    func testDestinationDiscovery() {
        let destinations = DestinationDiscovery.discoverDestinations()
        #expect(destinations.count >= 4)
        #expect(destinations.contains { $0.id == "macos_host" })
        #expect(destinations.contains { $0.id == "sim_iphone_16_pro" })

        let resolved = DestinationDiscovery.resolveDestination(id: "sim_iphone_16_pro", in: destinations)
        #expect(resolved?.name == "iPhone 16 Pro")

        let defaultResolved = DestinationDiscovery.resolveDestination(id: nil, in: destinations)
        #expect(defaultResolved != nil)
    }

    @Test("MCPServer executes destination discovery and session lifecycle tools")
    func testMCPServerSessionTools() async throws {
        let server = MCPServer()

        // 1. List destinations
        let listReq = JSONRPCRequest(
            id: .string("req-1"),
            method: "tools/call",
            params: .object([
                "name": .string("viewlens_destinations_list"),
                "arguments": .object([:])
            ])
        )
        let listRespData = try #require(await server.handleRequest(listReq))
        let listJson = try #require(JSONSerialization.jsonObject(with: listRespData) as? [String: Any])
        let listResult = try #require(listJson["result"] as? [String: Any])
        let listContent = try #require(listResult["content"] as? [[String: Any]])
        let listText = try #require(listContent.first?["text"] as? String)
        #expect(listText.contains("sim_iphone_16_pro"))

        // 2. Create Session
        let createReq = JSONRPCRequest(
            id: .string("req-2"),
            method: "tools/call",
            params: .object([
                "name": .string("viewlens_session_create"),
                "arguments": .object([
                    "destination_id": .string("sim_iphone_16_pro"),
                    "workspace_root": .string("/tmp/test_ws"),
                    "bundle_identifier": .string("com.test.app")
                ])
            ])
        )
        let createRespData = try #require(await server.handleRequest(createReq))
        let createJson = try #require(JSONSerialization.jsonObject(with: createRespData) as? [String: Any])
        let createResult = try #require(createJson["result"] as? [String: Any])
        let createContent = try #require(createResult["content"] as? [[String: Any]])
        let createText = try #require(createContent.first?["text"] as? String)
        #expect(createText.contains("session_"))

        // Extract session ID
        let sessionObj = try JSONDecoder().decode(RuntimeSession.self, from: Data(createText.utf8))

        // 3. Get Session
        let getReq = JSONRPCRequest(
            id: .string("req-3"),
            method: "tools/call",
            params: .object([
                "name": .string("viewlens_session_get"),
                "arguments": .object([
                    "session_id": .string(sessionObj.id)
                ])
            ])
        )
        let getRespData = try #require(await server.handleRequest(getReq))
        let getJson = try #require(JSONSerialization.jsonObject(with: getRespData) as? [String: Any])
        let getResult = try #require(getJson["result"] as? [String: Any])
        let getContent = try #require(getResult["content"] as? [[String: Any]])
        let getText = try #require(getContent.first?["text"] as? String)
        #expect(getText.contains(sessionObj.id))

        // 4. Close Session
        let closeReq = JSONRPCRequest(
            id: .string("req-4"),
            method: "tools/call",
            params: .object([
                "name": .string("viewlens_session_close"),
                "arguments": .object([
                    "session_id": .string(sessionObj.id)
                ])
            ])
        )
        let closeRespData = try #require(await server.handleRequest(closeReq))
        let closeJson = try #require(JSONSerialization.jsonObject(with: closeRespData) as? [String: Any])
        let closeResult = try #require(closeJson["result"] as? [String: Any])
        let closeContent = try #require(closeResult["content"] as? [[String: Any]])
        let closeText = try #require(closeContent.first?["text"] as? String)
        #expect(closeText.contains("closed"))
    }
}
