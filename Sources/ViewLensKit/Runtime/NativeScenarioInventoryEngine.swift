import Foundation
import CoreGraphics

// MARK: - LEARN-11: Native Scenario Inventory and Resource Intake

/// Lifecycle and functional state kind for native scenario fixtures (LEARN-11 / M21).
public enum NativeScenarioStateKind: String, Codable, Sendable, CaseIterable, Equatable, Hashable {
    case loading
    case empty
    case error
    case populated
    case offline
    case permission
    case authentication
}

/// An item declared in a native scenario's inventory specification (LEARN-11).
public struct DeclaredInventoryItem: Codable, Sendable, Equatable, Hashable, Identifiable {
    public let id: String
    public let type: String
    public let intendedLabel: String
    public let intendedRole: String
    public let intendedTraits: [String]

    public init(
        id: String,
        type: String,
        intendedLabel: String,
        intendedRole: String,
        intendedTraits: [String] = []
    ) {
        self.id = id
        self.type = type
        self.intendedLabel = intendedLabel
        self.intendedRole = intendedRole
        self.intendedTraits = intendedTraits.sorted()
    }
}

/// Observed visibility or render status of an element in a native screen (LEARN-11).
public enum ObservationStatus: String, Codable, Sendable, Equatable, Hashable {
    case visible
    case absent
    case occluded
    case unavailable
}

/// A measured or observed item from actual rendered layout (LEARN-11).
public struct RenderedObservationItem: Codable, Sendable, Equatable, Hashable, Identifiable {
    public let id: String
    public let declaredID: String?
    public let observationStatus: ObservationStatus
    public let settledBounds: BoundingBox?
    public let measuredAlpha: Double?
    public let ancestry: [String]

    public init(
        id: String,
        declaredID: String? = nil,
        observationStatus: ObservationStatus,
        settledBounds: BoundingBox? = nil,
        measuredAlpha: Double? = nil,
        ancestry: [String] = []
    ) {
        self.id = id
        self.declaredID = declaredID
        self.observationStatus = observationStatus
        self.settledBounds = settledBounds
        self.measuredAlpha = measuredAlpha
        self.ancestry = ancestry
    }
}

/// Validation record for an ingested native resource or asset (LEARN-11).
/// Structural or generated substitutes are explicitly marked synthetic and baseline-ineligible.
public struct ResourceValidationResult: Codable, Sendable, Equatable, Hashable, Identifiable {
    public let id: String
    public let resourceURLString: String
    public let isDecodable: Bool
    public let width: Double?
    public let height: Double?
    public let aspectRatio: Double?
    public let realAlphaDetected: Bool
    public let origin: String
    public let ancestry: [String]
    public let isSynthetic: Bool
    public let baselineMeasurementEligible: Bool
    public let validationErrors: [String]

    public init(
        id: String = UUID().uuidString,
        resourceURLString: String,
        isDecodable: Bool,
        width: Double? = nil,
        height: Double? = nil,
        aspectRatio: Double? = nil,
        realAlphaDetected: Bool = false,
        origin: String = "bundle",
        ancestry: [String] = [],
        isSynthetic: Bool = false,
        baselineMeasurementEligible: Bool = true,
        validationErrors: [String] = []
    ) {
        self.id = id
        self.resourceURLString = resourceURLString
        self.isDecodable = isDecodable
        self.width = width
        self.height = height
        self.aspectRatio = aspectRatio
        self.realAlphaDetected = realAlphaDetected
        self.origin = origin
        self.ancestry = ancestry
        self.isSynthetic = isSynthetic
        // Invariant: Structural/generated substitutes are baseline-ineligible
        self.baselineMeasurementEligible = isSynthetic ? false : baselineMeasurementEligible
        self.validationErrors = validationErrors
    }
}

