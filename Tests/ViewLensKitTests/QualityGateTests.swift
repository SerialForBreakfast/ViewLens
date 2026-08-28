import Testing
import Foundation
@testable import ViewLensKit

@Suite("QualityGateEvaluator and PR Summary Tests")
struct QualityGateTests {
    @Test("Passes evaluation when no errors exist and policy is failOn: error")
    func testPassingQualityGate() {
        let gate = GateConfig(failOn: .error, purposes: [.touchTargets, .clipping])

        let cleanReport = AuditReport(
            sourceMode: .rendered,
            target: "LoginForm [iPhone16Pro_large_light]",
            device: "iPhone 16 Pro",
            dimensions: AuditDimensions(width: 1179, height: 2556, scale: 3.0),
            elements: [],
            issues: []
        )

        let matrixReport = MatrixAuditReport(
            sourceMode: .rendered,
            template: "LoginForm",
            passed: true,
            summary: MatrixSummary(totalPermutations: 1, passedCount: 1, failedCount: 0, worstIssue: nil, failedPermutations: []),
            permutations: ["iPhone16Pro_large_light": cleanReport]
        )

        let evaluation = QualityGateEvaluator.evaluate(gateName: "pre-commit", config: gate, matrixReport: matrixReport)
        #expect(evaluation.passed)
        #expect(evaluation.errorCount == 0)
        #expect(evaluation.failureReason == nil)
    }

    @Test("Blocks quality gate when touch target error occurs and policy is failOn: error")
    func testFailingQualityGateOnError() {
        let gate = GateConfig(failOn: .error, purposes: [.touchTargets])

        let defectiveIssue = ViewLensIssue(
            kind: .tappableTargetTooSmall,
            severity: .error,
            description: "Button height 24pt is below 44pt",
            confidence: 0.95,
            elementIndex: 0
        )

        let defectiveReport = AuditReport(
            sourceMode: .rendered,
            target: "Sub44ptButtonBug [iPhone16Pro_large_light]",
            device: "iPhone 16 Pro",
            dimensions: AuditDimensions(width: 1179, height: 2556, scale: 3.0),
            elements: [],
            issues: [defectiveIssue]
        )

        let matrixReport = MatrixAuditReport(
            sourceMode: .rendered,
            template: "Sub44ptButtonBug",
            passed: false,
            summary: MatrixSummary(totalPermutations: 1, passedCount: 0, failedCount: 1, worstIssue: "Defective", failedPermutations: ["iPhone16Pro_large_light"]),
            permutations: ["iPhone16Pro_large_light": defectiveReport]
        )

        let evaluation = QualityGateEvaluator.evaluate(gateName: "pre-commit", config: gate, matrixReport: matrixReport)
        #expect(!evaluation.passed)
        #expect(evaluation.errorCount == 1)
        #expect(evaluation.failureReason != nil)
    }

    @Test("PRSummaryGenerator formats markdown with badge and code blocks")
    func testPRSummaryGeneration() {
        let gate = GateConfig(failOn: .error)
        let issue = ViewLensIssue(
            kind: .tappableTargetTooSmall,
            severity: .error,
            description: "Button height 24pt below 44pt",
            confidence: 0.95,
            remediation: RemediationAdvice(description: "Increase height", codeSnippet: ".frame(height: 44)")
        )

        let report = AuditReport(
            sourceMode: .rendered,
            target: "TestTarget [iPhone16Pro_large_light]",
            device: "iPhone 16 Pro",
            dimensions: AuditDimensions(width: 1179, height: 2556, scale: 3.0),
            elements: [],
            issues: [issue]
        )

        let matrixReport = MatrixAuditReport(
            sourceMode: .rendered,
            template: "TestTarget",
            passed: false,
            summary: MatrixSummary(totalPermutations: 1, passedCount: 0, failedCount: 1, worstIssue: "Test", failedPermutations: ["iPhone16Pro_large_light"]),
            permutations: ["iPhone16Pro_large_light": report]
        )

        let eval = QualityGateEvaluator.evaluate(gateName: "pull-request", config: gate, matrixReport: matrixReport)
        let md = PRSummaryGenerator.generateMarkdown(gateName: "pull-request", config: gate, matrixReport: matrixReport, evaluation: eval)

        #expect(md.contains("❌ FAILED"))
        #expect(md.contains(".frame(height: 44)"))
        #expect(md.contains("iPhone 16 Pro"))
    }

    private func cleanMatrixReport(template: String = "LoginForm") -> MatrixAuditReport {
        let report = AuditReport(
            sourceMode: .rendered,
            target: "\(template) [iPhone16Pro_large_light]",
            device: "iPhone 16 Pro",
            dimensions: AuditDimensions(width: 1179, height: 2556, scale: 3.0),
            elements: [],
            issues: []
        )
        return MatrixAuditReport(
            sourceMode: .rendered,
            template: template,
            passed: true,
            summary: MatrixSummary(totalPermutations: 1, passedCount: 1, failedCount: 0, worstIssue: nil, failedPermutations: []),
            permutations: ["iPhone16Pro_large_light": report]
        )
    }

