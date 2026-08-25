import Testing
import Foundation
@testable import ViewLensKit

@Suite("Nonvisual MCP Prompt Tests (NV-3.2)")
struct NonvisualPromptTests {

    @Test("viewlens_nonvisual_review prompt is registered in MCPPromptRegistry")
    func testNonvisualPromptRegistration() {
        let prompts = MCPPromptRegistry.prompts
        let nonvisual = prompts.first { $0.name == "viewlens_nonvisual_review" }

        #expect(nonvisual != nil)
        #expect(nonvisual?.title == "Run Nonvisual Semantic Review")
        #expect(nonvisual?.arguments.contains(where: { $0.name == "template" }) == true)
        #expect(nonvisual?.arguments.contains(where: { $0.name == "image_path" }) == true)
        #expect(nonvisual?.arguments.contains(where: { $0.name == "profile" }) == true)
        #expect(nonvisual?.arguments.contains(where: { $0.name == "wcag_level" }) == true)
    }

    @Test("viewlens_nonvisual_review prompt resolves with valid inputs")
    func testNonvisualPromptResolution() throws {
        let result = try MCPPromptRegistry.resolve(
            name: "viewlens_nonvisual_review",
            arguments: [
                "template": JSONValue.string("LoginForm"),
                "profile": JSONValue.string("braille"),
                "wcag_level": JSONValue.string("AAA")
            ]
        )

        #expect(result.messages.count >= 1)
        let text = result.messages[0].content.text ?? ""
        #expect(text.contains("LoginForm"))
        #expect(text.contains("braille"))
        #expect(text.contains("AAA"))
        #expect(text.contains("viewlens_accessibility_audit"))
        #expect(text.contains("semantic-outline"))
    }
}
