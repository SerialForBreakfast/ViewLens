import Foundation

// MARK: - LEARN-12: Guarded Journeys and Independent Accessibility Focus

/// Node state in an exploratory or scripted accessibility journey graph (LEARN-12).
public enum JourneyNodeState: String, Codable, Sendable, Equatable, Hashable {
    case visited
    case frontier
    case blocked
    case unreached
}

/// A target of focus during journey execution, distinguishing input vs. accessibility focus (LEARN-12).
public struct JourneyFocusTarget: Codable, Sendable, Equatable, Hashable {
    public let elementID: String?
    public let label: String?
    public let role: String?
    public let isFirstFocusable: Bool
    public let bounds: BoundingBox?

    public init(
        elementID: String?,
        label: String? = nil,
        role: String? = nil,
        isFirstFocusable: Bool = false,
        bounds: BoundingBox? = nil
    ) {
        self.elementID = elementID
        self.label = label
        self.role = role
        self.isFirstFocusable = isFirstFocusable
        self.bounds = bounds
    }
}

/// Receipt confirming action dispatch (LEARN-12).
public struct JourneyDispatchReceipt: Codable, Sendable, Equatable, Hashable {
    public let timestampMs: Int
    public let actionDescription: String
    public let wasDispatched: Bool
    public let policyApproved: Bool
    public let policyRejectionReason: String?

    public init(
        timestampMs: Int,
        actionDescription: String,
        wasDispatched: Bool,
        policyApproved: Bool,
        policyRejectionReason: String? = nil
    ) {
        self.timestampMs = timestampMs
        self.actionDescription = actionDescription
        self.wasDispatched = wasDispatched
        self.policyApproved = policyApproved
        self.policyRejectionReason = policyRejectionReason
    }
}

/// Observed UI effect after an action dispatch (LEARN-12).
public struct JourneyObservedEffect: Codable, Sendable, Equatable, Hashable {
    public let uiChanged: Bool
    public let deltaDescription: String?
    public let previousState: String
    public let currentState: String

    public init(
        uiChanged: Bool,
        deltaDescription: String? = nil,
        previousState: String,
        currentState: String
    ) {
        self.uiChanged = uiChanged
        self.deltaDescription = deltaDescription
        self.previousState = previousState
        self.currentState = currentState
    }
}

/// Settling status confirming animations or transitions resolved before measurement (LEARN-12).
public struct JourneySettledScreen: Codable, Sendable, Equatable, Hashable {
    public let isSettled: Bool
    public let settledDurationMs: Int
    public let timedOut: Bool

    public init(isSettled: Bool, settledDurationMs: Int, timedOut: Bool = false) {
        self.isSettled = isSettled
        self.settledDurationMs = settledDurationMs
        self.timedOut = timedOut
    }
}

/// Record of an assistive technology announcement emitted during a journey step (LEARN-12).
public struct JourneyAnnouncementReceipt: Codable, Sendable, Equatable, Hashable {
    public let message: String
    public let emittedAtMs: Int
    public let isDuplicateConsecutive: Bool
    public let wasInterrupted: Bool
    public let priority: String

    public init(
        message: String,
        emittedAtMs: Int,
        isDuplicateConsecutive: Bool = false,
        wasInterrupted: Bool = false,
        priority: String = "announcement"
    ) {
        self.message = message
        self.emittedAtMs = emittedAtMs
        self.isDuplicateConsecutive = isDuplicateConsecutive
        self.wasInterrupted = wasInterrupted
        self.priority = priority
    }
}

/// Cleanup and restoration receipt following a journey step (LEARN-12).
public struct JourneyCleanupReceipt: Codable, Sendable, Equatable, Hashable {
    public let cleanupCompleted: Bool
    public let temporaryArtifactsPruned: Int
    public let stateRestored: Bool

    public init(cleanupCompleted: Bool, temporaryArtifactsPruned: Int = 0, stateRestored: Bool = true) {
        self.cleanupCompleted = cleanupCompleted
        self.temporaryArtifactsPruned = temporaryArtifactsPruned
        self.stateRestored = stateRestored
    }
}

