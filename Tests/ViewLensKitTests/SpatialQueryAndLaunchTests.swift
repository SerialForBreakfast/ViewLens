import Testing
import Foundation
import CoreGraphics
@testable import ViewLensKit

@Suite("Spatial Queries & App Launch Tests (M15.3, M15.4, M15.6, M15.10, M15.11)")
struct SpatialQueryAndLaunchTests {

    @Test("LaunchSecurityValidator sanitizes environment and validates paths")
    func testLaunchSecurityValidator() {
        let rawEnv = [
            "UI_TESTING": "1",
            "VIEWLENS_INSPECTION_MODE": "true",
            "DYLD_INSERT_LIBRARIES": "/bad/lib.dylib",
            "SECRET_TOKEN": "secret_12345"
        ]

        let sanitized = LaunchSecurityValidator.sanitizeEnvironment(rawEnv)
        #expect(sanitized["UI_TESTING"] == "1")
        #expect(sanitized["VIEWLENS_INSPECTION_MODE"] == "true")
        #expect(sanitized["DYLD_INSERT_LIBRARIES"] == nil)
        #expect(sanitized["SECRET_TOKEN"] == nil)

        let cwd = FileManager.default.currentDirectoryPath
        #expect(LaunchSecurityValidator.validateWorkspaceRoot(cwd))
        #expect(!LaunchSecurityValidator.validateWorkspaceRoot("/nonexistent/random/directory"))
    }

    @Test("ProcessController launches and tracks target applications")
    func testProcessController() async {
        let controller = ProcessController()

        let destination = RuntimeDestination(
            id: "sim_iphone_16_pro",
            name: "iPhone 16 Pro",
            kind: .simulator
        )

        let descriptor = LaunchDescriptor(
            workspaceRoot: "/tmp/project",
            scheme: "MainApp",
            configuration: "Debug",
            destination: destination,
            bundleIdentifier: "com.viewlens.demoapp",
            launchArguments: ["-ui_testing", "1"],
            environment: ["UI_TESTING": "1", "BAD_KEY": "drop_me"]
        )

        #expect(descriptor.environment["BAD_KEY"] == nil)
        #expect(descriptor.environment["UI_TESTING"] == "1")

        let result = await controller.launch(descriptor: descriptor)
        #expect(result.bundleIdentifier == "com.viewlens.demoapp")
        #expect(result.status == "running")

        let status = await controller.status(for: "com.viewlens.demoapp")
        #expect(status != nil)

        let terminated = await controller.terminate(bundleIdentifier: "com.viewlens.demoapp")
        #expect(terminated)
        #expect(await controller.status(for: "com.viewlens.demoapp") == nil)
    }

    @Test("SpatialQueryEngine performs spatial containment, nearest neighbor, and relationship calculations")
    func testSpatialQueryEngine() {
        let prov = EvidenceProvenance(kind: .measured, source: "testFixture")
        let headerNode = NativeAccessibilityNode(
            id: NonvisualID("header_1"),
            label: "Settings",
            value: nil,
            traits: [.isHeader],
            frame: BoundingBox(x: 0.1, y: 0.1, width: 0.8, height: 0.1),
            provenance: prov
        )

        let buttonNode = NativeAccessibilityNode(
            id: NonvisualID("btn_save"),
            label: "Save Changes",
            value: nil,
            traits: [.isButton],
            frame: BoundingBox(x: 0.2, y: 0.3, width: 0.6, height: 0.1),
            provenance: prov
        )

        let nodes = [headerNode, buttonNode]

        // 1. Find by ID
        let found = SpatialQueryEngine.findElement(byID: "btn_save", in: nodes)
        #expect(found?.label == "Save Changes")

        // 2. Find at Point
        let atPoint = SpatialQueryEngine.findElements(at: CGPoint(x: 0.5, y: 0.35), in: nodes)
        #expect(atPoint.count == 1)
        #expect(atPoint.first?.id.rawValue == "btn_save")

        // 3. Find Nearest Element
        let nearest = SpatialQueryEngine.findNearestElement(to: CGPoint(x: 0.5, y: 0.12), in: nodes)
        #expect(nearest?.node.id.rawValue == "header_1")

        // 4. Search Elements
        let searchResults = SpatialQueryEngine.searchElements(query: "save", role: nil, in: nodes)
        #expect(searchResults.count == 1)
        #expect(searchResults.first?.id.rawValue == "btn_save")

        let headerResults = SpatialQueryEngine.searchElements(query: nil, role: "header", in: nodes)
        #expect(headerResults.count == 1)
        #expect(headerResults.first?.id.rawValue == "header_1")

        // 5. Compute Relationships
        let rels = SpatialQueryEngine.computeRelationships(nodeA: headerNode, nodeB: buttonNode)
        #expect(rels.contains(SpatialDirection.above))
    }

    @Test("MCPServer executes app launch, hierarchy queries, and spatial queries")
    func testMCPServerLaunchAndSpatialTools() async throws {
        let server = MCPServer()

        // 1. App Launch Tool
        let launchReq = JSONRPCRequest(
            id: .string("req-launch"),
            method: "tools/call",
            params: .object([
                "name": .string("viewlens_app_launch"),
                "arguments": .object([
                    "workspace_root": .string(FileManager.default.currentDirectoryPath),
                    "bundle_identifier": .string("com.example.app"),
                    "destination_id": .string("sim_iphone_16_pro")
                ])
            ])
        )
        let launchRespData = try #require(await server.handleRequest(launchReq))
        let launchJson = try #require(JSONSerialization.jsonObject(with: launchRespData) as? [String: Any])
        let launchResult = try #require(launchJson["result"] as? [String: Any])
        let launchContent = try #require(launchResult["content"] as? [[String: Any]])
        let launchText = try #require(launchContent.first?["text"] as? String)
        #expect(launchText.contains("com.example.app"))

        // 2. Query Hierarchy Tool
        let queryReq = JSONRPCRequest(
            id: .string("req-query"),
            method: "tools/call",
            params: .object([
                "name": .string("viewlens_query_hierarchy"),
                "arguments": .object([
                    "template": .string("LoginForm")
                ])
            ])
        )
        let queryRespData = try #require(await server.handleRequest(queryReq))
        let queryJson = try #require(JSONSerialization.jsonObject(with: queryRespData) as? [String: Any])
        let queryResult = try #require(queryJson["result"] as? [String: Any])
        #expect(queryResult["isError"] as? Bool == false)

        // 3. Query Spatial Tool (Point query)
        let spatialReq = JSONRPCRequest(
            id: .string("req-spatial"),
            method: "tools/call",
            params: .object([
                "name": .string("viewlens_query_spatial"),
                "arguments": .object([
                    "template": .string("LoginForm"),
                    "x": .number(0.5),
                    "y": .number(0.5)
                ])
            ])
        )
        let spatialRespData = try #require(await server.handleRequest(spatialReq))
        let spatialJson = try #require(JSONSerialization.jsonObject(with: spatialRespData) as? [String: Any])
        let spatialResult = try #require(spatialJson["result"] as? [String: Any])
        #expect(spatialResult["isError"] as? Bool == false)
    }
}
