import Foundation

/// Controls how ViewLens responds when source code references a resource that is not
/// present in the selected target context.
public enum MissingResourcePolicy: String, Codable, Sendable, CaseIterable {
    case fail
    case request
    case structuralMock = "structural_mock"
    case generatedMock = "generated_mock"
}

/// Controls whether package discovery may use only the existing lockfile or may later
/// perform an explicitly authorized dependency resolution operation.
public enum PackageResolutionPolicy: String, Codable, Sendable, CaseIterable {
    case locked
    case localOnly = "local_only"
    case allowResolution = "allow_resolution"
}

/// User-supplied, bounded context needed to locate a Swift view in its owning build target.
public struct ProjectContextManifest: Codable, Sendable, Equatable {
    public let schemaVersion: String
    public let workspaceRoot: String
    public let projectPath: String?
    public let scheme: String?
    public let target: String?
    public let configuration: String
    public let destination: String?
    public let rootSymbol: String?
    public let sourceFile: String?
    public let scenario: String?
    public let packagePolicy: PackageResolutionPolicy
    public let missingResourcePolicy: MissingResourcePolicy

    public init(
        schemaVersion: String = "1.0",
        workspaceRoot: String,
        projectPath: String? = nil,
        scheme: String? = nil,
        target: String? = nil,
        configuration: String = "Debug",
        destination: String? = nil,
        rootSymbol: String? = nil,
        sourceFile: String? = nil,
        scenario: String? = nil,
        packagePolicy: PackageResolutionPolicy = .locked,
        missingResourcePolicy: MissingResourcePolicy = .fail
    ) {
        self.schemaVersion = schemaVersion
        self.workspaceRoot = workspaceRoot
        self.projectPath = projectPath
        self.scheme = scheme
        self.target = target
        self.configuration = configuration
        self.destination = destination
        self.rootSymbol = rootSymbol
        self.sourceFile = sourceFile
        self.scenario = scenario
        self.packagePolicy = packagePolicy
        self.missingResourcePolicy = missingResourcePolicy
    }
}

public enum ProjectContainerKind: String, Codable, Sendable {
    case workspace
    case project
    case swiftPackage = "swift_package"
}

public struct ProjectContainerRecord: Codable, Sendable, Equatable {
    public let kind: ProjectContainerKind
    public let path: String
    public let selected: Bool
}

public enum ProjectContextStatus: String, Codable, Sendable {
    case readyForBuild = "ready_for_build"
    case inputRequired = "input_required"
    case blocked
}

public enum ContextEvidenceStatus: String, Codable, Sendable {
    case complete
    case partial
    case unavailable
}

public struct ProjectContextCompleteness: Codable, Sendable, Equatable {
    public let buildContext: ContextEvidenceStatus
    public let sourceContext: ContextEvidenceStatus
    public let resourceContext: ContextEvidenceStatus
    public let scenarioContext: ContextEvidenceStatus
}

public enum ContextDiagnosticSeverity: String, Codable, Sendable {
    case info
    case warning
    case error
}

public enum ContextDiagnosticCode: String, Codable, Sendable {
    case invalidWorkspace = "invalid_workspace"
    case pathOutsideWorkspace = "path_outside_workspace"
    case buildContainerUnavailable = "build_container_unavailable"
    case rootSourceUnavailable = "root_source_unavailable"
    case ambiguousSymbol = "ambiguous_symbol"
    case sourceReferenceUnavailable = "source_reference_unavailable"
    case resourceUnavailable = "resource_unavailable"
    case scenarioRequired = "scenario_required"
    case scanTruncated = "scan_truncated"
    case packageResolutionRequired = "package_resolution_required"
    case syntheticResource = "synthetic_resource"
}

public struct ProjectContextDiagnostic: Codable, Sendable, Equatable {
    public let code: ContextDiagnosticCode
    public let severity: ContextDiagnosticSeverity
    public let message: String
    public let sourcePath: String?
    public let recoveryAction: String?

    public init(
        code: ContextDiagnosticCode,
        severity: ContextDiagnosticSeverity,
        message: String,
        sourcePath: String? = nil,
        recoveryAction: String? = nil
    ) {
        self.code = code
        self.severity = severity
        self.message = message
        self.sourcePath = sourcePath
        self.recoveryAction = recoveryAction
    }
}

