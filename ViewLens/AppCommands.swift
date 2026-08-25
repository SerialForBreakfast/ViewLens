import SwiftUI

extension Notification.Name {
    static let viewLensNavigate = Notification.Name("ViewLens.navigate")
    static let viewLensImport = Notification.Name("ViewLens.import")
    static let viewLensToggleInspector = Notification.Name("ViewLens.toggleInspector")
    static let viewLensRerun = Notification.Name("ViewLens.rerun")
    static let viewLensSelectNextElement = Notification.Name("ViewLens.selectNextElement")
    static let viewLensSelectPreviousElement = Notification.Name("ViewLens.selectPreviousElement")
    static let viewLensSelectNextFinding = Notification.Name("ViewLens.selectNextFinding")
    static let viewLensSelectPreviousFinding = Notification.Name("ViewLens.selectPreviousFinding")
    static let viewLensSetWorkbenchMode = Notification.Name("ViewLens.setWorkbenchMode")
    static let viewLensToggleOverlays = Notification.Name("ViewLens.toggleOverlays")
    static let viewLensToggleLabels = Notification.Name("ViewLens.toggleLabels")
    static let viewLensToggleSafeAreas = Notification.Name("ViewLens.toggleSafeAreas")
    static let viewLensCopyRemediation = Notification.Name("ViewLens.copyRemediation")
}

struct ViewLensCommands: Commands {
    var body: some Commands {
        CommandGroup(after: .newItem) {
            Button("Import & Validate…") {
                NotificationCenter.default.post(name: .viewLensImport, object: nil)
            }
            .keyboardShortcut("o", modifiers: .command)
        }

        CommandMenu("View") {
            Button("Canvas View") {
                NotificationCenter.default.post(name: .viewLensSetWorkbenchMode, object: WorkbenchViewMode.canvas)
            }
            .keyboardShortcut("1", modifiers: .command)

            Button("Nonvisual Outline View") {
                NotificationCenter.default.post(name: .viewLensSetWorkbenchMode, object: WorkbenchViewMode.outline)
            }
            .keyboardShortcut("2", modifiers: .command)

            Button("Split View") {
                NotificationCenter.default.post(name: .viewLensSetWorkbenchMode, object: WorkbenchViewMode.split)
            }
            .keyboardShortcut("3", modifiers: .command)

            Divider()

            Button("Toggle Overlays") {
                NotificationCenter.default.post(name: .viewLensToggleOverlays, object: nil)
            }
            .keyboardShortcut("o", modifiers: [.command, .option])

            Button("Toggle Element Labels") {
                NotificationCenter.default.post(name: .viewLensToggleLabels, object: nil)
            }
            .keyboardShortcut("l", modifiers: [.command, .option])

            Button("Toggle Safe Area Guides") {
                NotificationCenter.default.post(name: .viewLensToggleSafeAreas, object: nil)
            }
            .keyboardShortcut("s", modifiers: [.command, .option])

            Button("Toggle Inspector") {
                NotificationCenter.default.post(name: .viewLensToggleInspector, object: nil)
            }
            .keyboardShortcut("i", modifiers: [.command, .option])
        }

        CommandMenu("Navigate") {
            Button("Next Element") {
                NotificationCenter.default.post(name: .viewLensSelectNextElement, object: nil)
            }
            .keyboardShortcut("]", modifiers: .command)

            Button("Previous Element") {
                NotificationCenter.default.post(name: .viewLensSelectPreviousElement, object: nil)
            }
            .keyboardShortcut("[", modifiers: .command)

            Divider()

            Button("Next Finding") {
                NotificationCenter.default.post(name: .viewLensSelectNextFinding, object: nil)
            }
            .keyboardShortcut("]", modifiers: [.command, .shift])

            Button("Previous Finding") {
                NotificationCenter.default.post(name: .viewLensSelectPreviousFinding, object: nil)
            }
            .keyboardShortcut("[", modifiers: [.command, .shift])

            Divider()

            ForEach(Array(AppDestination.allCases.enumerated()), id: \.element.id) { index, destination in
                Button(destination.rawValue) {
                    NotificationCenter.default.post(name: .viewLensNavigate, object: destination.rawValue)
                }
                .keyboardShortcut(KeyEquivalent(Character(String(index + 1))), modifiers: [.command, .option])
            }
        }

        CommandMenu("Review") {
            Button("Re-run Review") {
                NotificationCenter.default.post(name: .viewLensRerun, object: nil)
            }
            .keyboardShortcut("r", modifiers: .command)

            Button("Copy Selected Remediation") {
                NotificationCenter.default.post(name: .viewLensCopyRemediation, object: nil)
            }
            .keyboardShortcut("c", modifiers: [.command, .option])
        }
    }
}
