# ViewLens Desktop UI Design Specification

**Status:** Proposed implementation baseline  
**Platform:** macOS 14+ / SwiftUI  
**Design direction:** Current Status dashboard + AI Review command center + native inspection workbench  
**Reference concepts:** [AI Review Command Center](DesignConcepts/ui-01-ai-review-command-center.png), [Native Inspection Workbench](DesignConcepts/ui-02-native-inspection-workbench.png), [Current Status Dashboard](DesignConcepts/ui-03-current-status-dashboard.png)

## 1. Purpose

This document defines the product structure, visual language, component behavior, interaction states, accessibility requirements, and implementation plan for the modernized ViewLens macOS application.

The desktop app has three primary jobs:

1. Show whether ViewLens and its audit infrastructure are ready.
2. Explain what an AI-driven accessibility review is doing, found, and recommends.
3. Let a developer manually import or render a screen and validate it with the same ViewLens tooling.

The interface should make **Current Status** and **AI Review** the dominant workflows. **Playground** remains a capable secondary workspace rather than the default landing page.

## 2. Product Principles

### 2.1 Trust before decoration

Every score, status, finding, and recommendation must communicate its source and certainty. ViewLens must distinguish between:

- Passed
- Failed
- Not evaluated
- In progress
- Unavailable
- Stale

A green score must never imply that unevaluated criteria passed.

### 2.2 Review progress must remain understandable

Long-running work exposes its current phase, completed phases, elapsed time, and cancel/retry actions. Activity language describes useful work, such as “Evaluating Dynamic Type at AX5,” instead of generic loading text.

### 2.3 Findings and pixels stay connected

Selecting an issue selects and reveals the related element on the canvas. Selecting an element filters or highlights related findings. This bidirectional selection is the core review interaction.

### 2.4 Native Mac behavior

Use SwiftUI and AppKit conventions for window toolbars, sidebars, inspectors, menus, keyboard shortcuts, drag and drop, focus, selection, context menus, and restoration. Avoid web-dashboard behavior where a native control already exists.

### 2.5 Accessibility is part of the app contract

The ViewLens app itself must model the standards it audits: keyboard operation, VoiceOver semantics, sufficient contrast, Reduce Motion, Increase Contrast, Differentiate Without Color, and usable layouts at large accessibility text sizes.

## 3. Information Architecture

The primary navigation order is:

| Screen | Purpose | Default presentation |
|---|---|---|
| **Current Status** | System readiness, active work, recent reviews, quality trend | App landing screen |
| **AI Review** | Active or selected audit, visual evidence, findings, remediation | Main working screen |
| **Playground** | Manual file import and registered-template validation | Secondary workspace |
| **History** | Search, compare, reopen, and export prior reviews | Review archive |
| **Settings** | Audit policies, integrations, appearance, storage, diagnostics | Configuration |

Supporting surfaces:

- **Inspector:** Contextual issue details and remediation on AI Review.
- **Status popover:** Fast MCP/CoreML readiness details from the toolbar.
- **Import sheet:** File selection, source metadata, and audit options.
- **Diagnostics sheet:** Full doctor report and corrective actions.
- **Export sheet:** JSON, Markdown, annotated PNG, and report bundle options.

## 4. Window and Navigation Model

### 4.1 Window anatomy

Use `NavigationSplitView` as the root structure:

1. **Sidebar:** 216 pt ideal width, 188–280 pt resizable range.
2. **Content:** Current Status, Playground, History, or AI Review canvas.
3. **Inspector:** AI Review details, 320 pt ideal width, 280–420 pt range; hideable.

The toolbar contains:

- Sidebar toggle
- Current context title or breadcrumb
- MCP readiness pill
- Detector readiness pill
- Primary `Import & Validate` action
- Contextual controls such as zoom, overlays, export, and inspector toggle

### 4.2 Window sizing

