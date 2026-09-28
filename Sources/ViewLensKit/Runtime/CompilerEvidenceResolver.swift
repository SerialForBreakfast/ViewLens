import Foundation

public enum CompilerEvidenceSource: String, Codable, Sendable {
    case swiftPMBuildDescription = "swiftpm_build_description"
    case xcodeSwiftFileList = "xcode_swift_file_list"
}

public enum CompilerEvidenceStatus: String, Codable, Sendable {
    case available
    case partial
    case unavailable
}

public struct CompilerTargetMembership: Codable, Sendable, Equatable, Hashable {
    public let sourcePath: String
    public let targetName: String
    public let source: CompilerEvidenceSource
    public let evidencePath: String
}

public struct CompilerEvidenceSnapshot: Codable, Sendable, Equatable {
    public let status: CompilerEvidenceStatus
    public let memberships: [CompilerTargetMembership]
    public let inspectedArtifacts: [String]
    public let diagnostics: [ChangeImpactDiagnostic]
    public let evidenceLimitations: [String]

    public func targets(for sourcePath: String) -> [String] {
        memberships.filter { $0.sourcePath == sourcePath }.map(\.targetName).uniqued().sorted()
    }

    public func restricted(to sourcePaths: Set<String>) -> CompilerEvidenceSnapshot {
        let selected = memberships.filter { sourcePaths.contains($0.sourcePath) }
        return .init(
            status: selected.isEmpty ? .unavailable : status,
            memberships: selected,
            inspectedArtifacts: inspectedArtifacts,
            diagnostics: diagnostics,
            evidenceLimitations: evidenceLimitations
        )
    }
}

public struct CompilerEvidenceLimits: Sendable, Equatable {
    public var maximumEntries: Int
    public var maximumArtifacts: Int
    public var maximumArtifactBytes: Int

    public init(maximumEntries: Int = 20_000, maximumArtifacts: Int = 100, maximumArtifactBytes: Int = 25_000_000) {
        self.maximumEntries = max(1, maximumEntries)
        self.maximumArtifacts = max(1, maximumArtifacts)
        self.maximumArtifactBytes = max(1, maximumArtifactBytes)
    }
}

/// Reads existing compiler-generated build metadata without invoking SwiftPM, Xcode,
/// build scripts, package resolution, or the compiler.
public enum CompilerEvidenceResolver {
    public static func resolve(
        workspaceRoot: String,
        limits: CompilerEvidenceLimits = CompilerEvidenceLimits()
    ) -> CompilerEvidenceSnapshot {
        let root = URL(fileURLWithPath: workspaceRoot).standardizedFileURL.resolvingSymlinksInPath()
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: root.path, isDirectory: &isDirectory), isDirectory.boolValue else {
            return .init(
                status: .unavailable,
                memberships: [], inspectedArtifacts: [],
                diagnostics: [.init(severity: .error, code: "invalid_workspace", message: "Workspace root does not exist or is not a directory.", path: workspaceRoot)],
                evidenceLimitations: limitations
            )
        }

        var artifacts: [(URL, CompilerEvidenceSource)] = []
        var entryCount = 0
        var truncated = false
        for searchRoot in [root.appendingPathComponent(".build"), root.appendingPathComponent("DerivedData")] {
            guard FileManager.default.fileExists(atPath: searchRoot.path),
                  let enumerator = FileManager.default.enumerator(at: searchRoot, includingPropertiesForKeys: [.isDirectoryKey, .isRegularFileKey, .fileSizeKey], options: [.skipsHiddenFiles]) else { continue }
            while let entry = enumerator.nextObject() as? URL {
                entryCount += 1
                if entryCount > limits.maximumEntries || artifacts.count >= limits.maximumArtifacts { truncated = true; break }
                let values = try? entry.resourceValues(forKeys: [.isDirectoryKey, .isRegularFileKey, .fileSizeKey])
                if values?.isDirectory == true, entry.lastPathComponent == "checkouts" {
                    enumerator.skipDescendants()
                    continue
                }
                guard values?.isRegularFile == true, (values?.fileSize ?? 0) <= limits.maximumArtifactBytes else { continue }
                if entry.lastPathComponent == "description.json" {
                    artifacts.append((entry, .swiftPMBuildDescription))
                } else if entry.pathExtension == "SwiftFileList" {
                    artifacts.append((entry, .xcodeSwiftFileList))
                }
            }
            if truncated { break }
        }

