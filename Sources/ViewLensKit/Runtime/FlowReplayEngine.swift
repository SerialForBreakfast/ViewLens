import Foundation
import CoreGraphics
#if canImport(NativeUIAuditKit)
import NativeUIAuditKit
#endif

/// A declared assertion on a step during a replay flow.
public struct FlowAssertion: Codable, Sendable, Equatable {
    public let kind: String // "element_exists", "element_contains_text", "element_focused", "text_anchor"
    public let targetElementID: String
    public let expectedValue: String?
    public let forbiddenValues: [String]?

    public init(
        kind: String,
        targetElementID: String,
        expectedValue: String? = nil,
        forbiddenValues: [String]? = nil
    ) {
        self.kind = kind
        self.targetElementID = targetElementID
        self.expectedValue = expectedValue
        self.forbiddenValues = forbiddenValues
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
    public let mutatedRegions: [BoundingBox]?
    public let changeScale: String?
    public let similarityDistance: Float?

    public init(
        stepID: String,
        actionResult: InteractionResult,
        assertionPassed: Bool = true,
        assertionMessage: String? = nil,
        mutatedRegions: [BoundingBox]? = nil,
        changeScale: String? = nil,
        similarityDistance: Float? = nil
    ) {
        self.stepID = stepID
        self.actionResult = actionResult
        self.assertionPassed = assertionPassed
        self.assertionMessage = assertionMessage
        self.mutatedRegions = mutatedRegions
        self.changeScale = changeScale
        self.similarityDistance = similarityDistance
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

    /// Replays a script against an active template or session synchronously.
    public static func replay(
        script: FlowScript,
        accessibilityNodes: [NativeAccessibilityNode] = [],
        visualElements: [DetectedElement] = [],
        previousFrame: CGImage? = nil,
        currentFrame: CGImage? = nil
    ) -> FlowReplayReport {
        var results: [FlowStepResult] = []
        var allPassed = true
        let startTime = Date()

        let perception = computePerception(previousFrame: previousFrame, currentFrame: currentFrame)

        for step in script.steps {
            let actRes = InteractionEngine.performAction(step.action)
            var stepAssertionPassed = true
            var assertMsg: String?

            if let assertion = step.assertion {
                let eval = evaluateAssertion(
                    assertion: assertion,
                    accessibilityNodes: accessibilityNodes,
                    visualElements: visualElements
                )
                stepAssertionPassed = eval.passed
                assertMsg = eval.message
            }

            let stepRes = FlowStepResult(
                stepID: step.id,
                actionResult: actRes,
                assertionPassed: stepAssertionPassed,
                assertionMessage: assertMsg,
                mutatedRegions: perception.mutatedRegions,
                changeScale: perception.changeScale,
                similarityDistance: perception.similarityDistance
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

    /// Replays a script against an active template or session asynchronously with optional Vision OCR text anchor verification.
    public static func replayAsync(
        script: FlowScript,
        accessibilityNodes: [NativeAccessibilityNode] = [],
        visualElements: [DetectedElement] = [],
        previousFrame: CGImage? = nil,
        currentFrame: CGImage? = nil
    ) async -> FlowReplayReport {
        var results: [FlowStepResult] = []
        var allPassed = true
        let startTime = Date()

        let perception = computePerception(previousFrame: previousFrame, currentFrame: currentFrame)

        for step in script.steps {
            let actRes = InteractionEngine.performAction(step.action)
            var stepAssertionPassed = true
            var assertMsg: String?

            if let assertion = step.assertion {
                if assertion.kind == "text_anchor", let curr = currentFrame {
                    #if canImport(NativeUIAuditKit)
                    let verifier = TextAnchorVerifier()
                    var roi: CGRect? = nil

                    if let foundNode = SpatialQueryEngine.findElement(byID: assertion.targetElementID, in: accessibilityNodes),
                       let frame = foundNode.frame {
                        roi = frame.toPixelRect(imageSize: CGSize(width: curr.width, height: curr.height))
                    } else if let foundVisual = visualElements.first(where: { $0.type.localizedCaseInsensitiveContains(assertion.targetElementID) }) {
                        roi = foundVisual.boundingBox.toPixelRect(imageSize: CGSize(width: curr.width, height: curr.height))
                    }

                    var reqStrings: [String] = []
                    if let exp = assertion.expectedValue, !exp.isEmpty {
                        reqStrings.append(exp)
                    }
                    let reqs = TextAnchorRequirements(
                        required: reqStrings,
                        forbidden: assertion.forbiddenValues ?? []
                    )

                    do {
                        let res = try await verifier.verify(reqs, in: curr, regionOfInterest: roi)
                        switch res.status {
                        case .verified:
                            stepAssertionPassed = true
                            assertMsg = "Text anchor verified for '\(assertion.targetElementID)'"
                        case .unverified:
                            stepAssertionPassed = false
                            if !res.missingRequired.isEmpty {
                                assertMsg = "Missing required text anchors: \(res.missingRequired.joined(separator: ", "))"
                            } else {
                                assertMsg = "Forbidden text anchor matched in element"
                            }
                        case .ambiguous:
                            stepAssertionPassed = false
                            assertMsg = "Text anchor verification ambiguous (no text detected in ROI)"
                        }
                    } catch {
                        stepAssertionPassed = false
                        assertMsg = "Text anchor verification failed: \(error.localizedDescription)"
                    }
                    #else
                    let eval = evaluateAssertion(
                        assertion: assertion,
                        accessibilityNodes: accessibilityNodes,
                        visualElements: visualElements
                    )
                    stepAssertionPassed = eval.passed
                    assertMsg = eval.message
                    #endif
                } else {
                    let eval = evaluateAssertion(
                        assertion: assertion,
                        accessibilityNodes: accessibilityNodes,
                        visualElements: visualElements
                    )
                    stepAssertionPassed = eval.passed
                    assertMsg = eval.message
                }
            }

            let stepRes = FlowStepResult(
                stepID: step.id,
                actionResult: actRes,
                assertionPassed: stepAssertionPassed,
                assertionMessage: assertMsg,
                mutatedRegions: perception.mutatedRegions,
                changeScale: perception.changeScale,
                similarityDistance: perception.similarityDistance
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

    private static func computePerception(
        previousFrame: CGImage?,
        currentFrame: CGImage?
    ) -> (mutatedRegions: [BoundingBox]?, changeScale: String?, similarityDistance: Float?) {
        guard let prev = previousFrame, let curr = currentFrame else {
            return (nil, nil, nil)
        }

        #if canImport(NativeUIAuditKit)
        var simDist: Float? = nil
        let sim = FrameSimilarity()
        if let dist = try? sim.distance(prev, to: curr) {
            simDist = dist
        }

        var mutatedBoxes: [BoundingBox]? = nil
        var scaleString: String? = nil
        let localizer = ChangeRegionLocalizer()
        if let locResult = try? localizer.localize(prev, current: curr) {
            switch locResult.scale {
            case .none: scaleString = "none"
            case .local: scaleString = "local"
            case .regional: scaleString = "regional"
            case .fullFrame: scaleString = "fullFrame"
            }

            let imgW = Double(curr.width)
            let imgH = Double(curr.height)
            if imgW > 0 && imgH > 0 {
                mutatedBoxes = locResult.regions.map { r in
                    BoundingBox(
                        x: r.origin.x / imgW,
                        y: r.origin.y / imgH,
                        width: r.width / imgW,
                        height: r.height / imgH
                    )
                }
            }
        }

        return (mutatedBoxes, scaleString, simDist)
        #else
        return (nil, nil, nil)
        #endif
    }

    private static func evaluateAssertion(
        assertion: FlowAssertion,
        accessibilityNodes: [NativeAccessibilityNode],
        visualElements: [DetectedElement]
    ) -> (passed: Bool, message: String) {
        switch assertion.kind {
        case "element_exists":
            let foundA11y = SpatialQueryEngine.findElement(byID: assertion.targetElementID, in: accessibilityNodes)
            let foundVisual = visualElements.first { $0.type.localizedCaseInsensitiveContains(assertion.targetElementID) }
            let passed = (foundA11y != nil || foundVisual != nil)
            let msg = passed ? "Element '\(assertion.targetElementID)' verified" : "Element '\(assertion.targetElementID)' not found"
            return (passed, msg)

        case "element_contains_text":
            let found = SpatialQueryEngine.findElement(byID: assertion.targetElementID, in: accessibilityNodes)
            if let exp = assertion.expectedValue, let label = found?.label {
                let passed = label.localizedCaseInsensitiveContains(exp)
                let msg = passed ? "Text '\(exp)' matched in '\(label)'" : "Expected text '\(exp)' but found '\(label)'"
                return (passed, msg)
            } else {
                return (false, "Element '\(assertion.targetElementID)' missing or empty text")
            }

        case "element_focused":
            let foundNode = SpatialQueryEngine.findElement(byID: assertion.targetElementID, in: accessibilityNodes)
            let foundVisual = visualElements.first { $0.type.localizedCaseInsensitiveContains(assertion.targetElementID) }
            let isA11yFocused = foundNode?.traits.contains(.isSelected) ?? false
            let isVisualFocused = foundVisual?.isFocused ?? false
            let actuallyFocused = isA11yFocused || isVisualFocused
            let expected = (assertion.expectedValue?.lowercased() != "false")
            let passed = (actuallyFocused == expected)
            var msg = passed
                ? "Element '\(assertion.targetElementID)' focus state matched expectation (\(expected))"
                : "Element '\(assertion.targetElementID)' focus state mismatch: expected \(expected), got \(actuallyFocused)"
            if foundVisual?.isAmbiguousFocus == true {
                msg += " (Warning: visual focus is ambiguous)"
            }
            return (passed, msg)

        case "text_anchor":
            let found = SpatialQueryEngine.findElement(byID: assertion.targetElementID, in: accessibilityNodes)
            let candidateText = [found?.label, found?.value, found?.hint].compactMap { $0 }.joined(separator: " ")

            var matchedRequired = true
            if let req = assertion.expectedValue, !req.isEmpty {
                matchedRequired = candidateText.localizedCaseInsensitiveContains(req)
            }

            var matchedForbidden = false
            if let forbiddens = assertion.forbiddenValues {
                for forbidden in forbiddens where !forbidden.isEmpty {
                    if candidateText.localizedCaseInsensitiveContains(forbidden) {
                        matchedForbidden = true
                        break
                    }
                }
            }

            let passed = matchedRequired && !matchedForbidden
            let msg: String
            if !matchedRequired {
                msg = "Required text anchor '\(assertion.expectedValue ?? "")' not found in element '\(assertion.targetElementID)'"
            } else if matchedForbidden {
                msg = "Forbidden text anchor matched in element '\(assertion.targetElementID)'"
            } else {
                msg = "Text anchor verified for element '\(assertion.targetElementID)'"
            }
            return (passed, msg)

        default:
            return (true, "Assertion '\(assertion.kind)' passed")
        }
    }
}
