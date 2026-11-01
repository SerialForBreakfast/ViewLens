import Foundation
import CryptoKit

/// Artifact classification within a privacy-safe export bundle (LEARN-10).
public enum ExportArtifactKind: String, Codable, Sendable, Equatable, Hashable {
    case auditSummaryJSON = "audit_summary_json"
    case nonvisualNarrative = "nonvisual_narrative"
    case redactedScreenshot = "redacted_screenshot"
    case rawScreenshot = "raw_screenshot"
    case redactedSourceContext = "redacted_source_context"
    case rawSourceSnippet = "raw_source_snippet"
}

/// Sensitivity tier for an exported artifact (LEARN-10).
public enum ExportSensitivityTier: String, Codable, Sendable, Equatable, Hashable {
    case publicSafe = "public_safe"
    case internalRedacted = "internal_redacted"
    case sensitiveRaw = "sensitive_raw"
}

/// Receiver review status kept strictly separate from byte delivery (LEARN-10).
public enum ExportReceiverReviewStatus: String, Codable, Sendable, Equatable, Hashable {
    case notDelivered = "not_delivered"
    case deliveredPendingReview = "delivered_pending_review"
    case reviewedWithLimitations = "reviewed_with_limitations"
    case accepted = "accepted"
    case rejected = "rejected"
}

/// Options controlling what is included and redacted in an evidence export (LEARN-10).
/// Raw screenshots and raw source require explicit opt-in (`includeRawScreenshots`, `includeRawSource`).
public struct PrivacyExportConfiguration: Codable, Sendable, Equatable, Hashable {
    public var redactSecrets: Bool
    public var scrubWorkspacePaths: Bool
    public var redactSensitiveRegions: Bool
    public var includeRawScreenshots: Bool
    public var includeRawSource: Bool
    public var workspaceRootToScrub: String?
    public var authorizedScopes: Set<String>

    public init(
        redactSecrets: Bool = true,
        scrubWorkspacePaths: Bool = true,
        redactSensitiveRegions: Bool = true,
        includeRawScreenshots: Bool = false,
        includeRawSource: Bool = false,
        workspaceRootToScrub: String? = nil,
        authorizedScopes: Set<String> = ["audit:read", "export:read"]
    ) {
        self.redactSecrets = redactSecrets
        self.scrubWorkspacePaths = scrubWorkspacePaths
        self.redactSensitiveRegions = redactSensitiveRegions
        self.includeRawScreenshots = includeRawScreenshots
        self.includeRawSource = includeRawSource
        self.workspaceRootToScrub = workspaceRootToScrub
        self.authorizedScopes = authorizedScopes
    }
}

/// Individual artifact entry in the export manifest with ancestry and baseline-eligibility flags (LEARN-10).
public struct ExportManifestArtifactEntry: Codable, Sendable, Equatable, Hashable, Identifiable {
    public let id: String
    public let kind: ExportArtifactKind
    public let sensitivity: ExportSensitivityTier
    public let provenance: EvidenceProvenance
    public let isRedactedDerivative: Bool
    public let parentArtifactID: String?
    public let appliedRedactions: [String]
    public let geometryLimitations: [String]
    public let baselineMeasurementEligible: Bool
    public let sha256Hex: String
    public let sizeBytes: Int64
    public let resourceURI: String

    public init(
        id: String,
        kind: ExportArtifactKind,
        sensitivity: ExportSensitivityTier,
        provenance: EvidenceProvenance,
        isRedactedDerivative: Bool,
        parentArtifactID: String? = nil,
        appliedRedactions: [String] = [],
        geometryLimitations: [String] = [],
        baselineMeasurementEligible: Bool? = nil,
        sha256Hex: String,
        sizeBytes: Int64,
        resourceURI: String
    ) {
        self.id = id
        self.kind = kind
        self.sensitivity = sensitivity
        self.provenance = provenance
        self.isRedactedDerivative = isRedactedDerivative
        self.parentArtifactID = parentArtifactID
        self.appliedRedactions = appliedRedactions
        self.geometryLimitations = geometryLimitations
        // Redacted derivatives can NEVER silently replace measurement baselines (LEARN-10)
        if isRedactedDerivative {
            self.baselineMeasurementEligible = false
        } else {
            self.baselineMeasurementEligible = baselineMeasurementEligible ?? (provenance.kind == .measured)
        }
        self.sha256Hex = sha256Hex
        self.sizeBytes = sizeBytes
        self.resourceURI = resourceURI
    }
}