        var memberships: Set<CompilerTargetMembership> = []
        var diagnostics: [ChangeImpactDiagnostic] = []
        var inspected: [String] = []
        for (artifact, source) in artifacts.sorted(by: { $0.0.path < $1.0.path }) {
            let evidencePath = relativePath(artifact, root: root)
            inspected.append(evidencePath)
            switch source {
            case .swiftPMBuildDescription:
                guard let data = try? Data(contentsOf: artifact),
                      let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                      let commands = object["swiftCommands"] as? [String: Any] else {
                    diagnostics.append(.init(severity: .warning, code: "compiler_evidence_malformed", message: "SwiftPM build description could not be decoded.", path: evidencePath))
                    continue
                }
                for (commandID, rawCommand) in commands {
                    guard let command = rawCommand as? [String: Any],
                          let moduleName = command["moduleName"] as? String,
                          let inputs = command["inputs"] as? [[String: Any]] else { continue }
                    for input in inputs where input["kind"] as? String == "file" {
                        guard let name = input["name"] as? String, name.hasSuffix(".swift"),
                              let sourcePath = scopedRelativePath(name, root: root) else { continue }
                        memberships.insert(.init(sourcePath: sourcePath, targetName: moduleName, source: source, evidencePath: "\(evidencePath)#\(commandID)"))
                    }
                }
            case .xcodeSwiftFileList:
                guard let contents = try? String(contentsOf: artifact, encoding: .utf8) else {
                    diagnostics.append(.init(severity: .warning, code: "compiler_evidence_malformed", message: "Xcode Swift file list could not be read.", path: evidencePath))
                    continue
                }
                let targetName = artifact.deletingPathExtension().lastPathComponent
                for line in contents.split(whereSeparator: \.isNewline).map(String.init) {
                    guard let sourcePath = scopedRelativePath(line, root: root) else { continue }
                    memberships.insert(.init(sourcePath: sourcePath, targetName: targetName, source: source, evidencePath: evidencePath))
                }
            }
        }

        if truncated {
            diagnostics.append(.init(severity: .warning, code: "compiler_evidence_truncated", message: "Compiler evidence discovery reached its configured bound.", path: nil))
        }
        let status: CompilerEvidenceStatus = memberships.isEmpty ? .unavailable : ((truncated || diagnostics.contains { $0.severity != .info }) ? .partial : .available)
        return .init(
            status: status,
            memberships: memberships.sorted { ($0.sourcePath, $0.targetName, $0.evidencePath) < ($1.sourcePath, $1.targetName, $1.evidencePath) },
            inspectedArtifacts: inspected.sorted(),
            diagnostics: diagnostics,
            evidenceLimitations: limitations
        )
    }

    private static func scopedRelativePath(_ path: String, root: URL) -> String? {
        let expanded = path.replacingOccurrences(of: "$(SRCROOT)", with: root.path)
        let url = (expanded as NSString).isAbsolutePath ? URL(fileURLWithPath: expanded) : root.appendingPathComponent(expanded)
        let canonical = url.standardizedFileURL.resolvingSymlinksInPath()
        let rootPath = root.path
        guard canonical.path == rootPath || canonical.path.hasPrefix(rootPath + "/") else { return nil }
        return canonical.path == rootPath ? "." : String(canonical.path.dropFirst(rootPath.count + 1))
    }

    private static func relativePath(_ url: URL, root: URL) -> String {
        let canonical = url.standardizedFileURL.resolvingSymlinksInPath().path
        return canonical == root.path ? "." : String(canonical.dropFirst(root.path.count + 1))
    }

    private static let limitations = [
        "Evidence proves that a source path appeared in an existing compiler build plan; it does not prove that the current file contents compiled successfully.",
        "Conditional-compilation branches, overload resolution, generated sources, and runtime reachability require richer compiler or Index Store queries.",
        "No build, package resolution, script execution, or source mutation was performed while collecting this evidence."
    ]
}

private extension Sequence where Element: Hashable {
    func uniqued() -> [Element] {
        var seen: Set<Element> = []
        return filter { seen.insert($0).inserted }
    }
}
