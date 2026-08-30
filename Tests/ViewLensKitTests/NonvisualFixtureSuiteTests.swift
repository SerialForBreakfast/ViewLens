import Foundation
import Testing
@testable import ViewLensKit

@Suite("Nonvisual Fixture Suite Tests (NV-0.4)")
struct NonvisualFixtureSuiteTests {
    @Test("Modal focus escape fixture captures focus trap and background escape mismatch")
    func modalFocusEscapeFixture() {
        let fixture = NonvisualFixtureSuite.makeModalFocusEscapeFixture()

        #expect(fixture.title == "CheckoutModalView")
        #expect(fixture.regions.count == 2)
        #expect(fixture.mismatches.count == 1)
        #expect(fixture.mismatches[0].kind == .missingValueOrState)
        #expect(fixture.mismatches[0].description.contains("WCAG 2.4.3"))
        #expect(fixture.navigationSequences.first?.elementIDs.count == 2)
    }

    @Test("Color-only state fixture detects WCAG 1.4.1 defect")
    func colorOnlyFixture() {
        let fixture = NonvisualFixtureSuite.makeColorOnlyStateFixture()

        #expect(fixture.title == "ServerHealthStatusView")
        #expect(fixture.mismatches.count == 1)
        #expect(fixture.mismatches[0].kind == .missingAccessibleName)
        #expect(fixture.mismatches[0].description.contains("WCAG 1.4.1"))
    }

    @Test("AX5 clipping fixture detects WCAG 1.4.4 / 1.4.10 defect")
    func ax5ClippingFixture() {
        let fixture = NonvisualFixtureSuite.makeAX5ClippingFixture()

        #expect(fixture.title == "NewsArticleCardView")
        #expect(fixture.mismatches.count == 1)
        #expect(fixture.mismatches[0].kind == .readingOrderDivergence)
        #expect(fixture.mismatches[0].description.contains("WCAG 1.4.4"))
    }

    @Test("Name mismatch fixture detects WCAG 2.5.3 defect")
    func nameMismatchFixture() {
        let fixture = NonvisualFixtureSuite.makeNameMismatchFixture()

        #expect(fixture.title == "CheckoutFooterView")
        #expect(fixture.mismatches.count == 1)
        #expect(fixture.mismatches[0].kind == .visibleLabelNameConflict)
        #expect(fixture.mismatches[0].description.contains("WCAG 2.5.3"))
    }
}
