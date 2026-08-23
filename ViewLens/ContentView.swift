//
//  ContentView.swift
//  ViewLens
//
//  Created by Joseph McCraw on 8/23/26.
//

import SwiftUI
import ViewLensKit

public enum SidebarTab: String, CaseIterable, Identifiable {
    case playground = "Playground"
    case issues = "HIG Issues"
    case activity = "Agent Activity"

    public var id: String { rawValue }

    public var icon: String {
        switch self {
        case .playground: return "slider.horizontal.3"
        case .issues: return "exclamationmark.triangle"
        case .activity: return "bolt.horizontal"
        }
    }
}

struct ContentView: View {
    @State private var model = AppModel.shared
    @State private var selectedTab: SidebarTab = .playground

    var body: some View {
        VStack(spacing: 0) {
            // Live MCP Server Status & Doctor Bar
            DoctorStatusView(model: model)

            Divider()

            // Main Split Workspace
            HSplitView {
                // Left Control & Activity Sidebar
                VStack(spacing: 0) {
                    Picker("Section", selection: $selectedTab) {
                        ForEach(SidebarTab.allCases) { tab in
                            Label(tab.rawValue, systemImage: tab.icon).tag(tab)
                        }
                    }
                    .pickerStyle(.segmented)
                    .padding(10)
                    .background(Color(NSColor.controlBackgroundColor))

                    Divider()

                    switch selectedTab {
                    case .playground:
                        TemplatePlaygroundView(model: model)
                    case .issues:
                        IssuesSidebarView(model: model)
                    case .activity:
                        ActivityLogView(model: model)
                    }
                }
                .frame(minWidth: 280, idealWidth: 320, maxWidth: 400)

                // Center Visual Inspector Canvas (Current Work Preview)
                VisualInspectorView(model: model)
                    .frame(minWidth: 500, idealWidth: 700)

                // Right HIG Remediation Detail Inspector
                IssuesSidebarView(model: model)
                    .frame(minWidth: 260, idealWidth: 300, maxWidth: 380)
            }
        }
        .frame(minWidth: 1050, minHeight: 650)
    }
}

#Preview {
    ContentView()
}
