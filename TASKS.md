# ViewLens — Implementation Tasks & Work Breakdown

This document provides the master task breakdown, milestone roadmap, user stories, acceptance criteria, test specifications, and architectural considerations for the **ViewLens** project.

---

## Roadmap & Milestones Summary

| Milestone | Target | Description | Status |
|---|---|---|---|
| **M0: Foundation, Packaging & Spikes** | Sprint 1 | SPM Package structure, model discovery, shared types, 100% Pure Swift architecture | ✅ Complete |
| **M1: Detection CLI + Pure Swift MCP Server MVP** | Sprint 1–2 | `ViewLensKit` inference engine, `viewlens` CLI (`doctor`, `scan`, `batch`, `mcp`), Native stdio JSON-RPC server, `.agents/skills` playbook | ✅ Complete |
| **M2: Multi-Tier Rendering Canvas & Layout Introspection** | Sprint 3 | In-process SwiftUI `ImageRenderer` canvas, Catalyst IPC & UIKit harness, `UIView.hasAmbiguousLayout` window-attached introspection, `viewlens render` CLI, `viewlens_audit_view` MCP tool | 📋 Ready for Next Phase |
| **M3: macOS Desktop Visual Inspector** | Sprint 4+ | SwiftUI macOS Canvas App, live screen/window capture audit, visual bounding box inspector, embedded daemon control (Independent Phase) | 📋 Planned |

---

## Completed Tasks (Milestones 0 & 1)

