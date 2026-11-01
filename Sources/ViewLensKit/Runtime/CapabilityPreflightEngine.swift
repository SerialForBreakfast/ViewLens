import Foundation

/// Workflow kinds evaluated by capability-based preflight (LEARN-05).
public enum PreflightWorkflowKind: String, Codable, Sendable, Equatable, Hashable, CaseIterable {
    case screenshotAudit = "screenshot_audit"
    case nativeOnlyCheck = "native_only_check"
    case templateMatrixAudit = "template_matrix_audit"
    case sourceBuildAndVerify = "source_build_and_verify"
    case liveSimulatorCapture = "live_simulator_capture"
}

/// Prerequisite domains evaluated for a requested workflow (LEARN-05).
public enum PreflightPrerequisiteDomain: String, Codable, Sendable, Equatable, Hashable, CaseIterable {
    case access
    case toolchain
    case target
    case runtime
    case model
    case sourceContext = "source_context"
    case storage
    case ownership
}

/// Standardized readiness state for an individual prerequisite or overall workflow (LEARN-05).
public enum PreflightRequirementStatus: String, Codable, Sendable, Equatable, Hashable {
    case ready
    case blocked
    case unknown
    case notRequired = "not_required"
}

/// Typed root-cause codes shared across Dashboard, Playground, CLI, and MCP (LEARN-05).
public enum PreflightCauseCode: String, Codable, Sendable, Equatable, Hashable {
    case none
    case missingModel = "missing_model"
    case missingXcode = "missing_xcode"
    case missingSimulatorRuntime = "missing_simulator_runtime"
    case permissionDenied = "permission_denied"
    case unknownPermission = "unknown_permission"
    case invalidWorkspace = "invalid_workspace"
    case wrongTarget = "wrong_target"
    case missingDependencies = "missing_dependencies"
    case partialDiscovery = "partial_discovery"
    case insufficientStorage = "insufficient_storage"
    case targetContention = "target_contention"
    case staleReply = "stale_reply"
    case pendingCleanup = "pending_cleanup"
}

/// Actionable guided repair instructions paired with a typed cause code (LEARN-05).
public struct GuidedRepairAction: Codable, Sendable, Equatable, Hashable {
    public let cause: PreflightCauseCode
    public let title: String
    public let instructions: String
    public let suggestedCommand: String?

    public init(
        cause: PreflightCauseCode,
        title: String,
        instructions: String,
        suggestedCommand: String? = nil
    ) {
        self.cause = cause
        self.title = title
        self.instructions = instructions
        self.suggestedCommand = suggestedCommand
    }
}

/// Read-only preview of effects a workflow will perform once authorized and executed (LEARN-05).
public struct WorkflowEffectPreview: Codable, Sendable, Equatable, Hashable {
    public let workflow: PreflightWorkflowKind
    public let willBuild: Bool
    public let willInstall: Bool
    public let willLaunch: Bool
    public let willCapture: Bool
    public let requiredScopes: [String]
    public let summary: String

    public init(
        workflow: PreflightWorkflowKind,
        willBuild: Bool,
        willInstall: Bool,
        willLaunch: Bool,
        willCapture: Bool,
        requiredScopes: [String],
        summary: String
    ) {
        self.workflow = workflow
        self.willBuild = willBuild
        self.willInstall = willInstall
        self.willLaunch = willLaunch
        self.willCapture = willCapture
        self.requiredScopes = requiredScopes
        self.summary = summary
    }
}

/// Evaluation of a single prerequisite domain for a requested workflow (LEARN-05).
public struct PrerequisiteEvaluation: Codable, Sendable, Equatable, Hashable {
    public let domain: PreflightPrerequisiteDomain
    public let status: PreflightRequirementStatus
    public let isBlocking: Bool
    public let cause: PreflightCauseCode
    public let detail: String
    public let repair: GuidedRepairAction?

    public init(
        domain: PreflightPrerequisiteDomain,
        status: PreflightRequirementStatus,
        isBlocking: Bool,
        cause: PreflightCauseCode = .none,
        detail: String,
        repair: GuidedRepairAction? = nil
    ) {
        self.domain = domain
        self.status = status
        self.isBlocking = isBlocking
        self.cause = cause
        self.detail = detail
        self.repair = repair
    }
}