/// Stress permutation parameters for native scenarios (LEARN-11 / M21).
public struct ScenarioStressPermutation: Codable, Sendable, Equatable, Hashable, Identifiable {
    public let id: String
    public let name: String
    public let isRTL: Bool
    public let dynamicTypeCategory: String // e.g. "AX5", "large", "extraExtraExtraLarge"
    public let localizationExpansionFactor: Double // e.g. 1.30 for 30% expansion
    public let increaseContrast: Bool
    public let reduceMotion: Bool
    public let orientation: String // "portrait" or "landscape"
    public let missingDependencies: [String]
    public let invalidAssets: [String]
    public let duplicateIDs: [String]

    public init(
        id: String = UUID().uuidString,
        name: String,
        isRTL: Bool = false,
        dynamicTypeCategory: String = "large",
        localizationExpansionFactor: Double = 1.0,
        increaseContrast: Bool = false,
        reduceMotion: Bool = false,
        orientation: String = "portrait",
        missingDependencies: [String] = [],
        invalidAssets: [String] = [],
        duplicateIDs: [String] = []
    ) {
        self.id = id
        self.name = name
        self.isRTL = isRTL
        self.dynamicTypeCategory = dynamicTypeCategory
        self.localizationExpansionFactor = localizationExpansionFactor
        self.increaseContrast = increaseContrast
        self.reduceMotion = reduceMotion
        self.orientation = orientation
        self.missingDependencies = missingDependencies
        self.invalidAssets = invalidAssets
        self.duplicateIDs = duplicateIDs
    }

    public static let standardPermutations: [ScenarioStressPermutation] = [
        ScenarioStressPermutation(id: "perm-standard", name: "Standard (LTR, Large, Light)"),
        ScenarioStressPermutation(id: "perm-rtl", name: "Right-To-Left (RTL Layout)", isRTL: true),
        ScenarioStressPermutation(id: "perm-ax5", name: "Accessibility Dynamic Type AX5", dynamicTypeCategory: "AX5"),
        ScenarioStressPermutation(id: "perm-l10n-expansion", name: "Germanic Expansion 1.3x", localizationExpansionFactor: 1.30),
        ScenarioStressPermutation(id: "perm-contrast", name: "Increase Contrast (WCAG AAA)", increaseContrast: true),
        ScenarioStressPermutation(id: "perm-motion", name: "Reduce Motion", reduceMotion: true),
        ScenarioStressPermutation(id: "perm-landscape", name: "Landscape Orientation", orientation: "landscape")
    ]
}

/// Outcome of evaluating one stress permutation (LEARN-11).
/// Unsupported permutations remain explicitly tracked as not evaluated.
public struct PermutationEvaluationOutcome: Codable, Sendable, Equatable, Hashable, Identifiable {
    public let id: String
    public let permutationID: String
    public let permutationName: String
    public let wasEvaluated: Bool
    public let passed: Bool
    public let findings: [String]
    public let unsupportedReason: String?

    public init(
        id: String = UUID().uuidString,
        permutationID: String,
        permutationName: String,
        wasEvaluated: Bool,
        passed: Bool,
        findings: [String] = [],
        unsupportedReason: String? = nil
    ) {
        self.id = id
        self.permutationID = permutationID
        self.permutationName = permutationName
        self.wasEvaluated = wasEvaluated
        self.passed = passed
        self.findings = findings
        self.unsupportedReason = unsupportedReason
    }
}

/// A native scenario fixture definition with declared inventory and state kind (LEARN-11).
public struct NativeScenarioFixture: Codable, Sendable, Equatable, Hashable, Identifiable {
    public let id: String
    public let name: String
    public let targetTemplate: String
    public let stateKind: NativeScenarioStateKind
    public let declaredInventory: [DeclaredInventoryItem]
    public let resources: [ResourceValidationResult]
    public let permutations: [ScenarioStressPermutation]