| Mode | Width | Behavior |
|---|---:|---|
| Minimum | 900 pt | Sidebar may collapse; inspector becomes an overlay or sheet |
| Compact | 900–1199 pt | One supporting column visible at a time |
| Standard | 1200–1599 pt | Sidebar + content + inspector |
| Wide | 1600+ pt | Expanded canvas and activity/details without stretching text |

Minimum window height is 650 pt. Content must remain operable at minimum size without controls overlapping or disappearing.

### 4.3 Sidebar behavior

Each item has an SF Symbol, text label, selection state, and optional badge.

| Item | Symbol | Badge |
|---|---|---|
| Current Status | `waveform.path.ecg` | Active review count when greater than zero |
| AI Review | `sparkles` | Unresolved critical/serious issue count |
| Playground | `flask` | Running indicator only |
| History | `clock.arrow.circlepath` | None |
| Settings | `gearshape` | Attention dot when configuration is invalid |

The sidebar footer shows overall system health. Activating it opens the diagnostics sheet. Health is represented by icon, text, and color.

## 5. Screen Specifications

## 5.1 Current Status

### Purpose

Answer “Is ViewLens ready, what is running, and what needs my attention?” within a few seconds.

### Layout

1. Header with “Current Status,” overall health, last refreshed time, and refresh action.
2. Four status cards: MCP Server, CoreML Detector, Active Reviews, Accessibility Pass Rate.
3. Recent AI Reviews table.
4. Seven-day quality trend.
5. Review Activity feed.
6. Compact “Drop a screen to validate” action leading to Playground/import.

### Status cards

| Card | Content | Interaction | States |
|---|---|---|---|
| MCP Server | Connection state and transport | Opens connection detail | Ready, connecting, disconnected, incompatible, error |
| CoreML Detector | Model identity and compute readiness | Opens model diagnostics | Ready, loading, missing, incompatible, failed |
| Active Reviews | Count and current phase summary | Opens filtered AI Review list | Zero, active, queued, paused, failed |
| Pass Rate | Evaluated criteria pass rate and period | Opens History filtered to period | Available, partial, stale, unavailable |

Status cards are buttons only when they lead somewhere. Noninteractive cards must not imitate button chrome.

### Recent AI Reviews table

Columns:

- Screen/target name
- Source type
- Review status
- Accessibility score
- Issue count by highest severity
- Coverage/completeness
- Last run

Behavior:

- Single click selects a row.
- Double click or Return opens it in AI Review.
- Column headers sort; target name and status can be filtered.
- Context menu supports Open, Re-run, Export, Reveal Source, and Delete.
- Delete requires confirmation and states whether source assets are retained.

States: loading skeleton, populated, filtered-empty, first-use empty, load error, stale data.

### Quality trend

The chart shows score and completeness separately; incomplete audits use a dashed segment. It provides an accessible text summary and keyboard-accessible data points. The graph is supplementary, never the only representation.

### Activity feed

Shows audit start/completion/failure, model readiness changes, and MCP connections. Entries use plain-language summaries and absolute time in their accessibility value.

## 5.2 AI Review

### Purpose

Make an automated audit observable, explainable, and actionable while keeping findings visually anchored to the inspected UI.

### Layout

The standard layout combines the strongest portions of the command-center and workbench concepts:

- **Review summary strip:** score, completion, target, environment, elapsed time.
- **Phase progress:** Import → Render/Detect → Evaluate → AI Review → Complete.
- **Canvas:** source image or rendered device with inspection overlays.
- **Inspector:** findings, reasoning/activity, and remediation.
- **Canvas controls:** zoom, fit, overlay layers, device/environment selector when applicable.

### Review lifecycle