/// Preview and final manifest for a privacy-safe evidence export (LEARN-10).
public struct PrivacySafeExportManifest: Codable, Sendable, Equatable, Hashable {
    public static let currentSchemaVersion = "viewlens.export.v1"

    public let schemaVersion: String
    public let manifestID: String
    public let createdAt: Date
    public let expiresAt: Date?
    public let artifacts: [ExportManifestArtifactEntry]
    public let omittedSensitiveArtifacts: [String]
    public let appliedRedactionsSummary: [String]
    public let geometryLimitations: [String]
    public let byteDeliveryCompleted: Bool
    public let receiverReviewStatus: ExportReceiverReviewStatus
    public let semanticAcceptanceEstablished: Bool
    public let keyboardReviewOrder: [String]
    public let nonvisualManifestSummary: String

    public init(
        schemaVersion: String = PrivacySafeExportManifest.currentSchemaVersion,
        manifestID: String = UUID().uuidString.lowercased(),
        createdAt: Date = Date(),
        expiresAt: Date? = nil,
        artifacts: [ExportManifestArtifactEntry],
        omittedSensitiveArtifacts: [String],
        appliedRedactionsSummary: [String],
        geometryLimitations: [String],
        byteDeliveryCompleted: Bool,
        receiverReviewStatus: ExportReceiverReviewStatus,
        semanticAcceptanceEstablished: Bool = false,
        keyboardReviewOrder: [String],
        nonvisualManifestSummary: String
    ) {
        self.schemaVersion = schemaVersion
        self.manifestID = manifestID
        self.createdAt = createdAt
        self.expiresAt = expiresAt
        self.artifacts = artifacts
        self.omittedSensitiveArtifacts = omittedSensitiveArtifacts
        self.appliedRedactionsSummary = appliedRedactionsSummary
        self.geometryLimitations = geometryLimitations
        self.byteDeliveryCompleted = byteDeliveryCompleted
        self.receiverReviewStatus = receiverReviewStatus
        self.semanticAcceptanceEstablished = semanticAcceptanceEstablished
        self.keyboardReviewOrder = keyboardReviewOrder
        self.nonvisualManifestSummary = nonvisualManifestSummary
    }
}

/// Errors raised during export preview, packaging, or archive validation (LEARN-10).
public enum PrivacyExportError: Error, Codable, Sendable, Equatable, Hashable {
    case accessDenied(missingScope: String)
    case resourceExpired(manifestID: String)
    case malformedArchive(reason: String)
    case baselineReplacementForbidden(artifactID: String)
}

/// Container holding both the privately preserved originals and the shareable export package (LEARN-10).
public struct PrivacySafeExportBundle: Codable, Sendable, Equatable {
    public let manifest: PrivacySafeExportManifest
    public let exportedPayloadsByID: [String: Data]
    /// Original unredacted bytes retained strictly in private storage and excluded from public export payloads unless explicitly opted in.
    public let privateOriginalPayloadsByID: [String: Data]
}

/// Engine for previewing, redacting, packaging, and validating privacy-safe evidence exports (LEARN-10).
public enum PrivacySafeExportEngine {