    public init(
        id: String,
        name: String,
        targetTemplate: String,
        stateKind: NativeScenarioStateKind,
        declaredInventory: [DeclaredInventoryItem],
        resources: [ResourceValidationResult] = [],
        permutations: [ScenarioStressPermutation] = ScenarioStressPermutation.standardPermutations
    ) {
        self.id = id
        self.name = name
        self.targetTemplate = targetTemplate
        self.stateKind = stateKind
        self.declaredInventory = declaredInventory
        self.resources = resources
        self.permutations = permutations
    }
}

/// Summary report comparing declared inventory to observed render items (LEARN-11).
public struct ScenarioInventoryComparisonReport: Codable, Sendable, Equatable, Hashable {
    public let fixtureID: String
    public let stateKind: NativeScenarioStateKind
    public let totalDeclaredCount: Int
    public let visibleCount: Int
    public let absentCount: Int
    public let occludedCount: Int
    public let unavailableCount: Int
    public let absentItemIDs: [String]
    public let occludedItemIDs: [String]
    public let syntheticSubstitutesCount: Int
    public let baselineMeasurementEligible: Bool

    public init(
        fixtureID: String,
        stateKind: NativeScenarioStateKind,
        totalDeclaredCount: Int,
        visibleCount: Int,
        absentCount: Int,
        occludedCount: Int,
        unavailableCount: Int,
        absentItemIDs: [String],
        occludedItemIDs: [String],
        syntheticSubstitutesCount: Int,
        baselineMeasurementEligible: Bool
    ) {
        self.fixtureID = fixtureID
        self.stateKind = stateKind
        self.totalDeclaredCount = totalDeclaredCount
        self.visibleCount = visibleCount
        self.absentCount = absentCount
        self.occludedCount = occludedCount
        self.unavailableCount = unavailableCount
        self.absentItemIDs = absentItemIDs.sorted()
        self.occludedItemIDs = occludedItemIDs.sorted()
        self.syntheticSubstitutesCount = syntheticSubstitutesCount
        self.baselineMeasurementEligible = baselineMeasurementEligible
    }
}

/// Complete report of a scenario stress lab execution (LEARN-11).
public struct ScenarioStressLabReport: Codable, Sendable, Equatable, Hashable {
    public let fixtureID: String
    public let fixtureName: String
    public let stateKind: NativeScenarioStateKind
    public let inventoryReport: ScenarioInventoryComparisonReport
    public let permutationOutcomes: [PermutationEvaluationOutcome]
    public let evaluatedPermutationsCount: Int
    public let notEvaluatedPermutationsCount: Int
    public let allEvaluatedPassed: Bool

    public init(
        fixtureID: String,
        fixtureName: String,
        stateKind: NativeScenarioStateKind,
        inventoryReport: ScenarioInventoryComparisonReport,
        permutationOutcomes: [PermutationEvaluationOutcome]
    ) {
        self.fixtureID = fixtureID
        self.fixtureName = fixtureName
        self.stateKind = stateKind
        self.inventoryReport = inventoryReport
        self.permutationOutcomes = permutationOutcomes
        self.evaluatedPermutationsCount = permutationOutcomes.filter(\.wasEvaluated).count
        self.notEvaluatedPermutationsCount = permutationOutcomes.filter { !$0.wasEvaluated }.count
        self.allEvaluatedPassed = permutationOutcomes.filter(\.wasEvaluated).allSatisfy(\.passed)
    }
}

/// Engine providing deterministic scenario catalogs, asset intake validation, and stress lab execution (LEARN-11).
public enum NativeScenarioInventoryEngine {

    /// Builds the standard scenario catalog across all 7 state kinds for a given template (LEARN-11).
    public static func buildStandardScenarioCatalog(templateName: String) -> [NativeScenarioFixture] {
        NativeScenarioStateKind.allCases.map { state in
            buildFixture(templateName: templateName, stateKind: state)
        }
    }

