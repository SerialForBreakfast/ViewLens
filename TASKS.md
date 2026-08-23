# ViewLens — Implementation Tasks & Work Breakdown

This document provides the master task breakdown, milestone roadmap, user stories, acceptance criteria, test specifications, and architectural considerations for the **ViewLens** project.

---

## Roadmap & Milestones Summary

| Milestone | Target | Description | Status |
|---|---|---|---|
| **M0: Foundation & Packaging** | Week 1 | SPM Package structure, model discovery, shared types & coordinate contracts | ⏳ Ready |
| **M1: Detection CLI + MCP Server MVP** | Week 1–2 | `ViewLensKit` inference engine, `viewlens` CLI (`doctor`, `scan`, `batch`), Python MCP server, `.agents/skills` playbook | ⏳ Ready |
| **M2: SwiftUI Rendering Bridge** | Week 3 | `GeneratorRunner` IPC bridge, `viewlens render` CLI, `viewlens_audit_swiftui_view` MCP matrix tool | 📋 Planned |
| **M3: macOS Desktop Visual Inspector** | Week 4 | SwiftUI macOS Canvas App, live screen/window capture audit, visual bounding box inspector, embedded daemon control | 📋 Planned |

---

## Open Architectural Considerations & Questions

Before initiating implementation, the following key architectural and configuration questions should be reviewed:

1. **SPM vs Xcode Project Topology**:
   - *Current Setup*: An initial `ViewLens.xcodeproj` exists.
   - *Proposal*: Establish a root `Package.swift` as the single source of truth for `ViewLensKit` (library) and `viewlens` (executable CLI). The `ViewLens.xcodeproj` macOS App will consume `ViewLensKit` as a local package dependency.
   - *Question*: Is this SPM-first root structure preferred, or should Xcode Project schemes be maintained in lockstep?
2. **Model Distribution & Resolution**:
   - *Strategy*: Support dynamic discovery via:
     1. `--model <path>` argument
     2. `VIEWLENS_MODEL_PATH` or `NATIVEUI_MODEL_PATH` environment variables
     3. Sibling lookup: `../NativeUIAuditKit/models/best.mlpackage`
     4. Default cache: `~/Library/Application Support/ViewLens/models/best.mlpackage`
   - *Question*: Should we provide a `viewlens model download` or `scripts/download_model.sh` utility to pull pre-compiled CoreML models from GitHub Releases of `NativeUIAuditKit`?
3. **Binary & MCP Naming Aliases**:
   - *Naming*: Primary binary is `viewlens`. Should we generate a symlink or alias for `nativeui-audit` for backwards compatibility with earlier documentation and scripts?
   - *MCP Tools*: Prefix tools with `viewlens_` (`viewlens_doctor`, `viewlens_audit_screenshot`, `viewlens_audit_swiftui_view`) to prevent collision with other UI auditing MCP servers.
4. **Overlay Output Rendering**:
   - *Capabilities*: Should `--overlay <output.png>` support color-coded status (e.g. Green = HIG Compliant Element, Red = Element with Issue, Yellow = Warning / Confidence < 0.5)?
   - *Implementation*: CoreGraphics rendering in `ViewLensKit` on macOS.

---

## Milestone 0: Foundation & Packaging

### Task 0.1: SPM Package Manifest & Target Topology
- **ID**: `TASK-0.1`
- **User Story**: *As a developer, I want a clean Swift Package Manager configuration defining the library, CLI, and test targets, so that all components build seamlessly across macOS 15+ and Swift 6.*
- **Requirements**:
  - Create root `Package.swift` targeting macOS 15.0+.
  - Define `ViewLensKit` library target.
  - Define `viewlens` (alias `NativeUIAuditCLI`) executable target with `swift-argument-parser` (>= 1.3.0).
  - Define test targets `ViewLensKitTests` and `ViewLensCLITests`.
  - Configure Swift 6 concurrency and strict concurrency checks (`.enableExperimentalFeature("StrictConcurrency")`).