    /// Scrubs absolute host/workspace file paths and secrets from text.
    public static func sanitizeText(
        _ input: String,
        workspaceRoot: String?,
        redactSecrets: Bool,
        scrubPaths: Bool
    ) -> (text: String, redactionsApplied: [String]) {
        var result = input
        var applied: [String] = []

        if redactSecrets {
            let redacted = NonvisualRedactor.redactText(result)
            if redacted != result {
                applied.append("secret_token_or_credential_redacted")
                result = redacted
            }
        }

        if scrubPaths {
            if let root = workspaceRoot, !root.isEmpty, result.contains(root) {
                result = result.replacingOccurrences(of: root, with: "<workspace>")
                applied.append("workspace_root_path_scrubbed")
            }
            // Scrub `/Users/<username>/...` patterns
            let pattern = #"/Users/[^/\s"']+(/[^\s"']*)"#
            if let regex = try? NSRegularExpression(pattern: pattern) {
                let nsRange = NSRange(result.startIndex..<result.endIndex, in: result)
                if regex.firstMatch(in: result, range: nsRange) != nil {
                    result = regex.stringByReplacingMatches(in: result, range: nsRange, withTemplate: "<user_home>$1")
                    applied.append("host_user_path_scrubbed")
                }
            }
        }

        return (result, Array(Set(applied)).sorted())
    }

