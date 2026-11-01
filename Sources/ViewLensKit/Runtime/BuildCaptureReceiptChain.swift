import Foundation
import CryptoKit

/// Cryptographic digest and metadata for the workspace source tree at the start and end of a build (LEARN-04).
public struct SourceTreeReceipt: Codable, Sendable, Equatable, Hashable {
    public let workspaceRoot: String
    public let target: String
    public let sourceDigest: String
    public let fileDigests: [String: String]
    public let includesUncommittedChanges: Bool
    public let uncommittedFiles: [String]
    public let dependencyPins: [PackageDependencyRecord]
    public let capturedAt: Date

    public init(
        workspaceRoot: String,
        target: String,
        sourceDigest: String,
        fileDigests: [String: String],
        includesUncommittedChanges: Bool = true,
        uncommittedFiles: [String] = [],
        dependencyPins: [PackageDependencyRecord] = [],
        capturedAt: Date = Date()
    ) {
        self.workspaceRoot = workspaceRoot
        self.target = target
        self.sourceDigest = sourceDigest
        self.fileDigests = fileDigests
        self.includesUncommittedChanges = includesUncommittedChanges
        self.uncommittedFiles = uncommittedFiles.sorted()
        self.dependencyPins = dependencyPins
        self.capturedAt = capturedAt
    }
}

/// Immutable receipt produced by a target build under MCP-19.8 (LEARN-04).
public struct BuildArtifactReceipt: Codable, Sendable, Equatable, Hashable {
    public let receiptID: String
    public let workspaceRoot: String
    public let target: String
    public let scheme: String?
    public let configuration: String
    public let toolchainIdentifier: String
    public let preBuildSourceReceipt: SourceTreeReceipt
    public let postBuildSourceDigest: String
    public let driftDetectedDuringBuild: Bool
    public let buildSucceeded: Bool
    public let artifactPath: String?
    public let artifactDigest: String?
    public let failureReason: String?
    public let builtAt: Date

    public init(
        receiptID: String = UUID().uuidString.lowercased(),
        workspaceRoot: String,
        target: String,
        scheme: String? = nil,
        configuration: String = "Debug",
        toolchainIdentifier: String,
        preBuildSourceReceipt: SourceTreeReceipt,
        postBuildSourceDigest: String? = nil,
        buildSucceeded: Bool,
        artifactPath: String? = nil,
        artifactDigest: String? = nil,
        failureReason: String? = nil,
        builtAt: Date = Date()
    ) {
        self.receiptID = receiptID
        self.workspaceRoot = workspaceRoot
        self.target = target
        self.scheme = scheme
        self.configuration = configuration
        self.toolchainIdentifier = toolchainIdentifier
        self.preBuildSourceReceipt = preBuildSourceReceipt
        let resolvedPostDigest = postBuildSourceDigest ?? preBuildSourceReceipt.sourceDigest
        self.postBuildSourceDigest = resolvedPostDigest
        self.driftDetectedDuringBuild = (resolvedPostDigest != preBuildSourceReceipt.sourceDigest)
        self.buildSucceeded = buildSucceeded && !self.driftDetectedDuringBuild && (artifactDigest?.isEmpty == false)
        self.artifactPath = artifactPath
        self.artifactDigest = artifactDigest
        if self.driftDetectedDuringBuild {
            self.failureReason = failureReason ?? "Source files drifted while build was in progress (\(preBuildSourceReceipt.sourceDigest) != \(resolvedPostDigest))."
        } else {
            self.failureReason = failureReason
        }
        self.builtAt = builtAt
    }
}

/// Binds a fresh runtime/matrix capture to a specific built artifact and records fixture/resource provenance (LEARN-04).
public struct BoundCaptureReceipt: Codable, Sendable, Equatable, Hashable {
    public let captureIdentity: CaptureIdentity
    public let buildReceiptID: String
    public let artifactDigest: String
    public let target: String
    public let runtimeDestination: String
    public let requestedPermutations: [String]
    public let capturedPermutations: [String]
    public let resourceProvenances: [String: EvidenceProvenance]
    public let usedSyntheticSubstitutes: Bool
    public let capturedAt: Date