public struct SourceContextRecord: Codable, Sendable, Equatable {
    public let path: String
    public let declaredSymbols: [String]
    public let referencedLocalSymbols: [String]
    public let imports: [String]
    public let isRoot: Bool
}

public enum ProjectResourceKind: String, Codable, Sendable {
    case image
    case color
    case data
    case localization
    case font
    case other
}

public enum ProjectResourceStatus: String, Codable, Sendable {
    case resolved
    case missing
    case synthetic
}

public struct ProjectResourceRecord: Codable, Sendable, Equatable {
    public let name: String
    public let kind: ProjectResourceKind
    public let status: ProjectResourceStatus
    public let path: String?
    public let referencedBy: [String]
}

public struct ScenarioRequirement: Codable, Sendable, Equatable {
    public let propertyWrapper: String
    public let propertyName: String
    public let typeName: String
    public let sourcePath: String
}

public struct PackageDependencyRecord: Codable, Sendable, Equatable, Hashable {
    public let identity: String
    public let location: String?
    public let version: String?
    public let revision: String?
}

/// A deterministic request for a mock resource. This is evidence about a proposed
/// substitute, not the substitute itself, and is never eligible for baseline approval.
public struct SyntheticResourceDescriptor: Codable, Sendable, Equatable {
    public let name: String
    public let kind: ProjectResourceKind
    public let strategy: MissingResourcePolicy
    public let seed: UInt64
    public let suggestedAspectRatio: Double
    public let provenance: String
    public let baselineEligible: Bool
}

public struct ProjectContextReport: Codable, Sendable, Equatable {
    public let schemaVersion: String
    public let manifest: ProjectContextManifest
    public let status: ProjectContextStatus
    public let completeness: ProjectContextCompleteness
    public let containers: [ProjectContainerRecord]
    public let sourceClosure: [SourceContextRecord]
    public let modules: [String]
    public let packages: [PackageDependencyRecord]
    public let resources: [ProjectResourceRecord]
    public let scenarioRequirements: [ScenarioRequirement]
    public let syntheticResources: [SyntheticResourceDescriptor]
    public let diagnostics: [ProjectContextDiagnostic]
    public let scannedEntryCount: Int
    public let scanTruncated: Bool
    public let evidenceLimitations: [String]

    public var previewHarness: PreviewHarnessDescriptor {
        PreviewHarnessGenerator.generateHarness(for: self)
    }
}

public struct ProjectContextLimits: Sendable, Equatable {
    public var maximumEntries: Int
    public var maximumSwiftFiles: Int
    public var maximumSourceBytesPerFile: Int

    public init(
        maximumEntries: Int = 10_000,
        maximumSwiftFiles: Int = 2_000,
        maximumSourceBytesPerFile: Int = 1_000_000
    ) {
        self.maximumEntries = max(1, maximumEntries)
        self.maximumSwiftFiles = max(1, maximumSwiftFiles)
        self.maximumSourceBytesPerFile = max(1, maximumSourceBytesPerFile)
    }
}

/// Performs read-only, bounded project-context discovery. It never builds the target,
/// downloads packages, runs project scripts, or creates synthetic files.
public enum ProjectContextResolver {
    private struct SourceAnalysis {
        let path: String
        let contents: String
        let declarations: [String]
        let imports: [String]
        let invokedTypes: [String]
        let assets: [(String, ProjectResourceKind)]
        let scenarioRequirements: [ScenarioRequirement]
    }

    private struct InventoryResource {
        let name: String
        let kind: ProjectResourceKind
        let path: String
    }

    private static let skippedDirectoryNames: Set<String> = [
        ".git", ".build", "DerivedData", "Build", ".swiftpm", ".idea", ".vscode"
    ]

    private static let frameworkViewTypes: Set<String> = [
        "AnyView", "Button", "Canvas", "Circle", "ColorPicker", "Divider", "EmptyView",
        "ForEach", "Form", "GeometryReader", "Group", "GroupBox", "HStack", "Image",
        "Label", "LazyHGrid", "LazyHStack", "LazyVGrid", "LazyVStack", "Link", "List",
        "Menu", "NavigationLink", "NavigationStack", "NavigationSplitView", "Picker",
        "ProgressView", "Rectangle", "RoundedRectangle", "ScrollView", "Section", "Slider",
        "Spacer", "TabView", "Text", "TextEditor", "TextField", "Toggle", "VStack", "ZStack"
    ]

