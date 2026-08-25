# ViewLens Nonvisual & Accessible Authoring Guide

Comprehensive guide to using ViewLens with screen readers (VoiceOver, refreshable braille displays), coding agents (MCP, CLI), and deterministic accessibility auditing.

---

## 1. Overview

ViewLens provides complete nonvisual accessibility inspection and design verification without requiring sighted assistance or screenshot interpretation.

Key pillars:
- **Zero-Visual Dependency**: All overlays, charts, and heatmaps have textual equivalents and structured nonvisual outlines.
- **Evidence Provenance**: Every finding and measurement clearly separates *measured* facts from *derived* calculations, *inferred* heuristics, or *unavailable* data.
- **Durable Identity**: Stable element, region, and finding IDs (`NonvisualID`) allow seamless cross-referencing between Mac UI, CLI, MCP agent workflows, and exported `.viewlensreport` bundles.
- **Deterministic Remediation**: Provides exact SwiftUI/UIKit modifier recommendations and automated Swift Testing (`@Test`) regression assertions.

---

## 2. Keyboard & VoiceOver Shortcuts (macOS)

| Command | Keybinding | Purpose |
|---|---|---|
| **Workbench Canvas** | `⌘1` | Switches to visual matrix canvas |
| **Nonvisual Outline** | `⌘2` | Switches to text-first accessibility outline |
| **Split Mode** | `⌘3` | Displays canvas and nonvisual outline side-by-side |
| **Toggle Overlays** | `⌥⌘O` | Toggles visual bounding boxes and highlights |
| **Toggle Labels** | `⌥⌘L` | Toggles element type/name labels |
| **Toggle Safe Areas** | `⌥⌘S` | Toggles safe area boundary guides |
| **Toggle Inspector** | `⌥⌘I` | Shows or hides the right detail inspector |
| **Next Element** | `⌘]` | Traverses forward to the next screen element |
| **Previous Element** | `⌘[` | Traverses backward to the previous screen element |
| **Next Finding** | `⇧⌘]` | Navigates to the next failing accessibility issue |
| **Previous Finding** | `⇧⌘[` | Navigates to the previous failing accessibility issue |
| **Copy Remediation** | `⌥⌘C` | Copies SwiftUI fix snippet for the selected issue |

---

## 3. CLI Nonvisual Workflows

Run audits directly from Terminal with structured, accessible outputs:

### A. Screen Summary
```bash
viewlens audit --template LoginForm --nonvisual-summary
```

### B. Full Semantic Outline & Traversal Graph
```bash
viewlens audit --template LoginForm --nonvisual-outline
```

### C. Textual Design Diff Between Two States
```bash
viewlens diff baseline.png current.png --textual-diff
```

### D. Output Formats
- `--profile speech`: Concise spoken summaries for screen readers.
- `--profile braille`: Dense, symbol-coded format optimized for 40-cell braille displays.
- `--profile developer`: Complete provenance, stable IDs, and bounding geometry.

---

## 4. MCP Agent & Prompt Integration

AI coding agents using Model Context Protocol (MCP) can interact with ViewLens via:

### Available Resources
- `viewlens://reviews/{reviewId}/nonvisual-summary`: Concise screen breakdown and findings.
- `viewlens://reviews/{reviewId}/semantic-outline`: Complete element tree and rotor candidate index.
- `viewlens://reviews/{reviewId}/navigation`: Traversal order comparison and focus graph.
- `viewlens://reviews/{reviewId}/visual-diff-narrative`: Textual before/after diff narrative.

### Available Prompts
- `viewlens_nonvisual_review`: Structured workflow guiding agents through nonvisual evidence analysis and deterministic remediation generation.

---

## 5. Privacy & Secret Redaction

Under **Settings > Accessibility & Nonvisual**, the **Redact secure input values in nonvisual exports** toggle is available:
- **Default (Off)**: Exports models without redaction modification.
- **Enabled (On)**: Automatically scrubs password fields (`••••••••`) and sensitive credential patterns (`Bearer [REDACTED_SECRET]`, `API Key: [REDACTED_SECRET]`) across persisted reviews, MCP resources, and export bundles.

---

## 6. Manual VoiceOver Verification Plans

ViewLens synthesizes structured manual testing checklists for features requiring physical OS-level verification (custom gestures, rotor categories, Dynamic Type AX5 font scaling). Access them via:
- Mac App: **Export > Manual VoiceOver Verification Plan (.md)**
- Swift API: `ManualVerificationGenerator.generatePlan(from: model)`
