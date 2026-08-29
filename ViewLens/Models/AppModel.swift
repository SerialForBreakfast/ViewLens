import CoreGraphics
import SwiftUI
import ViewLensKit

public struct ScreenshotAuditConfiguration: Equatable, Sendable {
    public var displayScale: Double?
    public var wcagLevel: String
    public var device: DeviceProfile?
    public var minimumConfidence: Double

    public init(displayScale: Double? = nil, wcagLevel: String = "AA", device: DeviceProfile? = nil, minimumConfidence: Double = 0.15) {
        self.displayScale = displayScale
        self.wcagLevel = wcagLevel
        self.device = device
        self.minimumConfidence = min(max(minimumConfidence, 0.05), 0.95)
    }
}

/// Composition root for system health, review lifecycle, canvas, and Playground configuration.
@MainActor
@Observable
public final class AppModel {
    public static let shared = AppModel()

    public let reviewStore: ReviewStore
    public let canvasStore: CanvasStore
    public let healthStore: SystemHealthStore
    public let playgroundStore: PlaygroundStore
    let navigationStore: NavigationStore
    let historyStore: HistoryStore
    let currentStatusStore: CurrentStatusStore
    let preferenceStore: PreferenceStore

    private var reviewTask: Task<Void, Never>?
    private var doctorTask: Task<Void, Never>?

    public convenience init() {
        let environment = ProcessInfo.processInfo.environment
        let isUITesting = environment["VIEWLENS_UI_TESTING"] == "1"
        self.init(
            reviewStore: isUITesting ? ReviewStore() : ReviewStore(repository: FileReviewRepository()),
            canvasStore: CanvasStore(),
            healthStore: SystemHealthStore(),
            playgroundStore: PlaygroundStore(),
            loadsInitialSample: false,
            runsDoctorCheck: !isUITesting
        )
        if isUITesting { loadUITestFixture(kind: environment["VIEWLENS_UI_FIXTURE"] ?? "completed") }
    }

    public init(
        reviewStore: ReviewStore,
        canvasStore: CanvasStore,
        healthStore: SystemHealthStore,
        playgroundStore: PlaygroundStore,
        loadsInitialSample: Bool = true,
        runsDoctorCheck: Bool = true
    ) {
        self.reviewStore = reviewStore
        self.canvasStore = canvasStore
        self.healthStore = healthStore
        self.playgroundStore = playgroundStore
        self.navigationStore = NavigationStore()
        self.historyStore = HistoryStore()
        self.currentStatusStore = CurrentStatusStore()
        self.preferenceStore = PreferenceStore()
        applyAuditPreferenceDefaults()
        self.reviewStore.applyRetention(days: self.preferenceStore.retentionDays)
        if runsDoctorCheck { runDoctorCheck() }
        if loadsInitialSample { loadInitialSample() }
    }

    // MARK: Compatibility accessors while views migrate to focused stores

    public var preferences: PreferenceStore { preferenceStore }

    public var activeActivity: MCPAgentActivity? {
        get { reviewStore.activeActivity }
        set { reviewStore.activeActivity = newValue }
    }

    public var activityHistory: [MCPAgentActivity] { reviewStore.activityHistory }

    public var mcpStatus: String {
        get { healthStore.mcpStatus }
        set { healthStore.mcpStatus = newValue }
    }

    public var doctorReport: DoctorReport? {
        get { healthStore.doctorReport }
        set { healthStore.doctorReport = newValue }
    }

    public var isRunningDoctor: Bool {
        get { healthStore.isRunningDoctor }
        set { healthStore.isRunningDoctor = newValue }
    }

    public var selectedTemplateName: String {
        get { playgroundStore.selectedTemplateName }
        set { playgroundStore.selectedTemplateName = newValue }
    }

    public var selectedDevice: DeviceProfile {
        get { playgroundStore.selectedDevice }
        set { playgroundStore.selectedDevice = newValue }
    }

    public var selectedDynamicType: DynamicTypeSize {
        get { playgroundStore.selectedDynamicType }
        set { playgroundStore.selectedDynamicType = newValue }
    }

    public var selectedColorScheme: ColorScheme {
        get { playgroundStore.selectedColorScheme }
        set { playgroundStore.selectedColorScheme = newValue }
    }

    public var currentImage: CGImage? {
        get { canvasStore.image }
        set { canvasStore.image = newValue }
    }

    public var currentElements: [DetectedElement] {
        get { canvasStore.elements }
        set { canvasStore.elements = newValue }
    }

    public var currentIssues: [ViewLensIssue] {
        get { canvasStore.issues }
        set { canvasStore.replaceIssues(newValue) }
    }

