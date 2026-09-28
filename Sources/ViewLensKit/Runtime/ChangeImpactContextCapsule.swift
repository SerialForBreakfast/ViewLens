import Foundation

public struct ChangeImpactEvidenceSummary: Codable, Sendable, Equatable {
    public let confidence: ChangeImpactConfidence
    public let completeness: ChangeImpactCompleteness
    public let compilerEvidenceStatus: CompilerEvidenceStatus
    public let inspectedArtifactCount: Int
    public let scanTruncated: Bool
}

/// A bounded, source-body-free context packet intended for selective MCP resource reads.
public struct ChangeImpactContextCapsule: Codable, Sendable, Equatable {
    public let schemaVersion: String
    public let capsuleID: String
    public let changedFiles: [String]
    public let affectedSourceFiles: [String]
    public let affectedRootViews: [ImpactedRootView]
    public let recommendations: [ImpactAuditRecommendation]
    public let evidence: ChangeImpactEvidenceSummary
    public let diagnostics: [ChangeImpactDiagnostic]
    public let evidenceLimitations: [String]
    public let truncated: Bool

    public static func make(id: String, report: ChangeImpactReport) -> ChangeImpactContextCapsule {
        let changed = Array(report.changedFiles.prefix(100))
        let affected = Array(report.affectedSourceFiles.prefix(250))
        let roots = Array(report.affectedRootViews.prefix(100))
        let recommendations = Array(report.recommendations.prefix(100))
        let diagnostics = report.diagnostics.prefix(100).map { diagnostic in
            ChangeImpactDiagnostic(
                severity: diagnostic.severity,
                code: diagnostic.code,
                message: diagnostic.message,
                path: diagnostic.path.flatMap { ($0 as NSString).isAbsolutePath ? nil : $0 }
            )
        }
        let limitations = Array(report.evidenceLimitations.prefix(20))
        let wasTruncated = changed.count < report.changedFiles.count ||
            affected.count < report.affectedSourceFiles.count ||
            roots.count < report.affectedRootViews.count ||
            recommendations.count < report.recommendations.count ||
            diagnostics.count < report.diagnostics.count ||
            limitations.count < report.evidenceLimitations.count

        return .init(
            schemaVersion: "1.0",
            capsuleID: id,
            changedFiles: changed,
            affectedSourceFiles: affected,
            affectedRootViews: roots,
            recommendations: recommendations,
            evidence: .init(
                confidence: report.confidence,
                completeness: report.completeness,
                compilerEvidenceStatus: report.compilerEvidence.status,
                inspectedArtifactCount: report.compilerEvidence.inspectedArtifacts.count,
                scanTruncated: report.scanTruncated
            ),
            diagnostics: diagnostics,
            evidenceLimitations: limitations,
            truncated: wasTruncated
        )
    }
}