/// Complete read-only capability preflight report for a specific workflow (LEARN-05).
public struct CapabilityPreflightReport: Codable, Sendable, Equatable, Hashable {
    public let workflow: PreflightWorkflowKind
    public let overallStatus: PreflightRequirementStatus
    public let prerequisites: [PreflightPrerequisiteDomain: PrerequisiteEvaluation]
    public let repairs: [GuidedRepairAction]
    public let effectPreview: WorkflowEffectPreview
    public let preflightSideEffectsExecuted: Int

    public init(
        workflow: PreflightWorkflowKind,
        overallStatus: PreflightRequirementStatus,
        prerequisites: [PreflightPrerequisiteDomain: PrerequisiteEvaluation],
        repairs: [GuidedRepairAction],
        effectPreview: WorkflowEffectPreview,
        preflightSideEffectsExecuted: Int = 0
    ) {
        self.workflow = workflow
        self.overallStatus = overallStatus
        self.prerequisites = prerequisites
        self.repairs = repairs
        self.effectPreview = effectPreview
        self.preflightSideEffectsExecuted = preflightSideEffectsExecuted
    }
}

/// Inputs describing current environment/session state for read-only preflight evaluation (LEARN-05).
public struct PreflightEnvironmentContext: Sendable {
    public var workspaceRoot: String?
    public var requestedTarget: String?
    public var availableTargets: [String]
    public var customModelPath: String?
    public var modelAvailableOverride: Bool?
    public var xcodeAvailableOverride: Bool?
    public var simulatorAvailableOverride: Bool?
    public var accessibilityTrustedOverride: Bool?
    public var screenRecordingGrantedOverride: Bool?
    public var partialDiscoveryTruncated: Bool
    public var missingDependencies: [String]
    public var availableStorageBytes: Int64
    public var minimumRequiredStorageBytes: Int64
    public var activeOwnerForTarget: String?
    public var hasPendingCleanup: Bool
    public var hasStaleReply: Bool

    public init(
        workspaceRoot: String? = nil,
        requestedTarget: String? = nil,
        availableTargets: [String] = [],
        customModelPath: String? = nil,
        modelAvailableOverride: Bool? = nil,
        xcodeAvailableOverride: Bool? = nil,
        simulatorAvailableOverride: Bool? = nil,
        accessibilityTrustedOverride: Bool? = nil,
        screenRecordingGrantedOverride: Bool? = nil,
        partialDiscoveryTruncated: Bool = false,
        missingDependencies: [String] = [],
        availableStorageBytes: Int64 = 10 * 1_024 * 1_024 * 1_024,
        minimumRequiredStorageBytes: Int64 = 100 * 1_024 * 1_024,
        activeOwnerForTarget: String? = nil,
        hasPendingCleanup: Bool = false,
        hasStaleReply: Bool = false
    ) {
        self.workspaceRoot = workspaceRoot
        self.requestedTarget = requestedTarget
        self.availableTargets = availableTargets
        self.customModelPath = customModelPath
        self.modelAvailableOverride = modelAvailableOverride
        self.xcodeAvailableOverride = xcodeAvailableOverride
        self.simulatorAvailableOverride = simulatorAvailableOverride
        self.accessibilityTrustedOverride = accessibilityTrustedOverride
        self.screenRecordingGrantedOverride = screenRecordingGrantedOverride
        self.partialDiscoveryTruncated = partialDiscoveryTruncated
        self.missingDependencies = missingDependencies
        self.availableStorageBytes = availableStorageBytes
        self.minimumRequiredStorageBytes = minimumRequiredStorageBytes
        self.activeOwnerForTarget = activeOwnerForTarget
        self.hasPendingCleanup = hasPendingCleanup
        self.hasStaleReply = hasStaleReply
    }
}

/// Read-only capability preflight engine with zero device/build/launch side effects (LEARN-05).
public enum CapabilityPreflightEngine {