- **Acceptance Criteria**:
  - [ ] `swift build` compiles both `ViewLensKit` and `viewlens` without warnings.
  - [ ] `swift test` runs cleanly.
- **Unit Tests**:
  - Package builds on Swift 6.0 toolchain.

---

### Task 0.2: Model Locator & Environment Resolution
- **ID**: `TASK-0.2`
- **User Story**: *As an agent or CLI user, I want ViewLens to automatically locate the CoreML `best.mlpackage` across flags, env vars, and standard directory hierarchies, so that I don't have to specify long paths repeatedly.*
- **Requirements**:
  - Implement `ModelLocator.resolve(customPath: String?) -> Result<URL, ModelLocatorError>`.
  - Resolution chain:
    1. `customPath` (from CLI `--model`)
    2. `ProcessInfo.processInfo.environment["VIEWLENS_MODEL_PATH"]`
    3. `ProcessInfo.processInfo.environment["NATIVEUI_MODEL_PATH"]`
    4. Relative paths: `../NativeUIAuditKit/models/best.mlpackage`, `../NativeUITrainer/yolo_runs/yolo11n_e100/weights/best.mlpackage`
    5. User Application Support directory: `~/Library/Application Support/ViewLens/models/best.mlpackage`
    6. App Bundle Resources (when running inside `ViewLens.app`).
  - Validate that the target exists, is a valid `.mlpackage` or compiled `.mlmodelc`, and is readable.
- **Acceptance Criteria**:
  - [ ] Resolves explicit path when supplied.
  - [ ] Falls back to env var when flag is absent.
  - [ ] Falls back to relative sibling repo when env var is absent.
  - [ ] Returns actionable error `{ "error": "model_not_found", "searchedPaths": [...] }` on failure.
- **Unit Tests**:
  - `ModelLocatorTests`: Test each priority fallback in isolated temporary directories.

---

## Milestone 1: Core Detection Engine, CLI, & MCP Server MVP

### Task 1.1: Core Types & Coordinate Geometry
- **ID**: `TASK-1.1`
- **User Story**: *As an AI Agent or developer, I want bounding boxes expressed in normalized top-left `[0.0, 1.0]` coordinates, so that I can directly map them to SwiftUI and UIKit frames without inverted Y-axis math.*
- **Requirements**:
  - Create `Sources/ViewLensKit/Models/BoundingBox.swift`:
    - Properties: `x` (left edge $[0,1]$), `y` (top edge $[0,1]$), `width` $[0,1]$, `height` $[0,1]$.
    - Computed properties: `minX`, `maxX`, `minY`, `maxY`, `midX`, `midY`, `area`.
    - Methods: `intersection(with:)`, `union(with:)`, `iou(with:) -> Double`, `toPixelRect(imageSize: CGSize) -> CGRect`.
    - Factory: `init(centerX:centerY:width:height:)` converting YOLO center coordinates to top-left origin.
  - Create `Sources/ViewLensKit/Models/DetectedElement.swift`:
    - `type`: String / `NativeUIElementType` (`navigationBar`, `primaryButton`, `tabBar`, `textField`, `toggle`, etc.).
    - `confidence`: Float ($0.0 \dots 1.0$).
    - `boundingBox`: `BoundingBox`.
  - Ensure all structs conform to `Codable`, `Sendable`, `Equatable`, `Hashable`.
- **Acceptance Criteria**:
  - [ ] Bounding box origin is top-left `(0,0)` at upper-left corner of image.
  - [ ] YOLO `(cx, cy, w, h)` conversion produces exact `(x = cx - w/2, y = cy - h/2)`.
  - [ ] IoU calculation matches standard intersection over union formula.
- **Unit Tests**:
  - `BoundingBoxTests`: Verify coordinate conversions, IoU edge cases (disjoint, identical, partial overlap), pixel scaling.

---

