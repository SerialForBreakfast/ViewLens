import Foundation

public enum ChangeImpactConfidence: String, Codable, Sendable {
    case lexical
    case buildPlanConfirmed = "build_plan_confirmed"
    case compilerConfirmed = "compiler_confirmed"
}

public enum ChangeImpactCompleteness: String, Codable, Sendable {
    case complete
    case partial
    case unavailable
}

public struct ImpactedRootView: Codable, Sendable, Equatable {
    public let symbol: String
    public let sourcePath: String
    public let dependencyDistance: Int
    public let confidence: ChangeImpactConfidence
    public let targetNames: [String]
    public let reasons: [String]
}

public struct ImpactAuditRecommendation: Codable, Sendable, Equatable {
    public let rootSymbol: String
    public let devices: [String]
    public let dynamicTypeSizes: [String]
    public let colorSchemes: [String]
    public let accommodations: [String]
    public let reason: String
}

public struct ChangeImpactDiagnostic: Codable, Sendable, Equatable {
    public let severity: ContextDiagnosticSeverity
    public let code: String
    public let message: String
    public let path: String?
}

public struct ChangeImpactReport: Codable, Sendable, Equatable {
    public let schemaVersion: String
    public let workspaceRoot: String
    public let changedFiles: [String]
    public let affectedSourceFiles: [String]
    public let affectedRootViews: [ImpactedRootView]
    public let recommendations: [ImpactAuditRecommendation]
    public let completeness: ChangeImpactCompleteness
    public let confidence: ChangeImpactConfidence
    public let scannedFileCount: Int
    public let scanTruncated: Bool
    public let diagnostics: [ChangeImpactDiagnostic]
    public let compilerEvidence: CompilerEvidenceSnapshot
    public let evidenceLimitations: [String]
}

public struct ChangeImpactLimits: Sendable, Equatable {
    public var maximumEntries: Int
    public var maximumSwiftFiles: Int
    public var maximumSourceBytesPerFile: Int

    public init(maximumEntries: Int = 10_000, maximumSwiftFiles: Int = 2_000, maximumSourceBytesPerFile: Int = 1_000_000) {
        self.maximumEntries = max(1, maximumEntries)
        self.maximumSwiftFiles = max(1, maximumSwiftFiles)
        self.maximumSourceBytesPerFile = max(1, maximumSourceBytesPerFile)
    }
}

/// Computes a bounded, read-only lexical impact graph. Compiler-backed confirmation is
/// intentionally represented as a future confidence level and is never inferred here.
public enum ChangeImpactAnalyzer {
    private struct SourceFacts {
        let path: String
        let declarations: [String]
        let viewSymbols: [String]
        let invokedTypes: [String]
        let resourceNames: Set<String>
    }

    private static let skippedDirectories: Set<String> = [
        ".git", ".build", "DerivedData", "Build", ".swiftpm", ".idea", ".vscode"
    ]

    public static func analyze(
        workspaceRoot: String,
        changedFiles: [String],
        limits: ChangeImpactLimits = ChangeImpactLimits()
    ) -> ChangeImpactReport {
        let root = URL(fileURLWithPath: workspaceRoot).standardizedFileURL.resolvingSymlinksInPath()
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: root.path, isDirectory: &isDirectory), isDirectory.boolValue else {
            return unavailableReport(workspaceRoot: workspaceRoot, changedFiles: changedFiles, message: "Workspace root does not exist or is not a directory.")
        }

        var diagnostics: [ChangeImpactDiagnostic] = []
        let normalizedChanges = changedFiles.compactMap { supplied -> String? in
            let url = scopedURL(supplied, root: root)
            guard isInside(url, root: root) else {
                diagnostics.append(.init(severity: .error, code: "path_outside_workspace", message: "Changed file is outside the declared workspace.", path: supplied))
                return nil
            }
            return relativePath(url, root: root)
        }

        guard !normalizedChanges.isEmpty else {
            let compilerEvidence = CompilerEvidenceResolver.resolve(workspaceRoot: workspaceRoot).restricted(to: [])
            return ChangeImpactReport(
                schemaVersion: "1.0", workspaceRoot: workspaceRoot, changedFiles: [], affectedSourceFiles: [], affectedRootViews: [], recommendations: [],
                completeness: .unavailable, confidence: .lexical, scannedFileCount: 0, scanTruncated: false, diagnostics: diagnostics + [
                    .init(severity: .error, code: "changed_files_required", message: "At least one in-scope changed file is required.", path: nil)
                ], compilerEvidence: compilerEvidence, evidenceLimitations: defaultLimitations + compilerEvidence.evidenceLimitations
            )
        }