    /// Evaluates prerequisites strictly for the requested `workflow` without triggering any launch, install, or input effects.
    public static func evaluate(
        workflow: PreflightWorkflowKind,
        context: PreflightEnvironmentContext = PreflightEnvironmentContext()
    ) -> CapabilityPreflightReport {
        var evaluations: [PreflightPrerequisiteDomain: PrerequisiteEvaluation] = [:]

        // 1. Access
        evaluations[.access] = evaluateAccess(workflow: workflow, context: context)

        // 2. Toolchain
        evaluations[.toolchain] = evaluateToolchain(workflow: workflow, context: context)

        // 3. Target
        evaluations[.target] = evaluateTarget(workflow: workflow, context: context)

        // 4. Runtime
        evaluations[.runtime] = evaluateRuntime(workflow: workflow, context: context)

        // 5. Model (Note: model-unavailable MUST NOT block nativeOnlyCheck!)
        evaluations[.model] = evaluateModel(workflow: workflow, context: context)

        // 6. Source Context
        evaluations[.sourceContext] = evaluateSourceContext(workflow: workflow, context: context)

        // 7. Storage
        evaluations[.storage] = evaluateStorage(workflow: workflow, context: context)

        // 8. Ownership / Pending Cleanup
        evaluations[.ownership] = evaluateOwnership(workflow: workflow, context: context)

        let blocking = evaluations.values.filter { $0.isBlocking && $0.status == .blocked }
        let unknowns = evaluations.values.filter { $0.isBlocking && $0.status == .unknown }

        let overallStatus: PreflightRequirementStatus
        if !blocking.isEmpty {
            overallStatus = .blocked
        } else if !unknowns.isEmpty {
            overallStatus = .unknown
        } else {
            overallStatus = .ready
        }

        let repairs = evaluations.values
            .sorted(by: { $0.domain.rawValue < $1.domain.rawValue })
            .compactMap(\.repair)

        return CapabilityPreflightReport(
            workflow: workflow,
            overallStatus: overallStatus,
            prerequisites: evaluations,
            repairs: repairs,
            effectPreview: previewEffects(for: workflow),
            preflightSideEffectsExecuted: 0
        )
    }

    public static func previewEffects(for workflow: PreflightWorkflowKind) -> WorkflowEffectPreview {
        switch workflow {
        case .screenshotAudit:
            return WorkflowEffectPreview(
                workflow: workflow,
                willBuild: false,
                willInstall: false,
                willLaunch: false,
                willCapture: false,
                requiredScopes: ["audit:read"],
                summary: "Reads a static image file and runs in-process visual detection without building or launching any target."
            )
        case .nativeOnlyCheck:
            return WorkflowEffectPreview(
                workflow: workflow,
                willBuild: false,
                willInstall: false,
                willLaunch: false,
                willCapture: true,
                requiredScopes: ["audit:read"],
                summary: "Inspects native accessibility hierarchy and structural layout without requiring CoreML vision model inference."
            )
        case .templateMatrixAudit:
            return WorkflowEffectPreview(
                workflow: workflow,
                willBuild: false,
                willInstall: false,
                willLaunch: false,
                willCapture: true,
                requiredScopes: ["audit:read", "render:in_process"],
                summary: "Renders registered SwiftUI templates in-process across the selected device, Dynamic Type, and appearance matrix."
            )
        case .sourceBuildAndVerify:
            return WorkflowEffectPreview(
                workflow: workflow,
                willBuild: true,
                willInstall: false,
                willLaunch: true,
                willCapture: true,
                requiredScopes: ["audit:read", "build:execute", "capture:execute"],
                summary: "Compiles the approved workspace target, verifies source/artifact digests, captures matrix permutations, and compares findings."
            )
        case .liveSimulatorCapture:
            return WorkflowEffectPreview(
                workflow: workflow,
                willBuild: true,
                willInstall: true,
                willLaunch: true,
                willCapture: true,
                requiredScopes: ["audit:read", "build:execute", "simulator:control", "capture:execute"],
                summary: "Builds, installs, and launches the target on a Simulator destination before capturing visual and semantic state."
            )
        }
    }

    // MARK: - Domain Evaluators