    public var selectedElementIndex: Int? {
        get { canvasStore.selectedElementIndex }
        set { canvasStore.selectedElementIndex = newValue }
    }

    public var selectedFindingID: ReviewFinding.ID? {
        get { canvasStore.selectedFindingID }
        set {
            canvasStore.selectedFindingID = newValue
            reviewStore.selectedFindingID = newValue
            if let newValue, let issue = canvasStore.findings.first(where: { $0.id == newValue })?.issue {
                canvasStore.selectedElementIndex = issue.elementIndex
            }
        }
    }

    public var selectedIssue: ViewLensIssue? {
        get { canvasStore.selectedIssue }
        set {
            canvasStore.selectedIssue = newValue
            reviewStore.selectedFindingID = canvasStore.selectedFindingID
        }
    }

    public func selectIssue(_ issue: ViewLensIssue?) {
        selectedIssue = issue
    }

    public var showOverlays: Bool {
        get { canvasStore.showOverlays }
        set { canvasStore.showOverlays = newValue }
    }

    public var showSafeAreaGuides: Bool {
        get { canvasStore.showSafeAreaGuides }
        set { canvasStore.showSafeAreaGuides = newValue }
    }

    public var showElementLabels: Bool {
        get { canvasStore.showElementLabels }
        set { canvasStore.showElementLabels = newValue }
    }

    public var isRenderingPlayground: Bool {
        reviewStore.activeReview?.status.isRunning == true
    }

    // MARK: System health

    public func runDoctorCheck() {
        doctorTask?.cancel()
        isRunningDoctor = true
        doctorTask = Task { @MainActor [weak self] in
            await Task.yield()
            guard let self, !Task.isCancelled else { return }
            let report = await DoctorEngine.run()
            guard !Task.isCancelled else { return }
            self.doctorReport = report
            self.isRunningDoctor = false
        }
    }

    // MARK: Review orchestration

    public func loadInitialSample() {
        renderPlaygroundTemplate()
    }

    private func loadUITestFixture(kind: String) {
        guard let image = Self.makeUITestImage() else { return }
        let richFixture = kind == "nonvisual"
        let elements = richFixture ? Self.makeNonvisualUITestElements() : [Self.makePrimaryUITestElement()]
        let issues = richFixture ? Self.makeNonvisualUITestIssues() : [Self.makePrimaryUITestIssue(elementIndex: 0)]
        let fixtureDate = Date(timeIntervalSince1970: 1_700_000_000)
        let reviewID = reviewStore.begin(
            source: .template(name: "LoginForm"),
            environment: ReviewEnvironment(deviceID: DeviceProfile.iPhone16Pro.id, deviceName: DeviceProfile.iPhone16Pro.name, dynamicType: "large", appearance: "Light", wcagLevel: "AA", detectorName: "UI Test Fixture"),
            startedAt: fixtureDate
        )
        let report = AuditReport(
            sourceMode: .rendered,
            target: "LoginForm [UI Test Fixture]",
            device: DeviceProfile.iPhone16Pro.name,
            dimensions: AuditDimensions(width: Double(image.width), height: Double(image.height), scale: 2),
            elements: elements,
            issues: issues
        )
        let activity = MCPAgentActivity(
            timestamp: fixtureDate,
            toolName: "viewlens_audit_view",
            argumentsDescription: "template: LoginForm, deterministic fixture",
            duration: 0.25,
            passed: false,
            summary: "\(issues.count) accessibility issue\(issues.count == 1 ? "" : "s") detected",
            previewImage: image,
            auditReport: report,
            reviewID: reviewID
        )
        canvasStore.update(image: image, elements: elements, issues: issues)
        reviewStore.complete(
            reviewID: reviewID,
            image: image,
            elements: elements,
            issues: issues,
            score: ReviewScore(value: 82, evaluatedCriteria: 8, totalCriteria: 8),
            activity: activity,
            nonvisualScreenModel: richFixture ? Self.makeNonvisualUITestModel() : nil,
            finishedAt: fixtureDate.addingTimeInterval(0.25)
        )
        if kind == "running" {
            let runningID = reviewStore.begin(
                source: .template(name: "CheckoutView"),
                environment: ReviewEnvironment(deviceName: DeviceProfile.iPhone16Pro.name, wcagLevel: "AA"),
                startedAt: fixtureDate.addingTimeInterval(10)
            )
            reviewStore.transition(reviewID: runningID, to: .evaluating, message: "Evaluating deterministic fixture")
        } else if richFixture {
            loadUITestComparisonBaseline(currentReviewID: reviewID, date: fixtureDate)
            reviewStore.activeActivity = activity
        }
        healthStore.mcpStatus = "Ready (UI Test)"
        healthStore.doctorReport = DoctorReport(
            status: "ready",
            checks: [DiagnosticCheck(name: "fixture", status: "confirmed", detail: "Deterministic UI test environment")],
            recommendedNextCommand: "viewlens accessibility --template LoginForm"
        )
    }

