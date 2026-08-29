import Foundation
import Testing
@testable import ViewLensKit

#if canImport(SwiftUI)
import SwiftUI
#endif

@Suite("Project Context Preview Harness & Synthetic Fixture Tests (MCP-19.6)")
struct PreviewHarnessGeneratorTests {
    @Test("Generates compilable preview harness for view with environment dependencies")
    func generatesHarnessWithEnvironmentMocks() {
        let manifest = ProjectContextManifest(
            workspaceRoot: "/tmp/fake-workspace",
            rootSymbol: "DashboardView",
            scenario: "authenticated"
        )
        let report = ProjectContextReport(
            schemaVersion: "1.0",
            manifest: manifest,
            status: .readyForBuild,
            completeness: .init(buildContext: .complete, sourceContext: .complete, resourceContext: .complete, scenarioContext: .complete),
            containers: [],
            sourceClosure: [
                SourceContextRecord(
                    path: "Sources/DashboardView.swift",
                    declaredSymbols: ["DashboardView"],
                    referencedLocalSymbols: ["HeaderView"],
                    imports: ["SwiftUI", "Charts"],
                    isRoot: true
                )
            ],
            modules: ["Charts", "SwiftUI"],
            packages: [],
            resources: [],
            scenarioRequirements: [
                ScenarioRequirement(
                    propertyWrapper: "@EnvironmentObject",
                    propertyName: "session",
                    typeName: "SessionModel",
                    sourcePath: "Sources/DashboardView.swift"
                ),
                ScenarioRequirement(
                    propertyWrapper: "@EnvironmentObject",
                    propertyName: "store",
                    typeName: "CartStore",
                    sourcePath: "Sources/DashboardView.swift"
                )
            ],
            syntheticResources: [],
            diagnostics: [],
            scannedEntryCount: 5,
            scanTruncated: false,
            evidenceLimitations: []
        )

        let harness = PreviewHarnessGenerator.generateHarness(for: report)

        #expect(harness.rootSymbol == "DashboardView")
        #expect(harness.harnessSourceName == "DashboardView_ViewLensPreviewHarness.swift")
        #expect(harness.synthesizedMocks.contains("MockSessionModel"))
        #expect(harness.synthesizedMocks.contains("MockCartStore"))
        #expect(harness.injectedEnvironmentObjects.contains("SessionModel"))
        #expect(harness.injectedEnvironmentObjects.contains("CartStore"))
        #expect(harness.baselineEligible == false)

        // Verify generated source content
        #expect(harness.harnessSource.contains("import SwiftUI"))
        #expect(harness.harnessSource.contains("import Charts"))
        #expect(harness.harnessSource.contains("final class MockSessionModel: ObservableObject"))
        #expect(harness.harnessSource.contains("final class MockCartStore: ObservableObject"))
        #expect(harness.harnessSource.contains("struct DashboardView_ViewLensPreviewHarness: View"))
        #expect(harness.harnessSource.contains(".environmentObject(mockSessionModel)"))
        #expect(harness.harnessSource.contains(".environmentObject(mockCartStore)"))
        #expect(harness.harnessSource.contains("#Preview(\"DashboardView [authenticated]\")"))
    }

    @Test("Generates harness with synthetic asset placeholders for missing resources")
    func generatesHarnessWithSyntheticAssets() {
        let manifest = ProjectContextManifest(
            workspaceRoot: "/tmp/fake-workspace",
            rootSymbol: "BannerView",
            missingResourcePolicy: .structuralMock
        )
        let report = ProjectContextReport(
            schemaVersion: "1.0",
            manifest: manifest,
            status: .readyForBuild,
            completeness: .init(buildContext: .partial, sourceContext: .complete, resourceContext: .partial, scenarioContext: .complete),
            containers: [],
            sourceClosure: [],
            modules: ["SwiftUI"],
            packages: [],
            resources: [
                ProjectResourceRecord(name: "promo_hero", kind: .image, status: .missing, path: nil, referencedBy: ["BannerView.swift"])
            ],
            scenarioRequirements: [],
            syntheticResources: [
                SyntheticResourceDescriptor(
                    name: "promo_hero",
                    kind: .image,
                    strategy: .structuralMock,
                    seed: 42,
                    suggestedAspectRatio: 1.77,
                    provenance: "BannerView.swift:10",
                    baselineEligible: false
                )
            ],
            diagnostics: [],
            scannedEntryCount: 3,
            scanTruncated: false,
            evidenceLimitations: []
        )

        let harness = PreviewHarnessGenerator.generateHarness(for: report)

        #expect(harness.rootSymbol == "BannerView")
        #expect(harness.baselineEligible == false)
        #expect(harness.syntheticAssets.count == 1)
        #expect(harness.syntheticAssets[0].name == "promo_hero")
        #expect(harness.harnessSource.contains("ViewLensSyntheticAssetPlaceholder"))
    }

    @MainActor
    @Test("SyntheticFixtureInjector registers dynamic template in TemplateRegistry")
    func registersSyntheticFixtureInRegistry() {
        let manifest = ProjectContextManifest(
            workspaceRoot: "/tmp/workspace",
            rootSymbol: "DynamicTestView"
        )
        let report = ProjectContextReport(
            schemaVersion: "1.0",
            manifest: manifest,
            status: .readyForBuild,
            completeness: .init(buildContext: .complete, sourceContext: .complete, resourceContext: .complete, scenarioContext: .complete),
            containers: [],
            sourceClosure: [],
            modules: ["SwiftUI"],
            packages: [],
            resources: [],
            scenarioRequirements: [],
            syntheticResources: [],
            diagnostics: [],
            scannedEntryCount: 1,
            scanTruncated: false,
            evidenceLimitations: []
        )

        let templateName = SyntheticFixtureInjector.registerContextFixture(report: report) {
            AnyView(Text("Dynamic Injected View"))
        }

        #expect(templateName == "ContextFixture_DynamicTestView")
        #expect(TemplateRegistry.shared.template(named: templateName) != nil)
        #expect(SyntheticFixtureInjector.isBaselineEligible(templateName: templateName) == true)
        #expect(SyntheticFixtureInjector.descriptor(for: templateName) != nil)
    }
}