    @Test("Evaluate without fixVerification is unchanged from pre-M17.13 behavior")
    func testEvaluateWithoutFixVerificationIsUnchanged() {
        let gate = GateConfig(failOn: .error, purposes: [])
        let matrixReport = cleanMatrixReport()

        let evaluation = QualityGateEvaluator.evaluate(gateName: "pre-commit", config: gate, matrixReport: matrixReport)
        #expect(evaluation.passed)
        #expect(evaluation.fixVerification == nil)
        #expect(evaluation.sourceRecords == nil)
    }

    @Test("Evaluate fails when fixVerification has regressions, even if config.failOn is none")
    func testEvaluateFailsWhenFixVerificationHasRegressionsEvenIfConfigFailOnIsNone() {
        let gate = GateConfig(failOn: .none, purposes: [])
        let matrixReport = cleanMatrixReport()
        let fixVerification = FixVerifier.verify(
            changeSet: ChangeSet(changedFiles: ["Sources/Example.swift"], targetTemplate: "LoginForm"),
            baselineIssues: [],
            currentIssues: ["tappableTargetTooSmall"]
        )
        #expect(fixVerification.hasRegressions)

        let evaluation = QualityGateEvaluator.evaluate(gateName: "pull-request", config: gate, matrixReport: matrixReport, fixVerification: fixVerification)
        #expect(!evaluation.passed)
        #expect(evaluation.failureReason?.contains("introduced issue") == true)
    }

    @Test("generateMarkdown omits the Fix Verification section when nil")
    func testGenerateMarkdownOmitsFixVerificationSectionWhenNil() {
        let gate = GateConfig(failOn: .error, purposes: [])
        let matrixReport = cleanMatrixReport()
        let evaluation = QualityGateEvaluator.evaluate(gateName: "pre-commit", config: gate, matrixReport: matrixReport)
        let md = PRSummaryGenerator.generateMarkdown(gateName: "pre-commit", config: gate, matrixReport: matrixReport, evaluation: evaluation)
        #expect(!md.contains("Fix Verification"))
    }

    @Test("generateMarkdown renders the Fix Verification section with source links when available")
    func testGenerateMarkdownRendersFixVerificationSectionWithSourceLinks() {
        let gate = GateConfig(failOn: .error, purposes: [])
        let matrixReport = cleanMatrixReport()
        let fixVerification = FixVerifier.verify(
            changeSet: ChangeSet(changedFiles: ["Sources/Example.swift"], targetTemplate: "LoginForm"),
            baselineIssues: ["tappableTargetTooSmall"],
            currentIssues: []
        )
        let sourceRecords = [
            SourceRecord(elementID: "BuggySmallButton", filePath: "Sources/ViewLensKit/Rendering/TemplateRegistry.swift", line: 1, symbol: "LoginForm", confidence: .approximate, detail: "Matched template source file.")
        ]
        let evaluation = QualityGateEvaluator.evaluate(gateName: "pull-request", config: gate, matrixReport: matrixReport, fixVerification: fixVerification, sourceRecords: sourceRecords)
        let md = PRSummaryGenerator.generateMarkdown(gateName: "pull-request", config: gate, matrixReport: matrixReport, evaluation: evaluation)

        #expect(md.contains("Fix Verification"))
        #expect(md.contains("Resolved | 1"))
        #expect(md.contains("TemplateRegistry.swift:1"))
        #expect(md.contains("confidence: approximate"))
    }

    @Test("generateMarkdown never fabricates a file:line for unavailable confidence")
    func testGenerateMarkdownNeverFabricatesFileLineForUnavailableConfidence() {
        let gate = GateConfig(failOn: .error, purposes: [])
        let matrixReport = cleanMatrixReport()
        let fixVerification = FixVerifier.verify(
            changeSet: ChangeSet(changedFiles: [], targetTemplate: "LoginForm"),
            baselineIssues: ["tappableTargetTooSmall"],
            currentIssues: []
        )
        let sourceRecords = [
            SourceRecord(elementID: "UnknownElement", filePath: nil, line: nil, symbol: nil, confidence: .unavailable, detail: "No instrumented debug metadata found.")
        ]
        let evaluation = QualityGateEvaluator.evaluate(gateName: "pull-request", config: gate, matrixReport: matrixReport, fixVerification: fixVerification, sourceRecords: sourceRecords)
        let md = PRSummaryGenerator.generateMarkdown(gateName: "pull-request", config: gate, matrixReport: matrixReport, evaluation: evaluation)

        #expect(!md.contains("UnknownElement ->"))
        #expect(md.contains("1 finding(s) had no available source location"))
    }
}