    private func loadUITestComparisonBaseline(currentReviewID: UUID, date: Date) {
        guard let baselineImage = Self.makeUITestImage(accentOffset: -24) else { return }
        let elements = Self.makeNonvisualUITestElements()
        let issue = ViewLensIssue(
            kind: .clippedElement,
            severity: .warning,
            description: "The help control intersects the trailing screen edge.",
            confidence: 1,
            elementIndex: 2,
            identifier: "FixtureClippedHelp",
            wcagCriterion: "WCAG 1.4.10",
            wcagLevel: "AA"
        )
        let baselineID = reviewStore.begin(
            source: .template(name: "LoginForm Baseline"),
            environment: ReviewEnvironment(deviceID: DeviceProfile.iPhone16Pro.id, deviceName: DeviceProfile.iPhone16Pro.name, dynamicType: "large", appearance: "Light", wcagLevel: "AA", detectorName: "UI Test Fixture"),
            startedAt: date.addingTimeInterval(-60)
        )
        let report = AuditReport(
            sourceMode: .rendered,
            target: "LoginForm Baseline [UI Test Fixture]",
            device: DeviceProfile.iPhone16Pro.name,
            dimensions: AuditDimensions(width: Double(baselineImage.width), height: Double(baselineImage.height), scale: 2),
            elements: elements,
            issues: [issue]
        )
        let activity = MCPAgentActivity(
            timestamp: date.addingTimeInterval(-60),
            toolName: "viewlens_design_diff",
            argumentsDescription: "deterministic comparison baseline",
            duration: 0.2,
            passed: false,
            summary: "Baseline contains one layout finding",
            previewImage: baselineImage,
            auditReport: report,
            reviewID: baselineID
        )
        reviewStore.complete(
            reviewID: baselineID,
            image: baselineImage,
            elements: elements,
            issues: [issue],
            score: ReviewScore(value: 88, evaluatedCriteria: 8, totalCriteria: 8),
            activity: activity,
            nonvisualScreenModel: Self.makeNonvisualUITestBaselineModel(),
            finishedAt: date.addingTimeInterval(-59.8)
        )
        reviewStore.load(reviewID: currentReviewID)
        historyStore.selectedReviewIDs = [currentReviewID, baselineID]
        if let current = reviewStore.activeReview { canvasStore.load(review: current) }
    }

    private static func makePrimaryUITestElement() -> DetectedElement {
        DetectedElement(
            type: "primaryButton",
            confidence: 0.98,
            boundingBox: BoundingBox(x: 0.18, y: 0.68, width: 0.64, height: 0.055)
        )
    }

    private static func makePrimaryUITestIssue(elementIndex: Int) -> ViewLensIssue {
        ViewLensIssue(
            kind: .tappableTargetTooSmall,
            severity: .error,
            description: "The primary action is smaller than the configured target-size policy.",
            confidence: 0.98,
            elementIndex: elementIndex,
            identifier: "FixturePrimaryAction",
            wcagCriterion: "WCAG 2.5.8",
            wcagLevel: "AA",
            remediation: RemediationAdvice(description: "Increase the control's interactive frame.", codeSnippet: ".frame(minWidth: 44, minHeight: 44)")
        )
    }

    private static func makeNonvisualUITestElements() -> [DetectedElement] {
        [
            DetectedElement(type: "navigationBar", confidence: 0.99, boundingBox: BoundingBox(x: 0.08, y: 0.08, width: 0.84, height: 0.08)),
            DetectedElement(type: "textField", confidence: 0.97, boundingBox: BoundingBox(x: 0.12, y: 0.34, width: 0.76, height: 0.08)),
            makePrimaryUITestElement()
        ]
    }

    private static func makeNonvisualUITestIssues() -> [ViewLensIssue] {
        [
            ViewLensIssue(
                kind: .missingAccessibilityLabel,
                severity: .error,
                description: "The email field has no programmatically determinable name.",
                confidence: 1,
                elementIndex: 1,
                identifier: "FixtureMissingEmailName",
                wcagCriterion: "WCAG 4.1.2",
                wcagLevel: "A",
                remediation: RemediationAdvice(description: "Expose the visible Email label.", codeSnippet: ".accessibilityLabel(\"Email\")")
            ),
            makePrimaryUITestIssue(elementIndex: 2)
        ]
    }

    private static func makeNonvisualUITestModel() -> NonvisualScreenModel {
        makeNonvisualUITestModel(isBaseline: false)
    }

