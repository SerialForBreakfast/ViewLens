import Foundation

/// Archive policy for retained evidence and failed attempts (LEARN-09).
/// Never performs automatic deletion, offload, or silent quota increases.
public enum EvidenceRetentionPolicyMode: String, Codable, Sendable, Equatable, Hashable {
    case retainAll = "retain_all"
    case archiveExplicitOnly = "archive_explicit_only"
}

/// Classification of storage budget failures (LEARN-09).
public enum StorageBudgetFailureCode: String, Codable, Sendable, Equatable, Hashable {
    case symlinkOrPathEscape = "symlink_or_path_escape"
    case perRunQuotaExceeded = "per_run_quota_exceeded"
    case workspaceQuotaExceeded = "workspace_quota_exceeded"
    case insufficientFreeCapacity = "insufficient_free_capacity"
    case cleanupReserveExhausted = "cleanup_reserve_exhausted"
    case midRunExhaustion = "mid_run_exhaustion"
    case reservationNotFound = "reservation_not_found"
}

/// Non-retryable storage failure with actionable guided repairs (LEARN-09).
public struct StorageBudgetError: Error, Codable, Sendable, Equatable, Hashable {
    public let code: StorageBudgetFailureCode
    public let message: String
    public let isRetryable: Bool
    public let repairs: [GuidedRepairAction]

    public init(
        code: StorageBudgetFailureCode,
        message: String,
        isRetryable: Bool = false,
        repairs: [GuidedRepairAction]
    ) {
        self.code = code
        self.message = message
        self.isRetryable = isRetryable
        self.repairs = repairs
    }
}

/// Accounting snapshot of storage quotas, retained/recovery bytes, and active reservations (LEARN-09).
public struct StorageAccountingSnapshot: Codable, Sendable, Equatable, Hashable {
    public let workspaceQuotaBytes: Int64
    public let perRunQuotaBytes: Int64
    public let cleanupReserveBytes: Int64
    public let freeDiskCapacityBytes: Int64
    public let retainedBytes: Int64
    public let recoveryBytes: Int64
    public let activeReservedBytes: Int64
    public let deduplicatedPaths: [String]
    public let retentionPolicy: EvidenceRetentionPolicyMode
    public let automaticDeletionPerformed: Bool
    public let automaticOffloadPerformed: Bool
    public let quotaSilentlyIncreased: Bool

    public var totalCommittedAndReservedBytes: Int64 {
        retainedBytes + recoveryBytes + activeReservedBytes + cleanupReserveBytes
    }

    public var availableWorkspaceBudgetBytes: Int64 {
        max(0, workspaceQuotaBytes - totalCommittedAndReservedBytes)
    }

    public var availableFreeCapacityAfterReserveBytes: Int64 {
        max(0, freeDiskCapacityBytes - activeReservedBytes - cleanupReserveBytes)
    }
}

/// Receipt for an admitted storage reservation covering build, capture, or export (LEARN-09).
public struct StorageReservationReceipt: Codable, Sendable, Equatable, Hashable {
    public enum Phase: String, Codable, Sendable, Equatable, Hashable {
        case active
        case finalizing
        case interruptedRecoveryPending = "interrupted_recovery_pending"
        case finalized
        case failedPreserved = "failed_preserved"
    }

    public let reservationID: String
    public let operationKind: String
    public let requestedBytes: Int64
    public var consumedBytes: Int64
    public let cleanupReserveBytes: Int64
    public var phase: Phase
    public let createdAt: Date
    public var updatedAt: Date
    public var preservedAttemptPaths: [String]
}

