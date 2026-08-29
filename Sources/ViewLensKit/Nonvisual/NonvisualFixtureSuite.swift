import Foundation

/// Deterministic, reproducible nonvisual test fixtures covering critical accessibility defect
/// archetypes for blind-developer verification (NV-0.4).
public enum NonvisualFixtureSuite {
    /// Fixture simulating a modal sheet where focus escapes behind the presentation layer.
    public static func makeModalFocusEscapeFixture() -> NonvisualScreenModel {
        let backgroundBtnId = NonvisualID("bg_button_checkout")
        let modalCloseBtnId = NonvisualID("modal_button_close")
        let modalSheetRegion = NonvisualID("region_modal_sheet")
        let backgroundRegion = NonvisualID("region_background")

        let regions = [
            NonvisualRegion(
                id: backgroundRegion,
                label: "Cart Background",
                role: "group",
                elementIDs: [backgroundBtnId],
                evidence: EvidenceProvenance(kind: .measured, source: "accessibility_tree")
            ),
            NonvisualRegion(
                id: modalSheetRegion,
                label: "Payment Confirmation Modal",
                role: "dialog",
                elementIDs: [modalCloseBtnId],
                evidence: EvidenceProvenance(kind: .measured, source: "accessibility_tree")
            )
        ]

        let elements = [
            NonvisualElement(
                id: backgroundBtnId,
                type: "primaryButton",
                visibleLabel: "Proceed to Checkout",
                regionID: backgroundRegion,
                semantics: NonvisualSemantics(accessibleName: "Proceed to Checkout", role: "button"),
                isInteractive: true,
                visualEvidence: EvidenceProvenance(kind: .measured, source: "view_hierarchy"),
                semanticEvidence: EvidenceProvenance(kind: .measured, source: "accessibility_tree")
            ),
            NonvisualElement(
                id: modalCloseBtnId,
                type: "primaryButton",
                visibleLabel: "Dismiss",
                regionID: modalSheetRegion,
                semantics: NonvisualSemantics(accessibleName: "Dismiss", role: "button"),
                isInteractive: true,
                visualEvidence: EvidenceProvenance(kind: .measured, source: "view_hierarchy"),
                semanticEvidence: EvidenceProvenance(kind: .measured, source: "accessibility_tree")
            )
        ]

        let mismatch = SemanticMismatch(
            id: NonvisualID("mismatch_modal_trap"),
            category: .missingState,
            elementID: backgroundBtnId,
            description: "Background control remains interactive and exposed to VoiceOver while modal dialog is active.",
            citedStandard: "WCAG 2.4.3 / HIG Modal Presentation",
            evidence: EvidenceProvenance(kind: .derived, source: "focus_graph")
        )

        return NonvisualScreenModel(
            id: NonvisualID("fixture_modal_focus_escape"),
            reviewID: "review_nv_modal_01",
            sourceMode: .runtime,
            target: "CheckoutModalView",
            regions: regions,
            elements: elements,
            mismatches: [mismatch],
            readingOrder: [modalCloseBtnId, backgroundBtnId], // Escaped order!
            evidence: EvidenceProvenance(kind: .measured, source: "runtime_capture")
        )
    }

    /// Fixture simulating color-only status encoding (WCAG 1.4.1).
    public static func makeColorOnlyStateFixture() -> NonvisualScreenModel {
        let statusDotId = NonvisualID("status_indicator_dot")
        let regionId = NonvisualID("region_server_health")

        let regions = [
            NonvisualRegion(
                id: regionId,
                label: "Server Health Monitor",
                role: "group",
                elementIDs: [statusDotId]
            )
        ]

        let elements = [
            NonvisualElement(
                id: statusDotId,
                type: "statusIndicator",
                visibleLabel: nil, // Only color!
                regionID: regionId,
                semantics: NonvisualSemantics(accessibleName: nil, role: "image", value: nil),
                isInteractive: false,
                requiresValueOrState: true,
                visualEvidence: EvidenceProvenance(kind: .measured, source: "view_hierarchy"),
                semanticEvidence: EvidenceProvenance(kind: .measured, source: "accessibility_tree")
            )
        ]

        let mismatch = SemanticMismatch(
            id: NonvisualID("mismatch_color_only"),
            category: .missingName,
            elementID: statusDotId,
            description: "Status is conveyed solely by pixel color without programmatic name, text label, or icon shape.",
            citedStandard: "WCAG 1.4.1 Use of Color",
            evidence: EvidenceProvenance(kind: .derived, source: "contrast_evaluator")
        )

        return NonvisualScreenModel(
            id: NonvisualID("fixture_color_only_state"),
            reviewID: "review_nv_color_01",
            sourceMode: .rendered,
            target: "ServerHealthStatusView",
            regions: regions,
            elements: elements,
            mismatches: [mismatch],
            readingOrder: [statusDotId]
        )
    }

