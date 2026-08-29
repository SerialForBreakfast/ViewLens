# ViewLens — Implementation Tasks & Work Breakdown

This document provides the master task breakdown, milestone roadmap, user stories, acceptance criteria, test specifications, and architectural considerations for the **ViewLens** project.

---

## Roadmap & Milestones Summary

| Milestone | Target | Description | Status |
|---|---|---|---|
| **M0: Foundation, Packaging & Spikes** | Sprint 1 | SPM Package structure, model discovery, shared types, 100% Pure Swift architecture | ✅ Complete |
| **M1: Detection CLI + Pure Swift MCP Server MVP** | Sprint 1–2 | `ViewLensKit` inference engine, `viewlens` CLI (`doctor`, `scan`, `batch`, `mcp`), Native stdio JSON-RPC server, `.agents/skills` playbook | ✅ Complete |
| **M2: Multi-Tier Rendering Canvas & Layout Introspection** | Sprint 3 | In-process SwiftUI `ImageRenderer` matrix canvas, `TemplateRegistry`, Catalyst IPC protocol & UIKit harness, `viewlens render` CLI, `viewlens_audit_view` MCP matrix tool | ✅ Complete |
| **M3: macOS Desktop Visual Inspector App** | Sprint 4 | SwiftUI macOS Canvas App, live MCP status bar, incoming agent activity stream, visual confirmation preview canvas, and HIG remediation sidebar | ✅ Complete |
| **M4: Terminal UI (TUI) & Headless ASCII Dashboard** | Sprint 5 | Full-screen interactive ANSI terminal UI (`viewlens tui`), ASCII wireframe visualizer, keyboard shortcuts, and headless CI streaming mode | ✅ Complete |
| **M5: Mac Catalyst Live Validation Spike** | Sprint 5 | Empirical verification of offscreen `UIWindow`, `hasAmbiguousLayout` accuracy, Dynamic Type trait overrides, and sub-millisecond layout benchmarking | ✅ Complete |
| **M6: Git Hooks & CI/CD Quality Gate Engine** | Sprint 6 | Declarative `.viewlens.yml` / `.viewlens.json` config, `viewlens hook pre-commit/pre-push/ci`, git diff auto-detection, and GitHub PR markdown report generator | ✅ Complete |
| **M7: NativeUIAuditKit 2.0 Integration & Model Bundling** | Sprint 7 | Resolved `NativeUIAuditKit` 2.0.0 SPM dependency, wired `NativeUIModelAsset.defaultModelURL` and `metadata`, verified zero-config `viewlens doctor` and `xcodebuild` | ✅ Complete |
| **M8: Desktop Design System & Navigation Shell** | UI Sprint 1 | Semantic tokens, reusable components, native split navigation, toolbar, commands, adaptive appearance | 🟨 In Progress |
| **M9: Review Domain & State Architecture** | UI Sprint 1–2 | Review lifecycle, focused stores, cancellable orchestration, errors, partial/stale results | ✅ Complete |
| **M10: Current Status Dashboard** | UI Sprint 2 | Health cards, recent reviews, quality trend, activity, quick import | ✅ Complete |
| **M11: AI Review Workbench** | UI Sprint 3–4 | Review progress, inspection canvas, findings, activity, remediation, export | ✅ Complete |
| **M12: Playground, History & Settings** | UI Sprint 4–5 | Manual/template audit setup, durable reviews, comparison, preferences and diagnostics | ✅ Complete |
| **M13: Desktop Accessibility & Release Verification** | UI Sprint 6 | Keyboard/VoiceOver coverage, self-audits, visual baselines, UI/build tests | 🟨 In Progress — host XCTest runner session pending |
| **M14: Modern MCP Protocol & Structured Evidence** | Agent Sprint 1–2 | Protocol negotiation, structured outputs, resources, prompts, tasks, cancellation, conformance | ✅ Complete |
| **M15: Live Native Review Sessions** | Agent Sprint 3–5 | Safe app launch, simulator/macOS capture, accessibility hierarchy, spatial queries, durable session handles | ✅ Complete |
| **M16: Interaction & Accessibility Graph** | Agent Sprint 6–8 | Allowlisted UI actions, focus traversal, state crawling, accommodations, localization and replay | ✅ Complete |
| **M17: Source Provenance & Fix Verification** | Agent Sprint 9–11 | Visual-to-source mapping, before/after verification, regression generation, CI evidence | ✅ Complete |
| **M18: Interactive MCP App & Remote Collaboration** | Agent Sprint 12–14 | Sandboxed review UI, approvals, streamable HTTP/SSE transport, scoped token authorization, AES-GCM encrypted storage, and threat model | 🟨 In Progress — MCP App, HTTP/SSE transport, auth, telemetry, and encrypted storage complete; packaging & skills next |
| **M19: Project Context & Dependency Resolution** | Agent Sprint 15 | Bounded source closure, package pins, asset discovery, deterministic synthetic mocks, preview harness generator, context CLI & MCP tool | ✅ Complete |
| **NV: Nonvisual Authoring Experience** | Cross-cutting M14–M19 | Text-first screen model, semantic/visual mismatch analysis, VoiceOver navigation intelligence, braille-efficient output, source-linked verification | 🟨 In Progress — NV-0 through NV-5 complete; NV-2.10 and NV-6 release verification pending |

