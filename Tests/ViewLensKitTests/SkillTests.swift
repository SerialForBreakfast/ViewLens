import Testing
import Foundation
@testable import ViewLensKit

@Suite("Agent Skill Playbook Export Tests")
struct SkillTests {
    @Test("Generates complete ViewLensSkill markdown containing all tools and workflows")
    func testSkillGeneration() {
        let md = SkillGenerator.generateSkillMarkdown()

        #expect(md.contains("name: viewlens"))
        #expect(md.contains("viewlens_doctor"))
        #expect(md.contains("viewlens_audit_screenshot"))
        #expect(md.contains("viewlens_audit_view"))
        #expect(md.contains("viewlens hook pre-commit"))
        #expect(md.contains("viewlens render"))
        #expect(md.contains("tappableTargetTooSmall"))
        #expect(md.contains("24×24pt AA"))
        #expect(md.contains("44×44pt AAA"))
        #expect(md.contains("AX1/AX3/AX5"))
        #expect(md.contains("WCAG 4.1.2 A"))
        #expect(md.contains("viewlens doctor --json"))
    }
}