    /// Fixture simulating Dynamic Type clipping and text truncation at AX5 (WCAG 1.4.4 / 1.4.10).
    public static func makeAX5ClippingFixture() -> NonvisualScreenModel {
        let titleLabelId = NonvisualID("label_article_title")
        let regionId = NonvisualID("region_article_card")

        let regions = [
            NonvisualRegion(
                id: regionId,
                label: "Article Summary Card",
                role: "group",
                elementIDs: [titleLabelId]
            )
        ]

        let elements = [
            NonvisualElement(
                id: titleLabelId,
                type: "text",
                visibleLabel: "Breaking News: Apple announces major SwiftUI...",
                regionID: regionId,
                semantics: NonvisualSemantics(
                    accessibleName: "Breaking News: Apple announces major SwiftUI accessibility update for developers worldwide",
                    role: "staticText"
                ),
                visualEvidence: EvidenceProvenance(kind: .measured, source: "image_renderer"),
                semanticEvidence: EvidenceProvenance(kind: .measured, source: "accessibility_tree")
            )
        ]

        let mismatch = SemanticMismatch(
            id: NonvisualID("mismatch_ax5_clipping"),
            category: .orderDivergence,
            elementID: titleLabelId,
            description: "Text is truncated by fixed frame at Accessibility 5 scale (AX5), hiding 45% of visible content.",
            citedStandard: "WCAG 1.4.4 Resize Text / WCAG 1.4.10 Reflow",
            evidence: EvidenceProvenance(kind: .derived, source: "dynamic_type_matrix")
        )

        return NonvisualScreenModel(
            id: NonvisualID("fixture_ax5_clipping"),
            reviewID: "review_nv_ax5_01",
            sourceMode: .rendered,
            target: "NewsArticleCardView",
            regions: regions,
            elements: elements,
            mismatches: [mismatch],
            readingOrder: [titleLabelId]
        )
    }

    /// Fixture simulating visible label vs programmatic name mismatch (WCAG 2.5.3).
    public static func makeNameMismatchFixture() -> NonvisualScreenModel {
        let submitBtnId = NonvisualID("btn_submit_order")
        let regionId = NonvisualID("region_checkout_footer")

        let regions = [
            NonvisualRegion(
                id: regionId,
                label: "Checkout Actions",
                role: "group",
                elementIDs: [submitBtnId]
            )
        ]

        let elements = [
            NonvisualElement(
                id: submitBtnId,
                type: "primaryButton",
                visibleLabel: "Place Order Now",
                regionID: regionId,
                semantics: NonvisualSemantics(accessibleName: "Submit", role: "button"),
                isInteractive: true,
                visualEvidence: EvidenceProvenance(kind: .measured, source: "view_hierarchy"),
                semanticEvidence: EvidenceProvenance(kind: .measured, source: "accessibility_tree")
            )
        ]

        let mismatch = SemanticMismatch(
            id: NonvisualID("mismatch_name_label"),
            category: .visibleNameConflict,
            elementID: submitBtnId,
            description: "Spoken/visible text 'Place Order Now' does not match programmatic accessibility label 'Submit'.",
            citedStandard: "WCAG 2.5.3 Label in Name",
            evidence: EvidenceProvenance(kind: .derived, source: "voice_control_validator")
        )

        return NonvisualScreenModel(
            id: NonvisualID("fixture_name_mismatch"),
            reviewID: "review_nv_name_01",
            sourceMode: .rendered,
            target: "CheckoutFooterView",
            regions: regions,
            elements: elements,
            mismatches: [mismatch],
            readingOrder: [submitBtnId]
        )
    }
}
