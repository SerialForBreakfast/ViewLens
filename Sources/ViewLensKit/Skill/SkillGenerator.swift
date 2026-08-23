import Foundation

/// Generates the official ViewLens Agent Skill Playbook (`ViewLensSkill.md` / `SKILL.md`)
/// for AI agents (Claude Code, Cursor, Windsurf, Copilot, Antigravity).
public struct SkillGenerator: Sendable {
    public static func generateSkillMarkdown() -> String {
        return """
        ---
        name: viewlens
        description: Visual UI layout auditor, Apple HIG compliance validator, and multi-device matrix linter for SwiftUI and UIKit. Performs token-free CoreML element detection, touch target measurement, Dynamic Type reflow checking, and automated pre-commit / PR quality gating.
        ---

        # ViewLens — Agent Skill Playbook & Tool Reference

        **ViewLens** is an Apple UI visual layout auditor, Human Interface Guidelines (HIG) compliance validator, and headless matrix rendering engine for native iOS and macOS applications.

        It provides AI agents with deep visual layout intelligence **without bloating the agent's LLM context window with raw image tokens**.

        ---

        ## 1. Core Architecture & Mental Model

        ```mermaid
        flowchart LR
            Agent["🤖 AI Agent (Claude Code / Cursor)"]
            MCP["⚡ ViewLens Pure Swift MCP Server"]
            Vision["🧠 CoreML YOLO11n (Apple Neural Engine)"]
            Canvas["📐 In-Process Virtual Canvas (ImageRenderer)"]
            HIG["📏 Apple HIG Deterministic Rules Engine"]
            Gate["🛡️ Git Hook & CI Quality Gate"]

            Agent -->|stdio JSON-RPC| MCP
            MCP --> Canvas
            MCP --> Vision
            MCP --> HIG
            MCP --> Gate
        ```

        ### Detection Capabilities:
        - `navigationBar`
        - `primaryButton`
        - `tabBar`
        - `textField`
        - `toggle`

        ### Deterministic HIG & Layout Rules:
        - `tappableTargetTooSmall`: Interactive elements with touch area $< 44 \\times 44\\text{pt}$ (Apple HIG requirement).
        - `clippedElement`: Controls placed $< 3\\text{pt}$ from viewport/safe-area borders without margins.
        - `overlappingElements`: Elements colliding with $\\text{IoU} > 0.30$.
        - `offScreen`: Elements positioned $> 50\\%$ outside the visible viewport.
        - `ambiguousAutoLayout`: Under-constrained UIKit view hierarchies.
        - `missingAccessibilityLabel`: Missing accessibility identifiers.

        ---

        ## 2. Pure Swift MCP Tools Reference

        ViewLens exposes 3 standard JSON-RPC tools over `stdio`:

        ### 1. `viewlens_doctor`
        Probes environment, Apple Neural Engine readiness, and CoreML model status.
        - **Arguments**: `{}`
        - **When to use**: Call once at session start to verify detector availability.

        ### 2. `viewlens_audit_screenshot`
        Audits static image files (simulator screenshots, test artifacts, mocks).
        - **Arguments**:
          - `image_path` (string, required): Absolute or relative path to PNG/JPEG image.
          - `scale` (number, optional): Explicit display scale (@2x, @3x). Automatically inferred if omitted.
          - `min_confidence` (number, optional): Minimum detection confidence (default `0.25`).
        - **Response Mode**: `sourceMode: "screenshot"`

        ### 3. `viewlens_audit_view`
        Renders a SwiftUI view template across a multi-device matrix entirely in-memory in $<0.5\\text{s}$.
        - **Arguments**:
          - `template` (string, required): Registered SwiftUI template name (e.g. `LoginForm`, `ProfileCard`, `SettingsList`).
          - `devices` (array of strings, optional): `["iPhoneSE", "iPhone16Pro", "iPadPro11"]`.
          - `dynamic_type_sizes` (array of strings, optional): `["large", "accessibility3", "accessibility5"]`.
          - `color_schemes` (array of strings, optional): `["light", "dark"]`.
        - **Response Mode**: `sourceMode: "rendered"` with synthesized worst-case issue matrix.

        ---

        ## 3. CLI Command Suite Reference

        When executing commands in the terminal, use the `viewlens` CLI binary:

        | Command | Purpose | Example |
        |---|---|---|
        | `viewlens doctor` | Model readiness and system check | `viewlens doctor --format json` |
        | `viewlens scan <image>` | Single/multi-image screenshot audit | `viewlens scan ./screenshot.png --strict` |
        | `viewlens batch <dir>` | Recursive folder screenshot audit | `viewlens batch ./DerivedData/Screenshots` |
        | `viewlens render` | Headless multi-device template matrix audit | `viewlens render --template LoginForm --devices iPhoneSE,iPhone16Pro` |
        | `viewlens tui` | Interactive terminal UI / headless ASCII dashboard | `viewlens tui --headless --template LoginForm` |
        | `viewlens hook <gate>` | Executes Git Hook or CI Quality Gate | `viewlens hook pre-commit --fail-on error` |
        | `viewlens install-hook` | Installs `.git/hooks/pre-commit` | `viewlens install-hook --type pre-commit` |
        | `viewlens init-config` | Generates `.viewlens.json` configuration | `viewlens init-config` |
        | `viewlens export-skill` | Exports this AI Agent Skill Playbook | `viewlens export-skill --output ViewLensSkill.md` |
        | `viewlens mcp` | Starts the native Swift MCP stdio server | `viewlens mcp` |

        ---

        ## 4. Agentic Workflow: Auditing & Fixing SwiftUI Code

        When asked to audit or improve a SwiftUI view, follow this loop:

        1. **Render Matrix**: Audit the view across devices and Dynamic Type sizes:
           ```bash
           viewlens render --template <ViewName> --devices iPhoneSE,iPhone16Pro --dt large,accessibility3
           ```
        2. **Analyze Issues**:
           - If `tappableTargetTooSmall` is detected on a button:
             ```swift
             // Fix: Add 44pt minimum touch target
             Button("Submit") { ... }
                 .frame(minWidth: 44, minHeight: 44)
                 .contentShape(Rectangle())
             ```
           - If `clippedElement` or Dynamic Type truncation occurs:
             ```swift
             // Fix: Use flexible layout containers with scroll fallbacks
             ViewThatFits(in: .vertical) {
                 VStack { ... }
                 ScrollView { VStack { ... } }
             }
             ```
        3. **Re-Verify Quality Gate**:
           ```bash
           viewlens hook pre-commit --template <ViewName> --fail-on error
           ```
           Ensure exit code is `0` before presenting the final code to the user.

        ---

        ## 5. Declarative Quality Gate Policy (`.viewlens.json`)

        ```json
        {
          "version": 1,
          "gates": {
            "pre-commit": {
              "failOn": "error",
              "purposes": ["touch_targets", "clipping", "accessibility"],
              "devices": ["iPhoneSE", "iPhone16Pro"],
              "dynamicTypeSizes": ["large", "accessibility3"],
              "colorSchemes": ["light", "dark"],
              "autoDetectStagedViews": true
            },
            "pull-request": {
              "failOn": "warning",
              "purposes": ["touch_targets", "clipping", "accessibility", "autolayout"],
              "devices": ["iPhoneSE", "iPhone16Pro", "iPadPro11"],
              "dynamicTypeSizes": ["large", "accessibility3"],
              "colorSchemes": ["light", "dark"],
              "outputMarkdown": "reports/viewlens_pr_summary.md",
              "strict": true
            }
          }
        }
        ```
        """
    }
}
