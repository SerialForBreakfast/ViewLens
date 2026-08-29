# ViewLens Nonvisual & Accessible Authoring Guide

Comprehensive guide to using ViewLens with VoiceOver, refreshable braille displays, coding agents (MCP and CLI), and deterministic accessibility auditing.

---

## 1. Overview

ViewLens provides structured nonvisual accessibility inspection and design-verification workflows without requiring visual screenshot interpretation or sighted assistance. Evidence that ViewLens cannot evaluate is identified explicitly and routed to manual verification.

Key pillars:
- **Zero-Visual Dependency**: All overlays, charts, and heatmaps have textual equivalents and structured nonvisual outlines.
- **Evidence Provenance**: Every finding and measurement clearly separates *measured* facts from *derived* calculations, *inferred* heuristics, or *unavailable* data.
- **Durable Identity**: Stable element, region, and finding IDs (`NonvisualID`) allow seamless cross-referencing between Mac UI, CLI, MCP agent workflows, and exported `.viewlensreport` bundles.
- **Deterministic Remediation**: Provides exact SwiftUI/UIKit modifier recommendations and automated Swift Testing (`@Test`) regression assertions.

### Language and audience terminology

ViewLens uses direct, specific language consistent with current usage by the [National Federation of the Blind](https://nfb.org/), [American Council of the Blind](https://www.acb.org/), [American Foundation for the Blind](https://www.afb.org/blindness-and-low-vision), and [RNIB](https://www.rnib.org.uk/).

- Use **blind person**, **blind people**, or **blind developer** when blindness is the relevant identity or experience. Identity-first language is accepted and commonly preferred in blind-led communities.
- Use **person who is blind** when an individual prefers person-first language or a partner's editorial standard requires it.
- Use **blind and low-vision people** or **blind and low-vision developers** when a statement applies to both audiences. In UK-specific material, **blind and partially sighted people** may be more appropriate.
- Use **screen-reader user**, **VoiceOver user**, **keyboard user**, or **refreshable-braille-display user** when the interaction method—not disability identity—is what matters.
- Use **visual impairment** only when required by a legal, clinical, educational, quoted, or externally named context. Do not use **vision impaired** as the default product label.
- Do not treat blind people, people with low vision, VoiceOver users, screen-reader users, and braille users as interchangeable groups. State which evidence, workflow, or accommodation applies.
- Avoid collective or deficit-oriented wording such as **the blind**, **suffers from blindness**, **afflicted with**, and **differently abled** unless it is part of an official name or a direct quotation.
- Follow each research participant's self-identification in personas, quotations, reports, and study records.

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