---

## Completed Tasks (Milestones 0–7)

### ✅ Milestone 0: Foundation & Core Setup
- **Task 0.1**: Created [Package.swift](file:///Users/josephmccraw/Dropbox/My%20Mac%20%28MacBook-Air%29/Documents/GitHub/ViewLens/Package.swift) defining `ViewLensKit`, `viewlens` CLI, and test targets.
- **Task 0.2**: Created [DeviceProfile.swift](file:///Users/josephmccraw/Dropbox/My%20Mac%20%28MacBook-Air%29/Documents/GitHub/ViewLens/Sources/ViewLensKit/Models/DeviceProfile.swift) with hardware metrics for iPhone SE, iPhone 16 Pro, iPhone 16 Pro Max, iPad Pro 11", and iPad Pro 13".
- **Task 0.4**: Created [ModelLocator.swift](file:///Users/josephmccraw/Dropbox/My%20Mac%20%28MacBook-Air%29/Documents/GitHub/ViewLens/Sources/ViewLensKit/Detector/ModelLocator.swift) with prioritized resolution chain.

### ✅ Milestone 1: Core Detection Engine & Pure Swift MCP Server
- **Task 1.1**: Implemented [BoundingBox.swift](file:///Users/josephmccraw/Dropbox/My%20Mac%20%28MacBook-Air%29/Documents/GitHub/ViewLens/Sources/ViewLensKit/Models/BoundingBox.swift) with normalized top-left $[0,1]$ space matching SwiftUI frames.
- **Task 1.2**: Implemented [YOLODetector.swift](file:///Users/josephmccraw/Dropbox/My%20Mac%20%28MacBook-Air%29/Documents/GitHub/ViewLens/Sources/ViewLensKit/Detector/YOLODetector.swift) and [NMS.swift](file:///Users/josephmccraw/Dropbox/My%20Mac%20%28MacBook-Air%29/Documents/GitHub/ViewLens/Sources/ViewLensKit/Detector/NMS.swift).
- **Task 1.3**: Implemented [IssueClassifier.swift](file:///Users/josephmccraw/Dropbox/My%20Mac%20%28MacBook-Air%29/Documents/GitHub/ViewLens/Sources/ViewLensKit/Rules/IssueClassifier.swift) and [HIGRule.swift](file:///Users/josephmccraw/Dropbox/My%20Mac%20%28MacBook-Air%29/Documents/GitHub/ViewLens/Sources/ViewLensKit/Rules/HIGRule.swift).
- **Task 1.4**: Implemented [OverlayRenderer.swift](file:///Users/josephmccraw/Dropbox/My%20Mac%20%28MacBook-Air%29/Documents/GitHub/ViewLens/Sources/ViewLensKit/Rendering/OverlayRenderer.swift).
- **Task 1.5**: Implemented [ViewLensCLI.swift](file:///Users/josephmccraw/Dropbox/My%20Mac%20%28MacBook-Air%29/Documents/GitHub/ViewLens/Sources/ViewLensCLI/ViewLensCLI.swift), [DoctorCommand.swift](file:///Users/josephmccraw/Dropbox/My%20Mac%20%28MacBook-Air%29/Documents/GitHub/ViewLens/Sources/ViewLensCLI/Commands/DoctorCommand.swift), [ScanCommand.swift](file:///Users/josephmccraw/Dropbox/My%20Mac%20%28MacBook-Air%29/Documents/GitHub/ViewLens/Sources/ViewLensCLI/Commands/ScanCommand.swift), and [BatchCommand.swift](file:///Users/josephmccraw/Dropbox/My%20Mac%20%28MacBook-Air%29/Documents/GitHub/ViewLens/Sources/ViewLensCLI/Commands/BatchCommand.swift).
- **Task 1.6**: Implemented [MCPServer.swift](file:///Users/josephmccraw/Dropbox/My%20Mac%20%28MacBook-Air%29/Documents/GitHub/ViewLens/Sources/ViewLensKit/MCP/MCPServer.swift) and [MCPProtocol.swift](file:///Users/josephmccraw/Dropbox/My%20Mac%20%28MacBook-Air%29/Documents/GitHub/ViewLens/Sources/ViewLensKit/MCP/MCPProtocol.swift) with zero Python dependencies.
- **Task 1.7**: Created [.agents/skills/viewlens/SKILL.md](file:///Users/josephmccraw/Dropbox/My%20Mac%20%28MacBook-Air%29/Documents/GitHub/ViewLens/.agents/skills/viewlens/SKILL.md) and [scripts/install_mcp.sh](file:///Users/josephmccraw/Dropbox/My%20Mac%20%28MacBook-Air%29/Documents/GitHub/ViewLens/scripts/install_mcp.sh).

### ✅ Milestone 2: Multi-Tier Matrix Canvas & Introspection
- **Task 2.1**: Implemented [MatrixRenderer.swift](file:///Users/josephmccraw/Dropbox/My%20Mac%20%28MacBook-Air%29/Documents/GitHub/ViewLens/Sources/ViewLensKit/Rendering/MatrixRenderer.swift), [VirtualDeviceContainer.swift](file:///Users/josephmccraw/Dropbox/My%20Mac%20%28MacBook-Air%29/Documents/GitHub/ViewLens/Sources/ViewLensKit/Rendering/VirtualDeviceContainer.swift), and [TemplateRegistry.swift](file:///Users/josephmccraw/Dropbox/My%20Mac%20%28MacBook-Air%29/Documents/GitHub/ViewLens/Sources/ViewLensKit/Rendering/TemplateRegistry.swift).
- **Task 2.2 & 2.3**: Implemented [CatalystIPC.swift](file:///Users/josephmccraw/Dropbox/My%20Mac%20%28MacBook-Air%29/Documents/GitHub/ViewLens/Sources/ViewLensKit/Introspection/CatalystIPC.swift) and [StructuralIntrospector.swift](file:///Users/josephmccraw/Dropbox/My%20Mac%20%28MacBook-Air%29/Documents/GitHub/ViewLens/Sources/ViewLensKit/Introspection/StructuralIntrospector.swift).
- **Task 2.5**: Implemented [RenderCommand.swift](file:///Users/josephmccraw/Dropbox/My%20Mac%20%28MacBook-Air%29/Documents/GitHub/ViewLens/Sources/ViewLensCLI/Commands/RenderCommand.swift).
- **Task 2.6**: Connected `viewlens_audit_view` tool in [MCPServer.swift](file:///Users/josephmccraw/Dropbox/My%20Mac%20%28MacBook-Air%29/Documents/GitHub/ViewLens/Sources/ViewLensKit/MCP/MCPServer.swift).

### ✅ Milestone 3: macOS Desktop Visual Inspector App
- **Task 3.1**: Implemented [AppModel.swift](file:///Users/josephmccraw/Dropbox/My%20Mac%20%28MacBook-Air%29/Documents/GitHub/ViewLens/ViewLens/Models/AppModel.swift) and [DoctorStatusView.swift](file:///Users/josephmccraw/Dropbox/My%20Mac%20%28MacBook-Air%29/Documents/GitHub/ViewLens/ViewLens/Views/DoctorStatusView.swift).
- **Task 3.2**: Implemented [VisualInspectorView.swift](file:///Users/josephmccraw/Dropbox/My%20Mac%20%28MacBook-Air%29/Documents/GitHub/ViewLens/ViewLens/Views/VisualInspectorView.swift) with interactive bounding box overlays and drag-and-drop.
- **Task 3.3**: Implemented [IssuesSidebarView.swift](file:///Users/josephmccraw/Dropbox/My%20Mac%20%28MacBook-Air%29/Documents/GitHub/ViewLens/ViewLens/Views/IssuesSidebarView.swift) and [ActivityLogView.swift](file:///Users/josephmccraw/Dropbox/My%20Mac%20%28MacBook-Air%29/Documents/GitHub/ViewLens/ViewLens/Views/ActivityLogView.swift).
- **Task 3.4**: Implemented [TemplatePlaygroundView.swift](file:///Users/josephmccraw/Dropbox/My%20Mac%20%28MacBook-Air%29/Documents/GitHub/ViewLens/ViewLens/Views/TemplatePlaygroundView.swift) and configured Xcode package integration in [ViewLens.xcodeproj](file:///Users/josephmccraw/Dropbox/My%20Mac%20%28MacBook-Air%29/Documents/GitHub/ViewLens/ViewLens.xcodeproj/project.pbxproj).

### ✅ Milestone 4: Terminal UI (TUI) & Headless ASCII Dashboard
- **Task 4.1**: Implemented [TerminalCanvas.swift](file:///Users/josephmccraw/Dropbox/My%20Mac%20%28MacBook-Air%29/Documents/GitHub/ViewLens/Sources/ViewLensKit/TUI/TerminalCanvas.swift) with ANSI screen buffers, cursor positioning, and raw mode.
- **Task 4.2**: Implemented [ASCIILayoutRenderer.swift](file:///Users/josephmccraw/Dropbox/My%20Mac%20%28MacBook-Air%29/Documents/GitHub/ViewLens/Sources/ViewLensKit/TUI/ASCIILayoutRenderer.swift) rendering 2D wireframes with embedded label chips and safe-area boundaries.
- **Task 4.3 & 4.4**: Implemented [TUICommand.swift](file:///Users/josephmccraw/Dropbox/My%20Mac%20%28MacBook-Air%29/Documents/GitHub/ViewLens/Sources/ViewLensCLI/Commands/TUICommand.swift) (`viewlens tui`) with interactive keyboard controls (`1-4`, `d`, `t`, `c`, `r`, `q`) and `--headless` CI mode.

### ✅ Milestone 5: Mac Catalyst Live Validation Spike
- **Task 5.1 & 5.2**: Implemented [CatalystSpikeHarness.swift](file:///Users/josephmccraw/Dropbox/My%20Mac%20%28MacBook-Air%29/Documents/GitHub/ViewLens/Sources/ViewLensKit/Introspection/CatalystSpikeHarness.swift) empirically validating that `view.hasAmbiguousLayout` returns `false` on fully-constrained layouts, `true` on under-constrained layouts when attached to offscreen `UIWindow`, and `UIGraphicsImageRenderer` rasterizes offscreen hierarchies in $<1\text{ms}$.

### ✅ Milestone 6: Git Hooks & CI/CD Quality Gate Engine
- **Task 6.1**: Implemented [ViewLensConfig.swift](file:///Users/josephmccraw/Dropbox/My%20Mac%20%28MacBook-Air%29/Documents/GitHub/ViewLens/Sources/ViewLensKit/Config/ViewLensConfig.swift) with declarative quality gate schemas and purpose filters (`touch_targets`, `clipping`, `accessibility`, `dark_mode`, `autolayout`).
- **Task 6.2**: Implemented [GitDiffAnalyzer.swift](file:///Users/josephmccraw/Dropbox/My%20Mac%20%28MacBook-Air%29/Documents/GitHub/ViewLens/Sources/ViewLensKit/Git/GitDiffAnalyzer.swift) parsing `git diff --cached` for modified view detection.
- **Task 6.3**: Implemented [QualityGateEvaluator.swift](file:///Users/josephmccraw/Dropbox/My%20Mac%20%28MacBook-Air%29/Documents/GitHub/ViewLens/Sources/ViewLensKit/QualityGate/QualityGateEvaluator.swift) with configurable `fail_on` thresholds.
- **Task 6.4**: Implemented [PRSummaryGenerator.swift](file:///Users/josephmccraw/Dropbox/My%20Mac%20%28MacBook-Air%29/Documents/GitHub/ViewLens/Sources/ViewLensKit/QualityGate/PRSummaryGenerator.swift) formatting GitHub PR comments and `$GITHUB_STEP_SUMMARY` markdown.
- **Task 6.5**: Implemented [HookCommand.swift](file:///Users/josephmccraw/Dropbox/My%20Mac%20%28MacBook-Air%29/Documents/GitHub/ViewLens/Sources/ViewLensCLI/Commands/HookCommand.swift), [InstallHookCommand.swift](file:///Users/josephmccraw/Dropbox/My%20Mac%20%28MacBook-Air%29/Documents/GitHub/ViewLens/Sources/ViewLensCLI/Commands/InstallHookCommand.swift), and [InitConfigCommand.swift](file:///Users/josephmccraw/Dropbox/My%20Mac%20%28MacBook-Air%29/Documents/GitHub/ViewLens/Sources/ViewLensCLI/Commands/InitConfigCommand.swift).

### ✅ Milestone 7: NativeUIAuditKit 2.0 Integration & Model Bundling
- **Task 7.1**: Integrated `NativeUIAuditKit` 2.0.0 via SPM in [Package.swift](file:///Users/josephmccraw/Dropbox/My%20Mac%20%28MacBook-Air%29/Documents/GitHub/ViewLens/Package.swift).
- **Task 7.2**: Wired `NativeUIModelAsset.defaultModelURL` in [ModelLocator.swift](file:///Users/josephmccraw/Dropbox/My%20Mac%20%28MacBook-Air%29/Documents/GitHub/ViewLens/Sources/ViewLensKit/Detector/ModelLocator.swift) for zero-config discovery.
- **Task 7.3**: Integrated `NativeUIModelAsset.metadata` for single-source-of-truth class labels and tensor dimensions in [YOLODetector.swift](file:///Users/josephmccraw/Dropbox/My%20Mac%20%28MacBook-Air%29/Documents/GitHub/ViewLens/Sources/ViewLensKit/Detector/YOLODetector.swift).
- **Task 7.4**: Verified `viewlens doctor` zero-config load in $0.66\text{s}$ and successful Xcode Mac App build.

---

## Planned Modernized Desktop UI (Milestones 8–13)

The detailed screen definitions, component states, style tokens, interaction rules, acceptance criteria, and task-level work breakdown are maintained in [ViewLens Desktop UI Design Specification](Docs/ViewLens-Desktop-UI-Design-Specification.md).

Implementation should begin with **M8 Design System & Shell**, followed by **M9 Review Domain & State Architecture**. The AI Review workbench and Current Status dashboard must share that domain model rather than maintaining separate transient representations of a review.

## Planned Agent Capability Platform (Milestones 14–18)

The detailed protocol contracts, runtime safety boundaries, task dependencies, acceptance criteria, and iteration slices are maintained in [ViewLens MCP & Agent Capability Roadmap](Docs/ViewLens-MCP-Agent-Capability-Roadmap.md).

The user journeys for blind and low-vision developers, nonvisual evidence contract, Mac/MCP/CLI tasks, runtime navigation intelligence, source remediation, and assistive-technology release gates are maintained in [ViewLens Nonvisual Authoring Experience Plan](Docs/ViewLens-Nonvisual-Authoring-Experience-Plan.md).

Implementation begins with **M14 Modern MCP Protocol & Structured Evidence**. Live runtime control must not be added until protocol-version negotiation, typed evidence, cancellation, explicit state handles, and conformance fixtures are in place.