| State | Presentation | Available actions |
|---|---|---|
| No review | Empty canvas with concise import guidance | Import File, Open Recent, Open Playground |
| Preparing | Validating source and configuration | Cancel |
| Queued | Queue position and reason | Cancel, prioritize if supported later |
| Running | Current phase, progress where determinate, live activity | Cancel, hide inspector, inspect completed findings |
| Completed: passed | Score, coverage, passed summary | Export, Re-run, compare |
| Completed: issues | Findings sorted by severity, first actionable issue selected | Apply/Copy guidance, export, re-run |
| Completed: incomplete | Warning banner and unevaluated criteria | Review limitations, re-run with required source |
| Failed | Error explanation with diagnostic detail disclosure | Retry, open diagnostics, copy error |
| Cancelled | Retained partial results clearly labeled partial | Resume/re-run, discard |
| Stale | Results exist but source/config changed | Re-run, inspect old result |

### Review summary

The overall score is shown only with a completeness indicator. Recommended presentation:

- `94` — evaluated compliance score
- `8/8 criteria evaluated` — completeness
- `WCAG 2.2 AA` — target policy
- `Completed 2m ago` — freshness

Score bands are not used as the sole pass/fail decision. The configured quality gate determines pass/fail.

### Phase progress component

Each phase can be pending, active, complete, skipped, failed, or cancelled. Active phases show a spinner or determinate progress. Failed phases expose the error. VoiceOver announces phase changes without repeatedly announcing every progress tick.

### Inspector tabs

1. **Findings:** Default tab. Searchable and filterable issue list.
2. **Activity:** Chronological tool and reasoning events.
3. **Details:** Source, device, Dynamic Type, appearance, detector, audit policy, timing.

Inspector tab selection is restored per window.

### Finding filters

- Severity: Critical, Serious, Moderate, Minor, Passed/Info
- Standard: WCAG, Apple HIG, custom rules
- Criterion
- Element type
- Evaluation state
- Text search

Filter chips must expose selected state programmatically and include a Clear Filters action.

### Finding card

Every finding contains:

- Severity icon, name, and semantic label
- Concise issue title
- Affected element or source location when available
- Observed value and required value
- WCAG/HIG criterion badge
- Confidence when generated from visual detection
- Evaluation environment, such as Dark Mode or AX5
- Disclosure affordance

Expanded content includes explanation, evidence, remediation, code snippet, limitations, and related findings.

Finding states: default, hover, keyboard focus, selected, expanded, copied, applying, resolved, suppressed, stale, and unavailable evidence.

### Remediation actions

- **Copy Guidance:** Copies explanation and optional Swift snippet.
- **Apply Fix:** Display only when an authenticated, reversible edit integration exists. It must preview the affected file and patch before changing code.
- **Mark Resolved:** Local review annotation; does not alter the underlying audit result.
- **Suppress:** Requires a reason and scope; suppression remains visible in reports.
- **Open Source:** Available only with a resolvable file location.

Generated advice is labeled as AI-assisted guidance. Deterministic rule evidence and AI interpretation are visually separated.

### Visual inspector canvas

Layers:

- Source image
- Detected element bounds
- Issue bounds
- Measurement guides
- Safe-area guides
- Dynamic Island/notch obstruction
- Design-diff heatmap
- Selection highlight

Canvas behavior:

- Fit, 50%, 75%, 100%, 200%, and custom zoom.
- Trackpad pinch and Command-plus/minus zoom.
- Space-drag or two-finger pan when zoomed.
- Clicking an element selects it and its top-priority finding.
- Tab/Shift-Tab cycles detected elements when canvas has focus.
- Escape clears selection.
- Overlay visibility is preserved per window.

Overlay colors must remain distinguishable with Differentiate Without Color by combining color with stroke pattern and glyph:

- Error: red, solid 2 pt, error glyph
- Warning: amber, dashed 2 pt, warning glyph
- Pass/detected: teal, solid 1 pt, check/element glyph
- Selection: blue outer focus ring plus semantic overlay
- Safe area: cyan dotted guide

### Empty and drop states

The canvas accepts PNG, JPEG, HEIC, and supported report/template sources. During drag hover, the full canvas receives a clear drop highlight. Unsupported files produce an inline error without discarding the current review.

## 5.3 Playground