    private static func evaluateAccess(
        workflow: PreflightWorkflowKind,
        context: PreflightEnvironmentContext
    ) -> PrerequisiteEvaluation {
        switch workflow {
        case .screenshotAudit, .templateMatrixAudit, .nativeOnlyCheck:
            return PrerequisiteEvaluation(
                domain: .access,
                status: .notRequired,
                isBlocking: false,
                detail: "In-process evaluation does not require macOS Accessibility or Screen Recording system permissions."
            )
        case .sourceBuildAndVerify, .liveSimulatorCapture:
            if let axTrusted = context.accessibilityTrustedOverride, !axTrusted {
                let repair = GuidedRepairAction(
                    cause: .permissionDenied,
                    title: "Grant Accessibility Permission",
                    instructions: "Enable Accessibility access for ViewLens in System Settings → Privacy & Security → Accessibility.",
                    suggestedCommand: "open 'x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility'"
                )
                return PrerequisiteEvaluation(
                    domain: .access,
                    status: .blocked,
                    isBlocking: true,
                    cause: .permissionDenied,
                    detail: "Accessibility permission is denied.",
                    repair: repair
                )
            }
            if let screenTrusted = context.screenRecordingGrantedOverride, !screenTrusted {
                let repair = GuidedRepairAction(
                    cause: .permissionDenied,
                    title: "Grant Screen Recording Permission",
                    instructions: "Enable Screen Recording access in System Settings → Privacy & Security → Screen Recording.",
                    suggestedCommand: "open 'x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture'"
                )
                return PrerequisiteEvaluation(
                    domain: .access,
                    status: .blocked,
                    isBlocking: true,
                    cause: .permissionDenied,
                    detail: "Screen Recording permission is denied.",
                    repair: repair
                )
            }
            if context.accessibilityTrustedOverride == nil && workflow == .liveSimulatorCapture {
                return PrerequisiteEvaluation(
                    domain: .access,
                    status: .unknown,
                    isBlocking: false,
                    cause: .unknownPermission,
                    detail: "Automation/Accessibility permission state is unknown without interactive probe; preflight remains read-only."
                )
            }
            return PrerequisiteEvaluation(
                domain: .access,
                status: .ready,
                isBlocking: true,
                detail: "Required access permissions are satisfied."
            )
        }
    }

    private static func evaluateToolchain(
        workflow: PreflightWorkflowKind,
        context: PreflightEnvironmentContext
    ) -> PrerequisiteEvaluation {
        switch workflow {
        case .screenshotAudit, .templateMatrixAudit, .nativeOnlyCheck:
            return PrerequisiteEvaluation(
                domain: .toolchain,
                status: .notRequired,
                isBlocking: false,
                detail: "Xcode build toolchain is not required for in-process template or screenshot checks."
            )
        case .sourceBuildAndVerify, .liveSimulatorCapture:
            let xcodeOK = context.xcodeAvailableOverride ?? true
            guard xcodeOK else {
                let repair = GuidedRepairAction(
                    cause: .missingXcode,
                    title: "Install or Select Full Xcode Toolchain",
                    instructions: "Point xcode-select to a full Xcode.app installation to enable target builds and simulator control.",
                    suggestedCommand: "sudo xcode-select -s /Applications/Xcode.app/Contents/Developer"
                )
                return PrerequisiteEvaluation(
                    domain: .toolchain,
                    status: .blocked,
                    isBlocking: true,
                    cause: .missingXcode,
                    detail: "Full Xcode toolchain (`xcodebuild`) is unavailable.",
                    repair: repair
                )
            }
            return PrerequisiteEvaluation(
                domain: .toolchain,
                status: .ready,
                isBlocking: true,
                detail: "Xcode build toolchain is available."
            )
        }
    }

    private static func evaluateTarget(
        workflow: PreflightWorkflowKind,
        context: PreflightEnvironmentContext
    ) -> PrerequisiteEvaluation {
        if workflow == .screenshotAudit {
            return PrerequisiteEvaluation(
                domain: .target,
                status: .notRequired,
                isBlocking: false,
                detail: "Static screenshot audit does not require a registered target."
            )
        }

        if let target = context.requestedTarget {
            if !context.availableTargets.isEmpty && !context.availableTargets.contains(target) {
                let repair = GuidedRepairAction(
                    cause: .wrongTarget,
                    title: "Select a Valid Target or Template",
                    instructions: "Target '\(target)' was not found in available targets (\(context.availableTargets.joined(separator: ", "))).",
                    suggestedCommand: "viewlens doctor"
                )
                return PrerequisiteEvaluation(
                    domain: .target,
                    status: .blocked,
                    isBlocking: true,
                    cause: .wrongTarget,
                    detail: "Requested target '\(target)' does not match any registered or discovered target.",
                    repair: repair
                )
            }
            return PrerequisiteEvaluation(
                domain: .target,
                status: .ready,
                isBlocking: true,
                detail: "Target '\(target)' is available."
            )
        }

        return PrerequisiteEvaluation(
            domain: .target,
            status: .ready,
            isBlocking: true,
            detail: "Default target selection is ready."
        )
    }

