//
//  ViewLensApp.swift
//  ViewLens
//
//  Created by Joseph McCraw on 8/23/26.
//

import SwiftUI
import ViewLensKit

@main
struct ViewLensApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .commands {
            ViewLensCommands()
        }

        Settings {
            ViewLensSettingsView(model: AppModel.shared)
                .frame(minWidth: 680, minHeight: 620)
        }

        MenuBarExtra("ViewLens", systemImage: "viewfinder", isInserted: Binding(
            get: { AppModel.shared.preferenceStore.showMenuBarItem },
            set: { AppModel.shared.preferenceStore.showMenuBarItem = $0 }
        )) {
            Text(AppModel.shared.doctorReport?.status == "ready" ? "ViewLens Ready" : "ViewLens Needs Attention")
            Divider()
            Button("Run Doctor Probe") { AppModel.shared.runDoctorCheck() }
            Button("Run Playground Audit") { AppModel.shared.renderPlaygroundTemplate() }
        }
    }
}