### Purpose

Provide a deliberate manual validation workspace for imported files and registered SwiftUI templates.

### Modes

Use a segmented control:

1. **Import File** — screenshot or supported design reference.
2. **Template** — a registered `TemplateRegistry` view.

### Import File mode

Controls:

- File picker/drop zone
- Display scale: Auto, 1×, 2×, 3×
- WCAG target: A, AA, AAA
- Optional device profile
- Minimum detector confidence
- Run Audit button

States: empty, file selected, invalid file, configuring, running, completed, failed.

### Template mode

Controls:

- Template
- Device matrix
- Dynamic Type matrix
- Light/Dark appearance matrix
- WCAG target
- Run Matrix Audit

The existing reactive auto-render behavior becomes an optional “Auto-run when configuration changes” setting. Default is off to prevent expensive or surprising repeated audits.

### Results

Playground audits open in the standard AI Review presentation. Playground retains the source configuration so the user can adjust and re-run it.

## 5.4 History

### Purpose

Manage prior reviews as durable records rather than transient activity events.

### Layout and behavior

- Search field and saved filters
- Table with target, branch/source, score, completeness, status, date, duration
- Preview/detail pane when space permits
- Compare action for two compatible reviews
- Export and deletion actions

History states: loading, populated, filtered-empty, first-use empty, persistence unavailable, corrupt record, migration required.

Comparison highlights score changes, introduced/resolved findings, environment differences, and visual diff when images are available.

## 5.5 Settings

Use a native macOS Settings scene and grouped sections.

### General

- Launch destination: Current Status or last-open screen
- Appearance: System, Light, Dark
- Show menu bar status item
- Confirm before cancelling active reviews

### Audit Policy

- Default WCAG target level
- Target-size policy
- Quality-gate failure severity
- Required evaluation matrix
- Detector confidence
- Custom rule configuration

### Integrations

- MCP installation and connection state
- Model location and version
- CLI location
- Optional source-control or editor integrations

### Storage

- History retention period
- Asset retention policy
- Cache size and clear-cache action
- Export default location

### Accessibility

- Overlay palette preview
- Differentiate Without Color preview
- Reduce Motion behavior summary
- Reset UI scale and panel layout

### Diagnostics

- Full doctor report
- Copy diagnostics
- Re-run checks
- Reveal logs
- Version and build information

Settings controls expose validation inline. Destructive actions state what will be removed and require confirmation.

## 6. Shared Components and States

| Component | Purpose | Core states |
|---|---|---|
| Health pill | Compact service readiness | Ready, busy, warning, error, unavailable, stale |
| Status card | Status overview and optional drill-in | Default, hover, focus, pressed, loading, disabled |
| Score ring | Score plus completeness | Pass, fail, partial, unavailable, stale |
| Severity badge | Finding priority | Critical, serious, moderate, minor, info |
| Criterion badge | Standard reference | WCAG A/AA/AAA, HIG, custom |
| Review row | Review selection in tables/lists | Default, hover, selected, running, failed, stale |
| Finding card | Evidence and remediation | See AI Review finding states |
| Progress timeline | Audit lifecycle | Pending, active, complete, skipped, failed, cancelled |
| Empty state | Explains absent content | First-use, no result, filtered-empty, unavailable |
| Drop zone | Manual source import | Idle, hover-valid, hover-invalid, loading, error |
| Banner | Important contextual notice | Info, warning, error, incomplete, offline |
| Toast | Confirms reversible transient action | Success, failure; auto-dismiss with accessible announcement |
| Skeleton | Preserves layout during initial loading | Animated normally, static with Reduce Motion |

## 7. Visual Style Guidelines

## 7.1 Theme

The signature appearance is graphite with restrained teal/cyan inspection accents. The app also supports a native light appearance. Follow the system setting by default.

Use semantic `Color` values wherever possible. Custom brand colors are accents, not replacements for system foreground/background roles.

### Core color tokens

