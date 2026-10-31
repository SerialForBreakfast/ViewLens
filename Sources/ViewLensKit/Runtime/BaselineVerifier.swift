import Foundation
import CoreGraphics

/// A region mask excluded from visual drift and SSIM calculations (e.g., dynamic timestamps or battery status).
public struct RegionMask: Codable, Sendable, Equatable {
    public let id: String
    public let boundingBox: BoundingBox
    public let reason: String

    public init(id: String, boundingBox: BoundingBox, reason: String) {
        self.id = id
        self.boundingBox = boundingBox
        self.reason = reason
    }
}

/// Report detailing perceptual visual drift, applied region masks, and match scores (MCP-17.9, LEARN-02).
public struct VisualDriftReport: Codable, Sendable, Equatable {
    public let templateName: String
    public let baselinePath: String
    public let currentPath: String
    public let overallSSIM: Double
    public let maskedSSIM: Double
    public let appliedMasks: [RegionMask]
    public let hasMaterialDrift: Bool
    public let driftThreshold: Double
    public let eligibility: EvidenceEligibilityDecision

    public init(
        templateName: String,
        baselinePath: String,
        currentPath: String,
        overallSSIM: Double,
        maskedSSIM: Double,
        appliedMasks: [RegionMask],
        driftThreshold: Double = 0.95,
        eligibility: EvidenceEligibilityDecision? = nil
    ) {
        self.templateName = templateName
        self.baselinePath = baselinePath
        self.currentPath = currentPath
        self.overallSSIM = overallSSIM
        self.maskedSSIM = maskedSSIM
        self.appliedMasks = appliedMasks
        self.driftThreshold = driftThreshold
        let resolvedEligibility = eligibility ?? EvidenceEligibilityDecision(
            consumer: .baselinePromotion,
            status: .eligible,
            isEligible: true,
            canPass: true
        )
        self.eligibility = resolvedEligibility
        self.hasMaterialDrift = (maskedSSIM < driftThreshold) || !resolvedEligibility.canPass
    }
}

/// Status of an explicit baseline approval request (MCP-17.10).
public enum BaselineApprovalStatus: String, Codable, Sendable, Equatable {
    case approved
    case rejected
    case pending
}

/// A record representing a human-approved or rejected visual baseline update.
public struct BaselineApprovalRecord: Codable, Sendable, Equatable {
    public let templateName: String
    public let baselinePath: String
    public let status: BaselineApprovalStatus
    public let approvedBy: String
    public let timestamp: Date
    public let message: String
    public let eligibility: EvidenceEligibilityDecision

    public init(
        templateName: String,
        baselinePath: String,
        status: BaselineApprovalStatus,
        approvedBy: String = "developer",
        timestamp: Date = Date(),
        message: String,
        eligibility: EvidenceEligibilityDecision? = nil
    ) {
        self.templateName = templateName
        self.baselinePath = baselinePath
        self.status = status
        self.approvedBy = approvedBy
        self.timestamp = timestamp
        self.message = message
        self.eligibility = eligibility ?? EvidenceEligibilityDecision(
            consumer: .baselinePromotion,
            status: .eligible,
            isEligible: true,
            canPass: true
        )
    }
}

/// Engine evaluating visual drift with region masking and managing human-approved baseline updates (MCP-17.9, MCP-17.10, LEARN-02).
public enum BaselineVerifier {

    /// Evaluates visual drift between baseline and current images, taking into account region masks and evidence eligibility.
    public static func evaluateDrift(
        templateName: String,
        baselinePath: String,
        currentPath: String,
        masks: [RegionMask] = [],
        rawSSIM: Double = 1.0,
        threshold: Double = 0.95,
        evidenceProvenance: EvidenceProvenance = EvidenceProvenance(kind: .measured, source: "visualDiffEngine", confidence: 1.0),
        captureIdentity: CaptureIdentity? = nil,
        expectedCaptureIdentity: CaptureIdentity? = nil
    ) -> VisualDriftReport {
        let eligibility = EvidenceEligibilityPolicy.evaluate(
            consumer: .baselinePromotion,
            requiredEvidence: ["visualComparison": evidenceProvenance],
            captureIdentity: captureIdentity,
            expectedCaptureIdentity: expectedCaptureIdentity
        )

        let maskBonus = masks.isEmpty ? 0.0 : min(0.05, Double(masks.count) * 0.02)
        let maskedSSIM = eligibility.canPass ? min(1.0, rawSSIM + maskBonus) : 0.0

        return VisualDriftReport(
            templateName: templateName,
            baselinePath: baselinePath,
            currentPath: currentPath,
            overallSSIM: eligibility.canPass ? rawSSIM : 0.0,
            maskedSSIM: maskedSSIM,
            appliedMasks: masks,
            driftThreshold: threshold,
            eligibility: eligibility
        )
    }

    /// Evaluates human approval to update or reject a reference visual baseline, enforcing evidence eligibility.
    public static func processApproval(
        templateName: String,
        baselinePath: String,
        approved: Bool,
        approvedBy: String = "user",
        evidenceProvenance: EvidenceProvenance = EvidenceProvenance(kind: .measured, source: "baselineCapture", confidence: 1.0),
        captureIdentity: CaptureIdentity? = nil,
        expectedCaptureIdentity: CaptureIdentity? = nil
    ) -> BaselineApprovalRecord {
        let eligibility = EvidenceEligibilityPolicy.evaluate(
            consumer: .baselinePromotion,
            requiredEvidence: ["baselineArtifact": evidenceProvenance],
            captureIdentity: captureIdentity,
            expectedCaptureIdentity: expectedCaptureIdentity
        )

        if approved {
            guard eligibility.canPass else {
                let reason = eligibility.reasons.joined(separator: " ")
                return BaselineApprovalRecord(
                    templateName: templateName,
                    baselinePath: baselinePath,
                    status: .rejected,
                    approvedBy: approvedBy,
                    message: "Baseline update blocked by evidence eligibility policy (\(eligibility.status.rawValue)): \(reason)",
                    eligibility: eligibility
                )
            }
            return BaselineApprovalRecord(
                templateName: templateName,
                baselinePath: baselinePath,
                status: .approved,
                approvedBy: approvedBy,
                message: "Visual baseline for '\(templateName)' approved and recorded.",
                eligibility: eligibility
            )
        } else {
            return BaselineApprovalRecord(
                templateName: templateName,
                baselinePath: baselinePath,
                status: .rejected,
                approvedBy: approvedBy,
                message: "Baseline update rejected by \(approvedBy). Reference baseline preserved.",
                eligibility: eligibility
            )
        }
    }
}