    public static func resolve(
        manifest: ProjectContextManifest,
        limits: ProjectContextLimits = ProjectContextLimits()
    ) -> ProjectContextReport {
        let rootURL = URL(fileURLWithPath: manifest.workspaceRoot).standardizedFileURL.resolvingSymlinksInPath()
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: rootURL.path, isDirectory: &isDirectory), isDirectory.boolValue else {
            return invalidWorkspaceReport(manifest: manifest, rootURL: rootURL)
        }

        var containers: [ProjectContainerRecord] = []
        var sourceURLs: [URL] = []
        var inventory: [InventoryResource] = []
        var packageResolvedURLs: [URL] = []
        var scannedEntries = 0
        var truncated = false

        if let enumerator = FileManager.default.enumerator(
            at: rootURL,
            includingPropertiesForKeys: [.isDirectoryKey, .isRegularFileKey, .fileSizeKey],
            options: [.skipsHiddenFiles]
        ) {
            while let entry = enumerator.nextObject() as? URL {
                scannedEntries += 1
                if scannedEntries > limits.maximumEntries {
                    truncated = true
                    break
                }

                let values = try? entry.resourceValues(forKeys: [.isDirectoryKey, .isRegularFileKey, .fileSizeKey])
                let relative = relativePath(entry, root: rootURL)
                if values?.isDirectory == true {
                    let extensionName = entry.pathExtension.lowercased()
                    if skippedDirectoryNames.contains(entry.lastPathComponent) {
                        enumerator.skipDescendants()
                        continue
                    }
                    if extensionName == "xcworkspace" {
                        containers.append(.init(kind: .workspace, path: relative, selected: false))
                        enumerator.skipDescendants()
                        continue
                    }
                    if extensionName == "xcodeproj" {
                        containers.append(.init(kind: .project, path: relative, selected: false))
                        enumerator.skipDescendants()
                        continue
                    }
                    if let kind = catalogResourceKind(extensionName) {
                        inventory.append(.init(name: entry.deletingPathExtension().lastPathComponent, kind: kind, path: relative))
                        enumerator.skipDescendants()
                    }
                    continue
                }

                guard values?.isRegularFile == true else { continue }
                if entry.lastPathComponent == "Package.swift" {
                    containers.append(.init(kind: .swiftPackage, path: relative, selected: false))
                } else if entry.lastPathComponent == "Package.resolved" {
                    packageResolvedURLs.append(entry)
                }

                if entry.pathExtension.lowercased() == "swift", sourceURLs.count < limits.maximumSwiftFiles {
                    sourceURLs.append(entry)
                } else if let kind = looseResourceKind(entry) {
                    inventory.append(.init(name: entry.deletingPathExtension().lastPathComponent, kind: kind, path: relative))
                }
            }
        }

        if sourceURLs.count >= limits.maximumSwiftFiles { truncated = true }
        containers = selectedContainers(containers, manifest: manifest, root: rootURL)

        var analyses: [String: SourceAnalysis] = [:]
        var declarationIndex: [String: [String]] = [:]
        for sourceURL in sourceURLs.sorted(by: { $0.path < $1.path }) {
            guard let size = (try? sourceURL.resourceValues(forKeys: [.fileSizeKey]))?.fileSize,
                  size <= limits.maximumSourceBytesPerFile,
                  let contents = try? String(contentsOf: sourceURL, encoding: .utf8) else { continue }
            let relative = relativePath(sourceURL, root: rootURL)
            let analysis = analyzeSource(contents, path: relative)
            analyses[relative] = analysis
            for declaration in analysis.declarations {
                declarationIndex[declaration, default: []].append(relative)
            }
        }

        var diagnostics: [ProjectContextDiagnostic] = []
        if containers.isEmpty {
            diagnostics.append(.init(
                code: .buildContainerUnavailable,
                severity: .error,
                message: "No .xcworkspace, .xcodeproj, or Package.swift was found in the bounded workspace scan.",
                recoveryAction: "Provide the owning Xcode workspace, project, or Swift package root."
            ))
        }
        if truncated {
            diagnostics.append(.init(
                code: .scanTruncated,
                severity: .warning,
                message: "Project discovery reached its configured scan limit.",
                recoveryAction: "Narrow the workspace root or increase the bounded context limits."
            ))
        }