### ✅ Task 0.1: SPM Package Manifest & Target Topology
- Created root [Package.swift](file:///Users/josephmccraw/Dropbox/My%20Mac%20%28MacBook-Air%29/Documents/GitHub/ViewLens/Package.swift) defining `ViewLensKit` library, `viewlens` executable CLI, and test targets with Swift 6 strict concurrency.

### ✅ Task 0.2: Device Configuration & Trait Matrix
- Created [DeviceProfile.swift](file:///Users/josephmccraw/Dropbox/My%20Mac%20%28MacBook-Air%29/Documents/GitHub/ViewLens/Sources/ViewLensKit/Models/DeviceProfile.swift) with hardware metrics for iPhone SE, iPhone 16 Pro, iPhone 16 Pro Max, iPad Pro 11", and iPad Pro 13".

### ✅ Task 0.4: Model Locator & Environment Resolution
- Created [ModelLocator.swift](file:///Users/josephmccraw/Dropbox/My%20Mac%20%28MacBook-Air%29/Documents/GitHub/ViewLens/Sources/ViewLensKit/Detector/ModelLocator.swift) with prioritized resolution chain (`--model`, `VIEWLENS_MODEL_PATH`, `NATIVEUI_MODEL_PATH`, sibling `NativeUIAuditKit` fallback, Application Support cache).

### ✅ Task 1.1: Core Types & Coordinate Geometry (`sourceMode` Contract)
- Implemented [BoundingBox.swift](file:///Users/josephmccraw/Dropbox/My%20Mac%20%28MacBook-Air%29/Documents/GitHub/ViewLens/Sources/ViewLensKit/Models/BoundingBox.swift) with normalized top-left origin $[0,1]$ matching SwiftUI frames.
- Implemented [DetectedElement.swift](file:///Users/josephmccraw/Dropbox/My%20Mac%20%28MacBook-Air%29/Documents/GitHub/ViewLens/Sources/ViewLensKit/Models/DetectedElement.swift), [ViewLensIssue.swift](file:///Users/josephmccraw/Dropbox/My%20Mac%20%28MacBook-Air%29/Documents/GitHub/ViewLens/Sources/ViewLensKit/Models/ViewLensIssue.swift), [DoctorReport.swift](file:///Users/josephmccraw/Dropbox/My%20Mac%20%28MacBook-Air%29/Documents/GitHub/ViewLens/Sources/ViewLensKit/Models/DoctorReport.swift), and [AuditReport.swift](file:///Users/josephmccraw/Dropbox/My%20Mac%20%28MacBook-Air%29/Documents/GitHub/ViewLens/Sources/ViewLensKit/Models/AuditReport.swift).

### ✅ Task 1.2: YOLO CoreML Inference & Greedy NMS Engine
- Implemented [YOLODetector.swift](file:///Users/josephmccraw/Dropbox/My%20Mac%20%28MacBook-Air%29/Documents/GitHub/ViewLens/Sources/ViewLensKit/Detector/YOLODetector.swift) with letterbox preprocessing, ANE/GPU CoreML execution, stride-based MultiArray tensor parsing, and [NMS.swift](file:///Users/josephmccraw/Dropbox/My%20Mac%20%28MacBook-Air%29/Documents/GitHub/ViewLens/Sources/ViewLensKit/Detector/NMS.swift).

### ✅ Task 1.3: Deterministic HIG Rules Engine
- Implemented [IssueClassifier.swift](file:///Users/josephmccraw/Dropbox/My%20Mac%20%28MacBook-Air%29/Documents/GitHub/ViewLens/Sources/ViewLensKit/Rules/IssueClassifier.swift) and [HIGRule.swift](file:///Users/josephmccraw/Dropbox/My%20Mac%20%28MacBook-Air%29/Documents/GitHub/ViewLens/Sources/ViewLensKit/Rules/HIGRule.swift) evaluating $44\times 44\text{pt}$ touch target minimums, boundary clipping, cross-class overlaps ($\text{IoU} > 0.30$), and off-screen elements.

### ✅ Task 1.4: Annotated Bounding Box Visual Overlay Generator
- Implemented [OverlayRenderer.swift](file:///Users/josephmccraw/Dropbox/My%20Mac%20%28MacBook-Air%29/Documents/GitHub/ViewLens/Sources/ViewLensKit/Rendering/OverlayRenderer.swift) with CoreGraphics color-coded bounding boxes (green/red/amber) and PNG export.

### ✅ Task 1.5: Swift CLI Binary Implementation (`viewlens`)
- Implemented [ViewLensCLI.swift](file:///Users/josephmccraw/Dropbox/My%20Mac%20%28MacBook-Air%29/Documents/GitHub/ViewLens/Sources/ViewLensCLI/ViewLensCLI.swift), [DoctorCommand.swift](file:///Users/josephmccraw/Dropbox/My%20Mac%20%28MacBook-Air%29/Documents/GitHub/ViewLens/Sources/ViewLensCLI/Commands/DoctorCommand.swift), [ScanCommand.swift](file:///Users/josephmccraw/Dropbox/My%20Mac%20%28MacBook-Air%29/Documents/GitHub/ViewLens/Sources/ViewLensCLI/Commands/ScanCommand.swift), [BatchCommand.swift](file:///Users/josephmccraw/Dropbox/My%20Mac%20%28MacBook-Air%29/Documents/GitHub/ViewLens/Sources/ViewLensCLI/Commands/BatchCommand.swift), [JSONFormatter.swift](file:///Users/josephmccraw/Dropbox/My%20Mac%20%28MacBook-Air%29/Documents/GitHub/ViewLens/Sources/ViewLensKit/Formatters/JSONFormatter.swift), and [TableFormatter.swift](file:///Users/josephmccraw/Dropbox/My%20Mac%20%28MacBook-Air%29/Documents/GitHub/ViewLens/Sources/ViewLensKit/Formatters/TableFormatter.swift).

### ✅ Task 1.6: 100% Pure Swift Native MCP Server (stdio Transport)
- Implemented [MCPServer.swift](file:///Users/josephmccraw/Dropbox/My%20Mac%20%28MacBook-Air%29/Documents/GitHub/ViewLens/Sources/ViewLensKit/MCP/MCPServer.swift), [MCPProtocol.swift](file:///Users/josephmccraw/Dropbox/My%20Mac%20%28MacBook-Air%29/Documents/GitHub/ViewLens/Sources/ViewLensKit/MCP/MCPProtocol.swift), and [MCPCommand.swift](file:///Users/josephmccraw/Dropbox/My%20Mac%20%28MacBook-Air%29/Documents/GitHub/ViewLens/Sources/ViewLensCLI/Commands/MCPCommand.swift) exposing `viewlens_doctor`, `viewlens_audit_screenshot`, and `viewlens_audit_view` over stdio JSON-RPC with zero Python dependencies.

### ✅ Task 1.7: Agent Skill Playbook
- Created [.agents/skills/viewlens/SKILL.md](file:///Users/josephmccraw/Dropbox/My%20Mac%20%28MacBook-Air%29/Documents/GitHub/ViewLens/.agents/skills/viewlens/SKILL.md) documenting agent order of operations and SwiftUI remediation patterns.

### ✅ Task 1.8: Installer & Integration Automation
- Created [scripts/install_mcp.sh](file:///Users/josephmccraw/Dropbox/My%20Mac%20%28MacBook-Air%29/Documents/GitHub/ViewLens/scripts/install_mcp.sh).

---

## Upcoming Milestone 2: Multi-Tier Rendering Canvas & Layout Introspection

- **Task 2.1**: In-Process SwiftUI Virtual Device Canvas (`VirtualDeviceContainer` + `ImageRenderer`).
- **Task 2.2**: Catalyst Headless Subprocess IPC Protocol (CLI-to-Catalyst JSON protocol).
- **Task 2.3**: Mac Catalyst UIKit Offscreen Canvas & Window-Attached Layout Harness.
- **Task 2.4**: Structural Introspection Engine (`hasAmbiguousLayout` + A11y + Truncation).
- **Task 2.5**: CLI `viewlens render` Subcommand.
- **Task 2.6**: MCP `viewlens_audit_view` Matrix Tool.