/// Actor coordinating bounded per-run/workspace storage quotas, symlink/path-escape validation,
/// concurrent reservations, interrupted finalization, and explicit recovery (LEARN-09).
public actor StorageBudgetCoordinator {
    private let allowedRootURL: URL
    private let workspaceQuotaBytes: Int64
    private let perRunQuotaBytes: Int64
    private let cleanupReserveBytes: Int64
    private let retentionPolicy: EvidenceRetentionPolicyMode
    private var freeDiskCapacityOverride: Int64?

    private var retainedPaths: [String: Int64] = [:]
    private var recoveryPaths: [String: Int64] = [:]
    private var reservations: [String: StorageReservationReceipt] = [:]
    private var archivedPaths: Set<String> = []

    public init(
        allowedRootURL: URL,
        workspaceQuotaBytes: Int64 = 500 * 1_024 * 1_024,
        perRunQuotaBytes: Int64 = 100 * 1_024 * 1_024,
        cleanupReserveBytes: Int64 = 16 * 1_024 * 1_024,
        retentionPolicy: EvidenceRetentionPolicyMode = .retainAll,
        freeDiskCapacityOverride: Int64? = nil
    ) {
        self.allowedRootURL = allowedRootURL.standardizedFileURL.resolvingSymlinksInPath()
        self.workspaceQuotaBytes = max(1_024, workspaceQuotaBytes)
        self.perRunQuotaBytes = max(1_024, perRunQuotaBytes)
        self.cleanupReserveBytes = max(512, cleanupReserveBytes)
        self.retentionPolicy = retentionPolicy
        self.freeDiskCapacityOverride = freeDiskCapacityOverride
    }

    public func setFreeDiskCapacityOverride(_ bytes: Int64?) {
        self.freeDiskCapacityOverride = bytes
    }

    /// Validates that a candidate path does not escape `allowedRootURL` via `..` or symlinks (LEARN-09).
    public nonisolated func validatePathWithinRoot(_ candidateURL: URL) throws -> String {
        let fm = FileManager.default
        let standardizedCandidate = candidateURL.standardizedFileURL

        // Check if any existing component is a symlink pointing outside allowedRootURL
        var current = standardizedCandidate
        while current.path != "/" && current.path.count >= allowedRootURL.path.count {
            if let values = try? current.resourceValues(forKeys: [.isSymbolicLinkKey]),
               values.isSymbolicLink == true {
                let resolved = current.resolvingSymlinksInPath().standardizedFileURL
                if !Self.isSubpath(resolved.path, of: allowedRootURL.path) {
                    throw Self.makePathEscapeError(path: candidateURL.path)
                }
            }
            if fm.fileExists(atPath: current.path) {
                break
            }
            current.deleteLastPathComponent()
        }

        let resolvedCandidate = standardizedCandidate.resolvingSymlinksInPath().standardizedFileURL
        guard Self.isSubpath(resolvedCandidate.path, of: allowedRootURL.path) else {
            throw Self.makePathEscapeError(path: candidateURL.path)
        }
        return resolvedCandidate.path
    }

    private nonisolated static func isSubpath(_ child: String, of root: String) -> Bool {
        if child == root { return true }
        let prefix = root.hasSuffix("/") ? root : root + "/"
        return child.hasPrefix(prefix)
    }

    private nonisolated static func makePathEscapeError(path: String) -> StorageBudgetError {
        StorageBudgetError(
            code: .symlinkOrPathEscape,
            message: "Path '\(path)' escapes the authorized workspace/storage boundary or traverses an external symlink.",
            isRetryable: false,
            repairs: [
                GuidedRepairAction(
                    cause: .invalidWorkspace,
                    title: "Use Workspace-Local Storage Path",
                    instructions: "Select an artifact or export destination inside the authorized workspace storage directory without external symlinks.",
                    suggestedCommand: "viewlens doctor"
                )
            ]
        )
    }

    /// Registers retained or recovery paths, deduplicating overlapping/nested paths so bytes are never double-counted.
    public func recordDiskPaths(
        retained: [(url: URL, bytes: Int64)] = [],
        recovery: [(url: URL, bytes: Int64)] = []
    ) throws {
        for item in retained {
            let safePath = try validatePathWithinRoot(item.url)
            retainedPaths[safePath] = max(0, item.bytes)
        }
        for item in recovery {
            let safePath = try validatePathWithinRoot(item.url)
            recoveryPaths[safePath] = max(0, item.bytes)
        }
    }

    /// Computes a deduplicated accounting snapshot without double-counting nested or repeated paths.
    public func accountingSnapshot() -> StorageAccountingSnapshot {
        let dedupedRetained = Self.deduplicatePathSizes(retainedPaths)
        // Exclude any recovery path already covered by a retained parent directory
        var filteredRecovery: [String: Int64] = [:]
        for (recPath, size) in recoveryPaths {
            let coveredByRetained = dedupedRetained.keys.contains { Self.isSubpath(recPath, of: $0) }
            if !coveredByRetained {
                filteredRecovery[recPath] = size
            }
        }
        let dedupedRecovery = Self.deduplicatePathSizes(filteredRecovery)

        let retainedSum = dedupedRetained.values.reduce(0, +)
        let recoverySum = dedupedRecovery.values.reduce(0, +)
        let activeSum = reservations.values
            .filter { $0.phase == .active || $0.phase == .finalizing }
            .map { max($0.requestedBytes, $0.consumedBytes) }
            .reduce(0, +)

        let allPaths = Array(Set(dedupedRetained.keys).union(dedupedRecovery.keys)).sorted()
        let freeDisk = resolvedFreeDiskBytes()

        return StorageAccountingSnapshot(
            workspaceQuotaBytes: workspaceQuotaBytes,
            perRunQuotaBytes: perRunQuotaBytes,
            cleanupReserveBytes: cleanupReserveBytes,
            freeDiskCapacityBytes: freeDisk,
            retainedBytes: retainedSum,
            recoveryBytes: recoverySum,
            activeReservedBytes: activeSum,
            deduplicatedPaths: allPaths,
            retentionPolicy: retentionPolicy,
            automaticDeletionPerformed: false,
            automaticOffloadPerformed: false,
            quotaSilentlyIncreased: false
        )
    }

    private static func deduplicatePathSizes(_ pathSizes: [String: Int64]) -> [String: Int64] {
        let sortedPaths = pathSizes.keys.sorted { $0.count < $1.count }
        var accepted: [String: Int64] = [:]
        for path in sortedPaths {
            let hasAncestor = accepted.keys.contains { ancestor in
                isSubpath(path, of: ancestor)
            }
            if !hasAncestor, let bytes = pathSizes[path] {
                accepted[path] = bytes
            }
        }
        return accepted
    }

    /// Pre-dispatch check and reservation before starting a build, capture, or export (LEARN-09).
    public func reserve(
        operationKind: String,
        estimatedBytes: Int64,
        targetPath: URL? = nil
    ) throws -> StorageReservationReceipt {
        if let targetPath {
            _ = try validatePathWithinRoot(targetPath)
        }
        let requested = max(0, estimatedBytes)
        if requested > perRunQuotaBytes {
            throw StorageBudgetError(
                code: .perRunQuotaExceeded,
                message: "Operation '\(operationKind)' requires \(requested) bytes, exceeding per-run quota (\(perRunQuotaBytes) bytes).",
                isRetryable: false,
                repairs: [
                    GuidedRepairAction(
                        cause: .insufficientStorage,
                        title: "Reduce Matrix Scope or Export Payload Size",
                        instructions: "Narrow the requested device/Dynamic Type permutation matrix or exclude raw uncompressed artifacts.",
                        suggestedCommand: "viewlens audit --devices iPhone16Pro"
                    )
                ]
            )
        }

        let snap = accountingSnapshot()
        if snap.totalCommittedAndReservedBytes + requested > workspaceQuotaBytes {
            throw StorageBudgetError(
                code: .workspaceQuotaExceeded,
                message: "Reserving \(requested) bytes for '\(operationKind)' would exceed workspace quota (\(workspaceQuotaBytes) bytes; committed+reserved+cleanup=\(snap.totalCommittedAndReservedBytes) bytes).",
                isRetryable: false,
                repairs: [
                    GuidedRepairAction(
                        cause: .insufficientStorage,
                        title: "Prune or Archive Retained Evidence Explicitly",
                        instructions: "Review retained artifacts in History or run explicit archive/cleanup before starting a new large review.",
                        suggestedCommand: "viewlens cache --clear"
                    )
                ]
            )
        }

        if snap.activeReservedBytes + cleanupReserveBytes + requested > snap.freeDiskCapacityBytes {
            throw StorageBudgetError(
                code: .insufficientFreeCapacity,
                message: "Insufficient free disk capacity (\(snap.freeDiskCapacityBytes) bytes) to reserve \(requested) bytes while preserving \(cleanupReserveBytes) bytes for cleanup/finalization.",
                isRetryable: false,
                repairs: [
                    GuidedRepairAction(
                        cause: .insufficientStorage,
                        title: "Free Disk Space Before Dispatch",
                        instructions: "Free disk space on the host volume so both the operation and the cleanup reserve fit safely.",
                        suggestedCommand: "df -h ."
                    )
                ]
            )
        }

        let now = Date()
        let receipt = StorageReservationReceipt(
            reservationID: UUID().uuidString.lowercased(),
            operationKind: operationKind,
            requestedBytes: requested,
            consumedBytes: 0,
            cleanupReserveBytes: cleanupReserveBytes,
            phase: .active,
            createdAt: now,
            updatedAt: now,
            preservedAttemptPaths: []
        )
        reservations[receipt.reservationID] = receipt
        return receipt
    }

    /// Records mid-run storage consumption, stopping safely if per-run, workspace, or cleanup-reserve limits are breached (LEARN-09).
    public func recordConsumption(
        reservationID: String,
        additionalBytes: Int64,
        attemptArtifactURL: URL? = nil
    ) throws -> StorageReservationReceipt {
        guard var receipt = reservations[reservationID] else {
            throw StorageBudgetError(
                code: .reservationNotFound,
                message: "Storage reservation '\(reservationID)' was not found.",
                isRetryable: false,
                repairs: []
            )
        }

        var safeAttemptPath: String?
        if let attemptArtifactURL {
            safeAttemptPath = try validatePathWithinRoot(attemptArtifactURL)
        }

        let newConsumed = receipt.consumedBytes + max(0, additionalBytes)
        if let safeAttemptPath, !receipt.preservedAttemptPaths.contains(safeAttemptPath) {
            receipt.preservedAttemptPaths.append(safeAttemptPath)
        }

        // Check per-run quota
        if newConsumed > perRunQuotaBytes {
            receipt.phase = .failedPreserved
            receipt.updatedAt = Date()
            reservations[reservationID] = receipt
            // Preserve failed attempt bytes in recovery accounting without deleting anything
            if let safeAttemptPath {
                recoveryPaths[safeAttemptPath] = newConsumed
            }
            throw StorageBudgetError(
                code: .midRunExhaustion,
                message: "Mid-run storage consumption (\(newConsumed) bytes) exceeded per-run quota (\(perRunQuotaBytes) bytes). Prior and partial results are preserved.",
                isRetryable: false,
                repairs: [
                    GuidedRepairAction(
                        cause: .insufficientStorage,
                        title: "Inspect Preserved Partial Evidence or Narrow Run",
                        instructions: "Prior results remain intact. Narrow the matrix or archive old runs before retrying.",
                        suggestedCommand: "viewlens doctor"
                    )
                ]
            )
        }

        let otherActiveBytes = reservations.values
            .filter { $0.reservationID != reservationID && ($0.phase == .active || $0.phase == .finalizing) }
            .map { max($0.requestedBytes, $0.consumedBytes) }
            .reduce(0, +)
        let snap = accountingSnapshot()
        let projectedTotal = snap.retainedBytes + snap.recoveryBytes + otherActiveBytes + max(receipt.requestedBytes, newConsumed) + cleanupReserveBytes

        if projectedTotal > workspaceQuotaBytes || (otherActiveBytes + newConsumed + cleanupReserveBytes > snap.freeDiskCapacityBytes) {
            receipt.phase = .failedPreserved
            receipt.updatedAt = Date()
            reservations[reservationID] = receipt
            if let safeAttemptPath {
                recoveryPaths[safeAttemptPath] = newConsumed
            }
            throw StorageBudgetError(
                code: .midRunExhaustion,
                message: "Mid-run storage consumption (\(newConsumed) bytes) exhausted available workspace or disk budget while preserving cleanup reserve. Prior results are preserved.",
                isRetryable: false,
                repairs: [
                    GuidedRepairAction(
                        cause: .insufficientStorage,
                        title: "Preserve Cleanup Reserve and Free Capacity",
                        instructions: "Execution stopped safely before exhausting cleanup reserve. Archive or prune older runs explicitly.",
                        suggestedCommand: "viewlens cache --clear"
                    )
                ]
            )
        }

        receipt.consumedBytes = newConsumed
        receipt.updatedAt = Date()
        reservations[reservationID] = receipt
        return receipt
    }

    /// Simulates or records an interrupted finalization, moving consumed bytes into recovery accounting while preserving originals (LEARN-09).
    public func markFinalizationInterrupted(
        reservationID: String,
        recoveryArtifactURL: URL
    ) throws -> StorageReservationReceipt {
        guard var receipt = reservations[reservationID] else {
            throw StorageBudgetError(
                code: .reservationNotFound,
                message: "Storage reservation '\(reservationID)' was not found.",
                isRetryable: false,
                repairs: []
            )
        }
        let safePath = try validatePathWithinRoot(recoveryArtifactURL)
        receipt.phase = .interruptedRecoveryPending
        receipt.updatedAt = Date()
        if !receipt.preservedAttemptPaths.contains(safePath) {
            receipt.preservedAttemptPaths.append(safePath)
        }
        reservations[reservationID] = receipt
        recoveryPaths[safePath] = max(receipt.consumedBytes, receipt.requestedBytes)
        return receipt
    }

    /// Completes finalization or recovery, committing retained bytes without double-counting recovery paths (LEARN-09).
    public func completeFinalization(
        reservationID: String,
        committedURL: URL,
        finalBytes: Int64
    ) throws -> StorageReservationReceipt {
        guard var receipt = reservations[reservationID] else {
            throw StorageBudgetError(
                code: .reservationNotFound,
                message: "Storage reservation '\(reservationID)' was not found.",
                isRetryable: false,
                repairs: []
            )
        }
        let safePath = try validatePathWithinRoot(committedURL)
        for path in receipt.preservedAttemptPaths {
            recoveryPaths.removeValue(forKey: path)
        }
        recoveryPaths.removeValue(forKey: safePath)
        retainedPaths[safePath] = max(0, finalBytes)
        receipt.consumedBytes = max(0, finalBytes)
        receipt.phase = .finalized
        receipt.updatedAt = Date()
        reservations[reservationID] = receipt
        return receipt
    }

    private func resolvedFreeDiskBytes() -> Int64 {
        if let override = freeDiskCapacityOverride {
            return override
        }
        if let values = try? allowedRootURL.resourceValues(forKeys: [.volumeAvailableCapacityForImportantUsageKey]),
           let available = values.volumeAvailableCapacityForImportantUsage {
            return Int64(available)
        }
        return 10 * 1_024 * 1_024 * 1_024
    }
}