        let rootPaths = resolveRootPaths(manifest: manifest, root: rootURL, analyses: analyses, declarationIndex: declarationIndex, diagnostics: &diagnostics)
        var queue = rootPaths
        var visited: Set<String> = []
        while let path = queue.first {
            queue.removeFirst()
            guard visited.insert(path).inserted, let analysis = analyses[path] else { continue }
            for symbol in analysis.invokedTypes {
                guard let paths = declarationIndex[symbol] else { continue }
                if paths.count > 1 {
                    diagnostics.append(.init(
                        code: .ambiguousSymbol,
                        severity: .warning,
                        message: "Symbol '\(symbol)' is declared in multiple source files.",
                        sourcePath: path,
                        recoveryAction: "Select the owning target and compile to disambiguate the symbol."
                    ))
                }
                queue.append(contentsOf: paths)
            }
        }

        for path in visited.sorted() {
            guard let analysis = analyses[path] else { continue }
            for symbol in analysis.invokedTypes where symbol.hasSuffix("View") && declarationIndex[symbol] == nil && !frameworkViewTypes.contains(symbol) {
                diagnostics.append(.init(
                    code: .sourceReferenceUnavailable,
                    severity: .error,
                    message: "Referenced view symbol '\(symbol)' was not found in the bounded source scan.",
                    sourcePath: path,
                    recoveryAction: "Include the file or package target that declares \(symbol)."
                ))
            }
        }

        let resourceIndex = Dictionary(grouping: inventory, by: { "\($0.kind.rawValue):\($0.name)" })
        var resourceReferences: [String: (kind: ProjectResourceKind, paths: Set<String>)] = [:]
        var scenarioRequirements: [ScenarioRequirement] = []
        var modules: Set<String> = []
        for path in visited.sorted() {
            guard let analysis = analyses[path] else { continue }
            modules.formUnion(analysis.imports)
            scenarioRequirements.append(contentsOf: analysis.scenarioRequirements)
            for (name, kind) in analysis.assets {
                let key = "\(kind.rawValue):\(name)"
                var value = resourceReferences[key] ?? (kind, [])
                value.paths.insert(path)
                resourceReferences[key] = value
            }
        }

        var resources: [ProjectResourceRecord] = []
        var syntheticResources: [SyntheticResourceDescriptor] = []
        for key in resourceReferences.keys.sorted() {
            guard let reference = resourceReferences[key] else { continue }
            let name = String(key.dropFirst(reference.kind.rawValue.count + 1))
            let matches = resourceIndex[key] ?? []
            if let match = matches.sorted(by: { $0.path < $1.path }).first {
                resources.append(.init(name: name, kind: reference.kind, status: .resolved, path: match.path, referencedBy: reference.paths.sorted()))
                continue
            }

            let status: ProjectResourceStatus
            switch manifest.missingResourcePolicy {
            case .fail, .request:
                status = .missing
            case .structuralMock, .generatedMock:
                status = .synthetic
                syntheticResources.append(.init(
                    name: name,
                    kind: reference.kind,
                    strategy: manifest.missingResourcePolicy,
                    seed: stableSeed("\(reference.kind.rawValue):\(name)"),
                    suggestedAspectRatio: 1.0,
                    provenance: "synthetic:project-context-resolver",
                    baselineEligible: false
                ))
            }
            resources.append(.init(name: name, kind: reference.kind, status: status, path: nil, referencedBy: reference.paths.sorted()))
            diagnostics.append(missingResourceDiagnostic(name: name, kind: reference.kind, paths: reference.paths.sorted(), policy: manifest.missingResourcePolicy))
        }

        scenarioRequirements = Array(Set(scenarioRequirements.map {
            "\($0.propertyWrapper)|\($0.propertyName)|\($0.typeName)|\($0.sourcePath)"
        })).sorted().compactMap { encoded in
            let parts = encoded.split(separator: "|", omittingEmptySubsequences: false).map(String.init)
            guard parts.count == 4 else { return nil }
            return ScenarioRequirement(propertyWrapper: parts[0], propertyName: parts[1], typeName: parts[2], sourcePath: parts[3])
        }
        if !scenarioRequirements.isEmpty && manifest.scenario?.isEmpty != false {
            diagnostics.append(.init(
                code: .scenarioRequired,
                severity: .warning,
                message: "The source closure requires \(scenarioRequirements.count) injected environment or observable value(s), but no preview scenario was supplied.",
                recoveryAction: "Provide a named deterministic preview scenario with non-sensitive fixture values."
            ))
        }