    private static func evaluateRuntime(
        workflow: PreflightWorkflowKind,
        context: PreflightEnvironmentContext
    ) -> PrerequisiteEvaluation {
        if context.hasStaleReply {
            let repair = GuidedRepairAction(
                cause: .staleReply,
                title: "Refresh Runtime Session",
                instructions: "The runtime destination returned a stale generation reply. Re-establish the runtime session before capturing.",
                suggestedCommand: "viewlens doctor"
            )
            return PrerequisiteEvaluation(
                domain: .runtime,
                status: .blocked,
                isBlocking: true,
                cause: .staleReply,
                detail: "Runtime channel reported a stale reply from an older generation.",
                repair: repair
            )
        }

        switch workflow {
        case .screenshotAudit, .nativeOnlyCheck, .templateMatrixAudit, .sourceBuildAndVerify:
            return PrerequisiteEvaluation(
                domain: .runtime,
                status: .ready,
                isBlocking: true,
                detail: "In-process rendering runtime is ready."
            )
        case .liveSimulatorCapture:
            let simOK = context.simulatorAvailableOverride ?? true
            guard simOK else {
                let repair = GuidedRepairAction(
                    cause: .missingSimulatorRuntime,
                    title: "Install an iOS/tvOS Simulator Runtime",
                    instructions: "Install a Simulator runtime in Xcode → Settings → Components.",
                    suggestedCommand: "xcrun simctl list devices"
                )
                return PrerequisiteEvaluation(
                    domain: .runtime,
                    status: .blocked,
                    isBlocking: true,
                    cause: .missingSimulatorRuntime,
                    detail: "No available Simulator runtime or device was found.",
                    repair: repair
                )
            }
            return PrerequisiteEvaluation(
                domain: .runtime,
                status: .ready,
                isBlocking: true,
                detail: "Simulator runtime is available."
            )
        }
    }

    private static func evaluateModel(
        workflow: PreflightWorkflowKind,
        context: PreflightEnvironmentContext
    ) -> PrerequisiteEvaluation {
        // LEARN-05: model-unavailable must NOT block supported native-only checks!
        if workflow == .nativeOnlyCheck {
            return PrerequisiteEvaluation(
                domain: .model,
                status: .notRequired,
                isBlocking: false,
                detail: "CoreML detector model is not required for native-only semantic and structural checks."
            )
        }

        let isModelAvailable: Bool
        if let override = context.modelAvailableOverride {
            isModelAvailable = override
        } else {
            if case .success = ModelLocator.resolve(customPath: context.customModelPath) {
                isModelAvailable = true
            } else {
                isModelAvailable = false
            }
        }

        guard isModelAvailable else {
            let repair = GuidedRepairAction(
                cause: .missingModel,
                title: "Provide CoreML Detector Model or Run Native-Only Check",
                instructions: "Ensure YOLO11n.mlmodelc is present in bundle resources or set VIEWLENS_MODEL_PATH. Native-only checks remain available without the model.",
                suggestedCommand: "viewlens accessibility --template LoginForm"
            )
            return PrerequisiteEvaluation(
                domain: .model,
                status: .blocked,
                isBlocking: true,
                cause: .missingModel,
                detail: "CoreML detector model is unavailable for visual inference.",
                repair: repair
            )
        }

        return PrerequisiteEvaluation(
            domain: .model,
            status: .ready,
            isBlocking: true,
            detail: "CoreML detector model is available."
        )
    }

