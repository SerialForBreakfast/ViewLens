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
| **M6: NativeUIAuditKit 2.0 Integration & Release Distribution** | Sprint 6 | `NativeUIAuditKitModels` 2.0.0 dependency wiring, `ModelLocator` zero-config bundled model resolution, and release packaging | 📋 Ready for Release |

---

## Completed Tasks (Milestones 0–5)

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