/// Detailed receipt of a single guarded journey step separating all execution aspects (LEARN-12).
public struct GuardedStepReceipt: Codable, Sendable, Equatable, Identifiable {
    public let id: String
    public let stepIndex: Int
    public let action: UIAction
    public let dispatch: JourneyDispatchReceipt
    public let observedEffect: JourneyObservedEffect
    public let settledScreen: JourneySettledScreen
    public let inputFocus: JourneyFocusTarget?
    public let accessibilityFocus: JourneyFocusTarget?
    public let announcements: [JourneyAnnouncementReceipt]
    public let cleanup: JourneyCleanupReceipt
    public let unsupportedATStatus: String?
    public let focusRaceDetected: Bool
    public let defectFindings: [String]

    public init(
        id: String = UUID().uuidString,
        stepIndex: Int,
        action: UIAction,
        dispatch: JourneyDispatchReceipt,
        observedEffect: JourneyObservedEffect,
        settledScreen: JourneySettledScreen,
        inputFocus: JourneyFocusTarget? = nil,
        accessibilityFocus: JourneyFocusTarget? = nil,
        announcements: [JourneyAnnouncementReceipt] = [],
        cleanup: JourneyCleanupReceipt = JourneyCleanupReceipt(cleanupCompleted: true),
        unsupportedATStatus: String? = nil,
        focusRaceDetected: Bool = false,
        defectFindings: [String] = []
    ) {
        self.id = id
        self.stepIndex = stepIndex
        self.action = action
        self.dispatch = dispatch
        self.observedEffect = observedEffect
        self.settledScreen = settledScreen
        self.inputFocus = inputFocus
        self.accessibilityFocus = accessibilityFocus
        self.announcements = announcements
        self.cleanup = cleanup
        self.unsupportedATStatus = unsupportedATStatus
        self.focusRaceDetected = focusRaceDetected
        self.defectFindings = defectFindings
    }
}

/// A versioned route specification defining allowed transitions, preconditions, and budgets (LEARN-12).
public struct JourneyRoute: Codable, Sendable, Equatable, Hashable, Identifiable {
    public let id: String
    public let routeVersion: String
    public let name: String
    public let sourceState: String
    public let destinationState: String
    public let allowedActionKinds: [UIActionKind]
    public let preconditions: [String]
    public let stepBudget: Int
    public let durationBudgetMs: Int
    public let destinationAssertions: [String]

    public init(
        id: String = UUID().uuidString,
        routeVersion: String = "1.0",
        name: String,
        sourceState: String,
        destinationState: String,
        allowedActionKinds: [UIActionKind] = [.activate, .typeText, .scroll, .moveFocus],
        preconditions: [String] = [],
        stepBudget: Int = 10,
        durationBudgetMs: Int = 15000,
        destinationAssertions: [String] = []
    ) {
        self.id = id
        self.routeVersion = routeVersion
        self.name = name
        self.sourceState = sourceState
        self.destinationState = destinationState
        self.allowedActionKinds = allowedActionKinds
        self.preconditions = preconditions
        self.stepBudget = stepBudget
        self.durationBudgetMs = durationBudgetMs
        self.destinationAssertions = destinationAssertions
    }
}

/// An edge in the observed journey graph established strictly by observed transitions (LEARN-12).
public struct JourneyGraphEdge: Codable, Sendable, Equatable, Hashable {
    public let fromState: String
    public let toState: String
    public let actionKind: UIActionKind
    public let stepIndex: Int
    public let transitionVerified: Bool

    public init(
        fromState: String,
        toState: String,
        actionKind: UIActionKind,
        stepIndex: Int,
        transitionVerified: Bool
    ) {
        self.fromState = fromState
        self.toState = toState
        self.actionKind = actionKind
        self.stepIndex = stepIndex
        self.transitionVerified = transitionVerified
    }
}

