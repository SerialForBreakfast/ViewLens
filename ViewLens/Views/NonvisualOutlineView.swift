import SwiftUI
import ViewLensKit

/// A hierarchical, accessible Nonvisual Outline displaying screen regions,
/// elements, semantics, and findings with stable-ID cross references.
public struct NonvisualOutlineView: View {
    @Bindable var model: AppModel
    @State private var searchText = ""
    @State private var filterSeverity: ViewLensSeverity?
    @State private var onlyInteractive = false
    @State private var expandedRegions: Set<NonvisualID> = []

    public init(model: AppModel) {
        self.model = model
    }

    private var nonvisualModel: NonvisualScreenModel? {
        model.reviewStore.activeReview?.nonvisualScreenModel
    }

    public var body: some View {
        VStack(spacing: 0) {
            outlineToolbar
            Divider()
            if let nonvisual = nonvisualModel {
                outlineContent(nonvisual: nonvisual)
            } else {
                emptyOutlineState
            }
        }
        .background(Color(nsColor: .windowBackgroundColor))
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Nonvisual Screen Outline")
        .accessibilityIdentifier("review.nonvisualOutline")
        .accessibilityRotor("Findings") {
            if let findings = model.reviewStore.activeReview?.findings {
                ForEach(findings) { finding in
                    AccessibilityRotorEntry(finding.issue.displayTitle, id: finding.id)
                }
            }
        }
        .accessibilityRotor("Interactive Controls") {
            if let nonvisual = nonvisualModel {
                ForEach(nonvisual.elements.filter(\.isInteractive), id: \.id) { el in
                    AccessibilityRotorEntry(el.visibleLabel ?? el.type, id: el.id)
                }
            }
        }
        .accessibilityRotor("Regions") {
            if let nonvisual = nonvisualModel {
                ForEach(nonvisual.regions, id: \.id) { reg in
                    AccessibilityRotorEntry(reg.label, id: reg.id)
                }
            }
        }
        .accessibilityRotor("Semantic Mismatches") {
            if let nonvisual = nonvisualModel {
                ForEach(nonvisual.mismatches, id: \.id) { mis in
                    AccessibilityRotorEntry(mis.description, id: mis.id)
                }
            }
        }
        .onAppear {
            if let nonvisual = nonvisualModel {
                expandedRegions = Set(nonvisual.regions.map(\.id))
            }
        }
        .onChange(of: nonvisualModel?.id) { _, _ in
            if let nonvisual = nonvisualModel {
                expandedRegions = Set(nonvisual.regions.map(\.id))
            }
        }
    }

    private var outlineToolbar: some View {
        HStack(spacing: 8) {
            Label("Nonvisual Outline", systemImage: "list.bullet.indent")
                .font(.headline)
            Spacer()
            TextField("Filter outline", text: $searchText)
                .textFieldStyle(.roundedBorder)
                .frame(maxWidth: 160)
                .accessibilityLabel("Filter outline elements and findings")
                .accessibilityIdentifier("outline.search")

            Menu {
                Button("All Severities") { filterSeverity = nil }
                Divider()
                Button("Errors Only") { filterSeverity = .error }
                Button("Warnings Only") { filterSeverity = .warning }
                Button("Info Only") { filterSeverity = .info }
            } label: {
                Label(filterSeverity?.rawValue.capitalized ?? "Severity", systemImage: "line.3.horizontal.decrease.circle")
            }
            .fixedSize()
            .help("Filter findings by severity")
            .accessibilityIdentifier("outline.severity")

            Toggle(isOn: $onlyInteractive) {
                Label("Interactive", systemImage: "hand.tap")
            }
            .toggleStyle(.button)
            .help("Show only interactive controls")
            .accessibilityIdentifier("outline.interactiveOnly")

            Picker("Profile", selection: Binding(get: { model.preferences.nonvisualProfile }, set: { model.preferences.nonvisualProfile = $0 })) {
                Text("Speech").tag("Speech")
                Text("Braille").tag("Braille")
                Text("Dev").tag("Developer")
            }
            .pickerStyle(.segmented)
            .frame(maxWidth: 140)
            .help("Choose presentation detail profile")
            .accessibilityIdentifier("outline.profile")
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(ViewLensTheme.elevatedBackground)
    }

    private var emptyOutlineState: some View {
        ContentUnavailableView {
            Label("No Nonvisual Outline", systemImage: "list.bullet.rectangle.portrait")
        } description: {
            Text("A nonvisual outline will be synthesized when a review is loaded or completed.")
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func outlineContent(nonvisual: NonvisualScreenModel) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                screenHeaderNode(nonvisual: nonvisual)
                screenSummaryNode(nonvisual: nonvisual)

                ForEach(filteredRegions(nonvisual: nonvisual), id: \.id) { region in
                    regionNode(region: region, nonvisual: nonvisual)
                }

                if !nonvisual.mismatches.isEmpty && searchText.isEmpty {
                    semanticMismatchesNode(nonvisual.mismatches)
                }

                if !nonvisual.navigationSequences.isEmpty && searchText.isEmpty {
                    navigationNode(nonvisual.navigationSequences, elements: nonvisual.elements)
                }

                if !nonvisual.relationships.isEmpty && searchText.isEmpty {
                    spatialRelationshipsNode(relationships: nonvisual.relationships)
                }
            }
            .padding(14)
        }
    }

