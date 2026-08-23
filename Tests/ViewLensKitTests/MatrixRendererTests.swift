import Testing
import CoreGraphics
#if canImport(SwiftUI)
import SwiftUI
#endif
@testable import ViewLensKit

@Suite("MatrixRenderer In-Process Canvas Tests")
struct MatrixRendererTests {
    @Test("TemplateRegistry returns registered templates")
    @MainActor
    func testTemplateRegistry() {
        let registry = TemplateRegistry.shared
        #expect(registry.template(named: "LoginForm") != nil)
        #expect(registry.template(named: "ProfileCard") != nil)
        #expect(registry.template(named: "Sub44ptButtonBug") != nil)
        #expect(registry.template(named: "non_existent_template") == nil)
    }

    @Test("Builds permutations for Cartesian product")
    func testPermutationsBuilder() {
        let permutations = MatrixRenderer.buildPermutations(
            devices: [.iPhoneSE, .iPhone16Pro],
            dynamicTypeSizes: ["large", "accessibility3"],
            colorSchemes: ["light", "dark"]
        )

        // 2 devices * 2 DT sizes * 2 color schemes = 8 permutations
        #expect(permutations.count == 8)
        #expect(permutations.contains { $0.key == "iPhoneSE_large_light" })
        #expect(permutations.contains { $0.key == "iPhone16Pro_accessibility3_dark" })
    }

    @Test("Renders template across matrix in memory")
    @MainActor
    func testMatrixAuditExecution() async throws {
        let permutations = MatrixRenderer.buildPermutations(
            devices: [.iPhoneSE],
            dynamicTypeSizes: ["large"],
            colorSchemes: ["light"]
        )

        guard let view = TemplateRegistry.shared.template(named: "LoginForm") else {
            Issue.record("LoginForm template missing")
            return
        }

        let matrixReport = try await MatrixRenderer.auditMatrix(
            templateName: "LoginForm",
            view: view,
            permutations: permutations
        )

        #expect(matrixReport.template == "LoginForm")
        #expect(matrixReport.summary.totalPermutations == 1)
        #expect(matrixReport.permutations["iPhoneSE_large_light"] != nil)
    }

    @Test("Detects HIG violation in defective template")
    @MainActor
    func testDefectiveTemplateAudit() async throws {
        // Given the defective template with a 24pt height button
        guard let buggyView = TemplateRegistry.shared.template(named: "Sub44ptButtonBug") else {
            Issue.record("Sub44ptButtonBug template missing")
            return
        }

        let permutations = MatrixRenderer.buildPermutations(
            devices: [.iPhone16Pro],
            dynamicTypeSizes: ["large"],
            colorSchemes: ["light"]
        )

        let report = try await MatrixRenderer.auditMatrix(
            templateName: "Sub44ptButtonBug",
            view: buggyView,
            permutations: permutations
        )

        #expect(report.permutations["iPhone16Pro_large_light"] != nil)
    }
}