    public init(
        captureIdentity: CaptureIdentity,
        buildReceiptID: String,
        artifactDigest: String,
        target: String,
        runtimeDestination: String = "in_process_host",
        requestedPermutations: [String],
        capturedPermutations: [String],
        resourceProvenances: [String: EvidenceProvenance] = [:],
        usedSyntheticSubstitutes: Bool = false,
        capturedAt: Date = Date()
    ) {
        self.captureIdentity = captureIdentity
        self.buildReceiptID = buildReceiptID
        self.artifactDigest = artifactDigest
        self.target = target
        self.runtimeDestination = runtimeDestination
        self.requestedPermutations = requestedPermutations.sorted()
        self.capturedPermutations = capturedPermutations.sorted()
        self.resourceProvenances = resourceProvenances
        let hasSyntheticResource = resourceProvenances.values.contains { $0.kind == .synthetic }
        self.usedSyntheticSubstitutes = usedSyntheticSubstitutes || hasSyntheticResource
        self.capturedAt = capturedAt
    }

    public var isCompleteRecapture: Bool {
        !requestedPermutations.isEmpty && Set(requestedPermutations).isSubset(of: Set(capturedPermutations))
    }

    public var isFidelityBaselineEligible: Bool {
        !usedSyntheticSubstitutes && isCompleteRecapture
    }
}

/// Failure codes when validating a source -> build -> capture -> verification chain (LEARN-04).
public enum SourceChainFailureCode: String, Codable, Sendable, Equatable, Hashable {
    case missingBuildReceipt = "missing_build_receipt"
    case missingCaptureReceipt = "missing_capture_receipt"
    case wrongTarget = "wrong_target"
    case workspaceMismatch = "workspace_mismatch"
    case sourceDriftDuringBuild = "source_drift_during_build"
    case sourceChangedAfterBuild = "source_changed_after_build"
    case missingDependencies = "missing_dependencies"
    case buildFailed = "build_failed"
    case staleOrMismatchedArtifact = "stale_or_mismatched_artifact"
    case partialRecapture = "partial_recapture"
    case syntheticSubstituteUsed = "synthetic_substitute_used"
    case incompleteFindingComparison = "incomplete_finding_comparison"
}

/// End-to-end validation result for the source -> build -> capture -> verification chain (LEARN-04).
public struct SourceVerificationChainReceipt: Codable, Sendable, Equatable, Hashable {
    public let expectedWorkspaceRoot: String
    public let expectedTarget: String
    public let buildReceipt: BuildArtifactReceipt?
    public let captureReceipt: BoundCaptureReceipt?
    public let currentSourceDigest: String?
    public let sourceChangesVerified: Bool
    public let fidelityBaselineEligible: Bool
    public let failureCodes: [SourceChainFailureCode]
    public let failureReasons: [String]
    public let eligibility: EvidenceEligibilityDecision

    public init(
        expectedWorkspaceRoot: String,
        expectedTarget: String,
        buildReceipt: BuildArtifactReceipt?,
        captureReceipt: BoundCaptureReceipt?,
        currentSourceDigest: String? = nil,
        sourceChangesVerified: Bool,
        fidelityBaselineEligible: Bool,
        failureCodes: [SourceChainFailureCode],
        failureReasons: [String],
        eligibility: EvidenceEligibilityDecision
    ) {
        self.expectedWorkspaceRoot = expectedWorkspaceRoot
        self.expectedTarget = expectedTarget
        self.buildReceipt = buildReceipt
        self.captureReceipt = captureReceipt
        self.currentSourceDigest = currentSourceDigest
        self.sourceChangesVerified = sourceChangesVerified
        self.fidelityBaselineEligible = fidelityBaselineEligible
        self.failureCodes = failureCodes
        self.failureReasons = failureReasons
        self.eligibility = eligibility
    }
}

/// Computes cryptographic source/artifact receipts and validates the build-to-capture verification chain (LEARN-04).
public enum BuildCaptureChainValidator {