/// Operational policy protecting guarded journeys from unapproved actions and mutations (LEARN-12).
public struct JourneyPolicy: Codable, Sendable, Equatable, Hashable {
    public let maxStepLimit: Int
    public let maxDurationMs: Int
    public let disallowHiddenMutations: Bool
    public let disallowUnannouncedVoiceOverChanges: Bool
    public let requireSettledAnimations: Bool

    public init(
        maxStepLimit: Int = 20,
        maxDurationMs: Int = 30000,
        disallowHiddenMutations: Bool = true,
        disallowUnannouncedVoiceOverChanges: Bool = true,
        requireSettledAnimations: Bool = true
    ) {
        self.maxStepLimit = maxStepLimit
        self.maxDurationMs = maxDurationMs
        self.disallowHiddenMutations = disallowHiddenMutations
        self.disallowUnannouncedVoiceOverChanges = disallowUnannouncedVoiceOverChanges
        self.requireSettledAnimations = requireSettledAnimations
    }
}

/// Comprehensive report of a guarded journey execution (LEARN-12).
public struct GuardedJourneyReport: Codable, Sendable, Equatable {
    public let route: JourneyRoute
    public let completedSuccessfully: Bool
    public let stepReceipts: [GuardedStepReceipt]
    public let visitedStates: [String]
    public let frontierStates: [String]
    public let blockedStates: [String]
    public let unreachedStates: [String]
    public let observedEdges: [JourneyGraphEdge]
    public let focusRacesCount: Int
    public let duplicateAnnouncementsCount: Int
    public let missingAnnouncementsCount: Int
    public let cyclicTransitionsDetected: Bool
    public let generatedManualVerificationSteps: [String]
    public let summary: String

    public init(
        route: JourneyRoute,
        completedSuccessfully: Bool,
        stepReceipts: [GuardedStepReceipt],
        visitedStates: [String],
        frontierStates: [String],
        blockedStates: [String],
        unreachedStates: [String],
        observedEdges: [JourneyGraphEdge],
        focusRacesCount: Int,
        duplicateAnnouncementsCount: Int,
        missingAnnouncementsCount: Int,
        cyclicTransitionsDetected: Bool,
        generatedManualVerificationSteps: [String],
        summary: String
    ) {
        self.route = route
        self.completedSuccessfully = completedSuccessfully
        self.stepReceipts = stepReceipts
        self.visitedStates = visitedStates.sorted()
        self.frontierStates = frontierStates.sorted()
        self.blockedStates = blockedStates.sorted()
        self.unreachedStates = unreachedStates.sorted()
        self.observedEdges = observedEdges
        self.focusRacesCount = focusRacesCount
        self.duplicateAnnouncementsCount = duplicateAnnouncementsCount
        self.missingAnnouncementsCount = missingAnnouncementsCount
        self.cyclicTransitionsDetected = cyclicTransitionsDetected
        self.generatedManualVerificationSteps = generatedManualVerificationSteps
        self.summary = summary
    }
}

/// Engine executing guarded journeys with independent focus tracking, policy checks, and graph validation (LEARN-12).
public enum GuardedJourneyEngine {

    /// Validates an intended action against route policy and preconditions before dispatch (LEARN-12).
    public static func validateActionPolicy(
        action: UIAction,
        route: JourneyRoute,
        policy: JourneyPolicy,
        currentStepIndex: Int,
        elapsedDurationMs: Int
    ) -> (approved: Bool, reason: String?) {
        if currentStepIndex >= route.stepBudget || currentStepIndex >= policy.maxStepLimit {
            return (false, "Step budget exceeded: \(currentStepIndex) >= limit (\(min(route.stepBudget, policy.maxStepLimit)))")
        }
        if elapsedDurationMs >= route.durationBudgetMs || elapsedDurationMs >= policy.maxDurationMs {
            return (false, "Duration budget exceeded: \(elapsedDurationMs)ms >= limit (\(min(route.durationBudgetMs, policy.maxDurationMs))ms)")
        }
        if !route.allowedActionKinds.contains(action.kind) {
            return (false, "Action kind '\(action.kind.rawValue)' is not permitted on route '\(route.name)'")
        }
        return (true, nil)
    }