| Token | Dark reference | Light reference | Use |
|---|---|---|---|
| `surface.window` | `#11161C` | `#F5F6F8` | Window background |
| `surface.sidebar` | `#151B22` | system sidebar material | Navigation |
| `surface.panel` | `#1A2129` | `#FFFFFF` | Cards and inspector groups |
| `surface.elevated` | `#202A33` | `#F8FAFC` | Hover/raised controls |
| `brand.primary` | `#55C7C2` | `#087F83` | Selection accents and guides |
| `brand.focus` | `#4C8DFF` | `#1769E0` | Keyboard focus and primary actions |
| `status.success` | system green | system green | Ready/pass |
| `status.warning` | system orange | system orange | Warning/partial |
| `status.error` | system red | system red | Error/fail |
| `guide.safeArea` | `#39C6E6` | `#007C99` | Safe-area guides |

All final color pairs require automated contrast verification in both appearances. Normal text must meet 4.5:1; large text and meaningful UI graphics must meet 3:1. Focus indicators and control boundaries must meet WCAG 1.4.11.

## 7.2 Typography

Use the system font and semantic text styles.

| Role | SwiftUI style | Weight |
|---|---|---|
| Screen title | `.title` | Bold |
| Section title | `.title3` | Semibold |
| Card metric | 32–48 pt rounded/system | Semibold |
| Primary row label | `.body` | Medium/Semibold when selected |
| Supporting text | `.subheadline` | Regular |
| Metadata | `.caption` | Regular |
| Code | 11–13 pt monospaced | Regular |

Do not hard-code text containers to a single line unless truncation is an intentional table behavior with a tooltip/accessibility value. Support the macOS accessibility text-size setting.

## 7.3 Spacing and sizing

Base spacing unit: 4 pt.

- 4 pt: icon/label micro-spacing
- 8 pt: related control spacing
- 12 pt: compact card padding
- 16 pt: standard panel padding
- 24 pt: section separation
- 32 pt: major region separation

Interactive controls target at least 28×28 pt for macOS pointer use and provide 44×44 pt where the same component is intended for touch/Catalyst. Small icon buttons require tooltips and accessible labels.

## 7.4 Shape and depth

- Compact controls: 6 pt corner radius
- Buttons and chips: 8 pt
- Cards and panels: 10–12 pt
- Large drop zones: 14–16 pt
- Selection ring: 2 pt outer ring, not layout-shifting

Prefer borders, materials, and tonal separation over heavy shadows. Use shadows only for floating inspectors, popovers, device previews, and drag objects.

## 7.5 Iconography

- Use SF Symbols with consistent rendering modes.
- Pair unfamiliar icons with text.
- Use filled variants for selected or active state and regular variants otherwise.
- Never use an icon’s shape or color as the only status cue.
- Product branding should follow the Audit Aperture icon direction; in-app branding uses a simplified flat symbol.

## 7.6 Motion

- Selection and panel transitions: 120–180 ms.
- Inspector disclosure: 180–220 ms.
- Progress changes: smooth but not decorative.
- Avoid continuous pulsing except an active indeterminate process.
- With Reduce Motion, replace movement with opacity or immediate state changes.

## 8. Interaction and Accessibility Guidelines

### Keyboard

Required shortcuts:

| Shortcut | Action |
|---|---|
| Command-1…5 | Navigate primary screens |
| Command-O | Import file |
| Command-R | Re-run selected/current audit |
| Command-E | Export current review |
| Command-F | Focus relevant search/filter field |
| Command-Option-I | Toggle inspector |
| Command-plus/minus/0 | Zoom in/out/fit |
| Space | Temporarily enable canvas pan |
| Escape | Clear selection or dismiss transient surface |

All menus and shortcuts must disable appropriately when their action is unavailable.

### VoiceOver