        let sourceClosure = visited.sorted().compactMap { path -> SourceContextRecord? in
            guard let analysis = analyses[path] else { return nil }
            let localSymbols = analysis.invokedTypes.filter { declarationIndex[$0] != nil }.sorted()
            return .init(
                path: path,
                declaredSymbols: analysis.declarations,
                referencedLocalSymbols: localSymbols,
                imports: analysis.imports,
                isRoot: rootPaths.contains(path)
            )
        }

        let packages = packageResolvedURLs.sorted(by: { $0.path < $1.path }).flatMap(parsePackageResolved)
        if manifest.packagePolicy == .locked && modules.contains(where: { module in
            !isKnownPlatformModule(module) && !packages.contains(where: { normalizedPackageName($0.identity) == normalizedPackageName(module) })
        }) {
            diagnostics.append(.init(
                code: .packageResolutionRequired,
                severity: .info,
                message: "Some imported modules cannot be proven from Package.resolved during read-only discovery.",
                recoveryAction: "Use the owning target's compiler diagnostics; authorize package resolution only if the lockfile is incomplete."
            ))
        }

        let hasError = diagnostics.contains { $0.severity == .error }
        let needsInput = diagnostics.contains { diagnostic in
            diagnostic.code == .scenarioRequired ||
            (diagnostic.code == .resourceUnavailable && manifest.missingResourcePolicy == .request)
        }
        let status: ProjectContextStatus = hasError ? .blocked : (needsInput ? .inputRequired : .readyForBuild)
        let resourceMissing = resources.contains { $0.status == .missing }