    private func screenHeaderNode(nonvisual: NonvisualScreenModel) -> some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .firstTextBaseline) {
                    Image(systemName: "iphone.gen3").foregroundStyle(ViewLensTheme.brand)
                    Text(nonvisual.title ?? "Screen").font(.headline)
                    Spacer()
                    Text(nonvisual.sourceMode.rawValue.capitalized)
                        .font(.caption2.bold())
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.secondary.opacity(0.12), in: Capsule())
                }
                Text("ID: `\(nonvisual.id.rawValue)`").font(.caption2.monospaced()).foregroundStyle(.secondary)
                HStack(spacing: 12) {
                    Label("\(nonvisual.regions.count) regions", systemImage: "square.split.2x2").font(.caption)
                    Label("\(nonvisual.elements.count) elements", systemImage: "square.on.square").font(.caption)
                    Label("\(nonvisual.elements.filter(\.isInteractive).count) interactive", systemImage: "hand.tap").font(.caption)
                }
                .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(4)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Screen \(nonvisual.title ?? "Screen"), \(nonvisual.regions.count) regions, \(nonvisual.elements.count) elements")
        .accessibilityIdentifier("outline.screen")
    }

    private func screenSummaryNode(nonvisual: NonvisualScreenModel) -> some View {
        let summary = NonvisualSummaryComposer.compose(nonvisual)
        let text = NonvisualPresentationRenderer.render(summary, profile: presentationProfile, maximumStatements: 8)
        return GroupBox("Screen Summary") {
            Text(text)
                .font(.caption)
                .frame(maxWidth: .infinity, alignment: .leading)
                .textSelection(.enabled)
                .padding(4)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Screen summary")
        .accessibilityValue(text)
        .accessibilityIdentifier("outline.summary")
    }

    private func regionNode(region: NonvisualRegion, nonvisual: NonvisualScreenModel) -> some View {
        let isExpanded = expandedRegions.contains(region.id)
        let elements = filteredElements(for: region, in: nonvisual)

        return VStack(alignment: .leading, spacing: 6) {
            Button {
                if isExpanded {
                    expandedRegions.remove(region.id)
                } else {
                    expandedRegions.insert(region.id)
                }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                        .font(.caption.bold())
                        .foregroundStyle(.secondary)
                        .frame(width: 14)
                    Image(systemName: "rectangle.3.group")
                        .foregroundStyle(ViewLensTheme.brand)
                    Text(region.label)
                        .fontWeight(.semibold)
                    if let role = region.role {
                        Text("(\(role))")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    Spacer()
                    Text("\(elements.count) element\(elements.count == 1 ? "" : "s")")
                        .font(.caption2).foregroundStyle(.secondary)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .padding(.vertical, 4)
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Region: \(region.label), \(elements.count) elements. \(isExpanded ? "Expanded" : "Collapsed")")
            .accessibilityHint("Double tap to toggle region expansion")
            .accessibilityIdentifier("outline.region.\(region.id.rawValue)")

            if isExpanded {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(elements, id: \.id) { element in
                        elementNode(element: element, nonvisual: nonvisual)
                            .padding(.leading, 20)
                    }
                }
            }
        }
        .padding(8)
        .background(Color.secondary.opacity(0.04), in: RoundedRectangle(cornerRadius: 8))
    }

    @ViewBuilder
    private func elementNode(element: NonvisualElement, nonvisual: NonvisualScreenModel) -> some View {
        let isSelected = model.selectedElementIndex == element.visualIndex
        let findings = findingsFor(element: element)

        VStack(alignment: .leading, spacing: 4) {
            Button {
                model.selectElement(at: element.visualIndex)
            } label: {
                elementRow(element: element, findings: findings, isSelected: isSelected)
            }
            .buttonStyle(.plain)
            .accessibilityElement(children: .combine)
            .accessibilityLabel(elementAccessibilityLabel(element, findings: findings, isSelected: isSelected))
            .accessibilityValue(elementAccessibilityValue(element))
            .accessibilityHint("Double tap to select element and reveal on visual canvas")
            .accessibilityIdentifier("outline.element.\(element.id.rawValue)")
            .accessibilityAddTraits(isSelected ? .isSelected : [])
            .accessibilityAction(named: "Select on Canvas") {
                model.selectElement(at: element.visualIndex)
            }
            .accessibilityAction(named: "Copy Element ID") {
                copyToClipboard(element.id.rawValue)
            }

            if !findings.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(findings) { finding in
                        findingNode(finding: finding, element: element)
                            .padding(.leading, 18)
                    }
                }
            }
        }
    }

    private func elementRow(element: NonvisualElement, findings: [ReviewFinding], isSelected: Bool) -> some View {
        HStack(alignment: .center, spacing: 8) {
            Image(systemName: symbolFor(elementType: element.type))
                .foregroundStyle(element.isInteractive ? ViewLensTheme.brand : .secondary)
                .frame(width: 16)

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(element.visibleLabel ?? element.semantics?.accessibleName ?? element.type.capitalized)
                        .fontWeight(isSelected ? .bold : .medium)
                    if element.isInteractive {
                        Image(systemName: "hand.tap.fill")
                            .font(.caption2)
                            .foregroundStyle(ViewLensTheme.brand)
                    }
                }
                HStack(spacing: 8) {
                    Text(element.type).font(.caption2).foregroundStyle(.secondary)
                    Text("ID: `\(element.id.rawValue)`").font(.caption2.monospaced()).foregroundStyle(.tertiary)
                }
            }

            Spacer()

            if !findings.isEmpty {
                findingCountBadges(findings: findings)
            }
        }
        .padding(8)
        .background(isSelected ? ViewLensTheme.brand.opacity(0.15) : Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 6))
        .overlay {
            if isSelected {
                RoundedRectangle(cornerRadius: 6).stroke(ViewLensTheme.brand, lineWidth: 1.5)
            }
        }
        .contentShape(Rectangle())
    }

    private func findingCountBadges(findings: [ReviewFinding]) -> some View {
        HStack(spacing: 4) {
            let errorCount = findings.filter { $0.issue.severity == .error }.count
            let warningCount = findings.filter { $0.issue.severity == .warning }.count
            if errorCount > 0 {
                Text("\(errorCount)")
                    .font(.caption2.bold())
                    .foregroundStyle(.white)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 2)
                    .background(Color.red, in: Capsule())
            }
            if warningCount > 0 {
                Text("\(warningCount)")
                    .font(.caption2.bold())
                    .foregroundStyle(.white)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 2)
                    .background(Color.orange, in: Capsule())
            }
        }
    }

    private func copyToClipboard(_ string: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(string, forType: .string)
    }

    private func findingNode(finding: ReviewFinding, element: NonvisualElement) -> some View {
        let isSelected = model.selectedFindingID == finding.id

        return Button {
            model.selectIssue(finding.issue)
        } label: {
            HStack(alignment: .top, spacing: 6) {
                Image(systemName: finding.issue.severity == .error ? "exclamationmark.octagon.fill" : "exclamationmark.triangle.fill")
                    .font(.caption)
                    .foregroundStyle(finding.issue.severity == .error ? Color.red : Color.orange)
                    .padding(.top, 2)

                VStack(alignment: .leading, spacing: 2) {
                    Text(finding.issue.displayTitle)
                        .font(.caption.weight(isSelected ? .bold : .medium))
                    Text(finding.issue.description)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                    HStack(spacing: 6) {
                        Text(finding.issue.wcagCriterion ?? "Apple HIG")
                            .font(.caption2.bold())
                            .foregroundStyle(.secondary)
                        Text("ID: `\(finding.id)`")
                            .font(.caption2.monospaced())
                            .foregroundStyle(.tertiary)
                    }
                }
                Spacer()
            }
            .padding(6)
            .background(isSelected ? Color.orange.opacity(0.15) : Color.clear, in: RoundedRectangle(cornerRadius: 4))
            .overlay {
                if isSelected {
                    RoundedRectangle(cornerRadius: 4).stroke(Color.orange, lineWidth: 1)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(finding.issue.severity.rawValue) finding: \(finding.issue.displayTitle), \(finding.issue.wcagCriterion ?? "Apple HIG")")
        .accessibilityValue("Criterion: \(finding.issue.wcagCriterion ?? "Apple HIG"), Finding ID: \(finding.id)")
        .accessibilityHint("Double tap to select finding and inspect remediation")
        .accessibilityIdentifier("outline.finding.\(finding.id)")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .accessibilityAction(named: "Copy Remediation Snippet") {
            if let snippet = finding.issue.remediation?.codeSnippet {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(snippet, forType: .string)
            }
        }
        .accessibilityAction(named: "Copy Finding ID") {
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(finding.id, forType: .string)
        }
    }

    private func spatialRelationshipsNode(relationships: [SpatialRelationship]) -> some View {
        GroupBox("Spatial & Relational Geometry (\(relationships.count))") {
            VStack(alignment: .leading, spacing: 6) {
                ForEach(relationships.prefix(10), id: \.id) { rel in
                    HStack(spacing: 6) {
                        Image(systemName: "arrow.triangle.swap").font(.caption).foregroundStyle(ViewLensTheme.brand)
                        Text(rel.description).font(.caption).foregroundStyle(.secondary)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(4)
        }
        .accessibilityIdentifier("outline.relationships")
    }

    private func semanticMismatchesNode(_ mismatches: [SemanticMismatch]) -> some View {
        GroupBox("Visual and Semantic Mismatches (\(mismatches.count))") {
            VStack(alignment: .leading, spacing: 7) {
                ForEach(mismatches.sorted(by: { $0.id < $1.id }), id: \.id) { mismatch in
                    VStack(alignment: .leading, spacing: 2) {
                        Text("\(mismatch.severity.rawValue.capitalized): \(mismatch.kind.rawValue.replacingOccurrences(of: "_", with: " "))")
                            .font(.caption.weight(.semibold))
                        Text(mismatch.description).font(.caption).foregroundStyle(.secondary)
                        Text("Evidence: \(mismatch.evidence.kind.rawValue), \(mismatch.evidence.source)")
                            .font(.caption2).foregroundStyle(.tertiary)
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel("\(mismatch.severity.rawValue) semantic mismatch: \(mismatch.description)")
                    .accessibilityValue("\(mismatch.evidence.kind.rawValue) evidence from \(mismatch.evidence.source)")
                    .accessibilityIdentifier("outline.mismatch.\(mismatch.id.rawValue)")
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(4)
        }
        .accessibilityIdentifier("outline.mismatches")
    }

    private func navigationNode(_ sequences: [NavigationSequence], elements: [NonvisualElement]) -> some View {
        let elementMap = Dictionary(uniqueKeysWithValues: elements.map { ($0.id, $0) })
        return GroupBox("Navigation and Predicted Screen Reader Traversal") {
            VStack(alignment: .leading, spacing: 8) {
                ForEach(sequences.sorted(by: { $0.id < $1.id }), id: \.id) { sequence in
                    let labels = sequence.elementIDs.map { id in
                        elementMap[id]?.semantics?.accessibleName ?? elementMap[id]?.visibleLabel ?? id.rawValue
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        Text(navigationTitle(sequence.kind)).font(.caption.weight(.semibold))
                        Text(labels.enumerated().map { "\($0.offset + 1). \($0.element)" }.joined(separator: ", "))
                            .font(.caption).foregroundStyle(.secondary)
                        Text(navigationEvidenceText(sequence))
                            .font(.caption2).foregroundStyle(.tertiary)
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel("\(navigationTitle(sequence.kind)): \(labels.joined(separator: ", "))")
                    .accessibilityValue(navigationEvidenceText(sequence))
                    .accessibilityIdentifier("outline.navigation.\(sequence.kind.rawValue)")
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(4)
        }
        .accessibilityIdentifier("outline.navigation")
    }

    private var presentationProfile: NonvisualPresentationProfile {
        switch model.preferences.nonvisualProfile.lowercased() {
        case "braille": .braille
        case "developer", "dev": .developer
        default: .speech
        }
    }

    private func elementAccessibilityLabel(_ element: NonvisualElement, findings: [ReviewFinding], isSelected: Bool) -> String {
        let name = element.semantics?.accessibleName ?? element.visibleLabel ?? "Unnamed element"
        let role = element.semantics?.role ?? element.type
        return "\(name), \(role), \(findings.count) findings\(isSelected ? ", selected" : "")"
    }

    private func elementAccessibilityValue(_ element: NonvisualElement) -> String {
        let semantics = element.semantics
        let value = semantics?.value ?? "no value"
        let states = semantics?.states.isEmpty == false ? semantics?.states.joined(separator: ", ") ?? "" : "no states"
        let actions = semantics?.actions.isEmpty == false ? semantics?.actions.joined(separator: ", ") ?? "" : "no actions"
        let confidence = element.semanticEvidence.confidence.map { ", confidence \(Int($0 * 100)) percent" } ?? ""
        return "Region \(element.regionID?.rawValue ?? "none"). Value \(value). States \(states). Actions \(actions). Evidence \(element.semanticEvidence.kind.rawValue) from \(element.semanticEvidence.source)\(confidence)."
    }

    private func navigationTitle(_ kind: NavigationSequenceKind) -> String {
        switch kind {
        case .readingOrder: "Reading order"
        case .keyboardFocus: "Keyboard focus order"
        case .predictedVoiceOver: "Predicted VoiceOver traversal"
        }
    }

    private func navigationEvidenceText(_ sequence: NavigationSequence) -> String {
        let limitation = sequence.kind == .predictedVoiceOver ? " API-derived prediction; manual VoiceOver verification is required." : ""
        return "\(sequence.evidence.kind.rawValue.capitalized) evidence from \(sequence.evidence.source).\(limitation)"
    }

    private func filteredRegions(nonvisual: NonvisualScreenModel) -> [NonvisualRegion] {
        if searchText.isEmpty && filterSeverity == nil && !onlyInteractive {
            return nonvisual.regions
        }
        return nonvisual.regions.filter { region in
            !filteredElements(for: region, in: nonvisual).isEmpty
        }
    }

    private func filteredElements(for region: NonvisualRegion, in nonvisual: NonvisualScreenModel) -> [NonvisualElement] {
        let regionElements = nonvisual.elements.filter { $0.regionID == region.id }
        return regionElements.filter { element in
            if onlyInteractive && !element.isInteractive { return false }
            let findings = findingsFor(element: element)
            if let filterSeverity, !findings.contains(where: { $0.issue.severity == filterSeverity }) {
                return false
            }
            if !searchText.isEmpty {
                let matchesLabel = (element.visibleLabel?.localizedStandardContains(searchText) ?? false)
                    || (element.semantics?.accessibleName?.localizedStandardContains(searchText) ?? false)
                    || element.type.localizedStandardContains(searchText)
                    || element.id.rawValue.localizedStandardContains(searchText)
                let matchesFindings = findings.contains {
                    $0.issue.displayTitle.localizedStandardContains(searchText)
                        || $0.issue.description.localizedStandardContains(searchText)
                }
                return matchesLabel || matchesFindings
            }
            return true
        }
    }

    private func findingsFor(element: NonvisualElement) -> [ReviewFinding] {
        let findings = model.reviewStore.activeReview?.findings ?? []
        return findings.filter { finding in
            if let idx = finding.issue.elementIndex, idx == element.visualIndex {
                return true
            }
            return element.findingIDs.contains(NonvisualID(finding.id))
        }
    }

    private func symbolFor(elementType: String) -> String {
        switch elementType.lowercased() {
        case "primarybutton", "button": "button.horizontal"
        case "textfield": "character.cursor.ibeam"
        case "toggle", "switch": "switch.2"
        case "navigationbar": "menubar.dock.rectangle"
        case "tabbar": "dock.rectangle"
        default: "square.dashed"
        }
    }
}