- Status values combine name, state, and relevant detail.
- Scores announce both score and completeness.
- Charts provide summaries and accessible data children.
- Canvas elements expose type, bounds, confidence, and issue count.
- Every review provides a hierarchical nonvisual outline synchronized with the canvas and findings; the outline is an equal review representation, not a fallback or reduced mode.
- Essential visual relationships and design differences have deterministic text equivalents with evidence provenance and uncertainty.
- Custom rotors provide direct navigation to critical findings, semantic mismatches, headings, interactive elements, and not-evaluated evidence.
- Finding selection changes move visual focus but do not unexpectedly move VoiceOver focus.
- Progress announcements are throttled to meaningful phase changes.

Detailed implementation tasks, journeys for blind and low-vision developers, speech and braille presentation profiles, and release gates are maintained in [ViewLens Nonvisual Authoring Experience Plan](ViewLens-Nonvisual-Authoring-Experience-Plan.md).

### Focus and selection

Keyboard focus uses the blue focus token and remains visible in both themes. Selection and keyboard focus are distinct. When an issue is selected, the associated overlay scrolls/pans into view without stealing focus.

### Errors

Errors state what happened, what was preserved, and what the user can do next. Technical details live in a disclosure region and can be copied. Do not clear a current successful review merely because a new import fails.

## 9. Application State Model

Refactor `AppModel` into focused observable stores while retaining a composition root:

```text
AppState
├── NavigationState
├── SystemHealthStore
├── ReviewStore
│   ├── activeReview
│   ├── selectedReviewID
│   ├── phase/events
│   └── findings/selection/filters
├── CanvasState
│   ├── source image
│   ├── overlays
│   └── zoom/pan/selection
├── PlaygroundState
├── HistoryStore
└── UserPreferences
```

Minimum domain models:

- `ReviewRecord`
- `ReviewSource`
- `ReviewStatus`
- `ReviewPhase`
- `ReviewEvent`
- `ReviewEnvironment`
- `ReviewScore` with completeness
- `FindingFilter`
- `SystemHealthSnapshot`
- `PersistedWorkspaceState`

UI views consume immutable presentation data where practical. Audit orchestration remains outside view bodies and exposes cancellable async operations.

## 10. Persistence and Data Freshness

- Persist review metadata, findings, environment, timestamps, and optional image references.
- Store large images outside preferences and reference them by durable URL.
- Store panel widths, selected screen, filter state, and overlay preferences per window.
- Mark a record stale when its source, audit policy, model version, or relevant configuration changes.
- Include schema versioning and migration handling from the first persistent release.
- Retention and deletion behavior follows Settings and is explicit to the user.

## 11. Implementation Plan

This redesign becomes Milestones 8–13 after the completed foundation work in `TASKS.md`.

### Milestone 8 — Design System and Shell

- [ ] **UI-8.1** Create semantic color, spacing, radius, typography, and animation tokens.
- [ ] **UI-8.2** Build reusable status pills, severity/criterion badges, cards, banners, empty states, drop zones, and progress timeline.
- [ ] **UI-8.3** Replace the segmented sidebar workspace with `NavigationSplitView` and five primary destinations.
- [ ] **UI-8.4** Add native toolbar commands, menus, keyboard shortcuts, inspector toggle, and window restoration.
- [ ] **UI-8.5** Add System/Light/Dark appearance support and accessibility-environment previews.
- [ ] **UI-8.6** Create SwiftUI previews covering component states, high contrast, Reduce Motion, and large text.

**Acceptance:** The shell works from 900 pt through wide windows; every navigation action is keyboard accessible; shared components render correctly in both appearances.

### Milestone 9 — State and Review Domain

- [x] **UI-9.1** Split `AppModel` into navigation, health, review, canvas, playground, history, and preference stores.
- [x] **UI-9.2** Define review lifecycle, source, environment, score/completeness, event, and persistence models.
- [x] **UI-9.3** Convert rendering, screenshot auditing, accessibility auditing, and doctor checks to cancellable async orchestration.
- [x] **UI-9.4** Add stable review/finding identifiers and bidirectional issue-element selection.
- [x] **UI-9.5** Add structured error, partial-result, stale-result, and cancellation handling.
- [x] **UI-9.6** Add review repository protocol and in-memory implementation for previews/tests.

