import Foundation
import Testing
@testable import ViewLensKit

@Suite("Project Context and Render Closure Tests (CTX-1 - CTX-6)")
struct ProjectContextResolverTests {
    @Test("Resolves transitive local views, package pins, assets, and scenario requirements")
    func resolvesProjectClosure() throws {
        let fixture = try makeFixture()
        defer { try? FileManager.default.removeItem(at: fixture) }

        let report = ProjectContextResolver.resolve(manifest: ProjectContextManifest(
            workspaceRoot: fixture.path,
            rootSymbol: "ProfileView",
            missingResourcePolicy: .request
        ))

        #expect(report.status == .inputRequired)
        #expect(report.sourceClosure.map(\.path) == ["Sources/AvatarView.swift", "Sources/ProfileView.swift"])
        #expect(report.packages.contains { $0.identity == "swift-argument-parser" && $0.version == "1.3.0" })
        #expect(report.resources.contains { $0.name == "avatar" && $0.status == .resolved })
        #expect(report.resources.contains { $0.name == "hero" && $0.status == .missing })
        #expect(report.scenarioRequirements.contains { $0.typeName == "SessionModel" })
        #expect(report.diagnostics.contains { $0.code == .scenarioRequired })
    }

    @Test("Structural mocks are explicit and never baseline eligible")
    func structuralMockPolicy() throws {
        let fixture = try makeFixture()
        defer { try? FileManager.default.removeItem(at: fixture) }

        let report = ProjectContextResolver.resolve(manifest: ProjectContextManifest(
            workspaceRoot: fixture.path,
            rootSymbol: "ProfileView",
            scenario: "signedIn",
            missingResourcePolicy: .structuralMock
        ))

        #expect(report.status == .readyForBuild)
        #expect(report.syntheticResources.count == 1)
        #expect(report.syntheticResources[0].name == "hero")
        #expect(report.syntheticResources[0].baselineEligible == false)
        #expect(report.diagnostics.contains { $0.code == .syntheticResource })
    }

    @Test("Rejects a root source file outside the declared workspace")
    func rejectsOutOfScopeSource() throws {
        let fixture = try makeFixture()
        defer { try? FileManager.default.removeItem(at: fixture) }

        let report = ProjectContextResolver.resolve(manifest: ProjectContextManifest(
            workspaceRoot: fixture.path,
            sourceFile: "/tmp/ProfileView.swift"
        ))

        #expect(report.status == .blocked)
        #expect(report.diagnostics.contains { $0.code == .pathOutsideWorkspace })
    }

    private func makeFixture() throws -> URL {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("viewlens-context-\(UUID().uuidString)")
        let sources = root.appendingPathComponent("Sources")
        let assets = root.appendingPathComponent("Assets.xcassets/avatar.imageset")
        try FileManager.default.createDirectory(at: sources, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: assets, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: root.appendingPathComponent("Example.xcodeproj"), withIntermediateDirectories: true)
        try Data("".utf8).write(to: root.appendingPathComponent("Example.xcodeproj/project.pbxproj"))
        try Data(#"{"pins":[{"identity":"swift-argument-parser","location":"https://github.com/apple/swift-argument-parser.git","state":{"version":"1.3.0"}}]}"#.utf8).write(to: root.appendingPathComponent("Package.resolved"))
        try Data("""
import SwiftUI
struct ProfileView: View {
    @EnvironmentObject var session: SessionModel
    var body: some View { VStack { AvatarView(); Image("avatar"); Image("hero") } }
}
""".utf8).write(to: sources.appendingPathComponent("ProfileView.swift"))
        try Data("""
import SwiftUI
struct AvatarView: View { var body: some View { Circle() } }
""".utf8).write(to: sources.appendingPathComponent("AvatarView.swift"))
        try Data(#"{"images":[]}"#.utf8).write(to: assets.appendingPathComponent("Contents.json"))
        return root
    }
}