    /// Computes a deterministic SHA-256 digest over source files in `workspaceRoot` (including uncommitted edits).
    public static func computeSourceReceipt(
        workspaceRoot: String,
        target: String,
        relativeFilePaths: [String],
        uncommittedFiles: [String] = [],
        dependencyPins: [PackageDependencyRecord] = [],
        capturedAt: Date = Date()
    ) -> SourceTreeReceipt {
        let rootURL = URL(fileURLWithPath: workspaceRoot).standardizedFileURL
        var fileDigests: [String: String] = [:]
        var combinedHasher = SHA256()

        let sortedPaths = Set(relativeFilePaths + uncommittedFiles).sorted()
        for relPath in sortedPaths {
            let fileURL = rootURL.appendingPathComponent(relPath).standardizedFileURL
            if let data = try? Data(contentsOf: fileURL) {
                let digest = sha256Hex(data)
                fileDigests[relPath] = digest
                combinedHasher.update(data: Data("\(relPath):\(digest)\n".utf8))
            } else {
                fileDigests[relPath] = "missing"
                combinedHasher.update(data: Data("\(relPath):missing\n".utf8))
            }
        }

        for pin in dependencyPins.sorted(by: { $0.identity < $1.identity }) {
            combinedHasher.update(data: Data("dep:\(pin.identity):\(pin.version ?? ""):\(pin.revision ?? "")\n".utf8))
        }

        let sourceDigest = combinedHasher.finalize().map { String(format: "%02x", $0) }.joined()
        return SourceTreeReceipt(
            workspaceRoot: rootURL.path,
            target: target,
            sourceDigest: sourceDigest,
            fileDigests: fileDigests,
            includesUncommittedChanges: true,
            uncommittedFiles: uncommittedFiles,
            dependencyPins: dependencyPins,
            capturedAt: capturedAt
        )
    }

    public static func sha256Hex(_ data: Data) -> String {
        SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }

    /// Validates that a build receipt, capture receipt, current source digest, and finding comparison form an unbroken chain.
    public static func validateChain(
        expectedWorkspaceRoot: String,
        expectedTarget: String,
        buildReceipt: BuildArtifactReceipt?,
        captureReceipt: BoundCaptureReceipt?,
        currentSourceDigest: String? = nil,
        missingDependencies: [String] = [],
        findingComparisonCompleted: Bool = true
    ) -> SourceVerificationChainReceipt {
        var codes: [SourceChainFailureCode] = []
        var reasons: [String] = []

        if !missingDependencies.isEmpty {
            codes.append(.missingDependencies)
            reasons.append("Missing required dependencies: \(missingDependencies.sorted().joined(separator: ", ")).")
        }

        guard let buildReceipt else {
            codes.append(.missingBuildReceipt)
            reasons.append("No build receipt was supplied; source changes were not compiled.")
            let decision = EvidenceEligibilityDecision(
                consumer: .fixVerification,
                status: .notEvaluated,
                isEligible: false,
                canPass: false,
                reasons: reasons
            )
            return SourceVerificationChainReceipt(
                expectedWorkspaceRoot: expectedWorkspaceRoot,
                expectedTarget: expectedTarget,
                buildReceipt: nil,
                captureReceipt: captureReceipt,
                currentSourceDigest: currentSourceDigest,
                sourceChangesVerified: false,
                fidelityBaselineEligible: false,
                failureCodes: codes,
                failureReasons: reasons,
                eligibility: decision
            )
        }

        let normalizedExpectedRoot = URL(fileURLWithPath: expectedWorkspaceRoot).standardizedFileURL.path
        let normalizedBuildRoot = URL(fileURLWithPath: buildReceipt.workspaceRoot).standardizedFileURL.path
        if normalizedExpectedRoot != normalizedBuildRoot {
            codes.append(.workspaceMismatch)
            reasons.append("Build receipt workspace '\(normalizedBuildRoot)' does not match expected workspace '\(normalizedExpectedRoot)'.")
        }

        if buildReceipt.target != expectedTarget {
            codes.append(.wrongTarget)
            reasons.append("Build receipt target '\(buildReceipt.target)' does not match expected target '\(expectedTarget)'.")
        }

        if buildReceipt.driftDetectedDuringBuild {
            codes.append(.sourceDriftDuringBuild)
            reasons.append(buildReceipt.failureReason ?? "Source tree drifted during the build.")
        }

        if !buildReceipt.buildSucceeded || buildReceipt.artifactDigest == nil {
            codes.append(.buildFailed)
            reasons.append(buildReceipt.failureReason ?? "Target build failed or produced no artifact digest.")
        }

        if let currentSourceDigest, currentSourceDigest != buildReceipt.postBuildSourceDigest {
            codes.append(.sourceChangedAfterBuild)
            reasons.append("Workspace source digest '\(currentSourceDigest)' changed after build receipt '\(buildReceipt.postBuildSourceDigest)'.")
        }

        guard let captureReceipt else {
            codes.append(.missingCaptureReceipt)
            reasons.append("No runtime capture receipt bound to the built artifact was supplied.")
            let decision = EvidenceEligibilityDecision(
                consumer: .fixVerification,
                status: .incomplete,
                isEligible: false,
                canPass: false,
                reasons: reasons
            )
            return SourceVerificationChainReceipt(
                expectedWorkspaceRoot: expectedWorkspaceRoot,
                expectedTarget: expectedTarget,
                buildReceipt: buildReceipt,
                captureReceipt: nil,
                currentSourceDigest: currentSourceDigest,
                sourceChangesVerified: false,
                fidelityBaselineEligible: false,
                failureCodes: codes,
                failureReasons: reasons,
                eligibility: decision
            )
        }

        if captureReceipt.target != expectedTarget {
            if !codes.contains(.wrongTarget) { codes.append(.wrongTarget) }
            reasons.append("Capture receipt target '\(captureReceipt.target)' does not match expected target '\(expectedTarget)'.")
        }

        if captureReceipt.buildReceiptID != buildReceipt.receiptID
            || captureReceipt.artifactDigest != (buildReceipt.artifactDigest ?? "")
            || captureReceipt.capturedAt < buildReceipt.builtAt {
            codes.append(.staleOrMismatchedArtifact)
            reasons.append("Capture receipt is stale or bound to a different artifact (\(captureReceipt.buildReceiptID) / \(captureReceipt.artifactDigest)) than build (\(buildReceipt.receiptID) / \(buildReceipt.artifactDigest ?? "nil")).")
        }

        if !captureReceipt.isCompleteRecapture {
            codes.append(.partialRecapture)
            let missingPerms = Set(captureReceipt.requestedPermutations).subtracting(Set(captureReceipt.capturedPermutations)).sorted()
            reasons.append("Partial recapture: missing matrix permutation(s) [\(missingPerms.joined(separator: ", "))].")
        }

        if captureReceipt.usedSyntheticSubstitutes {
            codes.append(.syntheticSubstituteUsed)
            reasons.append("Capture used synthetic fixture/resource substitutes and is ineligible for fidelity baseline or source-change verification.")
        }

        if !findingComparisonCompleted {
            codes.append(.incompleteFindingComparison)
            reasons.append("Per-finding comparison is incomplete or has un-retested/uncertain findings.")
        }

        let verified = codes.isEmpty
        let baselineEligible = verified && captureReceipt.isFidelityBaselineEligible
        let status: EvidenceEligibilityStatus = verified ? .eligible : (codes.contains(.syntheticSubstituteUsed) ? .ineligible : .incomplete)
        let decision = EvidenceEligibilityDecision(
            consumer: .fixVerification,
            status: status,
            isEligible: verified,
            canPass: verified,
            reasons: reasons,
            captureIdentity: captureReceipt.captureIdentity
        )

        return SourceVerificationChainReceipt(
            expectedWorkspaceRoot: expectedWorkspaceRoot,
            expectedTarget: expectedTarget,
            buildReceipt: buildReceipt,
            captureReceipt: captureReceipt,
            currentSourceDigest: currentSourceDigest,
            sourceChangesVerified: verified,
            fidelityBaselineEligible: baselineEligible,
            failureCodes: codes,
            failureReasons: reasons,
            eligibility: decision
        )
    }
}
