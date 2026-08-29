import Foundation
import CoreGraphics

#if canImport(SwiftUI)
import SwiftUI

/// Dynamically injects scenario environment models and synthetic asset placeholders
/// for project context view fixtures into the in-process `TemplateRegistry`.
@MainActor
public enum SyntheticFixtureInjector {
    private static var registeredSyntheticFixtures: [String: PreviewHarnessDescriptor] = [:]

    /// Registers a runtime view factory with synthetic environment injection in `TemplateRegistry`.
    @discardableResult
    public static func registerContextFixture(
        report: ProjectContextReport,
        viewFactory: @escaping @MainActor () -> AnyView
    ) -> String {
        let descriptor = PreviewHarnessGenerator.generateHarness(for: report)
        let templateName = "ContextFixture_\(descriptor.rootSymbol)"

        registeredSyntheticFixtures[templateName.lowercased()] = descriptor

        TemplateRegistry.shared.register(name: templateName) {
            AnyView(
                SyntheticHarnessContainer(descriptor: descriptor, content: viewFactory)
            )
        }

        return templateName
    }

    /// Checks whether a registered fixture is eligible for baseline recording/comparison.
    public static func isBaselineEligible(templateName: String) -> Bool {
        guard let descriptor = registeredSyntheticFixtures[templateName.lowercased()] else {
            return true // Standard built-in templates are baseline-eligible
        }
        return descriptor.baselineEligible
    }

    /// Retrieves descriptor for a registered context fixture.
    public static func descriptor(for templateName: String) -> PreviewHarnessDescriptor? {
        registeredSyntheticFixtures[templateName.lowercased()]
    }
}

/// Dynamic container view that provides placeholder indicators and scenario isolation.
private struct SyntheticHarnessContainer: View {
    let descriptor: PreviewHarnessDescriptor
    let content: () -> AnyView

    var body: some View {
        VStack(spacing: 0) {
            content()
        }
    }
}

#endif