    private static func evaluateSourceContext(
        workflow: PreflightWorkflowKind,
        context: PreflightEnvironmentContext
    ) -> PrerequisiteEvaluation {
        switch workflow {
        case .screenshotAudit, .templateMatrixAudit, .nativeOnlyCheck:
            return PrerequisiteEvaluation(
                domain: .sourceContext,
                status: .notRequired,
                isBlocking: false,
                detail: "Workspace source closure is not required for registered template or screenshot checks."
            )
        case .sourceBuildAndVerify, .liveSimulatorCapture:
            if !context.missingDependencies.isEmpty {
                let repair = GuidedRepairAction(
                    cause: .missingDependencies,
                    title: "Resolve Missing Package Dependencies",
                    instructions: "Missing dependencies: \(context.missingDependencies.joined(separator: ", ")). Resolve packages before building.",
                    suggestedCommand: "swift package resolve"
                )
                return PrerequisiteEvaluation(
                    domain: .sourceContext,
                    status: .blocked,
                    isBlocking: true,
                    cause: .missingDependencies,
                    detail: "Required package dependencies are missing: \(context.missingDependencies.joined(separator: ", ")).",
                    repair: repair
                )
            }
            if context.partialDiscoveryTruncated {
                let repair = GuidedRepairAction(
                    cause: .partialDiscovery,
                    title: "Narrow Workspace Scope or Increase Scan Budget",
                    instructions: "Project context discovery was truncated before full source closure was verified.",
                    suggestedCommand: "viewlens context --workspace ."
                )
                return PrerequisiteEvaluation(
                    domain: .sourceContext,
                    status: .unknown,
                    isBlocking: true,
                    cause: .partialDiscovery,
                    detail: "Source context discovery is partial/truncated.",
                    repair: repair
                )
            }
            if let root = context.workspaceRoot {
                var isDir: ObjCBool = false
                if !FileManager.default.fileExists(atPath: root, isDirectory: &isDir) || !isDir.boolValue {
                    let repair = GuidedRepairAction(
                        cause: .invalidWorkspace,
                        title: "Supply a Valid Workspace Directory",
                        instructions: "The workspace path '\(root)' does not exist or is not a directory.",
                        suggestedCommand: "pwd"
                    )
                    return PrerequisiteEvaluation(
                        domain: .sourceContext,
                        status: .blocked,
                        isBlocking: true,
                        cause: .invalidWorkspace,
                        detail: "Workspace root '\(root)' is invalid.",
                        repair: repair
                    )
                }
            }
            return PrerequisiteEvaluation(
                domain: .sourceContext,
                status: .ready,
                isBlocking: true,
                detail: "Source context and dependency pins are ready."
            )
        }
    }

    private static func evaluateStorage(
        workflow: PreflightWorkflowKind,
        context: PreflightEnvironmentContext
    ) -> PrerequisiteEvaluation {
        guard context.availableStorageBytes >= context.minimumRequiredStorageBytes else {
            let availMB = context.availableStorageBytes / (1_024 * 1_024)
            let reqMB = context.minimumRequiredStorageBytes / (1_024 * 1_024)
            let repair = GuidedRepairAction(
                cause: .insufficientStorage,
                title: "Free Disk Space or Prune Old Review Artifacts",
                instructions: "Available storage (\(availMB) MB) is below the required \(reqMB) MB reservation.",
                suggestedCommand: "viewlens cache --prune"
            )
            return PrerequisiteEvaluation(
                domain: .storage,
                status: .blocked,
                isBlocking: true,
                cause: .insufficientStorage,
                detail: "Insufficient storage capacity (\(availMB) MB available, \(reqMB) MB required).",
                repair: repair
            )
        }
        return PrerequisiteEvaluation(
            domain: .storage,
            status: .ready,
            isBlocking: true,
            detail: "Storage capacity is sufficient."
        )
    }

    private static func evaluateOwnership(
        workflow: PreflightWorkflowKind,
        context: PreflightEnvironmentContext
    ) -> PrerequisiteEvaluation {
        if context.hasPendingCleanup {
            let repair = GuidedRepairAction(
                cause: .pendingCleanup,
                title: "Await Pending Target Cleanup",
                instructions: "A previous cancelled or timed-out operation on this target is still completing cleanup.",
                suggestedCommand: "viewlens tasks --list"
            )
            return PrerequisiteEvaluation(
                domain: .ownership,
                status: .blocked,
                isBlocking: true,
                cause: .pendingCleanup,
                detail: "Target has pending cleanup from a prior operation.",
                repair: repair
            )
        }
        if let owner = context.activeOwnerForTarget {
            let repair = GuidedRepairAction(
                cause: .targetContention,
                title: "Target Busy with Active Operation",
                instructions: "Target is currently owned by operation '\(owner)'. Wait for completion or cancel the active task.",
                suggestedCommand: "viewlens tasks --cancel \(owner)"
            )
            return PrerequisiteEvaluation(
                domain: .ownership,
                status: .blocked,
                isBlocking: true,
                cause: .targetContention,
                detail: "Target contention: owned by active operation '\(owner)'.",
                repair: repair
            )
        }
        return PrerequisiteEvaluation(
            domain: .ownership,
            status: .ready,
            isBlocking: true,
            detail: "Target ownership is available."
        )
    }
}