    private static func makeNonvisualUITestBaselineModel() -> NonvisualScreenModel {
        makeNonvisualUITestModel(isBaseline: true)
    }

    private static func makeNonvisualUITestModel(isBaseline: Bool) -> NonvisualScreenModel {
        let screenID = NonvisualID(isBaseline ? "screen:login-baseline" : "screen:login-current")
        let regionID = NonvisualID("region:login-form")
        let measuredPixels = EvidenceProvenance(kind: .measured, source: "viewlens.ui_test.pixels")
        let measuredSemantics = EvidenceProvenance(kind: .measured, source: "viewlens.ui_test.accessibility_hierarchy")
        var elements = [
            NonvisualElement(
                id: NonvisualID("element:heading"),
                visualIndex: 0,
                type: "heading",
                visibleLabel: "Welcome Back",
                bounds: BoundingBox(x: 0.08, y: 0.08, width: 0.84, height: 0.08),
                regionID: regionID,
                semantics: NonvisualSemantics(accessibleName: "Welcome Back", role: "heading", isHeading: true),
                visualEvidence: measuredPixels,
                semanticEvidence: measuredSemantics
            ),
            NonvisualElement(
                id: NonvisualID("element:email"),
                visualIndex: 1,
                type: "textField",
                visibleLabel: "Email",
                bounds: BoundingBox(x: 0.12, y: 0.34, width: 0.76, height: 0.08),
                regionID: regionID,
                semantics: NonvisualSemantics(
                    accessibleName: isBaseline ? "Email" : nil,
                    role: "text field",
                    states: ["enabled"],
                    actions: ["focus"]
                ),
                isInteractive: true,
                requiresAction: true,
                visualEvidence: measuredPixels,
                semanticEvidence: measuredSemantics
            ),
            NonvisualElement(
                id: NonvisualID("element:submit"),
                visualIndex: 2,
                type: "primaryButton",
                visibleLabel: "Sign In",
                bounds: BoundingBox(x: 0.18, y: 0.68, width: 0.64, height: 0.055),
                regionID: regionID,
                semantics: isBaseline ? NonvisualSemantics(accessibleName: "Sign In", role: "button", actions: ["activate"]) : nil,
                isInteractive: true,
                requiresAction: true,
                visualEvidence: measuredPixels,
                semanticEvidence: measuredSemantics
            )
        ]
        if !isBaseline {
            elements.append(NonvisualElement(
                id: NonvisualID("element:legacy-action"),
                type: "button",
                regionID: regionID,
                semantics: NonvisualSemantics(accessibleName: "Legacy Sign In", role: "button", actions: ["activate"]),
                isInteractive: true,
                requiresAction: true,
                visualEvidence: measuredPixels,
                semanticEvidence: measuredSemantics
            ))
        }

        let readingIDs = [NonvisualID("element:heading"), NonvisualID("element:email"), NonvisualID("element:submit")]
        let voiceOverIDs = isBaseline
            ? readingIDs
            : [NonvisualID("element:heading"), NonvisualID("element:submit"), NonvisualID("element:email"), NonvisualID("element:legacy-action")]
        let navigation = [
            NavigationSequence(
                id: NonvisualID("navigation:reading"),
                kind: .readingOrder,
                elementIDs: readingIDs,
                evidence: EvidenceProvenance(kind: .measured, source: "viewlens.ui_test.visual_order")
            ),
            NavigationSequence(
                id: NonvisualID("navigation:voiceover"),
                kind: .predictedVoiceOver,
                elementIDs: voiceOverIDs,
                evidence: EvidenceProvenance(
                    kind: .derived,
                    source: "viewlens.ui_test.accessibility_hierarchy",
                    detail: "API-derived prediction; manual VoiceOver verification remains required."
                )
            )
        ]
        let relationships = NonvisualAnalyzer.deriveSpatialRelationships(screenID: screenID, elements: elements)
        let mismatches = NonvisualAnalyzer.detectSemanticMismatches(elements: elements, navigationSequences: navigation)
        return NonvisualScreenModel(
            id: screenID,
            title: isBaseline ? "Login Form Baseline" : "Login Form",
            sourceMode: .runtime,
            regions: [NonvisualRegion(
                id: regionID,
                label: "Authentication form",
                role: "form",
                bounds: BoundingBox(x: 0.06, y: 0.05, width: 0.88, height: 0.76),
                elementIDs: elements.map(\.id),
                evidence: measuredSemantics
            )],
            elements: elements,
            relationships: relationships,
            navigationSequences: navigation,
            mismatches: mismatches
        )
    }