**Acceptance:** Review state transitions are deterministic and unit tested; cancelling one review cannot corrupt a prior result; incomplete audits never appear fully passing.

### Milestone 10 — Current Status

- [x] **UI-10.1** Implement health header and four status cards backed by actual doctor/MCP/review data.
- [x] **UI-10.2** Implement recent-review table with sorting, filtering, selection, context menu, and keyboard opening.
- [x] **UI-10.3** Implement accessible quality trend and textual summary.
- [x] **UI-10.4** Implement system/review activity feed.
- [x] **UI-10.5** Add quick import/drop action and diagnostics drill-in.
- [x] **UI-10.6** Cover loading, empty, partial, stale, and error states.

**Acceptance:** A user can determine readiness and open or start a review without visiting another screen; all status signals include non-color cues.

### Milestone 11 — AI Review Workbench

- [x] **UI-11.1** Implement review header, score/completeness summary, environment metadata, and phase timeline.
- [x] **UI-11.2** Refactor `VisualInspectorView` into a reusable zoomable/pannable canvas with layer controls.
- [x] **UI-11.3** Add patterned semantic overlays, keyboard element navigation, and selection reveal.
- [x] **UI-11.4** Implement Findings inspector with search and severity/standard/criterion/element filters.
- [x] **UI-11.5** Implement expandable finding details, evidence, deterministic remediation, AI guidance labeling, and copy feedback.
- [x] **UI-11.6** Implement Activity and Details inspector tabs.
- [x] **UI-11.7** Implement review empty, running, complete, incomplete, failed, cancelled, and stale states.
- [x] **UI-11.8** Add export actions for JSON, Markdown, annotated PNG, and report bundle.
- [x] **UI-11.9** Gate Apply Fix behind a patch-preview integration; do not ship a nonfunctional action.

**Acceptance:** Findings and canvas elements remain synchronized; every review lifecycle state has a defined UI; an exported report preserves score completeness and unevaluated criteria.

### Milestone 12 — Playground, History, and Settings

- [x] **UI-12.1** Rebuild Playground with Import File and Template modes.
- [x] **UI-12.2** Add explicit audit configuration and optional auto-run preference.
- [x] **UI-12.3** Route Playground results into the shared AI Review workbench.
- [x] **UI-12.4** Implement durable review storage with schema migration and configurable retention.
- [x] **UI-12.5** Implement History search, filters, reopen, re-run, compare, export, and deletion.
- [x] **UI-12.6** Implement native Settings scene sections and inline validation.
- [x] **UI-12.7** Implement diagnostics and storage-management sheets.

**Acceptance:** Imported and template audits share one result model; reviews survive relaunch; destructive storage operations are confirmed and testable.

### Milestone 13 — Verification and Release Quality

- [x] **UI-13.1** Add unit tests for all domain state transitions, filters, scoring/completeness, persistence, and migrations.
- [x] **UI-13.2** Add UI tests for primary navigation, keyboard shortcuts, import, review selection, filters, export, and cancellation.
- [x] **UI-13.3** Add VoiceOver labels/values/actions and Accessibility Inspector test checklist.
- [x] **UI-13.4** Validate Increase Contrast, Differentiate Without Color, Reduce Motion, and accessibility text sizes.
- [x] **UI-13.5** Register representative desktop views in `TemplateRegistry` where feasible and run ViewLens self-audits.
- [x] **UI-13.6** Capture deterministic reference screenshots for compact/standard/wide windows in Light and Dark appearances.
- [x] **UI-13.7** Run visual diffs against approved design baselines and resolve material drift.
- [ ] **UI-13.8** Run `swift test` and the macOS Xcode build/test suite.