        var swiftURLs: [URL] = []
        var entryCount = 0
        var truncated = false
        if let enumerator = FileManager.default.enumerator(at: root, includingPropertiesForKeys: [.isDirectoryKey, .isRegularFileKey, .fileSizeKey], options: [.skipsHiddenFiles]) {
            while let entry = enumerator.nextObject() as? URL {
                entryCount += 1
                if entryCount > limits.maximumEntries { truncated = true; break }
                let values = try? entry.resourceValues(forKeys: [.isDirectoryKey, .isRegularFileKey, .fileSizeKey])
                if values?.isDirectory == true {
                    if skippedDirectories.contains(entry.lastPathComponent) { enumerator.skipDescendants() }
                    continue
                }
                if values?.isRegularFile == true, entry.pathExtension.lowercased() == "swift" {
                    if swiftURLs.count >= limits.maximumSwiftFiles { truncated = true; break }
                    swiftURLs.append(entry)
                }
            }
        }

        var factsByPath: [String: SourceFacts] = [:]
        var declarationPaths: [String: Set<String>] = [:]
        for url in swiftURLs.sorted(by: { $0.path < $1.path }) {
            guard let size = (try? url.resourceValues(forKeys: [.fileSizeKey]))?.fileSize,
                  size <= limits.maximumSourceBytesPerFile,
                  let source = try? String(contentsOf: url, encoding: .utf8) else { continue }
            let path = relativePath(url, root: root)
            let facts = parse(source: source, path: path)
            factsByPath[path] = facts
            for symbol in facts.declarations { declarationPaths[symbol, default: []].insert(path) }
        }

        var reverseEdges: [String: Set<String>] = [:]
        for facts in factsByPath.values {
            for symbol in facts.invokedTypes {
                for dependency in declarationPaths[symbol] ?? [] where dependency != facts.path {
                    reverseEdges[dependency, default: []].insert(facts.path)
                }
            }
        }

        var startingPaths: Set<String> = []
        var startReasons: [String: Set<String>] = [:]
        for changed in normalizedChanges.sorted() {
            if factsByPath[changed] != nil {
                startingPaths.insert(changed)
                startReasons[changed, default: []].insert("Changed Swift source: \(changed)")
                continue
            }

            let resourceName = changedResourceName(for: changed)
            let resourceConsumers = factsByPath.values.filter { $0.resourceNames.contains(resourceName) }
            if resourceConsumers.isEmpty {
                diagnostics.append(.init(severity: .warning, code: "change_unresolved", message: "No local Swift reference was found for the changed file.", path: changed))
            }
            for consumer in resourceConsumers {
                startingPaths.insert(consumer.path)
                startReasons[consumer.path, default: []].insert("References changed resource '\(resourceName)' from \(changed)")
            }
        }

        var distance: [String: Int] = [:]
        var reasons = startReasons
        var queue = startingPaths.sorted()
        for path in queue { distance[path] = 0 }
        while !queue.isEmpty {
            let current = queue.removeFirst()
            let nextDistance = (distance[current] ?? 0) + 1
            for dependent in (reverseEdges[current] ?? []).sorted() {
                if distance[dependent] == nil || nextDistance < distance[dependent]! {
                    distance[dependent] = nextDistance
                    queue.append(dependent)
                }
                reasons[dependent, default: []].insert("Transitively depends on \(current)")
            }
        }

        let affected = Set(distance.keys)
        let compilerEvidence = CompilerEvidenceResolver.resolve(workspaceRoot: workspaceRoot).restricted(to: affected)
        let allAffectedSourcesConfirmed = !affected.isEmpty && affected.allSatisfy { !compilerEvidence.targets(for: $0).isEmpty }
        let reportConfidence: ChangeImpactConfidence = allAffectedSourcesConfirmed ? .buildPlanConfirmed : .lexical

        var roots: [ImpactedRootView] = []
        for path in affected.sorted() {
            guard let facts = factsByPath[path], !facts.viewSymbols.isEmpty else { continue }
            let hasAffectedParent = !(reverseEdges[path] ?? []).intersection(affected).isEmpty
            if hasAffectedParent { continue }
            for symbol in facts.viewSymbols.sorted() {
                roots.append(.init(
                    symbol: symbol,
                    sourcePath: path,
                    dependencyDistance: distance[path] ?? 0,
                    confidence: compilerEvidence.targets(for: path).isEmpty ? .lexical : .buildPlanConfirmed,
                    targetNames: compilerEvidence.targets(for: path),
                    reasons: (reasons[path] ?? []).sorted()
                ))
            }
        }

        if !affected.isEmpty && roots.isEmpty {
            diagnostics.append(.init(severity: .warning, code: "root_view_unresolved", message: "Affected source was found, but no top-level SwiftUI View declaration could be identified lexically.", path: nil))
        }
        if truncated {
            diagnostics.append(.init(severity: .warning, code: "scan_truncated", message: "Change-impact discovery reached its configured scan limit.", path: nil))
        }

