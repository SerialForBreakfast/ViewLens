import Foundation

public enum NonvisualValidationCode: String, Codable, Sendable, Equatable, Hashable {
    case unsupportedSchemaVersion = "unsupported_schema_version"
    case emptyIdentifier = "empty_identifier"
    case duplicateIdentifier = "duplicate_identifier"
    case unresolvedReference = "unresolved_reference"
    case invalidEvidence = "invalid_evidence"
    case invalidBounds = "invalid_bounds"
    case invalidDistance = "invalid_distance"
}

public struct NonvisualValidationIssue: Codable, Sendable, Equatable, Hashable {
    public let code: NonvisualValidationCode
    public let subjectID: NonvisualID?
    public let message: String

    public init(code: NonvisualValidationCode, subjectID: NonvisualID? = nil, message: String) {
        self.code = code
        self.subjectID = subjectID
        self.message = message
    }
}

public enum NonvisualModelValidator {
    public static func validate(_ model: NonvisualScreenModel) -> [NonvisualValidationIssue] {
        var issues: [NonvisualValidationIssue] = []
        if model.schemaVersion != NonvisualScreenModel.currentSchemaVersion {
            issues.append(issue(.unsupportedSchemaVersion, model.id, "Unsupported schema version '\(model.schemaVersion)'."))
        }

        let identified: [(NonvisualID, String)] =
            [(model.id, "screen")] +
            model.regions.map { ($0.id, "region") } +
            model.elements.map { ($0.id, "element") } +
            model.relationships.map { ($0.id, "relationship") } +
            model.navigationSequences.map { ($0.id, "navigation sequence") } +
            model.mismatches.map { ($0.id, "mismatch") }
        for (id, kind) in identified where isBlank(id.rawValue) {
            issues.append(issue(.emptyIdentifier, id, "The \(kind) identifier must not be empty."))
        }
        for (id, values) in Dictionary(grouping: identified, by: { $0.0 }) where values.count > 1 {
            issues.append(issue(.duplicateIdentifier, id, "Identifier '\(id.rawValue)' is used \(values.count) times."))
        }

        let regionIDs = Set(model.regions.map(\.id))
        let elementIDs = Set(model.elements.map(\.id))
        let relationshipObjectIDs = elementIDs.union([model.id])

        for region in model.regions {
            validate(region.evidence, subjectID: region.id, into: &issues)
            validate(region.bounds, subjectID: region.id, into: &issues)
            for reference in region.elementIDs where !elementIDs.contains(reference) {
                issues.append(unresolved(reference, owner: region.id))
            }
        }
        for element in model.elements {
            validate(element.visualEvidence, subjectID: element.id, into: &issues)
            validate(element.semanticEvidence, subjectID: element.id, into: &issues)
            validate(element.bounds, subjectID: element.id, into: &issues)
            if let regionID = element.regionID, !regionIDs.contains(regionID) {
                issues.append(unresolved(regionID, owner: element.id))
            }
        }
        for relationship in model.relationships {
            validate(relationship.evidence, subjectID: relationship.id, into: &issues)
            if !elementIDs.contains(relationship.subjectID) {
                issues.append(unresolved(relationship.subjectID, owner: relationship.id))
            }
            if !relationshipObjectIDs.contains(relationship.objectID) {
                issues.append(unresolved(relationship.objectID, owner: relationship.id))
            }
            if let distance = relationship.distance, !distance.isFinite || distance < 0 {
                issues.append(issue(.invalidDistance, relationship.id, "Relationship distance must be finite and nonnegative."))
            }
        }
        for sequence in model.navigationSequences {
            validate(sequence.evidence, subjectID: sequence.id, into: &issues)
            for reference in sequence.elementIDs where !elementIDs.contains(reference) {
                issues.append(unresolved(reference, owner: sequence.id))
            }
        }
        for mismatch in model.mismatches {
            validate(mismatch.evidence, subjectID: mismatch.id, into: &issues)
            for reference in mismatch.elementIDs where !elementIDs.contains(reference) {
                issues.append(unresolved(reference, owner: mismatch.id))
            }
        }
        return issues.sorted {
            if $0.code.rawValue != $1.code.rawValue { return $0.code.rawValue < $1.code.rawValue }
            if $0.subjectID != $1.subjectID { return ($0.subjectID?.rawValue ?? "") < ($1.subjectID?.rawValue ?? "") }
            return $0.message < $1.message
        }
    }