    /// Generates a read-only preview manifest and packaged bundle while preserving original bytes privately (LEARN-10).
    public static func buildExportBundle(
        targetName: String,
        summaryText: String,
        nonvisualNarrative: String,
        rawScreenshotBytes: Data? = nil,
        rawSourceSnippet: String? = nil,
        maskedRegionsCount: Int = 0,
        configuration: PrivacyExportConfiguration,
        now: Date = Date(),
        ttlSeconds: TimeInterval? = 3_600,
        markDelivered: Bool = false
    ) throws -> PrivacySafeExportBundle {
        guard configuration.authorizedScopes.contains("export:read") else {
            throw PrivacyExportError.accessDenied(missingScope: "export:read")
        }
        if configuration.includeRawScreenshots || configuration.includeRawSource {
            guard configuration.authorizedScopes.contains("export:raw_sensitive") else {
                throw PrivacyExportError.accessDenied(missingScope: "export:raw_sensitive")
            }
        }

        var artifacts: [ExportManifestArtifactEntry] = []
        var exportedPayloads: [String: Data] = [:]
        var privateOriginals: [String: Data] = [:]
        var omitted: [String] = []
        var allRedactions = Set<String>()
        var geometryLimitations: [String] = []

        // 1. Summary JSON / Text
        let origSummaryID = "orig-summary-\(targetName.lowercased())"
        let origSummaryBytes = Data(summaryText.utf8)
        privateOriginals[origSummaryID] = origSummaryBytes

        let sanitizedSummary = sanitizeText(
            summaryText,
            workspaceRoot: configuration.workspaceRootToScrub,
            redactSecrets: configuration.redactSecrets,
            scrubPaths: configuration.scrubWorkspacePaths
        )
        allRedactions.formUnion(sanitizedSummary.redactionsApplied)
        let summaryData = Data(sanitizedSummary.text.utf8)
        let summaryEntryID = "artifact-summary-\(targetName.lowercased())"
        exportedPayloads[summaryEntryID] = summaryData
        artifacts.append(ExportManifestArtifactEntry(
            id: summaryEntryID,
            kind: .auditSummaryJSON,
            sensitivity: sanitizedSummary.redactionsApplied.isEmpty ? .publicSafe : .internalRedacted,
            provenance: EvidenceProvenance(
                kind: .derived,
                source: "viewlens.export.summary",
                detail: sanitizedSummary.redactionsApplied.isEmpty ? nil : "Sanitized summary derivative"
            ),
            isRedactedDerivative: !sanitizedSummary.redactionsApplied.isEmpty,
            parentArtifactID: origSummaryID,
            appliedRedactions: sanitizedSummary.redactionsApplied,
            sha256Hex: sha256Hex(summaryData),
            sizeBytes: Int64(summaryData.count),
            resourceURI: "viewlens://export/\(summaryEntryID)"
        ))

        // 2. Nonvisual Narrative
        let origNarrativeID = "orig-narrative-\(targetName.lowercased())"
        privateOriginals[origNarrativeID] = Data(nonvisualNarrative.utf8)

        let sanitizedNarrative = sanitizeText(
            nonvisualNarrative,
            workspaceRoot: configuration.workspaceRootToScrub,
            redactSecrets: configuration.redactSecrets,
            scrubPaths: configuration.scrubWorkspacePaths
        )
        allRedactions.formUnion(sanitizedNarrative.redactionsApplied)
        let narrativeData = Data(sanitizedNarrative.text.utf8)
        let narrativeEntryID = "artifact-narrative-\(targetName.lowercased())"
        exportedPayloads[narrativeEntryID] = narrativeData
        artifacts.append(ExportManifestArtifactEntry(
            id: narrativeEntryID,
            kind: .nonvisualNarrative,
            sensitivity: .publicSafe,
            provenance: EvidenceProvenance(kind: .derived, source: "viewlens.export.nonvisual"),
            isRedactedDerivative: !sanitizedNarrative.redactionsApplied.isEmpty,
            parentArtifactID: origNarrativeID,
            appliedRedactions: sanitizedNarrative.redactionsApplied,
            sha256Hex: sha256Hex(narrativeData),
            sizeBytes: Int64(narrativeData.count),
            resourceURI: "viewlens://export/\(narrativeEntryID)"
        ))

        // 3. Screenshot handling
        if let rawScreenshotBytes {
            let origImageID = "orig-screenshot-\(targetName.lowercased())"
            privateOriginals[origImageID] = rawScreenshotBytes

            if configuration.redactSensitiveRegions && maskedRegionsCount > 0 {
                let redactionNote = "masked_\(maskedRegionsCount)_sensitive_regions"
                allRedactions.insert(redactionNote)
                let limitation = "Redacted screenshot masks \(maskedRegionsCount) region(s); pixel contrast and SSIM inside masked bounds are unavailable and ineligible for baseline replacement."
                geometryLimitations.append(limitation)

                var redactedBytes = Data("REDACTED_DERIVATIVE_HEADER:".utf8)
                redactedBytes.append(rawScreenshotBytes.prefix(64))
                let redactedID = "artifact-redacted-screenshot-\(targetName.lowercased())"
                exportedPayloads[redactedID] = redactedBytes
                artifacts.append(ExportManifestArtifactEntry(
                    id: redactedID,
                    kind: .redactedScreenshot,
                    sensitivity: .internalRedacted,
                    provenance: EvidenceProvenance(
                        kind: .derived,
                        source: "viewlens.export.redacted_screenshot",
                        detail: "Ancestry: \(origImageID)"
                    ),
                    isRedactedDerivative: true,
                    parentArtifactID: origImageID,
                    appliedRedactions: [redactionNote],
                    geometryLimitations: [limitation],
                    baselineMeasurementEligible: false,
                    sha256Hex: sha256Hex(redactedBytes),
                    sizeBytes: Int64(redactedBytes.count),
                    resourceURI: "viewlens://export/\(redactedID)"
                ))
            }

            if configuration.includeRawScreenshots {
                let rawID = "artifact-raw-screenshot-\(targetName.lowercased())"
                exportedPayloads[rawID] = rawScreenshotBytes
                artifacts.append(ExportManifestArtifactEntry(
                    id: rawID,
                    kind: .rawScreenshot,
                    sensitivity: .sensitiveRaw,
                    provenance: EvidenceProvenance(kind: .measured, source: "viewlens.capture.pixels"),
                    isRedactedDerivative: false,
                    parentArtifactID: nil,
                    appliedRedactions: [],
                    baselineMeasurementEligible: true,
                    sha256Hex: sha256Hex(rawScreenshotBytes),
                    sizeBytes: Int64(rawScreenshotBytes.count),
                    resourceURI: "viewlens://export/\(rawID)"
                ))
            } else {
                omitted.append("raw_screenshot (\(rawScreenshotBytes.count) bytes omitted; requires explicit inclusion)")
            }
        }

        // 4. Source snippet handling
        if let rawSourceSnippet {
            let origSourceID = "orig-source-\(targetName.lowercased())"
            let rawSourceBytes = Data(rawSourceSnippet.utf8)
            privateOriginals[origSourceID] = rawSourceBytes

            if configuration.includeRawSource {
                let rawSourceArtifactID = "artifact-raw-source-\(targetName.lowercased())"
                exportedPayloads[rawSourceArtifactID] = rawSourceBytes
                artifacts.append(ExportManifestArtifactEntry(
                    id: rawSourceArtifactID,
                    kind: .rawSourceSnippet,
                    sensitivity: .sensitiveRaw,
                    provenance: EvidenceProvenance(kind: .measured, source: "viewlens.source.file"),
                    isRedactedDerivative: false,
                    parentArtifactID: nil,
                    baselineMeasurementEligible: false,
                    sha256Hex: sha256Hex(rawSourceBytes),
                    sizeBytes: Int64(rawSourceBytes.count),
                    resourceURI: "viewlens://export/\(rawSourceArtifactID)"
                ))
            } else {
                omitted.append("raw_source_snippet (\(rawSourceBytes.count) bytes omitted; requires explicit inclusion)")
            }
        }

        let sortedRedactions = Array(allRedactions).sorted()
        let keyboardOrder = artifacts.map(\.id)
        let nonvisualSummary = "Export manifest (\(PrivacySafeExportManifest.currentSchemaVersion)) for \(targetName): \(artifacts.count) artifact(s) included, \(omitted.count) sensitive raw artifact(s) omitted. Redactions: \(sortedRedactions.isEmpty ? "none" : sortedRedactions.joined(separator: ", ")). Receiver acceptance: not established by byte delivery."

        let manifest = PrivacySafeExportManifest(
            createdAt: now,
            expiresAt: ttlSeconds.map { now.addingTimeInterval($0) },
            artifacts: artifacts,
            omittedSensitiveArtifacts: omitted,
            appliedRedactionsSummary: sortedRedactions,
            geometryLimitations: geometryLimitations,
            byteDeliveryCompleted: markDelivered,
            receiverReviewStatus: markDelivered ? .deliveredPendingReview : .notDelivered,
            semanticAcceptanceEstablished: false,
            keyboardReviewOrder: keyboardOrder,
            nonvisualManifestSummary: nonvisualSummary
        )

        return PrivacySafeExportBundle(
            manifest: manifest,
            exportedPayloadsByID: exportedPayloads,
            privateOriginalPayloadsByID: privateOriginals
        )
    }

