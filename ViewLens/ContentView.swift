import SwiftUI
import UniformTypeIdentifiers
import ViewLensKit

struct ContentView: View {
    @State private var model = AppModel.shared
    @State private var navigation = AppModel.shared.navigationStore

    var body: some View {
        NavigationSplitView {
            sidebar
        } detail: {
            destinationView
        }
        .navigationSplitViewStyle(.balanced)
        .frame(minWidth: 900, minHeight: 650)
        .preferredColorScheme(preferredColorScheme)
        .toolbar { appToolbar }
        .fileImporter(
            isPresented: $navigation.showsImporter,
            allowedContentTypes: [.png, .jpeg, .heic, .image],
            allowsMultipleSelection: false
        ) { result in
            if case .success(let urls) = result, let url = urls.first {
                model.auditDroppedImage(url: url)
                navigation.destination = .aiReview
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .viewLensNavigate)) { notification in
            guard let rawValue = notification.object as? String,
                  let newDestination = AppDestination(rawValue: rawValue) else { return }
            navigation.destination = newDestination
        }
        .onReceive(NotificationCenter.default.publisher(for: .viewLensImport)) { _ in
            navigation.showsImporter = true
        }
        .onReceive(NotificationCenter.default.publisher(for: .viewLensToggleInspector)) { _ in
            navigation.showsInspector.toggle()
        }
        .onReceive(NotificationCenter.default.publisher(for: .viewLensRerun)) { _ in
            model.renderPlaygroundTemplate()
            navigation.destination = .aiReview
        }
    }

    private var sidebar: some View {
        VStack(spacing: 0) {
            List(selection: $navigation.destination) {
                Section {
                    ForEach(AppDestination.allCases) { item in
                        Label(item.rawValue, systemImage: item.symbol)
                            .badge(badgeCount(for: item))
                            .tag(item)
                            .accessibilityHint(accessibilityHint(for: item))
                            .accessibilityIdentifier(item.accessibilityIdentifier)
                    }
                }
            }
            .listStyle(.sidebar)
            .navigationTitle("ViewLens")

            Divider()

            Button {
                navigation.destination = .currentStatus
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
        switch navigation.destination ?? .currentStatus {
        case .currentStatus:
            CurrentStatusView(
                model: model,
                onOpenReview: { navigation.destination = .aiReview },
                onImport: { navigation.showsImporter = true }
            )
        case .aiReview:
            AIReviewView(model: model, showsInspector: $navigation.showsInspector) {
                navigation.showsImporter = true
            }
        case .playground:
            PlaygroundWorkspaceView(model: model) {
                navigation.destination = .aiReview
            }
        case .history:
            ReviewHistoryView(model: model) {
                navigation.destination = .aiReview
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
            if navigation.destination == .aiReview {
                Button {
                    navigation.showsInspector.toggle()
                } label: {
                    Label("Toggle Inspector", systemImage: "sidebar.trailing")
                }
                .help("Show or hide the review inspector")
            }

            Button {
                navigation.showsImporter = true
            } label: {
                Label("Import & Validate", systemImage: "square.and.arrow.down")
            }
            .accessibilityIdentifier("toolbar.import")
            .keyboardShortcut("o", modifiers: .command)
            .help("Import a screenshot for accessibility validation")
        }
    }

    private var detectorReady: Bool { model.doctorReport?.status == "ready" }

    private var preferredColorScheme: ColorScheme? {
        switch model.preferenceStore.appearance { case "Light": return .light; case "Dark": return .dark; default: return nil }
    }

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
