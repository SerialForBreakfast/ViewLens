import Testing
import Foundation
@testable import ViewLensKit

@Suite("Nonvisual Task Status & Presentation Budgeting Tests (NV-3.5, NV-3.7, NV-3.8)")
struct NonvisualTaskGoldenTests {

    @Test("MCPTaskSnapshot formats concise nonvisual status for speech and braille")
    func testMCPTaskSnapshotNonvisualStatus() {
        let meta = MCPResultMetadata()

        let workingSnapshot = MCPTaskSnapshot(
            resultType: "working",
            taskId: "task-100",
            status: .working,
            statusMessage: "Detecting elements in LoginForm",
            createdAt: "2026-08-24T18:00:00Z",
            lastUpdatedAt: "2026-08-24T18:00:01Z",
            ttlMs: 3600,
            pollIntervalMs: 250,
            inputRequests: nil,
            result: nil,
            error: nil,
            metadata: meta
        )
        #expect(workingSnapshot.nonvisualStatus() == "Detecting elements in LoginForm")

        let inputReqSnapshot = MCPTaskSnapshot(
            resultType: "input_required",
            taskId: "task-101",
            status: .inputRequired,
            statusMessage: "Select preferred contrast threshold.",
            createdAt: "2026-08-24T18:00:00Z",
            lastUpdatedAt: "2026-08-24T18:00:01Z",
            ttlMs: 3600,
            pollIntervalMs: 250,
            inputRequests: ["threshold": .string("AA")],
            result: nil,
            error: nil,
            metadata: meta
        )
        #expect(inputReqSnapshot.nonvisualStatus().contains("Input required for threshold"))

        let completeSnapshot = MCPTaskSnapshot(
            resultType: "complete",
            taskId: "task-102",
            status: .completed,
            statusMessage: "Audit completed with score 94.",
            createdAt: "2026-08-24T18:00:00Z",
            lastUpdatedAt: "2026-08-24T18:00:05Z",
            ttlMs: 3600,
            pollIntervalMs: 250,
            inputRequests: nil,
            result: nil,
            error: nil,
            metadata: meta
        )
        #expect(completeSnapshot.nonvisualStatus().contains("Task completed"))

        let failedSnapshot = MCPTaskSnapshot(
            resultType: "failed",
            taskId: "task-103",
            status: .failed,
            statusMessage: nil,
            createdAt: "2026-08-24T18:00:00Z",
            lastUpdatedAt: "2026-08-24T18:00:05Z",
            ttlMs: 3600,
            pollIntervalMs: 250,
            inputRequests: nil,
            result: nil,
            error: JSONRPCError(code: -32603, message: "Template render failed"),
            metadata: meta
        )
        #expect(failedSnapshot.nonvisualStatus().contains("Task failed: Template render failed"))

        let cancelledSnapshot = MCPTaskSnapshot(
            resultType: "cancelled",
            taskId: "task-104",
            status: .cancelled,
            statusMessage: nil,
            createdAt: "2026-08-24T18:00:00Z",
            lastUpdatedAt: "2026-08-24T18:00:02Z",
            ttlMs: 3600,
            pollIntervalMs: 250,
            inputRequests: nil,
            result: nil,
            error: nil,
            metadata: meta
        )
        #expect(cancelledSnapshot.nonvisualStatus() == "Task was cancelled.")
    }

    @Test("NonvisualPresentationRenderer enforces statement budget and character caps")
    func testPresentationBudgeting() throws {
        let root = try #require(Bundle.module.resourceURL)
        let url = root.appendingPathComponent("Fixtures/Nonvisual/problem-screen-evidence.json")
        let data = try Data(contentsOf: url)
        let fixture = try JSONDecoder().decode(NonvisualScreenModel.self, from: data)
        let summary = NonvisualSummaryComposer.compose(fixture)

        // 1. Unconstrained render
        let speechFull = NonvisualPresentationRenderer.render(summary, profile: .speech, maximumStatements: 20)
        #expect(!speechFull.isEmpty)

        // 2. Budgeted statement limit (e.g. 1 statement)
        let speechBudgeted = NonvisualPresentationRenderer.render(summary, profile: .speech, maximumStatements: 1, includeBudgetFooter: true)
        if summary.statements.count > 1 {
            #expect(speechBudgeted.contains("more statement"))
        }

        // 3. Braille truncation indicator
        let brailleBudgeted = NonvisualPresentationRenderer.render(summary, profile: .braille, maximumStatements: 1, includeBudgetFooter: true)
        if summary.statements.count > 1 {
            #expect(brailleBudgeted.contains("TRC"))
        }

        // 4. Character limit budget
        let charBudgeted = NonvisualPresentationRenderer.render(summary, profile: .developer, maximumStatements: 10, maximumCharacters: 50)
        #expect(charBudgeted.count <= 50)
        #expect(charBudgeted.contains("[budget]"))
    }
}