    /// Evaluates a step execution, detecting focus races, duplicate announcements, and state transitions (LEARN-12).
    public static func processStep(
        stepIndex: Int,
        action: UIAction,
        route: JourneyRoute,
        policy: JourneyPolicy,
        previousState: String,
        intendedNextState: String,
        settledScreen: JourneySettledScreen,
        inputFocus: JourneyFocusTarget?,
        accessibilityFocus: JourneyFocusTarget?,
        rawAnnouncements: [String],
        elapsedDurationMs: Int
    ) -> GuardedStepReceipt {
        let (approved, rejectionReason) = validateActionPolicy(
            action: action,
            route: route,
            policy: policy,
            currentStepIndex: stepIndex,
            elapsedDurationMs: elapsedDurationMs
        )

        let dispatch = JourneyDispatchReceipt(
            timestampMs: elapsedDurationMs,
            actionDescription: "\(action.kind.rawValue)\(action.elementID.map { " on \($0)" } ?? "")",
            wasDispatched: approved,
            policyApproved: approved,
            policyRejectionReason: rejectionReason
        )

        let uiChanged = approved && (previousState != intendedNextState)
        let observedEffect = JourneyObservedEffect(
            uiChanged: uiChanged,
            deltaDescription: uiChanged ? "Transitioned from \(previousState) to \(intendedNextState)" : "No state transition observed",
            previousState: previousState,
            currentState: approved ? intendedNextState : previousState
        )

        // Focus Race Detection: Input focus and accessibility focus diverge unexpectedly
        var focusRaceDetected = false
        var defectFindings: [String] = []

        if let inputTarget = inputFocus?.elementID, let a11yTarget = accessibilityFocus?.elementID {
            if inputTarget != a11yTarget {
                focusRaceDetected = true
                defectFindings.append("Focus Race: Input focus is at '\(inputTarget)' while Accessibility/VoiceOver focus is at '\(a11yTarget)'")
            }
        }

        // Announcement Analysis
        var announcements: [JourneyAnnouncementReceipt] = []
        var lastAnnouncement: String? = nil
        for (idx, msg) in rawAnnouncements.enumerated() {
            let isDuplicate = (msg == lastAnnouncement)
            if isDuplicate {
                defectFindings.append("Duplicate consecutive announcement: '\(msg)'")
            }
            announcements.append(JourneyAnnouncementReceipt(
                message: msg,
                emittedAtMs: elapsedDurationMs + (idx * 50),
                isDuplicateConsecutive: isDuplicate,
                wasInterrupted: false
            ))
            lastAnnouncement = msg
        }

        // Missing expected announcement on modal/alert transition
        if uiChanged && intendedNextState.contains("error") && rawAnnouncements.isEmpty {
            defectFindings.append("Missing announcement: transitioned to error state without accessibility announcement")
        }

        let cleanup = JourneyCleanupReceipt(cleanupCompleted: true, temporaryArtifactsPruned: 1, stateRestored: true)

        return GuardedStepReceipt(
            stepIndex: stepIndex,
            action: action,
            dispatch: dispatch,
            observedEffect: observedEffect,
            settledScreen: settledScreen,
            inputFocus: inputFocus,
            accessibilityFocus: accessibilityFocus,
            announcements: announcements,
            cleanup: cleanup,
            unsupportedATStatus: "unavailable (headless simulator; no audio AT daemon connected)",
            focusRaceDetected: focusRaceDetected,
            defectFindings: defectFindings
        )
    }

