import Foundation

/// Identifies a specific runtime capture or audit snapshot so consumers can verify provenance and freshness.
public struct CaptureIdentity: Codable, Sendable, Equatable, Hashable {
    public let captureID: String
    public let target: String
    public let capturedAt: Date?
    public let artifactDigest: String?
    public let environmentKey: String?

    public init(
        captureID: String = UUID().uuidString,
        target: String,
        capturedAt: Date? = Date(),
        artifactDigest: String? = nil,
        environmentKey: String? = nil
    ) {
        self.captureID = captureID
        self.target = target
        self.capturedAt = capturedAt
        self.artifactDigest = artifactDigest
        self.environmentKey = environmentKey
    }
}

/// Describes whether an evidence capture is fresh and aligned with the expected capture identity.
public enum EvidenceFreshness: Codable, Sendable, Equatable, Hashable {
    case fresh
    case stale(reason: String)
    case mismatchedCapture(expectedID: String, actualID: String)
    case unknown(reason: String)

    public var isFresh: Bool {
        if case .fresh = self {
            return true
        }
        return false
    }

    public var summary: String {
        switch self {
        case .fresh:
            return "fresh"
        case .stale(let reason):
            return "stale (\(reason))"
        case .mismatchedCapture(let expectedID, let actualID):
            return "mismatched capture (expected \(expectedID), got \(actualID))"
        case .unknown(let reason):
            return "unknown freshness (\(reason))"
        }
    }
}

/// Separate focus channels so predicted focus, native keyboard focus, accessibility focus, and human VoiceOver observations are never conflated.
public enum FocusObservationChannel: String, Codable, Sendable, Equatable, Hashable, CaseIterable {
    case predictedInputFocus = "predicted_input_focus"
    case nativeKeyboardFocus = "native_keyboard_focus"
    case accessibilityFocus = "accessibility_focus"
    case humanVoiceOverObservation = "human_voiceover_observation"
}

/// A single focus observation bound to a specific focus channel and provenance.
public struct FocusObservation: Codable, Sendable, Equatable, Hashable {
    public let elementID: String?
    public let label: String?
    public let channel: FocusObservationChannel
    public let provenance: EvidenceProvenance

    public init(
        elementID: String?,
        label: String? = nil,
        channel: FocusObservationChannel,
        provenance: EvidenceProvenance
    ) {
        self.elementID = elementID
        self.label = label
        self.channel = channel
        self.provenance = provenance
    }
}

/// Explicitly separated focus channels preventing predicted or keyboard focus from masquerading as accessibility focus or human VoiceOver confirmation.
public struct SeparatedFocusState: Codable, Sendable, Equatable, Hashable {
    public let predictedInputFocus: FocusObservation?
    public let nativeKeyboardFocus: FocusObservation?
    public let accessibilityFocus: FocusObservation?
    public let humanVoiceOverObservation: FocusObservation?

    public init(
        predictedInputFocus: FocusObservation? = nil,
        nativeKeyboardFocus: FocusObservation? = nil,
        accessibilityFocus: FocusObservation? = nil,
        humanVoiceOverObservation: FocusObservation? = nil
    ) {
        self.predictedInputFocus = predictedInputFocus
        self.nativeKeyboardFocus = nativeKeyboardFocus
        self.accessibilityFocus = accessibilityFocus
        self.humanVoiceOverObservation = humanVoiceOverObservation
    }

    /// Returns the observation for a specific focus channel without falling back across channels.
    public func observation(for channel: FocusObservationChannel) -> FocusObservation? {
        switch channel {
        case .predictedInputFocus:
            return predictedInputFocus
        case .nativeKeyboardFocus:
            return nativeKeyboardFocus
        case .accessibilityFocus:
            return accessibilityFocus
        case .humanVoiceOverObservation:
            return humanVoiceOverObservation
        }
    }