        let hasError = diagnostics.contains { $0.severity == .error }
        let completeness: ChangeImpactCompleteness = hasError ? .unavailable : ((truncated || diagnostics.contains { $0.severity == .warning }) ? .partial : .complete)
        let recommendations = roots.map { rootView in
            ImpactAuditRecommendation(
                rootSymbol: rootView.symbol,
                devices: ["iPhoneSE", "iPhone16Pro", "iPadPro11"],
                dynamicTypeSizes: ["large", "accessibility3", "accessibility5"],
                colorSchemes: ["light", "dark"],
                accommodations: ["increase_contrast", "differentiate_without_color", "reduce_motion", "rtl"],
                reason: "Audit the top-level affected view at dependency distance \(rootView.dependencyDistance)."
            )
        }

        return ChangeImpactReport(
            schemaVersion: "1.0",
            workspaceRoot: workspaceRoot,
            changedFiles: normalizedChanges.sorted(),
            affectedSourceFiles: affected.sorted(),
            affectedRootViews: roots.sorted { ($0.dependencyDistance, $0.symbol) > ($1.dependencyDistance, $1.symbol) },
            recommendations: recommendations.sorted { $0.rootSymbol < $1.rootSymbol },
            completeness: completeness,
            confidence: reportConfidence,
            scannedFileCount: factsByPath.count,
            scanTruncated: truncated,
            diagnostics: diagnostics + compilerEvidence.diagnostics,
            compilerEvidence: compilerEvidence,
            evidenceLimitations: defaultLimitations + compilerEvidence.evidenceLimitations
        )
    }

    private static func parse(source: String, path: String) -> SourceFacts {
        let declarations = captures(#"\b(?:struct|class|enum|protocol|actor|typealias)\s+([A-Za-z_][A-Za-z0-9_]*)"#, source)
        let viewSymbols = captures(#"\bstruct\s+([A-Za-z_][A-Za-z0-9_]*)\s*(?::[^\{]*\bView\b)"#, source)
        let invokedTypes = Array(Set(captures(#"\b([A-Z][A-Za-z0-9_]*)\s*\("#, source))).sorted()
        let images = captures(#"\b(?:Image|Color)\s*\(\s*\"([^\"]+)\""#, source)
        let bundleResources = captures(#"forResource:\s*\"([^\"]+)\""#, source)
        return SourceFacts(path: path, declarations: declarations.sorted(), viewSymbols: viewSymbols.sorted(), invokedTypes: invokedTypes, resourceNames: Set(images + bundleResources))
    }

    private static func captures(_ pattern: String, _ source: String) -> [String] {
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return [] }
        let range = NSRange(source.startIndex..<source.endIndex, in: source)
        return regex.matches(in: source, range: range).compactMap { match in
            guard match.numberOfRanges > 1, let range = Range(match.range(at: 1), in: source) else { return nil }
            return String(source[range])
        }
    }

    private static func relativePath(_ url: URL, root: URL) -> String {
        let rootPath = root.standardizedFileURL.resolvingSymlinksInPath().path
        let path = url.standardizedFileURL.resolvingSymlinksInPath().path
        return path == rootPath ? "." : String(path.dropFirst(rootPath.count + 1))
    }

    private static func scopedURL(_ path: String, root: URL) -> URL {
        let url = (path as NSString).isAbsolutePath
            ? URL(fileURLWithPath: path)
            : root.appendingPathComponent(path)
        return url.standardizedFileURL.resolvingSymlinksInPath()
    }

    private static func changedResourceName(for path: String) -> String {
        let components = URL(fileURLWithPath: path).pathComponents
        if let catalogComponent = components.reversed().first(where: {
            let ext = URL(fileURLWithPath: $0).pathExtension.lowercased()
            return ["imageset", "symbolset", "colorset", "dataset"].contains(ext)
        }) {
            return URL(fileURLWithPath: catalogComponent).deletingPathExtension().lastPathComponent
        }
        return URL(fileURLWithPath: path).deletingPathExtension().lastPathComponent
    }

    private static func isInside(_ url: URL, root: URL) -> Bool {
        let rootPath = root.resolvingSymlinksInPath().path
        let path = url.resolvingSymlinksInPath().path
        return path == rootPath || path.hasPrefix(rootPath + "/")
    }

    private static let defaultLimitations = [
        "Impact edges are lexical and do not prove target membership, conditional-compilation paths, overload resolution, or runtime navigation reachability.",
        "Audit recommendations describe conservative coverage and are not evidence that a permutation was executed.",
        "No package download, build, script execution, application launch, or source mutation was performed."
    ]

    private static func unavailableReport(workspaceRoot: String, changedFiles: [String], message: String) -> ChangeImpactReport {
        ChangeImpactReport(
            schemaVersion: "1.0", workspaceRoot: workspaceRoot, changedFiles: changedFiles, affectedSourceFiles: [], affectedRootViews: [], recommendations: [],
            completeness: .unavailable, confidence: .lexical, scannedFileCount: 0, scanTruncated: false,
            diagnostics: [.init(severity: .error, code: "invalid_workspace", message: message, path: workspaceRoot)],
            compilerEvidence: .init(status: .unavailable, memberships: [], inspectedArtifacts: [], diagnostics: [], evidenceLimitations: []),
            evidenceLimitations: defaultLimitations
        )
    }
}
