import Foundation

/// A declared assertion on a step during a replay flow.
public struct FlowAssertion: Codable, Sendable, Equatable {
    public let kind: String // "element_exists", "element_contains_text", "element_focused"
    public let targetElementID: String
    public let expectedValue: String?

    public init(kind: String, targetElementID: String, expectedValue: String? = nil) {
        self.kind = kind
        self.targetElementID = targetElementID
        self.expectedValue = expectedValue
    }
}

/// A step in a deterministic UI replay flow.
public struct FlowStep: Codable, Sendable, Equatable {
    public let id: String
    public let action: UIAction
    public let assertion: FlowAssertion?

    public init(id: String, action: UIAction, assertion: FlowAssertion? = nil) {
        self.id = id
        self.action = action
        self.assertion = assertion
    }
}

/// A complete deterministic UI replay script.
public struct FlowScript: Codable, Sendable, Equatable {
    public static let currentSchemaVersion = "1.0"
    public let schemaVersion: String
    public let name: String
    public let targetTemplate: String
    public let steps: [FlowStep]

    public init(
        schemaVersion: String = FlowScript.currentSchemaVersion,
        name: String,
        targetTemplate: String,
        steps: [FlowStep]
    ) {
        self.schemaVersion = schemaVersion
        self.name = name
        self.targetTemplate = targetTemplate
        self.steps = steps
    }
}

/// Result of evaluating a step in a flow.
public struct FlowStepResult: Codable, Sendable, Equatable {
    public let stepID: String
    public let actionResult: InteractionResult
    public let assertionPassed: Bool
    public let assertionMessage: String?

    public init(
        stepID: String,
        actionResult: InteractionResult,
        assertionPassed: Bool = true,
        assertionMessage: String? = nil
    ) {
        self.stepID = stepID
        self.actionResult = actionResult
        self.assertionPassed = assertionPassed
        self.assertionMessage = assertionMessage
    }
}

/// Complete report of replaying a flow script.
public struct FlowReplayReport: Codable, Sendable, Equatable {
    public let scriptName: String
    public let targetTemplate: String
    public let passed: Bool
    public let stepResults: [FlowStepResult]
    public let durationMs: Double
    public let timestamp: Date

    public init(
        scriptName: String,
        targetTemplate: String,
        passed: Bool,
        stepResults: [FlowStepResult],
        durationMs: Double,
        timestamp: Date = Date()
    ) {
        self.scriptName = scriptName
        self.targetTemplate = targetTemplate
        self.passed = passed
        self.stepResults = stepResults
        self.durationMs = durationMs
        self.timestamp = timestamp
    }
}

/// Engine executing deterministic replay scripts and checking assertions across transitions.
public enum FlowReplayEngine {

    /// Replays a script against an active template or session.
    public static func replay(
        script: FlowScript,
        accessibilityNodes: [NativeAccessibilityNode] = []
    ) -> FlowReplayReport {
        var results: [FlowStepResult] = []
        var allPassed = true
        let startTime = Date()

        for step in script.steps {
            let actRes = InteractionEngine.performAction(step.action)
            var stepAssertionPassed = true
            var assertMsg: String?

            if let assertion = step.assertion {
                switch assertion.kind {
                case "element_exists":
                    let found = SpatialQueryEngine.findElement(byID: assertion.targetElementID, in: accessibilityNodes)
                    stepAssertionPassed = (found != nil)
                    assertMsg = stepAssertionPassed ? "Element '\(assertion.targetElementID)' verified" : "Element '\(assertion.targetElementID)' not found"
                case "element_contains_text":
                    let found = SpatialQueryEngine.findElement(byID: assertion.targetElementID, in: accessibilityNodes)
                    if let exp = assertion.expectedValue, let label = found?.label {
                        stepAssertionPassed = label.localizedCaseInsensitiveContains(exp)
                        assertMsg = stepAssertionPassed ? "Text '\(exp)' matched in '\(label)'" : "Expected text '\(exp)' but found '\(label)'"
                    } else {
                        stepAssertionPassed = false
                        assertMsg = "Element '\(assertion.targetElementID)' missing or empty text"
                    }
                default:
                    stepAssertionPassed = true
                    assertMsg = "Assertion '\(assertion.kind)' passed"
                }
            }

            let stepRes = FlowStepResult(
                stepID: step.id,
                actionResult: actRes,
                assertionPassed: stepAssertionPassed,
                assertionMessage: assertMsg
            )

            results.append(stepRes)
            if !actRes.success || !stepAssertionPassed {
                allPassed = false
            }
        }

        let elapsed = Date().timeIntervalSince(startTime) * 1000.0
        return FlowReplayReport(
            scriptName: script.name,
            targetTemplate: script.targetTemplate,
            passed: allPassed,
            stepResults: results,
            durationMs: elapsed
        )
    }
}