    /// Whether measured or human-confirmed accessibility/VoiceOver focus is available.
    public var hasVerifiedAssistiveFocus: Bool {
        if let ax = accessibilityFocus,
           ax.provenance.kind == .measured || ax.provenance.kind == .humanConfirmed {
            return true
        }
        if let vo = humanVoiceOverObservation,
           vo.provenance.kind == .humanConfirmed {
            return true
        }
        return false
    }
}

/// Consumer domains governed by the shared evidence eligibility policy.
public enum EvidenceConsumerDomain: String, Codable, Sendable, Equatable, Hashable, CaseIterable {
    case nonvisualDescription = "nonvisual_description"
    case visualSemanticCorrelation = "visual_semantic_correlation"
    case baselinePromotion = "baseline_promotion"
    case fixVerification = "fix_verification"
    case exportReport = "export_report"
    case qualityGate = "quality_gate"
}

/// Standardized eligibility status across all evidence consumers.
public enum EvidenceEligibilityStatus: String, Codable, Sendable, Equatable, Hashable {
    case eligible
    case notEvaluated = "not_evaluated"
    case incomplete
    case ineligible
}

/// Shared eligibility decision explaining whether a consumer may treat the supplied evidence as passing/complete.
public struct EvidenceEligibilityDecision: Codable, Sendable, Equatable, Hashable {
    public let consumer: EvidenceConsumerDomain
    public let status: EvidenceEligibilityStatus
    public let isEligible: Bool
    public let canPass: Bool
    public let reasons: [String]
    public let migrationLimitations: [String]
    public let captureIdentity: CaptureIdentity?
    public let freshness: EvidenceFreshness

    public init(
        consumer: EvidenceConsumerDomain,
        status: EvidenceEligibilityStatus,
        isEligible: Bool,
        canPass: Bool,
        reasons: [String] = [],
        migrationLimitations: [String] = [],
        captureIdentity: CaptureIdentity? = nil,
        freshness: EvidenceFreshness = .fresh
    ) {
        self.consumer = consumer
        self.status = status
        self.isEligible = isEligible
        self.canPass = canPass
        self.reasons = reasons
        self.migrationLimitations = migrationLimitations
        self.captureIdentity = captureIdentity
        self.freshness = freshness
    }
}

