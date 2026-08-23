import Testing
import Foundation
@testable import ViewLensKit

@Suite("Structural Introspection & Catalyst IPC Tests")
struct StructuralIntrospectionTests {
    @Test("Encodes and decodes Catalyst IPC Request/Response")
    func testCatalystIPCSerialization() throws {
        let request = CatalystIPC.Request(
            command: "render",
            template: "LoginForm",
            device: .iPhone16Pro,
            dynamicTypeSize: "accessibility3",
            colorScheme: "dark"
        )

        let data = try JSONEncoder().encode(request)
        let decoded = try JSONDecoder().decode(CatalystIPC.Request.self, from: data)

        #expect(decoded.command == "render")
        #expect(decoded.template == "LoginForm")
        #expect(decoded.device.id == "iPhone16Pro")
        #expect(decoded.dynamicTypeSize == "accessibility3")
        #expect(decoded.colorScheme == "dark")

        let response = CatalystIPC.Response(
            success: true,
            template: "LoginForm",
            imagePath: "/tmp/login_screen.png",
            hasAmbiguousLayout: false,
            ambiguousViews: []
        )
        let respData = try JSONEncoder().encode(response)
        let decodedResp = try JSONDecoder().decode(CatalystIPC.Response.self, from: respData)
        #expect(decodedResp.success)
        #expect(decodedResp.hasAmbiguousLayout == false)
    }

    #if canImport(UIKit)
    @Test("StructuralIntrospector converts findings to ViewLensIssue models")
    func testIntrospectionToIssues() {
        let finding = StructuralIntrospector.IntrospectionFinding(
            viewClass: "UILabel",
            identifier: "HeadlineLabel",
            isAmbiguous: true,
            hasAccessibilityLabel: false,
            frame: .zero
        )

        let issues = StructuralIntrospector.toIssues(findings: [finding])
        #expect(issues.count == 2)
        #expect(issues.contains { $0.kind == .ambiguousAutoLayout })
        #expect(issues.contains { $0.kind == .missingAccessibilityLabel })
        #expect(issues.first?.identifier == "HeadlineLabel")
    }
    #endif
}