    private static func makeUITestImage(accentOffset: CGFloat = 0) -> CGImage? {
        let width = 390
        let height = 844
        guard let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: width * 4,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return nil }
        context.setFillColor(CGColor(red: 0.95, green: 0.97, blue: 0.99, alpha: 1)); context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        context.setFillColor(CGColor(red: 0.08, green: 0.48, blue: 0.50, alpha: 1)); context.fill(CGRect(x: 70 + accentOffset, y: 220, width: 250, height: 46))
        context.setFillColor(CGColor(gray: 0.22, alpha: 1)); context.fill(CGRect(x: 48, y: 650, width: 294, height: 18))
        context.fill(CGRect(x: 48, y: 610, width: 220, height: 12))
        return context.makeImage()
    }

    public func announceVoiceOverStatus(_ message: String) {
        guard preferenceStore.announcePhaseChanges, let application = NSApp else { return }
        NSAccessibility.post(
            element: application.mainWindow ?? application,
            notification: .announcementRequested,
            userInfo: [
                .announcement: message,
                .priority: NSAccessibilityPriorityLevel.medium.rawValue
            ]
        )
    }

    public func cancelActiveReview() {
        reviewTask?.cancel()
        reviewTask = nil
        guard let reviewID = reviewStore.activeReview?.id else { return }
        reviewStore.cancel(reviewID: reviewID)
        announceVoiceOverStatus("Review cancelled.")
    }

    public func renderPlaygroundTemplate() {
        cancelRunningReviewIfNeeded()

        let templateName = selectedTemplateName
        let devices = DeviceProfile.allPresets.filter { playgroundStore.selectedDeviceIDs.contains($0.id) }
        let dynamicTypeNames = Array(playgroundStore.selectedDynamicTypeNames).sorted()
        let appearanceNames = Array(playgroundStore.selectedAppearanceNames).sorted()
        let permutations = MatrixRenderer.buildPermutations(
            devices: devices.isEmpty ? [selectedDevice] : devices,
            dynamicTypeSizes: dynamicTypeNames.isEmpty ? ["large"] : dynamicTypeNames,
            colorSchemes: appearanceNames.isEmpty ? ["light"] : appearanceNames
        )
        let primary = permutations[0]
        let environment = ReviewEnvironment(
            deviceID: devices.count == 1 ? primary.device.id : nil,
            deviceName: devices.count == 1 ? primary.device.name : "\(Set(permutations.map(\.device.id)).count)-device matrix",
            dynamicType: dynamicTypeNames.joined(separator: ", "),
            appearance: appearanceNames.map(\.capitalized).joined(separator: ", "),
            wcagLevel: playgroundStore.wcagLevel,
            detectorName: doctorReport?.status == "ready" ? "YOLO11n" : nil
        )
        let reviewID = reviewStore.begin(source: .template(name: templateName), environment: environment)
        announceVoiceOverStatus("Starting matrix review for template \(templateName)...")

        guard let view = TemplateRegistry.shared.template(named: templateName) else {
            reviewStore.fail(
                reviewID: reviewID,
                failure: ReviewFailure(
                    title: "Template unavailable",
                    message: "The template \(templateName) is not registered.",
                    recoverySuggestion: "Choose another template in Playground."
                )
            )
            announceVoiceOverStatus("Template \(templateName) is unavailable.")
            return
        }

        reviewStore.transition(reviewID: reviewID, to: .rendering, message: "Rendering \(permutations.count) matrix permutation(s)")
        reviewTask = Task { @MainActor [weak self] in
            guard let self else { return }
            do {
                self.reviewStore.transition(reviewID: reviewID, to: .detecting, message: "Detecting interface elements across the matrix")
                self.announceVoiceOverStatus("Detecting interface elements across the matrix...")
                let detector: YOLODetector?
                if let modelURL = try? ModelLocator.resolve().get() { detector = try? YOLODetector(modelURL: modelURL) } else { detector = nil }
                let matrix = try await MatrixRenderer.auditMatrix(
                    templateName: templateName,
                    view: view,
                    permutations: permutations,
                    detector: detector,
                    minConfidence: Float(self.playgroundStore.minimumConfidence),
                    targetLevel: WCAGConformanceLevel(input: self.playgroundStore.wcagLevel) ?? .aa
                )
                guard !Task.isCancelled, self.reviewStore.activeReview?.id == reviewID else { return }
                self.reviewStore.transition(reviewID: reviewID, to: .evaluating, message: "Evaluating WCAG and Apple HIG rules")
                self.announceVoiceOverStatus("Evaluating WCAG and Apple HIG rules...")
                let representativeKey = matrix.summary.failedPermutations.first ?? primary.key
                let representative = matrix.permutations[representativeKey] ?? matrix.permutations.values.first
                let representativePermutation = permutations.first { $0.key == representativeKey } ?? primary
                guard let report = representative,
                      let image = InProcessCanvasRenderer.render(
                        profile: representativePermutation.device,
                        dynamicTypeSize: representativePermutation.dynamicTypeSize,
                        colorScheme: representativePermutation.colorScheme,
                        content: { view }
                      ) else { throw CocoaError(.fileReadUnknown) }
                self.reviewStore.transition(reviewID: reviewID, to: .reviewing, message: "Preparing matrix findings and remediation")
                let score = ReviewScore(
                    issues: matrix.permutations.values.flatMap(\.issues),
                    evaluatedCriteria: matrix.summary.totalPermutations * 8,
                    totalCriteria: matrix.summary.totalPermutations * 8
                )
                let activity = MCPAgentActivity(
                    toolName: "viewlens_audit_view",
                    argumentsDescription: "template: \(templateName), \(matrix.summary.totalPermutations) permutations",
                    duration: self.reviewStore.activeReview.map { Date().timeIntervalSince($0.startedAt) } ?? 0,
                    passed: matrix.passed,
                    summary: matrix.passed ? "All \(matrix.summary.totalPermutations) permutations passed" : "\(matrix.summary.failedCount) of \(matrix.summary.totalPermutations) permutations have findings",
                    previewImage: image,
                    auditReport: report,
                    reviewID: reviewID
                )
                self.canvasStore.update(image: image, elements: report.elements, issues: report.issues)
                self.reviewStore.complete(reviewID: reviewID, image: image, elements: report.elements, issues: report.issues, score: score, activity: activity)
                self.applyAssetRetentionPolicy()
                self.reviewTask = nil

                let errorFindings = report.issues.filter { $0.severity == .error }.count
                if errorFindings > 0 {
                    self.announceVoiceOverStatus("Matrix review complete with \(errorFindings) critical finding\(errorFindings == 1 ? "" : "s"). Score \(score.value) out of 100.")
                } else {
                    self.announceVoiceOverStatus("Matrix review complete: all permutations passed. Score \(score.value) out of 100.")
                }
            } catch {
                self.reviewStore.fail(reviewID: reviewID, failure: ReviewFailure(
                    title: "Matrix audit failed",
                    message: error.localizedDescription,
                    recoverySuggestion: "Reduce the matrix or verify the selected template."
                ))
                self.announceVoiceOverStatus("Matrix audit failed: \(error.localizedDescription)")
                self.reviewTask = nil
            }
        }
    }

    public func auditDroppedImage(url: URL) {
        auditDroppedImage(url: url, configuration: ScreenshotAuditConfiguration(
            wcagLevel: preferenceStore.wcagLevel,
            minimumConfidence: preferenceStore.detectorConfidence
        ))
    }

    public func auditDroppedImage(url: URL, configuration: ScreenshotAuditConfiguration) {
        cancelRunningReviewIfNeeded()

        let environment = ReviewEnvironment(
            deviceID: configuration.device?.id,
            deviceName: configuration.device?.name,
            wcagLevel: configuration.wcagLevel,
            detectorName: doctorReport?.status == "ready" ? "YOLO11n" : nil
        )
        let reviewID = reviewStore.begin(source: .image(url: url), environment: environment)
        announceVoiceOverStatus("Starting image review for \(url.lastPathComponent)...")

        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
              let image = CGImageSourceCreateImageAtIndex(source, 0, nil) else {
            reviewStore.fail(
                reviewID: reviewID,
                failure: ReviewFailure(
                    title: "Image unavailable",
                    message: "ViewLens could not read \(url.lastPathComponent).",
                    recoverySuggestion: "Choose a PNG, JPEG, or HEIC image that can be opened on this Mac."
                )
            )
            announceVoiceOverStatus("Image unavailable: ViewLens could not read \(url.lastPathComponent).")
            return
        }

        let imageSize = CGSize(width: image.width, height: image.height)
        let scale = configuration.displayScale ?? configuration.device?.scale ?? IssueClassifier.inferDisplayScale(imageWidth: Double(image.width))
        reviewStore.transition(reviewID: reviewID, to: .detecting, message: "Detecting elements in \(url.lastPathComponent)")

        reviewTask = Task { @MainActor [weak self] in
            guard let self else { return }
            self.announceVoiceOverStatus("Detecting elements in \(url.lastPathComponent)...")
            let elements = await self.detectElements(in: image, minimumConfidence: Float(configuration.minimumConfidence))
            guard !Task.isCancelled, self.reviewStore.activeReview?.id == reviewID else { return }

            self.reviewStore.transition(reviewID: reviewID, to: .evaluating, message: "Evaluating screenshot-detectable criteria")
            self.announceVoiceOverStatus("Evaluating screenshot-detectable criteria...")
            let issues = IssueClassifier.classify(
                elements: elements,
                imageSize: imageSize,
                scale: scale,
                image: image,
                targetLevel: WCAGConformanceLevel(input: configuration.wcagLevel) ?? .aa
            )
            guard !Task.isCancelled else { return }

            self.reviewStore.transition(reviewID: reviewID, to: .reviewing, message: "Preparing findings and coverage limitations")
            let report = AuditReport(
                sourceMode: .screenshot,
                image: url.lastPathComponent,
                dimensions: AuditDimensions(width: Double(image.width), height: Double(image.height), scale: scale),
                elements: elements,
                issues: issues
            )
            // Static screenshots cannot expose a complete programmatic accessibility tree.
            let score = ReviewScore(issues: issues, evaluatedCriteria: 4, totalCriteria: 8)
            let activity = MCPAgentActivity(
                toolName: "viewlens_audit_screenshot",
                argumentsDescription: "file: \(url.lastPathComponent)",
                duration: self.reviewStore.activeReview.map { Date().timeIntervalSince($0.startedAt) } ?? 0,
                passed: report.passed && score.isComplete,
                summary: issues.isEmpty ? "No visual issues; semantic checks not evaluated" : "\(issues.count) visual issue(s) detected",
                previewImage: image,
                auditReport: report,
                reviewID: reviewID
            )

            self.canvasStore.update(image: image, elements: elements, issues: issues)
            self.reviewStore.complete(reviewID: reviewID, image: image, elements: elements, issues: issues, score: score, activity: activity)
            self.applyAssetRetentionPolicy()
            self.reviewTask = nil

            let errorCount = issues.filter { $0.severity == .error }.count
            if errorCount > 0 {
                self.announceVoiceOverStatus("Image audit complete with \(errorCount) critical finding\(errorCount == 1 ? "" : "s"). Score \(score.value) out of 100.")
            } else {
                self.announceVoiceOverStatus("Image audit complete with \(issues.count) finding\(issues.count == 1 ? "" : "s"). Score \(score.value) out of 100.")
            }
        }
    }

    public func openActivity(_ activity: MCPAgentActivity) {
        if let reviewID = activity.reviewID {
            reviewStore.load(reviewID: reviewID)
            if let review = reviewStore.activeReview {
                canvasStore.load(review: review)
                reviewStore.activeActivity = activity
                return
            }
        }

        reviewStore.activeActivity = activity
        if let image = activity.previewImage, let report = activity.auditReport {
            canvasStore.update(image: image, elements: report.elements, issues: report.issues)
        }
    }

    public func openReview(reviewID: UUID) {
        reviewStore.load(reviewID: reviewID)
        guard let review = reviewStore.activeReview else { return }
        canvasStore.load(review: review)
        reviewStore.activeActivity = reviewStore.activityHistory.first { $0.reviewID == reviewID }
    }

    public func rerunReview(_ review: ReviewRecord) {
        switch review.source {
        case .template(let name):
            selectedTemplateName = name
            playgroundStore.mode = .template
            renderPlaygroundTemplate()
        case .image(let url):
            guard FileManager.default.fileExists(atPath: url.path) else {
                reviewStore.markStale(reviewID: review.id, reason: "The original screenshot is no longer available at \(url.path).")
                openReview(reviewID: review.id)
                return
            }
            auditDroppedImage(url: url, configuration: ScreenshotAuditConfiguration(
                wcagLevel: review.environment.wcagLevel,
                device: review.environment.deviceID.flatMap(DeviceProfile.named),
                minimumConfidence: preferenceStore.detectorConfidence
            ))
        }
    }

    public func applyRetentionPolicy() {
        reviewStore.applyRetention(days: preferenceStore.retentionDays)
    }

    public func applyAssetRetentionPolicy() {
        switch preferenceStore.assetRetention {
        case "Do not retain": reviewStore.applyAssetRetention(days: nil)
        case "30 days": reviewStore.applyAssetRetention(days: 30)
        default: break
        }
    }

    public func applyAuditPreferenceDefaults() {
        playgroundStore.wcagLevel = preferenceStore.wcagLevel
        playgroundStore.minimumConfidence = min(max(preferenceStore.detectorConfidence, 0.05), 0.95)
        switch preferenceStore.requiredMatrix {
        case "Expanded":
            playgroundStore.selectedDeviceIDs = [DeviceProfile.iPhoneSE.id, DeviceProfile.iPhone16Pro.id]
            playgroundStore.selectedDynamicTypeNames = ["large", "accessibility3"]
            playgroundStore.selectedAppearanceNames = ["light", "dark"]
        case "Exhaustive":
            playgroundStore.selectedDeviceIDs = Set(DeviceProfile.allPresets.map(\.id))
            playgroundStore.selectedDynamicTypeNames = ["large", "accessibility1", "accessibility3", "accessibility5"]
            playgroundStore.selectedAppearanceNames = ["light", "dark"]
        default:
            playgroundStore.selectedDeviceIDs = [DeviceProfile.iPhone16Pro.id]
            playgroundStore.selectedDynamicTypeNames = ["large"]
            playgroundStore.selectedAppearanceNames = ["light"]
        }
    }

    public func selectFinding(_ finding: ReviewFinding?) {
        reviewStore.selectedFindingID = finding?.id
        canvasStore.selectedFindingID = finding?.id
        canvasStore.selectedElementIndex = finding?.issue.elementIndex
    }

    public func selectElement(at index: Int?) {
        canvasStore.selectedElementIndex = index
        let finding = index.flatMap { elementIndex in
            canvasStore.findings.first { $0.issue.elementIndex == elementIndex }
        }
        canvasStore.selectedFindingID = finding?.id
        reviewStore.selectedFindingID = finding?.id
    }

    public func moveElementSelection(by offset: Int) {
        guard !canvasStore.elements.isEmpty else { return }
        let current = canvasStore.selectedElementIndex ?? (offset > 0 ? -1 : canvasStore.elements.count)
        let next = min(max(current + offset, 0), canvasStore.elements.count - 1)
        selectElement(at: next)
    }

    public func moveFindingSelection(by offset: Int) {
        let findings = canvasStore.findings
        guard !findings.isEmpty else { return }
        let currentIndex = findings.firstIndex { $0.id == reviewStore.selectedFindingID } ?? (offset > 0 ? -1 : findings.count)
        let nextIndex = min(max(currentIndex + offset, 0), findings.count - 1)
        selectFinding(findings[nextIndex])
    }

    public func copySelectedRemediation() {
        guard let findingID = reviewStore.selectedFindingID,
              let finding = canvasStore.findings.first(where: { $0.id == findingID }),
              let snippet = finding.issue.remediation?.codeSnippet else { return }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(snippet, forType: .string)
    }

    private func cancelRunningReviewIfNeeded() {
        guard reviewStore.activeReview?.status.isRunning == true else { return }
        cancelActiveReview()
    }

    private func detectElements(in image: CGImage, minimumConfidence: Float) async -> [DetectedElement] {
        guard let modelURL = try? ModelLocator.resolve().get(),
              let detector = try? YOLODetector(modelURL: modelURL) else { return [] }
        return (try? await detector.detect(image: image, minConfidence: minimumConfidence)) ?? []
    }

    private func fallbackElements(for templateName: String, device: DeviceProfile, image: CGImage) -> [DetectedElement] {
        let lowercasedName = templateName.lowercased()

        if lowercasedName.contains("buttonbug") {
            let box = BoundingBox(x: 0.1, y: 0.5, width: 0.8, height: (24 * device.scale) / Double(image.height))
            return [DetectedElement(type: "primaryButton", confidence: 0.96, boundingBox: box)]
        }
        if lowercasedName.contains("clipped") {
            let box = BoundingBox(x: 0, y: 0.5, width: 1, height: (44 * device.scale) / Double(image.height))
            return [DetectedElement(type: "primaryButton", confidence: 0.95, boundingBox: box)]
        }
        if lowercasedName.contains("overlap") {
            return [
                DetectedElement(type: "primaryButton", confidence: 0.95, boundingBox: BoundingBox(x: 0.2, y: 0.45, width: 0.6, height: 0.1)),
                DetectedElement(type: "primaryButton", confidence: 0.92, boundingBox: BoundingBox(x: 0.25, y: 0.48, width: 0.5, height: 0.08))
            ]
        }
        if lowercasedName.contains("login") {
            let pointWidth = Double(device.pointWidth)
            let pointHeight = Double(device.pointHeight)
            let buttonHeight = 50.0
            let buttonY = (pointHeight - (Double(device.safeAreaInsets.bottom) + 20 + buttonHeight)) / pointHeight
            let button = BoundingBox(
                x: 20 / pointWidth,
                y: buttonY,
                width: (pointWidth - 40) / pointWidth,
                height: buttonHeight / pointHeight
            )
            let navigation = BoundingBox(
                x: 0,
                y: Double(device.safeAreaInsets.top) / pointHeight,
                width: 1,
                height: 44 / pointHeight
            )
            return [
                DetectedElement(type: "navigationBar", confidence: 0.98, boundingBox: navigation),
                DetectedElement(type: "primaryButton", confidence: 0.95, boundingBox: button)
            ]
        }
        return []
    }
}