/// Shared policy enforcing provenance, capture identity, and freshness rules across all ViewLens consumers.
public enum EvidenceEligibilityPolicy {
    /// Evaluates whether a set of required evidence provenances is eligible for a given consumer domain.
    public static func evaluate(
        consumer: EvidenceConsumerDomain,
        requiredEvidence: [String: EvidenceProvenance],
        captureIdentity: CaptureIdentity? = nil,
        expectedCaptureIdentity: CaptureIdentity? = nil,
        maxAgeSeconds: TimeInterval? = nil,
        now: Date = Date(),
        migrationLimitations: [String] = []
    ) -> EvidenceEligibilityDecision {
        var reasons: [String] = []
        let freshness = evaluateFreshness(
            captureIdentity: captureIdentity,
            expectedCaptureIdentity: expectedCaptureIdentity,
            maxAgeSeconds: maxAgeSeconds,
            now: now
        )

        if !migrationLimitations.isEmpty {
            reasons.append(contentsOf: migrationLimitations)
        }

        if requiredEvidence.isEmpty {
            reasons.append("No required evidence was supplied for \(consumer.rawValue).")
            return EvidenceEligibilityDecision(
                consumer: consumer,
                status: .notEvaluated,
                isEligible: false,
                canPass: false,
                reasons: reasons,
                migrationLimitations: migrationLimitations,
                captureIdentity: captureIdentity,
                freshness: freshness
            )
        }

        var hasUnavailable = false
        var hasSynthetic = false
        var hasInferred = false

        for (field, provenance) in requiredEvidence.sorted(by: { $0.key < $1.key }) {
            switch provenance.kind {
            case .unavailable:
                hasUnavailable = true
                reasons.append("Required evidence '\(field)' is unavailable (\(provenance.source)).")
            case .synthetic:
                hasSynthetic = true
                reasons.append("Required evidence '\(field)' is synthetic (\(provenance.source)) and cannot satisfy measured or derived requirements.")
            case .inferred:
                hasInferred = true
                if consumer != .nonvisualDescription && consumer != .exportReport {
                    reasons.append("Required evidence '\(field)' is inferred (\(provenance.source)) and cannot establish conformance for \(consumer.rawValue).")
                }
            case .measured, .derived, .humanConfirmed:
                break
            }
        }

        switch freshness {
        case .fresh:
            break
        case .stale(let reason):
            reasons.append("Evidence is stale: \(reason)")
            if consumer != .nonvisualDescription && consumer != .exportReport {
                return EvidenceEligibilityDecision(
                    consumer: consumer,
                    status: .incomplete,
                    isEligible: false,
                    canPass: false,
                    reasons: reasons,
                    migrationLimitations: migrationLimitations,
                    captureIdentity: captureIdentity,
                    freshness: freshness
                )
            }
        case .mismatchedCapture(let expectedID, let actualID):
            reasons.append("Capture identity mismatch: expected \(expectedID) but received \(actualID).")
            return EvidenceEligibilityDecision(
                consumer: consumer,
                status: .incomplete,
                isEligible: false,
                canPass: false,
                reasons: reasons,
                migrationLimitations: migrationLimitations,
                captureIdentity: captureIdentity,
                freshness: freshness
            )
        case .unknown(let reason):
            if consumer == .visualSemanticCorrelation || consumer == .baselinePromotion || consumer == .fixVerification || consumer == .qualityGate {
                reasons.append("Capture freshness is unknown: \(reason)")
                return EvidenceEligibilityDecision(
                    consumer: consumer,
                    status: .incomplete,
                    isEligible: false,
                    canPass: false,
                    reasons: reasons,
                    migrationLimitations: migrationLimitations,
                    captureIdentity: captureIdentity,
                    freshness: freshness
                )
            }
        }

        if hasSynthetic {
            let status: EvidenceEligibilityStatus = (consumer == .nonvisualDescription || consumer == .exportReport) ? .incomplete : .ineligible
            return EvidenceEligibilityDecision(
                consumer: consumer,
                status: status,
                isEligible: false,
                canPass: false,
                reasons: reasons,
                migrationLimitations: migrationLimitations,
                captureIdentity: captureIdentity,
                freshness: freshness
            )
        }

        if hasUnavailable {
            let status: EvidenceEligibilityStatus = (consumer == .nonvisualDescription || consumer == .exportReport) ? .incomplete : .notEvaluated
            return EvidenceEligibilityDecision(
                consumer: consumer,
                status: status,
                isEligible: false,
                canPass: false,
                reasons: reasons,
                migrationLimitations: migrationLimitations,
                captureIdentity: captureIdentity,
                freshness: freshness
            )
        }

        if hasInferred && (consumer == .visualSemanticCorrelation || consumer == .baselinePromotion || consumer == .fixVerification || consumer == .qualityGate) {
            return EvidenceEligibilityDecision(
                consumer: consumer,
                status: .notEvaluated,
                isEligible: false,
                canPass: false,
                reasons: reasons,
                migrationLimitations: migrationLimitations,
                captureIdentity: captureIdentity,
                freshness: freshness
            )
        }

        if !migrationLimitations.isEmpty && (consumer == .baselinePromotion || consumer == .fixVerification || consumer == .qualityGate) {
            return EvidenceEligibilityDecision(
                consumer: consumer,
                status: .incomplete,
                isEligible: false,
                canPass: false,
                reasons: reasons,
                migrationLimitations: migrationLimitations,
                captureIdentity: captureIdentity,
                freshness: freshness
            )
        }

        return EvidenceEligibilityDecision(
            consumer: consumer,
            status: .eligible,
            isEligible: true,
            canPass: true,
            reasons: reasons,
            migrationLimitations: migrationLimitations,
            captureIdentity: captureIdentity,
            freshness: freshness
        )
    }

