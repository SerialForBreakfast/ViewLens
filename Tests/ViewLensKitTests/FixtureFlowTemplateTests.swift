import Testing
import Foundation
@testable import ViewLensKit

@Suite("Fixture Flow Template Tests (MCP-15.13)")
struct FixtureFlowTemplateTests {

    static let fixtureTemplateNames = [
        "FixtureFlowNavigation", "FixtureFlowForm", "FixtureFlowScroll", "FixtureFlowDialog",
        "FixtureFlowMenu", "FixtureFlowValidation", "FixtureFlowLoading", "FixtureFlowFailure",
        "FixtureFlowAccessibility"
    ]

    @Test("All fixture flow templates are registered")
    @MainActor
    func testAllFixtureFlowTemplatesRegistered() {
        let available = Set(TemplateRegistry.shared.availableTemplates)
        for name in Self.fixtureTemplateNames {
            #expect(available.contains(name), "\(name) should be registered")
        }
    }

    @Test("Each fixture flow template has a non-empty accessibility snapshot")
    @MainActor
    func testEachFixtureFlowTemplateHasNonEmptyAccessibilitySnapshot() {
        for name in Self.fixtureTemplateNames {
            let snapshots = TemplateRegistry.shared.accessibilitySnapshots(named: name)
            #expect(snapshots != nil, "\(name) should expose an accessibility snapshot")
            #expect(!(snapshots?.isEmpty ?? true), "\(name)'s accessibility snapshot should be non-empty")
        }
    }

    @Test("Fixture flow templates render deterministically")
    @MainActor
    func testFixtureFlowTemplatesRenderDeterministically() async throws {
        let permutations = MatrixRenderer.buildPermutations(
            devices: [.iPhoneSE],
            dynamicTypeSizes: ["large"],
            colorSchemes: ["light"]
        )

        for name in Self.fixtureTemplateNames {
            guard let view = TemplateRegistry.shared.template(named: name) else {
                Issue.record("\(name) template missing")
                continue
            }
            let first = try await MatrixRenderer.auditMatrix(templateName: name, view: view, permutations: permutations)
            let second = try await MatrixRenderer.auditMatrix(templateName: name, view: view, permutations: permutations)
            #expect(first.summary.failedCount == second.summary.failedCount, "\(name) should audit identically across renders")
            #expect(first.summary.worstIssue == second.summary.worstIssue, "\(name) should audit identically across renders")
        }
    }

    @Test("StateCrawler discovers fixture states from the validation template")
    @MainActor
    func testStateCrawlerDiscoversFixtureStates() {
        guard let snapshots = TemplateRegistry.shared.accessibilitySnapshots(named: "FixtureFlowValidation") else {
            Issue.record("FixtureFlowValidation accessibility snapshot missing")
            return
        }

        let prov = EvidenceProvenance(kind: .measured, source: "fixtureFlowTest")
        let nodes: [NativeAccessibilityNode] = snapshots.enumerated().map { index, snap in
            var traits: Set<NativeAccessibilityTrait> = []
            if let role = snap.role, role.localizedCaseInsensitiveContains("button") { traits.insert(.isButton) }
            return NativeAccessibilityNode(
                id: NonvisualID("node_\(index)"),
                label: snap.label,
                value: snap.value,
                traits: traits,
                frame: BoundingBox(x: 0.1, y: 0.1 * Double(index + 1), width: 0.8, height: 0.08),
                provenance: prov
            )
        }

        let report = StateCrawler.crawl(templateName: "FixtureFlowValidation", nodes: nodes, maxDepth: 3, maxStates: 10)
        #expect(report.discoveredStates.contains { $0.stateType == .validation || $0.stateType == .error })
    }

    @Test("viewlens_audit_view accepts every fixture flow template end-to-end")
    func testViewlensAuditViewAcceptsFixtureFlowTemplates() async throws {
        let server = MCPServer()
        for name in Self.fixtureTemplateNames {
            let request = JSONRPCRequest(
                id: .string("req-\(name)"),
                method: "tools/call",
                params: .object([
                    "name": .string("viewlens_audit_view"),
                    "arguments": .object([
                        "template": .string(name),
                        "devices": .array([.string("iPhoneSE")]),
                        "dynamic_type_sizes": .array([.string("large")]),
                        "color_schemes": .array([.string("light")])
                    ])
                ])
            )
            let responseData = try #require(await server.handleRequest(request))
            let json = try #require(JSONSerialization.jsonObject(with: responseData) as? [String: Any])
            let result = try #require(json["result"] as? [String: Any])
            #expect(result["isError"] as? Bool == false, "\(name) should audit without error")
        }
    }
}
