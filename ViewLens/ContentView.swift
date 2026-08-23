import SwiftUI
import UniformTypeIdentifiers
import ViewLensKit

enum AppDestination: String, CaseIterable, Identifiable {
    case currentStatus = "Current Status"
    case aiReview = "AI Review"
    case playground = "Playground"
    case history = "History"
    case settings = "Settings"

    var id: String { rawValue }

    var symbol: String {
        switch self {
        case .currentStatus: return "waveform.path.ecg"
        case .aiReview: return "sparkles"
        case .playground: return "flask"
        case .history: return "clock.arrow.circlepath"
        case .settings: return "gearshape"
        }
    }
}

struct ContentView: View {
    @State private var model = AppModel.shared
    @State private var destination: AppDestination? = .currentStatus
    @State private var showsInspector = true
    @State private var showsImporter = false

    var body: some View {
        NavigationSplitView {
            sidebar
        } detail: {
            destinationView
        }
        .navigationSplitViewStyle(.balanced)
        .frame(minWidth: 900, minHeight: 650)
        .toolbar { appToolbar }
        .fileImporter(
            isPresented: $showsImporter,
            allowedContentTypes: [.png, .jpeg, .heic, .image],
            allowsMultipleSelection: false
        ) { result in
            if case .success(let urls) = result, let url = urls.first {
                model.auditDroppedImage(url: url)
                destination = .aiReview
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .viewLensNavigate)) { notification in
            guard let rawValue = notification.object as? String,
                  let newDestination = AppDestination(rawValue: rawValue) else { return }
            destination = newDestination
        }
        .onReceive(NotificationCenter.default.publisher(for: .viewLensImport)) { _ in
            showsImporter = true
        }
        .onReceive(NotificationCenter.default.publisher(for: .viewLensToggleInspector)) { _ in
            showsInspector.toggle()
        }
        .onReceive(NotificationCenter.default.publisher(for: .viewLensRerun)) { _ in
            model.renderPlaygroundTemplate()
            destination = .aiReview
        }
    }

    private var sidebar: some View {
        VStack(spacing: 0) {
            List(selection: $destination) {
                Section {
                    ForEach(AppDestination.allCases) { item in
                        Label(item.rawValue, systemImage: item.symbol)
                            .badge(badgeCount(for: item))
                            .tag(item)
                            .accessibilityHint(accessibilityHint(for: item))
                    }
                }
            }
            .listStyle(.sidebar)
            .navigationTitle("ViewLens")

            Divider()

            Button {
                destination = .currentStatus
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: detectorReady ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                        .foregroundStyle(detectorReady ? .green : .orange)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(detectorReady ? "Healthy" : "Needs attention")
                            .font(.subheadline.weight(.semibold))
                        Text(detectorReady ? "All systems operational" : "Open status for details")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
                .contentShape(Rectangle())
                .padding(12)
            }
            .buttonStyle(.plain)
            .accessibilityElement(children: .combine)
        }
        .frame(minWidth: 188, idealWidth: 216, maxWidth: 280)
    }

    @ViewBuilder
    private var destinationView: some View {
        switch destination ?? .currentStatus {
        case .currentStatus:
            CurrentStatusView(
                model: model,
                onOpenReview: { destination = .aiReview },
                onImport: { showsImporter = true }
            )
        case .aiReview:
            AIReviewView(model: model, showsInspector: $showsInspector) {
                showsImporter = true
            }
        case .playground:
            PlaygroundWorkspaceView(model: model) {
                destination = .aiReview
            }
        case .history:
            ReviewHistoryView(model: model) {
                destination = .aiReview
            }
        case .settings:
            ViewLensSettingsView(model: model)
        }
    }

    @ToolbarContentBuilder
    private var appToolbar: some ToolbarContent {
        ToolbarItemGroup(placement: .automatic) {
            HealthPill(title: "MCP Ready", state: .ready)
            HealthPill(title: detectorReady ? "Detector Ready" : "Detector Attention", state: detectorReady ? .ready : .warning)
        }

        ToolbarItemGroup(placement: .primaryAction) {
            if destination == .aiReview {
                Button {
                    showsInspector.toggle()
                } label: {
                    Label("Toggle Inspector", systemImage: "sidebar.trailing")
                }
                .help("Show or hide the review inspector")
            }

            Button {
                showsImporter = true
            } label: {
                Label("Import & Validate", systemImage: "square.and.arrow.down")
            }
            .keyboardShortcut("o", modifiers: .command)
            .help("Import a screenshot for accessibility validation")
        }
    }

    private var detectorReady: Bool { model.doctorReport?.status == "ready" }

    private func badgeCount(for item: AppDestination) -> Int {
        switch item {
        case .aiReview:
            return model.currentIssues.filter { $0.severity == .error || $0.severity == .warning }.count
        case .currentStatus:
            return model.isRenderingPlayground ? 1 : 0
        default:
            return 0
        }
    }

    private func accessibilityHint(for item: AppDestination) -> String {
        switch item {
        case .currentStatus: return "Shows service readiness and recent reviews"
        case .aiReview: return "Shows the current accessibility review and findings"
        case .playground: return "Configures and runs manual validation"
        case .history: return "Shows previous review activity"
        case .settings: return "Configures ViewLens preferences and diagnostics"
        }
    }
}

#Preview {
    ContentView()
}