**Verification status (2026-08-23):** `swift test` passes 43 tests, the signed macOS app suite passes 15 tests, all six reference diffs pass, and the desktop self-audit reports WCAG 2.2 AA compliant at 100%. The six workflow UI tests and an isolated runner-handshake test compile and sign. On this host, `ViewLensUITests-Runner` is spawned but never establishes its XCTest session—even the handshake test that does not launch ViewLens waits indefinitely. Complete UI-13.8 by resolving the host Xcode/XCTest runner session and recording a passing UI suite.

**Acceptance:** No critical accessibility defects; keyboard-only completion of primary workflows; approved visual baselines; all automated tests and builds pass.

## 12. Recommended Delivery Order

The shortest path to a coherent usable release is:

1. Design tokens and navigation shell.
2. Review domain/state refactor.
3. AI Review workbench using current in-memory audit data.
4. Current Status using the same review domain.
5. Playground routing into AI Review.
6. Persistence and History.
7. Settings, diagnostics, exports, and comparison.
8. Full accessibility and visual-diff verification.

This order proves the primary review experience early and avoids implementing dashboard/history UI against temporary data structures.

## 13. Proposed SwiftUI File Structure

The exact split can evolve during implementation, but ownership should remain clear:

```text
ViewLens
├── App
│   ├── ViewLensApp.swift
│   ├── AppCommands.swift
│   └── AppState.swift
├── DesignSystem
│   ├── ViewLensColors.swift
│   ├── ViewLensMetrics.swift
│   ├── ViewLensTypography.swift
│   └── Components
├── Models
│   ├── ReviewRecord.swift
│   ├── ReviewLifecycle.swift
│   ├── ReviewEnvironment.swift
│   └── SystemHealthSnapshot.swift
├── Services
│   ├── ReviewCoordinator.swift
│   ├── ReviewRepository.swift
│   ├── ExportService.swift
│   └── PreferencesStore.swift
├── Features
│   ├── CurrentStatus
│   ├── AIReview
│   ├── Playground
│   ├── History
│   ├── Settings
│   └── Diagnostics
└── Shared
    ├── InspectionCanvas
    ├── FindingViews
    └── EmptyAndErrorStates
```

Existing views should be migrated, not blindly duplicated:

| Existing implementation | Destination |
|---|---|
| `DoctorStatusView` | Health pills, Current Status cards, Diagnostics sheet |
| `VisualInspectorView` | Shared `InspectionCanvas` used by AI Review |
| `IssuesSidebarView` | AI Review Findings inspector |
| `ActivityLogView` | Review Activity inspector/feed |
| `TemplatePlaygroundView` | Playground Template mode |
| `AppModel` audit methods | `ReviewCoordinator` and focused stores |

## 14. Decisions and Deferred Scope

### Baseline decisions

- Current Status is the default landing screen.
- AI Review is the primary work surface.
- Playground is a secondary source/configuration surface.
- Dark graphite is the signature theme; System appearance is the default preference.
- Scores always appear with audit completeness.
- Deterministic findings and AI-authored guidance remain distinguishable.
- Apply Fix is not shown until a safe preview-and-confirm integration exists.

### Deferred until separately specified

- Multi-user accounts and cloud synchronization
- Remote review queues
- Automatic source-code modification without patch preview
- Figma account/browser integration beyond importing a reference image
- Plugin marketplace or third-party rule store
- Team annotations, comments, and assignment workflows

## 15. Definition of Done for the Modernized UI

The redesign is complete when a user can:

1. Launch ViewLens and immediately understand system readiness.
2. Import or receive an audit and observe meaningful progress.
3. Inspect findings while seeing the exact affected UI elements.
4. Understand score, coverage, evidence, and remediation without ambiguity.
5. Re-run, export, find, and compare durable reviews.
6. Configure audit policy and diagnose the local installation.
7. Complete every primary workflow using keyboard and VoiceOver.
8. Use the app in Light/Dark Mode and relevant macOS accessibility settings without loss of content or meaning.