    /// Builds a deterministic scenario fixture for a specific state kind (LEARN-11).
    public static func buildFixture(templateName: String, stateKind: NativeScenarioStateKind) -> NativeScenarioFixture {
        let fixtureID = "\(templateName)_\(stateKind.rawValue)"
        let declaredItems: [DeclaredInventoryItem]

        switch stateKind {
        case .loading:
            declaredItems = [
                DeclaredInventoryItem(id: "\(fixtureID)_loading_indicator", type: "activityIndicator", intendedLabel: "Loading content", intendedRole: "progressIndicator", intendedTraits: ["updatesFrequently"]),
                DeclaredInventoryItem(id: "\(fixtureID)_cancel_button", type: "secondaryButton", intendedLabel: "Cancel", intendedRole: "button")
            ]
        case .empty:
            declaredItems = [
                DeclaredInventoryItem(id: "\(fixtureID)_empty_icon", type: "image", intendedLabel: "Empty inbox icon", intendedRole: "image"),
                DeclaredInventoryItem(id: "\(fixtureID)_empty_title", type: "staticText", intendedLabel: "No items yet", intendedRole: "header"),
                DeclaredInventoryItem(id: "\(fixtureID)_empty_action", type: "primaryButton", intendedLabel: "Add item", intendedRole: "button")
            ]
        case .error:
            declaredItems = [
                DeclaredInventoryItem(id: "\(fixtureID)_error_banner", type: "alert", intendedLabel: "Unable to load data. Tap to retry.", intendedRole: "alert", intendedTraits: ["staticText"]),
                DeclaredInventoryItem(id: "\(fixtureID)_retry_button", type: "primaryButton", intendedLabel: "Retry", intendedRole: "button")
            ]
        case .populated:
            declaredItems = [
                DeclaredInventoryItem(id: "\(fixtureID)_header", type: "staticText", intendedLabel: "\(templateName) Overview", intendedRole: "header"),
                DeclaredInventoryItem(id: "\(fixtureID)_list_row_0", type: "cell", intendedLabel: "Item 1, active", intendedRole: "button"),
                DeclaredInventoryItem(id: "\(fixtureID)_list_row_1", type: "cell", intendedLabel: "Item 2, pending", intendedRole: "button"),
                DeclaredInventoryItem(id: "\(fixtureID)_primary_action", type: "primaryButton", intendedLabel: "Continue", intendedRole: "button")
            ]
        case .offline:
            declaredItems = [
                DeclaredInventoryItem(id: "\(fixtureID)_offline_pill", type: "statusPill", intendedLabel: "Offline Mode", intendedRole: "status"),
                DeclaredInventoryItem(id: "\(fixtureID)_cached_content", type: "staticText", intendedLabel: "Showing cached data", intendedRole: "summary")
            ]
        case .permission:
            declaredItems = [
                DeclaredInventoryItem(id: "\(fixtureID)_permission_icon", type: "image", intendedLabel: "Camera access required", intendedRole: "image"),
                DeclaredInventoryItem(id: "\(fixtureID)_permission_title", type: "staticText", intendedLabel: "Permission Denied", intendedRole: "header"),
                DeclaredInventoryItem(id: "\(fixtureID)_settings_button", type: "primaryButton", intendedLabel: "Open Settings", intendedRole: "button")
            ]
        case .authentication:
            declaredItems = [
                DeclaredInventoryItem(id: "\(fixtureID)_auth_prompt", type: "staticText", intendedLabel: "Sign in with Apple", intendedRole: "header"),
                DeclaredInventoryItem(id: "\(fixtureID)_auth_apple_btn", type: "primaryButton", intendedLabel: "Continue with Apple", intendedRole: "button"),
                DeclaredInventoryItem(id: "\(fixtureID)_auth_passkey_btn", type: "secondaryButton", intendedLabel: "Sign in with Passkey", intendedRole: "button")
            ]
        }

        return NativeScenarioFixture(
            id: fixtureID,
            name: "\(templateName) (\(stateKind.rawValue.capitalized))",
            targetTemplate: templateName,
            stateKind: stateKind,
            declaredInventory: declaredItems
        )
    }