    /// Evaluates whether a focus state satisfies a required focus channel.
    public static func evaluateFocusChannel(
        _ focusState: SeparatedFocusState,
        requiredChannel: FocusObservationChannel
    ) -> EvidenceEligibilityDecision {
        guard let observation = focusState.observation(for: requiredChannel) else {
            return EvidenceEligibilityDecision(
                consumer: .qualityGate,
                status: .notEvaluated,
                isEligible: false,
                canPass: false,
                reasons: ["Missing focus observation for channel '\(requiredChannel.rawValue)'. Other focus channels cannot substitute for '\(requiredChannel.rawValue)'."]
            )
        }

        switch requiredChannel {
        case .humanVoiceOverObservation:
            guard observation.provenance.kind == .humanConfirmed else {
                return EvidenceEligibilityDecision(
                    consumer: .qualityGate,
                    status: .ineligible,
                    isEligible: false,
                    canPass: false,
                    reasons: ["Human VoiceOver observation requires 'human_confirmed' provenance, got '\(observation.provenance.kind.rawValue)'."]
                )
            }
        case .accessibilityFocus, .nativeKeyboardFocus:
            guard observation.provenance.kind == .measured || observation.provenance.kind == .humanConfirmed else {
                return EvidenceEligibilityDecision(
                    consumer: .qualityGate,
                    status: .notEvaluated,
                    isEligible: false,
                    canPass: false,
                    reasons: ["Focus channel '\(requiredChannel.rawValue)' requires measured or human-confirmed provenance, got '\(observation.provenance.kind.rawValue)'."]
                )
            }
        case .predictedInputFocus:
            guard observation.provenance.kind != .unavailable && observation.provenance.kind != .synthetic else {
                return EvidenceEligibilityDecision(
                    consumer: .nonvisualDescription,
                    status: .notEvaluated,
                    isEligible: false,
                    canPass: false,
                    reasons: ["Predicted input focus is '\(observation.provenance.kind.rawValue)'."]
                )
            }
        }

        return EvidenceEligibilityDecision(
            consumer: .qualityGate,
            status: .eligible,
            isEligible: true,
            canPass: true,
            reasons: []
        )
    }

    /// Assesses legacy stored reports or exports and produces safe migration limitation disclosures.
    public static func assessLegacyReport(
        schemaVersion: Int,
        currentSchemaVersion: Int = 2,
        hasProvenance: Bool,
        hasCaptureIdentity: Bool
    ) -> [String] {
        var limitations: [String] = []
        if schemaVersion < currentSchemaVersion {
            limitations.append("Legacy report schema v\(schemaVersion) predates v\(currentSchemaVersion) provenance enforcement; conformance claims require re-evaluation.")
        }
        if !hasProvenance {
            limitations.append("Report lacks field-level evidence provenance; findings are treated as incomplete for baseline promotion and fix verification.")
        }
        if !hasCaptureIdentity {
            limitations.append("Report lacks capture identity metadata; cross-artifact correlation and freshness verification are unavailable.")
        }
        return limitations
    }

    public static func evaluateFreshness(
        captureIdentity: CaptureIdentity?,
        expectedCaptureIdentity: CaptureIdentity? = nil,
        maxAgeSeconds: TimeInterval? = nil,
        now: Date = Date()
    ) -> EvidenceFreshness {
        if let expected = expectedCaptureIdentity {
            guard let actual = captureIdentity else {
                return .unknown(reason: "Missing capture identity to compare against expected \(expected.captureID).")
            }
            if actual.captureID != expected.captureID {
                return .mismatchedCapture(expectedID: expected.captureID, actualID: actual.captureID)
            }
            if actual.target != expected.target {
                return .mismatchedCapture(expectedID: "\(expected.target)#\(expected.captureID)", actualID: "\(actual.target)#\(actual.captureID)")
            }
        }

        if let maxAgeSeconds {
            guard let capturedAt = captureIdentity?.capturedAt else {
                return .unknown(reason: "Capture timestamp is unavailable.")
            }
            let age = now.timeIntervalSince(capturedAt)
            if age > maxAgeSeconds {
                return .stale(reason: String(format: "Capture age %.1fs exceeds maximum %.1fs.", age, maxAgeSeconds))
            }
        }

        return .fresh
    }
}