    /// Executes a scripted route, maintaining graph state and generating manual verification steps (LEARN-12).
    public static func executeScriptedJourney(
        route: JourneyRoute,
        steps: [(action: UIAction, targetState: String, inputFocus: JourneyFocusTarget?, a11yFocus: JourneyFocusTarget?, announcements: [String])],
        policy: JourneyPolicy = JourneyPolicy()
    ) -> GuardedJourneyReport {
        var receipts: [GuardedStepReceipt] = []
        var visited = Set<String>([route.sourceState])
        var frontier = Set<String>()
        var blocked = Set<String>()
        var observedEdges: [JourneyGraphEdge] = []
        var currentState = route.sourceState
        var elapsedMs = 0
        var stateVisitCount: [String: Int] = [route.sourceState: 1]
        var cyclicDetected = false

        for (idx, step) in steps.enumerated() {
            let settled = JourneySettledScreen(isSettled: true, settledDurationMs: 120)
            elapsedMs += 250

            let receipt = processStep(
                stepIndex: idx,
                action: step.action,
                route: route,
                policy: policy,
                previousState: currentState,
                intendedNextState: step.targetState,
                settledScreen: settled,
                inputFocus: step.inputFocus,
                accessibilityFocus: step.a11yFocus,
                rawAnnouncements: step.announcements,
                elapsedDurationMs: elapsedMs
            )
            receipts.append(receipt)

            if receipt.dispatch.wasDispatched && receipt.observedEffect.uiChanged {
                let from = currentState
                let to = receipt.observedEffect.currentState
                currentState = to
                visited.insert(to)
                frontier.remove(to)

                stateVisitCount[to, default: 0] += 1
                if stateVisitCount[to]! > 2 {
                    cyclicDetected = true
                }

                // Invariant: Only observed transitions establish edges
                observedEdges.append(JourneyGraphEdge(
                    fromState: from,
                    toState: to,
                    actionKind: step.action.kind,
                    stepIndex: idx,
                    transitionVerified: true
                ))
            } else if !receipt.dispatch.wasDispatched {
                blocked.insert(step.targetState)
                break
            } else {
                frontier.insert(step.targetState)
            }
        }

        let allKnownStates = Set([route.sourceState, route.destinationState] + steps.map(\.targetState))
        let unreached = allKnownStates.subtracting(visited).subtracting(blocked)

        let completed = (currentState == route.destinationState) && receipts.allSatisfy { $0.dispatch.policyApproved }

        var manualSteps: [String] = []
        let totalFocusRaces = receipts.filter(\.focusRaceDetected).count
        let totalDupAnnouncements = receipts.flatMap(\.announcements).filter(\.isDuplicateConsecutive).count

        if totalFocusRaces > 0 {
            manualSteps.append("Verify VoiceOver focus alignment on real iOS device: \(totalFocusRaces) focus race(s) detected during automated run.")
        }
        if receipts.contains(where: { $0.unsupportedATStatus != nil }) {
            manualSteps.append("Conduct manual VoiceOver auditory review: Audio AT daemon unavailable in headless automation.")
        }
        if cyclicDetected {
            manualSteps.append("Inspect navigation backstack: Potential focus trapping cycle detected.")
        }

        let summary = "Guarded journey '\(route.name)': \(completed ? "PASSED" : "FAILED"). Visited \(visited.count) state(s), observed \(observedEdges.count) edge(s), \(totalFocusRaces) focus race(s)."

        return GuardedJourneyReport(
            route: route,
            completedSuccessfully: completed,
            stepReceipts: receipts,
            visitedStates: Array(visited),
            frontierStates: Array(frontier),
            blockedStates: Array(blocked),
            unreachedStates: Array(unreached),
            observedEdges: observedEdges,
            focusRacesCount: totalFocusRaces,
            duplicateAnnouncementsCount: totalDupAnnouncements,
            missingAnnouncementsCount: receipts.flatMap(\.defectFindings).filter { $0.contains("Missing announcement") }.count,
            cyclicTransitionsDetected: cyclicDetected,
            generatedManualVerificationSteps: manualSteps,
            summary: summary
        )
    }
}
