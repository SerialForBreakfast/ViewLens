import Foundation
import Testing
@testable import ViewLensKit

@Suite("Change Impact Graph Tests (INT-20.1 - INT-20.5)")
struct ChangeImpactAnalyzerTests {
    @Test("Traces a changed leaf view to its top-level root")
    func tracesTransitiveViewImpact() throws {
        let fixture = try makeFixture()
        defer { try? FileManager.default.removeItem(at: fixture) }

        let report = ChangeImpactAnalyzer.analyze(workspaceRoot: fixture.path, changedFiles: ["Sources/AvatarView.swift"])

        #expect(report.completeness == .complete)
        #expect(report.affectedSourceFiles == ["Sources/AppRootView.swift", "Sources/AvatarView.swift", "Sources/ProfileView.swift"])
        #expect(report.affectedRootViews.map(\.symbol) == ["AppRootView"])
        #expect(report.affectedRootViews[0].dependencyDistance == 2)
        #expect(report.recommendations[0].dynamicTypeSizes.contains("accessibility5"))
        #expect(report.confidence == .lexical)
    }

    @Test("Traces a changed image resource through its Swift consumer")
    func tracesResourceImpact() throws {
        let fixture = try makeFixture()
        defer { try? FileManager.default.removeItem(at: fixture) }

        let report = ChangeImpactAnalyzer.analyze(workspaceRoot: fixture.path, changedFiles: ["Assets.xcassets/avatar.imageset/Contents.json"])

        #expect(report.affectedRootViews.map(\.symbol) == ["AppRootView"])
        #expect(report.affectedSourceFiles.contains("Sources/AvatarView.swift"))
    }

    @Test("Rejects out-of-scope changes")
    func rejectsOutOfScopeChange() throws {
        let fixture = try makeFixture()
        defer { try? FileManager.default.removeItem(at: fixture) }

        let report = ChangeImpactAnalyzer.analyze(workspaceRoot: fixture.path, changedFiles: ["/tmp/Other.swift"])

        #expect(report.completeness == .unavailable)
        #expect(report.diagnostics.contains { $0.code == "path_outside_workspace" })
    }

    @Test("Upgrades target membership confidence from an existing SwiftPM build plan")
    func confirmsMembershipFromBuildPlan() throws {
        let fixture = try makeFixture()
        defer { try? FileManager.default.removeItem(at: fixture) }
        let description = fixture.appendingPathComponent(".build/arm64-apple-macosx/debug/description.json")
        try FileManager.default.createDirectory(at: description.deletingLastPathComponent(), withIntermediateDirectories: true)
        let inputPaths = ["AppRootView.swift", "ProfileView.swift", "AvatarView.swift"].map {
            fixture.appendingPathComponent("Sources/\($0)").path
        }
        let object: [String: Any] = [
            "swiftCommands": [
                "C.Example-arm64-debug.module": [
                    "moduleName": "Example",
                    "inputs": inputPaths.map { ["kind": "file", "name": $0] }
                ]
            ]
        ]
        try JSONSerialization.data(withJSONObject: object).write(to: description)

        let report = ChangeImpactAnalyzer.analyze(workspaceRoot: fixture.path, changedFiles: ["Sources/AvatarView.swift"])

        #expect(report.confidence == .buildPlanConfirmed)
        #expect(report.compilerEvidence.status == .available)
        #expect(report.compilerEvidence.memberships.count == 3)
        #expect(report.affectedRootViews[0].targetNames == ["Example"])
        #expect(report.affectedRootViews[0].confidence == .buildPlanConfirmed)
    }

    @Test("Reads Xcode Swift file-list target membership without launching a build")
    func readsXcodeFileList() throws {
        let fixture = try makeFixture()
        defer { try? FileManager.default.removeItem(at: fixture) }
        let fileList = fixture.appendingPathComponent("DerivedData/Build/Intermediates.noindex/Example.build/Debug/App.build/Objects-normal/arm64/App.SwiftFileList")
        try FileManager.default.createDirectory(at: fileList.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data((fixture.appendingPathComponent("Sources/AppRootView.swift").path + "\n").utf8).write(to: fileList)

        let evidence = CompilerEvidenceResolver.resolve(workspaceRoot: fixture.path)

        #expect(evidence.status == .available)
        #expect(evidence.targets(for: "Sources/AppRootView.swift") == ["App"])
        #expect(evidence.memberships[0].source == .xcodeSwiftFileList)
    }

    @Test("Context capsules are bounded and omit workspace and source bodies")
    func boundsContextCapsule() throws {
        let fixture = try makeFixture()
        defer { try? FileManager.default.removeItem(at: fixture) }
        let base = ChangeImpactAnalyzer.analyze(workspaceRoot: fixture.path, changedFiles: ["Sources/AvatarView.swift"])
        let oversized = ChangeImpactReport(
            schemaVersion: base.schemaVersion,
            workspaceRoot: fixture.path,
            changedFiles: (0..<120).map { "Sources/Changed\($0).swift" },
            affectedSourceFiles: base.affectedSourceFiles,
            affectedRootViews: base.affectedRootViews,
            recommendations: base.recommendations,
            completeness: base.completeness,
            confidence: base.confidence,
            scannedFileCount: base.scannedFileCount,
            scanTruncated: base.scanTruncated,
            diagnostics: base.diagnostics,
            compilerEvidence: base.compilerEvidence,
            evidenceLimitations: base.evidenceLimitations
        )

        let capsule = ChangeImpactContextCapsule.make(id: "capsule", report: oversized)
        let encoded = String(decoding: try JSONEncoder().encode(capsule), as: UTF8.self)

        #expect(capsule.changedFiles.count == 100)
        #expect(capsule.truncated)
        #expect(!encoded.contains(fixture.path))
        #expect(!encoded.contains("var body"))
    }

    private func makeFixture() throws -> URL {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("viewlens-impact-\(UUID().uuidString)")
        let sources = root.appendingPathComponent("Sources")
        let asset = root.appendingPathComponent("Assets.xcassets/avatar.imageset")
        try FileManager.default.createDirectory(at: sources, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: asset, withIntermediateDirectories: true)
        try Data("import SwiftUI\nstruct AppRootView: View { var body: some View { ProfileView() } }".utf8).write(to: sources.appendingPathComponent("AppRootView.swift"))
        try Data("import SwiftUI\nstruct ProfileView: View { var body: some View { AvatarView() } }".utf8).write(to: sources.appendingPathComponent("ProfileView.swift"))
        try Data("import SwiftUI\nstruct AvatarView: View { var body: some View { Image(\"avatar\") } }".utf8).write(to: sources.appendingPathComponent("AvatarView.swift"))
        try Data("{}".utf8).write(to: asset.appendingPathComponent("Contents.json"))
        return root
    }
}