        return ProjectContextReport(
            schemaVersion: "1.0",
            manifest: manifest,
            status: status,
            completeness: .init(
                buildContext: containers.isEmpty ? .unavailable : .partial,
                sourceContext: rootPaths.isEmpty ? .unavailable : (diagnostics.contains { $0.code == .sourceReferenceUnavailable } ? .partial : .complete),
                resourceContext: resourceMissing ? .partial : .complete,
                scenarioContext: scenarioRequirements.isEmpty || manifest.scenario?.isEmpty == false ? .complete : .partial
            ),
            containers: containers,
            sourceClosure: sourceClosure,
            modules: modules.sorted(),
            packages: Array(Set(packages)).sorted { $0.identity < $1.identity },
            resources: resources,
            scenarioRequirements: scenarioRequirements,
            syntheticResources: syntheticResources.sorted { $0.name < $1.name },
            diagnostics: diagnostics,
            scannedEntryCount: min(scannedEntries, limits.maximumEntries),
            scanTruncated: truncated,
            evidenceLimitations: [
                "Discovery is lexical and read-only; compiler and Index Store evidence have not yet confirmed target membership or overload resolution.",
                "No package download, build script, compilation, signing, application launch, or synthetic file creation was performed.",
                "Synthetic resource descriptors are proposed substitutes and are never eligible for design-fidelity or approved-baseline evidence."
            ]
        )
    }

    private static func invalidWorkspaceReport(manifest: ProjectContextManifest, rootURL: URL) -> ProjectContextReport {
        ProjectContextReport(
            schemaVersion: "1.0",
            manifest: manifest,
            status: .blocked,
            completeness: .init(buildContext: .unavailable, sourceContext: .unavailable, resourceContext: .unavailable, scenarioContext: .unavailable),
            containers: [], sourceClosure: [], modules: [], packages: [], resources: [], scenarioRequirements: [], syntheticResources: [],
            diagnostics: [.init(
                code: .invalidWorkspace,
                severity: .error,
                message: "Workspace root does not exist or is not a directory: \(rootURL.path)",
                recoveryAction: "Provide an existing workspace directory."
            )],
            scannedEntryCount: 0,
            scanTruncated: false,
            evidenceLimitations: ["No project context was inspected because the workspace root was invalid."]
        )
    }

    private static func resolveRootPaths(
        manifest: ProjectContextManifest,
        root: URL,
        analyses: [String: SourceAnalysis],
        declarationIndex: [String: [String]],
        diagnostics: inout [ProjectContextDiagnostic]
    ) -> [String] {
        if let sourceFile = manifest.sourceFile, !sourceFile.isEmpty {
            let sourceURL = URL(fileURLWithPath: sourceFile, relativeTo: root).standardizedFileURL.resolvingSymlinksInPath()
            guard isInside(sourceURL, root: root) else {
                diagnostics.append(.init(code: .pathOutsideWorkspace, severity: .error, message: "Source file is outside the workspace scope.", recoveryAction: "Choose a Swift file under the declared workspace root."))
                return []
            }
            let relative = relativePath(sourceURL, root: root)
            guard analyses[relative] != nil else {
                diagnostics.append(.init(code: .rootSourceUnavailable, severity: .error, message: "Root source file was not found or could not be read.", sourcePath: relative, recoveryAction: "Provide a readable Swift source file within the scan limits."))
                return []
            }
            return [relative]
        }

        if let rootSymbol = manifest.rootSymbol, !rootSymbol.isEmpty, let paths = declarationIndex[rootSymbol] {
            if paths.count > 1 {
                diagnostics.append(.init(code: .ambiguousSymbol, severity: .warning, message: "Root symbol '\(rootSymbol)' has multiple declarations.", recoveryAction: "Provide source_file to select the intended declaration."))
            }
            return paths.sorted()
        }

        diagnostics.append(.init(
            code: .rootSourceUnavailable,
            severity: .error,
            message: "Neither a readable source_file nor a resolvable root_symbol identified the root view.",
            recoveryAction: "Provide root_symbol or source_file together with its owning workspace."
        ))
        return []
    }

    private static func analyzeSource(_ contents: String, path: String) -> SourceAnalysis {
        let declarations = captures(#"\b(?:struct|class|enum|protocol|actor|typealias)\s+([A-Za-z_][A-Za-z0-9_]*)"#, in: contents).map { $0[0] }.sorted()
        let imports = captures(#"(?m)^\s*(?:@testable\s+)?import\s+(?:class\s+|struct\s+|enum\s+|protocol\s+|func\s+|var\s+|let\s+|typealias\s+)?([A-Za-z_][A-Za-z0-9_]*)"#, in: contents).map { $0[0] }.sorted()
        let invokedTypes = Array(Set(captures(#"\b([A-Z][A-Za-z0-9_]*)\s*\("#, in: contents).map { $0[0] })).sorted()
        var assets: [(String, ProjectResourceKind)] = []
        assets += captures(#"\bImage\s*\(\s*\"([^\"]+)\""#, in: contents).map { ($0[0], .image) }
        assets += captures(#"\bColor\s*\(\s*\"([^\"]+)\""#, in: contents).map { ($0[0], .color) }
        assets += captures(#"\b(?:NSDataAsset|DataAsset)\s*\(\s*(?:name:\s*)?\"([^\"]+)\""#, in: contents).map { ($0[0], .data) }
        assets += captures(#"url\s*\(\s*forResource:\s*\"([^\"]+)\""#, in: contents).map { ($0[0], .data) }

        let scenarioRequirements = captures(#"@(EnvironmentObject|ObservedObject|StateObject)\s+(?:private\s+|internal\s+|public\s+)?var\s+([A-Za-z_][A-Za-z0-9_]*)\s*:\s*([A-Za-z_][A-Za-z0-9_\.]*)"#, in: contents).compactMap { values -> ScenarioRequirement? in
            guard values.count == 3 else { return nil }
            return ScenarioRequirement(propertyWrapper: values[0], propertyName: values[1], typeName: values[2], sourcePath: path)
        }
        return SourceAnalysis(path: path, contents: contents, declarations: declarations, imports: imports, invokedTypes: invokedTypes, assets: assets, scenarioRequirements: scenarioRequirements)
    }

    private static func captures(_ pattern: String, in text: String) -> [[String]] {
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return [] }
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        return regex.matches(in: text, range: range).map { match in
            (1..<match.numberOfRanges).compactMap { index in
                guard let range = Range(match.range(at: index), in: text) else { return nil }
                return String(text[range])
            }
        }
    }

    private static func catalogResourceKind(_ extensionName: String) -> ProjectResourceKind? {
        switch extensionName {
        case "imageset", "symbolset": return .image
        case "colorset": return .color
        case "dataset": return .data
        default: return nil
        }
    }

    private static func looseResourceKind(_ url: URL) -> ProjectResourceKind? {
        switch url.pathExtension.lowercased() {
        case "png", "jpg", "jpeg", "heic", "gif", "pdf", "svg": return .image
        case "json", "plist", "yaml", "yml", "csv": return .data
        case "strings", "xcstrings": return .localization
        case "ttf", "otf": return .font
        default: return nil
        }
    }

    private static func selectedContainers(_ containers: [ProjectContainerRecord], manifest: ProjectContextManifest, root: URL) -> [ProjectContainerRecord] {
        let requested = manifest.projectPath.map {
            relativePath(URL(fileURLWithPath: $0, relativeTo: root).standardizedFileURL, root: root)
        }
        let preferred = requested ?? containers.sorted { lhs, rhs in
            let order: [ProjectContainerKind: Int] = [.workspace: 0, .project: 1, .swiftPackage: 2]
            return (order[lhs.kind] ?? 9, lhs.path) < (order[rhs.kind] ?? 9, rhs.path)
        }.first?.path
        return containers.map { .init(kind: $0.kind, path: $0.path, selected: $0.path == preferred) }.sorted { $0.path < $1.path }
    }

    private static func parsePackageResolved(_ url: URL) -> [PackageDependencyRecord] {
        guard let data = try? Data(contentsOf: url),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return [] }
        let pins = (json["pins"] as? [[String: Any]]) ?? ((json["object"] as? [String: Any])?["pins"] as? [[String: Any]]) ?? []
        return pins.compactMap { pin in
            let identity = (pin["identity"] as? String) ?? (pin["package"] as? String)
            guard let identity else { return nil }
            let state = pin["state"] as? [String: Any]
            return PackageDependencyRecord(
                identity: identity,
                location: pin["location"] as? String,
                version: state?["version"] as? String,
                revision: state?["revision"] as? String
            )
        }
    }

    private static func missingResourceDiagnostic(name: String, kind: ProjectResourceKind, paths: [String], policy: MissingResourcePolicy) -> ProjectContextDiagnostic {
        switch policy {
        case .fail:
            return .init(code: .resourceUnavailable, severity: .error, message: "Missing \(kind.rawValue) resource '\(name)'.", sourcePath: paths.first, recoveryAction: "Add the resource to the owning target or choose an explicit mock policy.")
        case .request:
            return .init(code: .resourceUnavailable, severity: .warning, message: "Input is required for missing \(kind.rawValue) resource '\(name)'.", sourcePath: paths.first, recoveryAction: "Provide or map the resource before rendering.")
        case .structuralMock, .generatedMock:
            return .init(code: .syntheticResource, severity: .info, message: "A \(policy.rawValue) descriptor was created for missing \(kind.rawValue) resource '\(name)'.", sourcePath: paths.first, recoveryAction: "Materialize and visibly label the synthetic resource; do not use it for baseline or fidelity claims.")
        }
    }

    private static func relativePath(_ url: URL, root: URL) -> String {
        let rootPath = root.standardizedFileURL.path
        let path = url.standardizedFileURL.path
        guard path == rootPath || path.hasPrefix(rootPath + "/") else { return path }
        return path == rootPath ? "." : String(path.dropFirst(rootPath.count + 1))
    }

    private static func isInside(_ url: URL, root: URL) -> Bool {
        let rootPath = root.standardizedFileURL.resolvingSymlinksInPath().path
        let path = url.standardizedFileURL.resolvingSymlinksInPath().path
        return path == rootPath || path.hasPrefix(rootPath + "/")
    }

    private static func stableSeed(_ value: String) -> UInt64 {
        value.utf8.reduce(14_695_981_039_346_656_037) { ($0 ^ UInt64($1)) &* 1_099_511_628_211 }
    }

    private static func normalizedPackageName(_ value: String) -> String {
        value.lowercased().filter { $0.isLetter || $0.isNumber }
    }

    private static func isKnownPlatformModule(_ module: String) -> Bool {
        let known: Set<String> = [
            "AppKit", "AVFoundation", "Combine", "CoreData", "CoreGraphics", "CoreImage",
            "CoreLocation", "Foundation", "ImageIO", "MapKit", "Observation", "OSLog",
            "QuartzCore", "Swift", "SwiftUI", "UIKit", "UniformTypeIdentifiers", "Vision"
        ]
        return known.contains(module)
    }
}
