import Foundation

/// A single step in a manual VoiceOver / assistive technology test plan.
public struct ManualVerificationStep: Codable, Sendable, Equatable, Identifiable {
    public var id: Int { stepNumber }
    public let stepNumber: Int
    public let action: String
    public let expectedOutput: String
    public let assistiveTechnology: String

    public init(
        stepNumber: Int,
        action: String,
        expectedOutput: String,
        assistiveTechnology: String = "VoiceOver"
    ) {
        self.stepNumber = stepNumber
        self.action = action
        self.expectedOutput = expectedOutput
        self.assistiveTechnology = assistiveTechnology
    }
}

/// A comprehensive manual verification checklist for a screen or workflow.
public struct ManualVerificationPlan: Codable, Sendable, Equatable {
    public let screenID: NonvisualID
    public let title: String
    public let steps: [ManualVerificationStep]

    public init(
        screenID: NonvisualID,
        title: String,
        steps: [ManualVerificationStep] = []
    ) {
        self.screenID = screenID
        self.title = title
        self.steps = steps
    }

    public func formattedMarkdown() -> String {
        var md = """
        ### 🧪 Manual VoiceOver Verification Plan for `\(title)`
        
        | Step | Action / Gesture | Expected Speech / Braille Announcement | AT Tool |
        |---|---|---|---|
        """
        for s in steps {
            md += "\n| \(s.stepNumber) | \(s.action) | \(s.expectedOutput) | \(s.assistiveTechnology) |"
        }
        return md
    }
}

/// Synthesizes deterministic manual VoiceOver testing scripts from a nonvisual screen model.
public enum ManualVerificationGenerator {

    public static func generatePlan(from model: NonvisualScreenModel) -> ManualVerificationPlan {
        var steps: [ManualVerificationStep] = []
        var stepNum = 1

        let title = model.title ?? model.id.rawValue

        // 1. Initial Screen Arrival Step
        steps.append(ManualVerificationStep(
            stepNumber: stepNum,
            action: "Open screen '\(title)' with VoiceOver active (`⌘F5` on Mac, triple-click Side Button on iOS)",
            expectedOutput: "VoiceOver announces screen title and focuses first landmark or primary heading."
        ))
        stepNum += 1

        // 2. Sequential Reading Order Check
        let elementsCount = model.elements.count
        steps.append(ManualVerificationStep(
            stepNumber: stepNum,
            action: "Swipe Right / Press `VO + Right Arrow` continuously through all \(elementsCount) element(s)",
            expectedOutput: "Focus progresses linearly top-to-bottom without skipping interactive controls or trapping focus."
        ))
        stepNum += 1

        // 3. Rotor Heading Verification
        let headings = model.elements.filter { $0.semantics?.isHeading == true || $0.type == "heading" }
        if !headings.isEmpty {
            let headingNames = headings.compactMap { $0.semantics?.accessibleName ?? $0.visibleLabel }.joined(separator: ", ")
            steps.append(ManualVerificationStep(
                stepNumber: stepNum,
                action: "Turn Rotor to 'Headings' (`VO + U` on Mac, two-finger rotate on iOS)",
                expectedOutput: "Rotor lists \(headings.count) heading(s): [\(headingNames)]."
            ))
            stepNum += 1
        }

        // 4. Interactive Controls & Actions Check
        let buttons = model.elements.filter { $0.isInteractive }
        if !buttons.isEmpty {
            steps.append(ManualVerificationStep(
                stepNumber: stepNum,
                action: "Navigate to primary action button and activate (`VO + Space` on Mac, Double-Tap on iOS)",
                expectedOutput: "Button activates immediately with clear auditory feedback and state update announcement."
            ))
            stepNum += 1
        }

        // 5. Dynamic Type AX5 Reflow Check
        steps.append(ManualVerificationStep(
            stepNumber: stepNum,
            action: "In Accessibility settings / Accessibility Inspector, increase Dynamic Type to AX5 (312%)",
            expectedOutput: "All labels enlarge and wrap cleanly without truncating words or overlapping adjacent controls."
        ))

        return ManualVerificationPlan(screenID: model.id, title: title, steps: steps)
    }
}