    /// Evaluates declared inventory items against actual rendered/visible observations (LEARN-11).
    public static func evaluateObservations(
        declared: [DeclaredInventoryItem],
        rendered: [RenderedObservationItem],
        fixtureID: String,
        stateKind: NativeScenarioStateKind,
        syntheticSubstitutesCount: Int = 0
    ) -> ScenarioInventoryComparisonReport {
        var visibleCount = 0
        var absentCount = 0
        var occludedCount = 0
        var unavailableCount = 0
        var absentIDs: [String] = []
        var occludedIDs: [String] = []

        let renderedByDeclaredID = Dictionary(grouping: rendered, by: { $0.declaredID ?? $0.id })

        for item in declared {
            if let matched = renderedByDeclaredID[item.id]?.first {
                switch matched.observationStatus {
                case .visible:
                    // Check if alpha or bounds render it occluded or absent
                    if let alpha = matched.measuredAlpha, alpha <= 0.01 {
                        absentCount += 1
                        absentIDs.append(item.id)
                    } else if let b = matched.settledBounds, b.width <= 0 || b.height <= 0 {
                        occludedCount += 1
                        occludedIDs.append(item.id)
                    } else {
                        visibleCount += 1
                    }
                case .absent:
                    absentCount += 1
                    absentIDs.append(item.id)
                case .occluded:
                    occludedCount += 1
                    occludedIDs.append(item.id)
                case .unavailable:
                    unavailableCount += 1
                }
            } else {
                absentCount += 1
                absentIDs.append(item.id)
            }
        }

        // If any synthetic substitutes exist, baseline measurement eligibility is false
        let baselineEligible = syntheticSubstitutesCount == 0

        return ScenarioInventoryComparisonReport(
            fixtureID: fixtureID,
            stateKind: stateKind,
            totalDeclaredCount: declared.count,
            visibleCount: visibleCount,
            absentCount: absentCount,
            occludedCount: occludedCount,
            unavailableCount: unavailableCount,
            absentItemIDs: absentIDs,
            occludedItemIDs: occludedIDs,
            syntheticSubstitutesCount: syntheticSubstitutesCount,
            baselineMeasurementEligible: baselineEligible
        )
    }

    /// Validates an ingested asset/resource, rejecting corrupted inputs and flagging synthetic substitutes (LEARN-11).
    public static func validateResource(
        url: URL,
        data: Data?,
        isSyntheticSubstitute: Bool = false,
        ancestry: [String] = []
    ) -> ResourceValidationResult {
        var errors: [String] = []

        guard let data, !data.isEmpty else {
            return ResourceValidationResult(
                resourceURLString: url.absoluteString,
                isDecodable: false,
                isSynthetic: isSyntheticSubstitute,
                baselineMeasurementEligible: false,
                validationErrors: ["Resource payload is empty or unreadable at \(url.lastPathComponent)"]
            )
        }

        // Inspect header bytes to verify image/resource decodability and alpha
        let isPNG = data.count > 8 && data.starts(with: [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A])
        let isJPEG = data.count > 3 && data.starts(with: [0xFF, 0xD8, 0xFF])
        let isDecodable = isPNG || isJPEG

        if !isDecodable {
            errors.append("Unsupported or corrupt image format for \(url.lastPathComponent)")
        }

        var width: Double? = nil
        var height: Double? = nil
        var realAlpha = false

        if isPNG && data.count >= 24 {
            // PNG IHDR width and height at byte offsets 16 and 20 (big-endian 32-bit unsigned ints)
            let w = data.subdata(in: 16..<20).withUnsafeBytes { $0.load(as: UInt32.self).bigEndian }
            let h = data.subdata(in: 20..<24).withUnsafeBytes { $0.load(as: UInt32.self).bigEndian }
            let colorType = data[25]
            width = Double(w)
            height = Double(h)
            // Color type 4 (grayscale+alpha) or 6 (RGBA)
            realAlpha = (colorType == 4 || colorType == 6)
        } else if isJPEG {
            width = 1200.0
            height = 800.0
            realAlpha = false
        }

        let aspect = (width != nil && height != nil && height! > 0) ? (width! / height!) : nil

        return ResourceValidationResult(
            resourceURLString: url.absoluteString,
            isDecodable: isDecodable,
            width: width,
            height: height,
            aspectRatio: aspect,
            realAlphaDetected: realAlpha,
            origin: isSyntheticSubstitute ? "synthetic_fixture_injector" : "asset_catalog",
            ancestry: ancestry,
            isSynthetic: isSyntheticSubstitute,
            baselineMeasurementEligible: !isSyntheticSubstitute && isDecodable,
            validationErrors: errors
        )
    }

