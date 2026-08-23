import SwiftUI

extension Notification.Name {
    static let viewLensNavigate = Notification.Name("ViewLens.navigate")
    static let viewLensImport = Notification.Name("ViewLens.import")
    static let viewLensToggleInspector = Notification.Name("ViewLens.toggleInspector")
    static let viewLensRerun = Notification.Name("ViewLens.rerun")
}

struct ViewLensCommands: Commands {
    var body: some Commands {
        CommandGroup(after: .newItem) {
            Button("Import & Validate…") {
                NotificationCenter.default.post(name: .viewLensImport, object: nil)
            }
            .keyboardShortcut("o", modifiers: .command)
        }

        CommandMenu("Navigate") {
            ForEach(Array(AppDestination.allCases.enumerated()), id: \.element.id) { index, destination in
                Button(destination.rawValue) {
                    NotificationCenter.default.post(name: .viewLensNavigate, object: destination.rawValue)
                }
                .keyboardShortcut(KeyEquivalent(Character(String(index + 1))), modifiers: .command)
            }
        }

        CommandMenu("Review") {
            Button("Re-run Review") {
                NotificationCenter.default.post(name: .viewLensRerun, object: nil)
            }
            .keyboardShortcut("r", modifiers: .command)

            Button("Toggle Inspector") {
                NotificationCenter.default.post(name: .viewLensToggleInspector, object: nil)
            }
            .keyboardShortcut("i", modifiers: [.command, .option])
        }
    }
}