### Task 1.2: YOLO CoreML Inference & NMS Engine
- **ID**: `TASK-1.2`
- **User Story**: *As a developer, I want high-speed ANE-accelerated YOLO11n CoreML inference with non-maximum suppression (NMS), so that screenshots are detected in <15ms.*
- **Requirements**:
  - Port validated letterboxing, `CVPixelBuffer` creation, and output parsing from `NativeUIAuditKit/scripts/eval_yolo_map.swift`.
  - Implement `YOLODetector` actor in `Sources/ViewLensKit/Detector/YOLODetector.swift`:
    - `init(modelURL: URL, configuration: MLModelConfiguration = default)`
    - `func detect(image: CGImage, minConfidence: Float = 0.10, iouThreshold: Double = 0.30) async throws -> [DetectedElement]`
    - `func detectBatch(images: [CGImage], minConfidence: Float = 0.10, iouThreshold: Double = 0.30) async throws -> [[DetectedElement]]`
  - Implement Letterboxing: Scale preserving aspect ratio with centered padding to model input size ($640 \times 640$).
  - Greedy NMS algorithm filtering multi-detections at IoU threshold $0.30$.
  - Batch detection reusing a single loaded `MLModel` instance to avoid cold-load overhead.
- **Acceptance Criteria**:
  - [ ] Correctly processes single images and image arrays.
  - [ ] Inverts letterbox offset/scale to return normalized coordinates relative to original unpadded image.
  - [ ] MultiArray stride parsing matches YOLO11 output shape `[1, 5 + num_classes, 8400]`.
- **Unit Tests**:
  - `YOLODetectorTests`: Mock CoreML input/output MultiArray parsing, coordinate normalization tests, NMS deduplication verification.

---