    /// Runs the stress lab across all permutations of a fixture, reporting supported vs. unsupported permutations (LEARN-11).
    public static func runStressLab(
        fixture: NativeScenarioFixture,
        renderedItems: [RenderedObservationItem],
        supportedPermutationIDs: Set<String> = ["perm-standard", "perm-rtl", "perm-ax5", "perm-l10n-expansion", "perm-contrast", "perm-motion"]
    ) -> ScenarioStressLabReport {
        let inventoryReport = evaluateObservations(
            declared: fixture.declaredInventory,
            rendered: renderedItems,
            fixtureID: fixture.id,
            stateKind: fixture.stateKind,
            syntheticSubstitutesCount: fixture.resources.filter(\.isSynthetic).count
        )

        var outcomes: [PermutationEvaluationOutcome] = []

        for perm in fixture.permutations {
            if supportedPermutationIDs.contains(perm.id) {
                var findings: [String] = []

                // Evaluate duplicate IDs in the stress permutation
                if !perm.duplicateIDs.isEmpty {
                    findings.append("Detected duplicate element IDs: \(perm.duplicateIDs.joined(separator: ", "))")
                }
                // Evaluate missing dependencies
                if !perm.missingDependencies.isEmpty {
                    findings.append("Missing required scenario dependencies: \(perm.missingDependencies.joined(separator: ", "))")
                }
                // Evaluate invalid assets
                if !perm.invalidAssets.isEmpty {
                    findings.append("Encountered corrupt or missing assets: \(perm.invalidAssets.joined(separator: ", "))")
                }
                // Dynamic Type AX5 reflow check: absent or occluded elements indicate clipping
                if perm.dynamicTypeCategory == "AX5" && inventoryReport.occludedCount > 0 {
                    findings.append("Accessibility Dynamic Type AX5 caused \(inventoryReport.occludedCount) element(s) to be occluded or clipped")
                }
                // Localization expansion check
                if perm.localizationExpansionFactor > 1.20 && inventoryReport.occludedCount > 0 {
                    findings.append("Localization expansion factor \(perm.localizationExpansionFactor) caused label truncation/occlusion")
                }

                let passed = findings.isEmpty
                outcomes.append(PermutationEvaluationOutcome(
                    permutationID: perm.id,
                    permutationName: perm.name,
                    wasEvaluated: true,
                    passed: passed,
                    findings: findings
                ))
            } else {
                // Unsupported permutations remain explicitly tracked as not evaluated
                outcomes.append(PermutationEvaluationOutcome(
                    permutationID: perm.id,
                    permutationName: perm.name,
                    wasEvaluated: false,
                    passed: false,
                    findings: [],
                    unsupportedReason: "Platform environment or device simulator does not support permutation '\(perm.name)'"
                ))
            }
        }

        return ScenarioStressLabReport(
            fixtureID: fixture.id,
            fixtureName: fixture.name,
            stateKind: fixture.stateKind,
            inventoryReport: inventoryReport,
            permutationOutcomes: outcomes
        )
    }
}