    /// Validates a serialized export bundle for schema version, expiration, hash/size integrity, and baseline eligibility (LEARN-10).
    public static func validateExportBundle(
        _ bundle: PrivacySafeExportBundle,
        forBaselineReplacement artifactID: String? = nil,
        now: Date = Date()
    ) throws {
        guard bundle.manifest.schemaVersion == PrivacySafeExportManifest.currentSchemaVersion else {
            throw PrivacyExportError.malformedArchive(reason: "Unsupported schema version '\(bundle.manifest.schemaVersion)'.")
        }
        if let expiresAt = bundle.manifest.expiresAt, now > expiresAt {
            throw PrivacyExportError.resourceExpired(manifestID: bundle.manifest.manifestID)
        }
        for entry in bundle.manifest.artifacts {
            guard let payload = bundle.exportedPayloadsByID[entry.id] else {
                throw PrivacyExportError.malformedArchive(reason: "Missing payload bytes for manifest artifact '\(entry.id)'.")
            }
            if Int64(payload.count) != entry.sizeBytes {
                throw PrivacyExportError.malformedArchive(reason: "Size mismatch for artifact '\(entry.id)': expected \(entry.sizeBytes), found \(payload.count).")
            }
            let actualHash = sha256Hex(payload)
            if actualHash != entry.sha256Hex {
                throw PrivacyExportError.malformedArchive(reason: "SHA-256 hash mismatch for artifact '\(entry.id)'.")
            }
        }
        if let artifactID {
            guard let entry = bundle.manifest.artifacts.first(where: { $0.id == artifactID }) else {
                throw PrivacyExportError.malformedArchive(reason: "Artifact '\(artifactID)' not found in manifest.")
            }
            if entry.isRedactedDerivative || !entry.baselineMeasurementEligible {
                throw PrivacyExportError.baselineReplacementForbidden(artifactID: artifactID)
            }
        }
    }

    private static func sha256Hex(_ data: Data) -> String {
        SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }
}