### Task 1.3: Deterministic HIG Rules & Issue Classifier Engine
- **ID**: `TASK-1.3`
- **User Story**: *As an AI Agent, I want deterministic rule-based classifications of layout and accessibility bugs, so that I can provide actionable remediation steps to developers.*
- **Requirements**:
  - Implement `Sources/ViewLensKit/Rules/IssueClassifier.swift`.
  - Implement `ViewLensIssue` model:
    - `kind`: `ViewLensIssueKind` (`tappableTargetTooSmall`, `clippedElement`, `overlappingElements`, `offScreen`, `misalignedElement`).
    - `severity`: `error` | `warning` | `info`.
    - `description`: Human- and LLM-readable diagnosis with exact measurements (points and pixels).
    - `elementIndex`: Int index into detected elements array.
    - `confidence`: Float.
    - `remediation`: Suggested SwiftUI / UIKit fix code snippet.
  - Rule implementations:
    - `tappableTargetTooSmall`: If element is `primaryButton` or `toggle`, check if `width < 44 * scale` or `height < 44 * scale` in px.
    - `clippedElement`: If bounding box pixel rect touches or is $< 2\text{px}$ from screen bounds (unless it's a full-width navigationBar or tabBar).
    - `overlappingElements`: If cross-element IoU $> 0.30$ between interactive elements.
    - `offScreen`: If $> 50\%$ of element area lies outside normalized $[0,0,1,1]$.
  - Scale inference: If not specified, infer from image width (1179, 1290, 1170 $\to @3x$; 750, 828 $\to @2x$; otherwise default 3.0).
- **Acceptance Criteria**:
  - [ ] Identifies sub-44pt touch targets with explicit pt/px readout.
  - [ ] Flags overlapping buttons or clipped controls accurately.
  - [ ] Returns empty issue list and `passed: true` for compliant layouts.
- **Unit Tests**:
  - `IssueClassifierTests`: Synthetic layout test fixtures covering each HIG rule condition and edge cases.

---

### Task 1.4: Annotated Bounding Box Visual Overlay Generator
- **ID**: `TASK-1.4`
- **User Story**: *As a developer or reviewer, I want to output an annotated PNG image with color-coded bounding boxes and issue tags, so that I can visually verify what the model and rules engine saw.*
- **Requirements**:
  - Implement `Sources/ViewLensKit/Rendering/OverlayRenderer.swift`.
  - Render bounding boxes using CoreGraphics / ImageIO:
    - Green box ($2\text{px}$ stroke) for compliant elements (`passed: true`).
    - Red box ($3\text{px}$ stroke + semi-transparent fill) for elements with issues (`severity: .error`).
    - Amber box for warnings (`severity: .warning`).
    - Element label chip with class name and confidence score (e.g. `primaryButton 96%`).
    - Issue badge callout (e.g. `⚠️ 32pt < 44pt`).
  - Output to target file path when `--overlay <path>` is provided.
- **Acceptance Criteria**:
  - [ ] Writes high-resolution annotated image matching input dimensions.
  - [ ] Supports light and dark mode backgrounds with high-contrast label chips.
- **Unit Tests**:
  - `OverlayRendererTests`: Verify image generation and file writing without crashes or memory leaks.

---

### Task 1.5: Swift CLI (`viewlens`) Implementation
- **ID**: `TASK-1.5`
- **User Story**: *As a terminal user or CI runner, I want a fast CLI binary with `doctor`, `scan`, and `batch` subcommands, so that I can run audits locally or gate PRs in CI.*
- **Requirements**:
  - Root command `viewlens` (aliased as `NativeUIAuditCLI` / `nativeui-audit`).
  - `viewlens doctor`:
    - Checks: model located, file size verification ($< 15\text{MB}$), cold load latency test.
    - Flags: `--json` (machine output), `--model <path>` (override).
    - Exit codes: `0` (ready), `2` (environment/model failure).
  - `viewlens scan <images...>`:
    - Flags: `--model <path>`, `--format table|json` (default `table`), `--min-confidence <f>` (default 0.1), `--scale <f>`, `--overlay <path>`, `--strict`.
    - Exit codes: `0` (success/passed), `1` (issues detected with `--strict`), `2` (runtime/file error).
  - `viewlens batch <directory>`:
    - Flags: `--pattern "*.png"`, `--format json`, `--output <file>`, `--strict`.
  - Structured Error Standard: On exit code $>0$, writes JSON `{ "error": "...", "nextCommand": "..." }` to stderr.
- **Acceptance Criteria**:
  - [ ] `viewlens doctor --json` outputs valid status JSON.
  - [ ] `viewlens scan screenshot.png --format table` renders an ASCII table.
  - [ ] `viewlens scan screenshot.png --format json` outputs valid JSON parseable by standard tooling.
  - [ ] `--strict` returns exit code 1 when issues are found.
- **Integration Tests**:
  - `CLISmokeTests`: Execute binary via `Process`, assert on stdout, stderr, and exit codes.

---

### Task 1.6: Python MCP Server (stdio Transport)
- **ID**: `TASK-1.6`
- **User Story**: *As an AI Agent (Claude Code / Cursor), I want an MCP server exposing `viewlens_doctor` and `viewlens_audit_screenshot` over stdio, so that I can inspect UI layouts during coding sessions.*
- **Requirements**:
  - Directory: `mcp-server/`.
  - File `mcp-server/server.py` using official `mcp` Python SDK (FastMCP / stdio).
  - File `mcp-server/requirements.txt` with `mcp>=1.0`.
  - Tools:
    - `viewlens_doctor()`: Invokes `viewlens doctor --json`, returns health status and model path.
    - `viewlens_audit_screenshot(image_path: str, min_confidence: float = 0.1, scale: float = None)`: Invokes `viewlens scan <path> --format json`, returns parsed JSON element and issue structure.
  - Subprocess error handling: Catch exit code 2 and stderr JSON, formatting into friendly MCP Tool Error messages.
  - No daemon requirement; server boots on demand per agent session.
- **Acceptance Criteria**:
  - [ ] Claude Code / Cursor connects via stdio JSON-RPC.
  - [ ] `viewlens_doctor` executes and returns diagnostic results.
  - [ ] `viewlens_audit_screenshot` returns structured element coordinates and issues.
- **Integration Tests**:
  - Python test invoking `server.py` via `stdin`/`stdout` JSON-RPC test harness.

---

### Task 1.7: Agent Skill Playbook (`.agents/skills/viewlens/SKILL.md`)
- **ID**: `TASK-1.7`
- **User Story**: *As an AI Agent, I want clear operational instructions and schema documentation in my skill prompt, so that I know when and how to invoke ViewLens tools correctly.*
- **Requirements**:
  - Create `.agents/skills/viewlens/SKILL.md`.
  - Sections:
    - **Overview & Mental Model**: What ViewLens does and how it avoids image token consumption.
    - **Order of Operations**: 1. Call `viewlens_doctor`, 2. Call `viewlens_audit_screenshot`, 3. Propose SwiftUI/UIKit fixes.
    - **Coordinate System**: Explicitly describe normalized top-left `[0,1]` origin matching SwiftUI frames.
    - **Issue Catalog & Remediation Guide**: Map of each `ViewLensIssueKind` to concrete SwiftUI modifiers (e.g. `.frame(minHeight: 44)`, `.padding()`, `.ignoresSafeArea()`).
    - **Edge Cases & Pitfalls**: Handling scale factors (@2x vs @3x), low confidence detections, and simulator screenshot artifacts.
- **Acceptance Criteria**:
  - [ ] Document adheres to Agent Skill specifications.
  - [ ] Referenced directly in MCP server tool descriptions.

---

### Task 1.8: Installer & Integration Automation
- **ID**: `TASK-1.8`
- **User Story**: *As a developer or agent user, I want a single setup script that builds the binary and configures Claude Code / Cursor, so that setup takes under 30 seconds.*
- **Requirements**:
  - Create `scripts/install_mcp.sh`:
    - Compiles release binary `swift build -c release --product viewlens`.
    - Creates symlink in `/usr/local/bin/viewlens` or `~/.local/bin/viewlens`.
    - Prompts or automatically writes `mcpServers.viewlens` configuration into `~/.claude/settings.json` and Cursor config.
    - Runs `viewlens doctor` and reports ready status.
- **Acceptance Criteria**:
  - [ ] Script runs idempotently on fresh macOS installations.
  - [ ] Verifies all dependencies (Python 3.10+, Swift 6.0).

---

## Milestone 2: SwiftUI Rendering Bridge & Matrix Audit

### Task 2.1: GeneratorRunner IPC Test Bridge
- **ID**: `TASK-2.1`
- **User Story**: *As a developer or agent, I want to render SwiftUI views into screenshots dynamically without manual simulator manipulation, so that automated matrix audits can be performed.*
- **Requirements**:
  - Create an XCTest IPC runner in `ViewLensKit/Rendering/GeneratorRunnerBridge.swift`.
  - Accepts JSON configuration via stdin/args: Template name, list of devices (e.g., iPhone SE, iPhone 16 Pro), Dynamic Type sizes (`large`, `accessibility3`), Color Schemes (`light`, `dark`).
  - Executes batch capture in a **single simulator session** to avoid multiple cold-boot cycles.
  - Emits rendered screenshot file paths to stdout.
- **Acceptance Criteria**:
  - [ ] Renders matrix cells efficiently in single runner pass.
  - [ ] Outputs deterministic screenshot file paths.

---

### Task 2.2: CLI `viewlens render` Subcommand
- **ID**: `TASK-2.2`
- **User Story**: *As a CLI user, I want `viewlens render` to render and immediately audit a SwiftUI view template in one step.*
- **Requirements**:
  - Subcommand `viewlens render --template <name> --device <dev> --dt <size> --scheme <light|dark>`.
  - Seamlessly pipes captured screenshots from Task 2.1 into `YOLODetector` and `IssueClassifier`.
  - Returns combined JSON with `screenshotPath`, detected elements, and HIG issues.
- **Acceptance Criteria**:
  - [ ] One-line execution produces complete audit for any registered SwiftUI template.

---

### Task 2.3: MCP Matrix Audit Tool (`viewlens_audit_swiftui_view`)
- **ID**: `TASK-2.3`
- **User Story**: *As an AI Agent, I want to audit a SwiftUI component across a matrix of devices and accessibility settings with a single MCP call, so that I can catch layout breakage across all form factors.*
- **Requirements**:
  - Expose `viewlens_audit_swiftui_view` tool in `server.py`.
  - Parameters: `template` (string), `matrix` (dict with `devices`, `dynamicTypeSizes`, `colorSchemes`).
  - Executes single batch render + single batch CoreML inference.
  - Synthesizes worst-case issue summary across all matrix permutations.
- **Acceptance Criteria**:
  - [ ] Returns matrix results map keyed by `device_dt_scheme` (e.g. `iPhoneSE_accessibility3_dark`).
  - [ ] Includes root `summary: { "passed": false, "worstIssue": "..." }`.

---

## Milestone 3: macOS Desktop Visual Inspector App

### Task 3.1: SwiftUI Desktop Inspector Canvas
- **ID**: `TASK-3.1`
- **User Story**: *As a macOS user, I want a native desktop app to drag-and-drop screenshots or paste images, so that I can visually explore detected elements and HIG annotations interactively.*
- **Requirements**:
  - Modern macOS 15+ SwiftUI canvas with zoom, pan, and split-view layout.
  - Interactive bounding box overlays with hover state, selection, and coordinate inspector.
  - Filter by element class (`navigationBar`, `primaryButton`, etc.) and issue severity.

---

### Task 3.2: Issue Timeline & Remediation Code Inspector
- **ID**: `TASK-3.2`
- **User Story**: *As a developer using the desktop app, I want to click on any flagged issue and see the exact HIG guideline and suggested SwiftUI modifier fix.*
- **Requirements**:
  - Sidebar listing all issues grouped by severity.
  - Detailed inspection panel showing computed vs expected tap target size, clipping margins, and HIG link.
  - "Copy Fix" button providing SwiftUI replacement code snippet.

---

### Task 3.3: Live Screen Capture & Window Snapper
- **ID**: `TASK-3.3`
- **User Story**: *As a developer, I want to capture a live iOS Simulator or macOS window and audit it in real time, so that I can audit views as I build them in Xcode.*
- **Requirements**:
  - ScreenCaptureKit integration to select running Simulator window.
  - Continuous or hotkey-triggered audit cycle.

---

### Task 3.4: MCP Server Status & Embedded Daemon Controller
- **ID**: `TASK-3.4`
- **User Story**: *As a developer, I want to view active MCP agent connections, live audit logs, and model status from the macOS menu bar.*
- **Requirements**:
  - Menu bar extra displaying MCP server status.
  - Live log stream showing agent tool requests (`audit_screenshot`, `doctor`) in real time.

---

## Test & Quality Assurance Plan

```
┌─────────────────────────────────────────────────────────────┐
│                    ViewLens Test Suite                      │
├───────────────────────────────┬─────────────────────────────┤
│ Level                         │ Scope                       │
├───────────────────────────────┼─────────────────────────────┤
│ 1. Unit Tests (ViewLensKit)   │ BoundingBox math, IoU, NMS, │
│                               │ HIG rules classification,   │
│                               │ ModelLocator resolution     │
│ 2. CLI Integration Tests      │ Argument parsing, exit code │
│                               │ matrix (0, 1, 2), table &   │
│                               │ JSON formatters             │
│ 3. MCP Integration Tests      │ stdio JSON-RPC protocol,    │
│                               │ tool call responses, errors │
│ 4. End-to-End Golden Scans    │ Full inference on fixture   │
│                               │ screenshots with validation │
└───────────────────────────────┴─────────────────────────────┘
```

---

## Definition of Done (DoD) Checklist

For every task to be marked complete:
- [ ] Code is implemented according to Swift 6 / Python standards.
- [ ] No compiler warnings or strict concurrency violations.
- [ ] Unit tests are written and passing with $>90\%$ branch coverage for core geometry and rules.
- [ ] CLI commands respond with documented exit codes and JSON schema.
- [ ] Agent documentation (`SKILL.md` / `README.md`) is updated to reflect any API changes.
- [ ] Smoke test passes on macOS 15+ Apple Silicon hardware.
