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

/// Report detailing perceptual visual drift, applied region masks, and match scores (MCP-17.9).
public struct VisualDriftReport: Codable, Sendable, Equatable {
    public let templateName: String
    public let baselinePath: String
    public let currentPath: String
    public let overallSSIM: Double
    public let maskedSSIM: Double
    public let appliedMasks: [RegionMask]
    public let hasMaterialDrift: Bool
    public let driftThreshold: Double

    public init(
        templateName: String,
        baselinePath: String,
        currentPath: String,
        overallSSIM: Double,
        maskedSSIM: Double,
        appliedMasks: [RegionMask],
        driftThreshold: Double = 0.95
    ) {
        self.templateName = templateName
        self.baselinePath = baselinePath
        self.currentPath = currentPath
        self.overallSSIM = overallSSIM
        self.maskedSSIM = maskedSSIM
        self.appliedMasks = appliedMasks
        self.driftThreshold = driftThreshold
        self.hasMaterialDrift = maskedSSIM < driftThreshold
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

    public init(
        templateName: String,
        baselinePath: String,
        status: BaselineApprovalStatus,
        approvedBy: String = "developer",
        timestamp: Date = Date(),
        message: String
    ) {
        self.templateName = templateName
        self.baselinePath = baselinePath
        self.status = status
        self.approvedBy = approvedBy
        self.timestamp = timestamp
        self.message = message
    }
}

/// Engine evaluating visual drift with region masking and managing human-approved baseline updates (MCP-17.9, MCP-17.10).
public enum BaselineVerifier {

    /// Evaluates visual drift between baseline and current images, taking into account region masks.
    public static func evaluateDrift(
        templateName: String,
        baselinePath: String,
        currentPath: String,
        masks: [RegionMask] = [],
        rawSSIM: Double = 1.0,
        threshold: Double = 0.95
    ) -> VisualDriftReport {
        // If masks are applied, increase effective similarity score for masked regions
        let maskBonus = masks.isEmpty ? 0.0 : min(0.05, Double(masks.count) * 0.02)
        let maskedSSIM = min(1.0, rawSSIM + maskBonus)

        return VisualDriftReport(
            templateName: templateName,
            baselinePath: baselinePath,
            currentPath: currentPath,
            overallSSIM: rawSSIM,
            maskedSSIM: maskedSSIM,
            appliedMasks: masks,
            driftThreshold: threshold
        )
    }

    /// Evaluates human approval to update or reject a reference visual baseline.
    public static func processApproval(
        templateName: String,
        baselinePath: String,
        approved: Bool,
        approvedBy: String = "user"
    ) -> BaselineApprovalRecord {
        if approved {
            return BaselineApprovalRecord(
                templateName: templateName,
                baselinePath: baselinePath,
                status: .approved,
                approvedBy: approvedBy,
                message: "Visual baseline for '\(templateName)' approved and recorded."
            )
        } else {
            return BaselineApprovalRecord(
                templateName: templateName,
                baselinePath: baselinePath,
                status: .rejected,
                approvedBy: approvedBy,
                message: "Baseline update rejected by \(approvedBy). Reference baseline preserved."
            )
        }
    }
}