    private static func validate(
        _ evidence: EvidenceProvenance,
        subjectID: NonvisualID,
        into issues: inout [NonvisualValidationIssue]
    ) {
        if isBlank(evidence.source) {
            issues.append(issue(.invalidEvidence, subjectID, "Evidence source must not be empty."))
        }
        if evidence.kind == .inferred, evidence.confidence == nil {
            issues.append(issue(.invalidEvidence, subjectID, "Inferred evidence requires confidence."))
        }
        if let confidence = evidence.confidence, !confidence.isFinite || !(0...1).contains(confidence) {
            issues.append(issue(.invalidEvidence, subjectID, "Evidence confidence must be finite and between zero and one."))
        }
    }

    private static func validate(
        _ bounds: BoundingBox?,
        subjectID: NonvisualID,
        into issues: inout [NonvisualValidationIssue]
    ) {
        guard let bounds else { return }
        let values = [bounds.x, bounds.y, bounds.width, bounds.height]
        if values.contains(where: { !$0.isFinite }) || bounds.width < 0 || bounds.height < 0 {
            issues.append(issue(.invalidBounds, subjectID, "Bounds must be finite with nonnegative width and height."))
        }
    }

    private static func unresolved(_ reference: NonvisualID, owner: NonvisualID) -> NonvisualValidationIssue {
        issue(.unresolvedReference, owner, "Reference '\(reference.rawValue)' does not resolve.")
    }

    private static func issue(
        _ code: NonvisualValidationCode,
        _ subjectID: NonvisualID?,
        _ message: String
    ) -> NonvisualValidationIssue {
        NonvisualValidationIssue(code: code, subjectID: subjectID, message: message)
    }

    private static func isBlank(_ value: String) -> Bool {
        value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}

public enum NonvisualSchemaError: Error, Sendable, Equatable, LocalizedError {
    case missingSchemaVersion
    case unsupportedSchemaVersion(String)
    case invalidModel([NonvisualValidationIssue])

    public var errorDescription: String? {
        switch self {
        case .missingSchemaVersion:
            "The nonvisual model has no schemaVersion."
        case .unsupportedSchemaVersion(let version):
            "Unsupported nonvisual schema version '\(version)'."
        case .invalidModel(let issues):
            "The nonvisual model failed validation with \(issues.count) issue(s)."
        }
    }
}

/// Decodes the current schema and the layout-compatible 0.9 preview schema.
/// All returned models are validated current-schema values.
public enum NonvisualSchemaMigrator {
    public static func decodeAndMigrate(_ data: Data) throws -> NonvisualScreenModel {
        guard var object = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let version = object["schemaVersion"] as? String else {
            throw NonvisualSchemaError.missingSchemaVersion
        }
        switch version {
        case NonvisualScreenModel.currentSchemaVersion:
            break
        case "0.9":
            object["schemaVersion"] = NonvisualScreenModel.currentSchemaVersion
        default:
            throw NonvisualSchemaError.unsupportedSchemaVersion(version)
        }
        let migratedData = try JSONSerialization.data(withJSONObject: object, options: [.sortedKeys])
        let model = try JSONDecoder().decode(NonvisualScreenModel.self, from: migratedData)
        let issues = NonvisualModelValidator.validate(model)
        guard issues.isEmpty else { throw NonvisualSchemaError.invalidModel(issues) }
        return model
    }
}
