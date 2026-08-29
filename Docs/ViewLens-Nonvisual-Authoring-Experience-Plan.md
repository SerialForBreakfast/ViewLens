# ViewLens Nonvisual Authoring Experience Plan

**Status:** Proposed cross-cutting implementation backlog  
**Scope:** NV workstream across M14–M18  
**Outcome:** A blind developer can independently understand a screen's visual and semantic structure, find an accessibility defect, locate remediation context, verify a change, and export evidence without relying on sighted interpretation.

## 1. Product contract

ViewLens is both an authoring tool and an accessibility evaluation tool. The workstream therefore follows the two-part model in the [W3C Authoring Tool Accessibility Guidelines](https://www.w3.org/WAI/standards-guidelines/atag/): the tool itself must be accessible, and it must actively help authors produce accessible interfaces.

ViewLens must:

- Treat the nonvisual screen model as an equal representation of a review, not a fallback description of the visual canvas.
- Keep visual structure, accessibility semantics, navigation order, findings, and eventual source provenance synchronized through stable identifiers.
- Prefer concise relational descriptions such as “below Password” or “inside the navigation bar” over raw coordinates, while keeping measured geometry available on demand.
- Distinguish measured platform evidence, deterministic derivation, model inference, and unavailable evidence in every representation.
- Never treat a screenshot prediction as proof of an accessible name, role, value, state, action, reading order, or VoiceOver behavior.
- Support VoiceOver, keyboard-only navigation, and refreshable braille without requiring drag, hover, pointer gestures, color interpretation, or visual focus tracking.
- Offer user-selected speech, braille, and developer-detail presentation profiles without assuming a profile from disability or assistive-technology usage.
- Keep deterministic evidence separate from AI-authored explanation and require preview and approval before any proposed source change.

ViewLens must not:

- Claim complete VoiceOver or assistive-technology conformance from static hierarchy inspection or a predicted traversal transcript.
- Generate visual descriptions that hide uncertainty or invent content not supported by captured evidence.
- Make workflows used by blind developers a segregated mode with reduced functionality.
- Announce every progress update, move VoiceOver focus to follow visual selection, or require users to traverse decorative preview content.
- Store credentials, personal production data, or unredacted secure-field values in semantic trees, transcripts, task records, or reports.

## 2. Primary user journeys

### NV-J1 — Understand an unfamiliar screen

The developer imports, renders, or captures a screen and receives a concise screen summary, region outline, element inventory, visual relationships, completeness statement, and top findings without opening the image.

### NV-J2 — Compare pixels with semantics

The developer can identify controls that are visually present but absent from the accessibility hierarchy, accessibility nodes with no visible equivalent, visible-label/name conflicts, missing state, incorrect grouping, and meaningful-order differences.

### NV-J3 — Inspect the screen-reader experience

The developer can navigate a predicted VoiceOver transcript, heading and rotor inventory, custom actions, control states, announcements, modal boundaries, and focus restoration evidence. Unsupported behavior is presented as a manual verification requirement rather than a pass.

### NV-J4 — Understand a visual regression

The developer receives a prioritized textual diff describing added, removed, moved, resized, restyled, clipped, and semantically changed elements. Cosmetic pixel noise is separated from material accessibility or layout changes.

### NV-J5 — Repair and verify

The developer can move from a finding to responsible source context, copy deterministic remediation, preview an agent-proposed patch, rerun affected states, and hear a before/after verification summary.

### NV-J6 — Collaborate with mixed-vision teams

The exported review contains the same stable finding and element identifiers in its text, JSON, semantic outline, source links, screenshots, and overlays so collaborators who are blind, have low vision, or are sighted can discuss the same evidence.

## 3. Dependency sequence

```text
NV-0 Co-design and baseline
  └─ NV-1 Shared nonvisual evidence model
       ├─ NV-2 Accessible Mac authoring experience
       └─ NV-3 MCP, CLI, and export surfaces
            └─ NV-4 Runtime accessibility and navigation intelligence
                 └─ NV-5 Semantic diff, source remediation, and verification
                      └─ NV-6 Blind-developer release validation
```

NV-1 is the contract shared by every later surface. NV-2 and NV-3 may proceed in parallel after its schema and fixtures stabilize. NV-4 aligns with M15–M16, NV-5 aligns with M17, and the interactive MCP App in M18 must reuse NV-1 rather than inventing a separate accessibility representation.

## 4. Task backlog

### NV-0 — Co-design, terminology, and baseline

- [ ] **NV-0.1** Write a research protocol with blind developers covering screen understanding, finding navigation, design-diff interpretation, remediation, verification, and report handoff; include VoiceOver and refreshable-braille workflows.
- [x] **NV-0.2** Define respectful product terminology and documentation guidance for blindness, low vision, screen-reader usage, and evidence limitations; avoid assuming identical preferences or abilities. *(The house style is published in the [ViewLens Nonvisual & Accessible Authoring Guide](ViewLens-Nonvisual-Authoring-Guide.md#language-and-audience-terminology).)*
- [ ] **NV-0.3** Capture baseline completion time, error rate, assistance requests, navigation count, and confidence for the six primary journeys using the current Mac app and MCP/CLI surfaces.
- [ ] **NV-0.4** Create deterministic fixture screens containing missing names, visible/programmatic-name conflicts, incorrect grouping, meaningful-order defects, modal focus loss, color-only state, clipped AX5 content, and a material visual regression. *(The first runtime-evidence JSON fixture now covers visual/semantic counterpart gaps, name conflict, missing state, order divergence, and clipping; grouping, modal restoration, AX5, color-only, and before/after visual-regression fixtures remain.)*
- [x] **NV-0.5** Record an ADR establishing the nonvisual model as a first-class review representation and defining the boundary between measured evidence, deterministic derivation, inference, and human verification. *(Recorded in [ADR-010-Nonvisual-Evidence-Model.md](ADR/ADR-010-Nonvisual-Evidence-Model.md).)*

**Acceptance:** The team has repeatable tasks, representative fixtures, baseline measurements, and at least one review of the plan by blind developers before interaction design is frozen.

### NV-1 — Shared nonvisual evidence model

- [x] **NV-1.1** Define versioned `NonvisualScreenModel`, `NonvisualRegion`, `NonvisualElement`, `SpatialRelationship`, `NavigationSequence`, `SemanticMismatch`, and `EvidenceProvenance` types in `ViewLensKit`.
- [x] **NV-1.2** Give regions, elements, findings, runtime nodes, and future source records stable cross-references; preserve identifiers through persistence, comparison, MCP resources, and exports.
- [x] **NV-1.3** Implement a deterministic relational-geometry engine that produces bounded descriptions such as above, below, leading, trailing, contained by, overlapping, aligned, clipped, and off-screen.
- [x] **NV-1.4** Implement visual-versus-semantic mismatch categories for missing visual/semantic counterparts, visible-label/name conflicts, missing role/value/state/action, duplicate exposure, incorrect grouping, and order divergence.
- [x] **NV-1.5** Add a screen-summary composer that reports purpose, major regions, element counts, top blocking findings, evidence completeness, and recommended next navigation target.
- [x] **NV-1.6** Add presentation renderers for `speech`, `braille`, and `developer` detail profiles with stable ordering, bounded verbosity, and on-demand expansion.
- [x] **NV-1.7** Require every statement to carry `measured`, `derived`, `inferred`, or `unavailable` provenance plus confidence where inference is involved.
- [x] **NV-1.8** Add schema-validation, deterministic-ordering, serialization, migration, malformed-input, unavailable-evidence, and golden narrative tests.

**Acceptance:** The same fixture produces deterministic JSON and human-readable summaries; screenshot-only input cannot produce a semantic pass; every statement can be traced to its evidence type.

### NV-2 — Accessible Mac authoring experience

- [x] **NV-2.1** Add a hierarchical Nonvisual Outline beside the visual canvas with screen, region, group, and element nodes; make it available for every review even when overlays are hidden.
- [x] **NV-2.2** Synchronize outline, canvas, finding, and source selection without moving VoiceOver focus unexpectedly; selection changes announce a concise status only when initiated outside the focused representation.
- [x] **NV-2.3** Add custom VoiceOver rotors for critical findings, all findings, unlabeled controls, headings, interactive elements, semantic mismatches, and not-evaluated evidence.
- [x] **NV-2.4** Expose each element's name, role, value, state, actions, region, relational position, size, confidence, issue count, and evidence provenance through structured accessibility children.
- [x] **NV-2.5** Replace pointer-oriented canvas guidance with input-aware instructions and ensure import, pan alternatives, element navigation, filtering, comparison, export, and cancellation are fully operable from menus and keyboard.
- [x] **NV-2.6** Add explicit speech, braille, and developer-detail preferences; preserve them per user and never enable them solely because VoiceOver is running.
- [x] **NV-2.7** Add a textual design-diff view grouped by accessibility impact, semantic impact, layout impact, and cosmetic-only changes.
- [x] **NV-2.8** Provide accessible chart data tables and concise trend summaries with direct navigation to the reviews responsible for material changes.
- [x] **NV-2.9** Throttle announcements to phase changes, input-required decisions, new blocking findings, cancellation, failure, and completion; never announce every percentage tick.
- [ ] **NV-2.10** Add Mac UI tests for complete keyboard and VoiceOver execution of NV-J1 through NV-J4, including minimum window size, Increase Contrast, Reduce Motion, and Differentiate Without Color. *(Deterministic NV-J1–NV-J4 UI fixtures, accessibility identifiers, keyboard-selection assertions, minimum-window/accommodation cases, and the [manual VoiceOver/braille matrix](NV-2.10-VoiceOver-Keyboard-Verification.md) are implemented. The target builds, but completion remains open until the host UI automation service runs the suite successfully and the manual checks are recorded.)*

**Acceptance:** A VoiceOver user can import a fixture, understand the screen, navigate all findings and elements, inspect evidence, compare two reviews, and export results without interacting with the image or using a pointer.

### NV-3 — MCP, CLI, prompt, and export surfaces

- [x] **NV-3.1** Add bounded MCP resources for `viewlens://reviews/{reviewId}/nonvisual-summary`, `/semantic-outline`, `/navigation`, and `/visual-diff-narrative` with explicit unavailable states.
- [x] **NV-3.2** Add `viewlens_nonvisual_review` prompt workflow that prioritizes semantics, focus/reading order, visual-semantic mismatches, completeness, and deterministic remediation.
- [x] **NV-3.3** Define a shared `NonvisualPresentationProfile` for MCP, CLI, and exports with speech, braille, and developer detail; presentation changes must not alter underlying evidence.
- [x] **NV-3.4** Add CLI formats and flags for concise screen summary, outline, transcript, mismatch-only output, and textual design diff without requiring image or ANSI-canvas interpretation.
- [x] **NV-3.5** Make durable task status messages concise and meaningful in speech and braille, and expose task input-required decisions without repeated polling narration.
- [x] **NV-3.6** Extend Markdown, JSON, and report-bundle exports with the nonvisual model, stable anchors, evidence provenance, and textual equivalents for every overlay, chart, and heatmap.
- [x] **NV-3.7** Add golden MCP/CLI fixtures for complete, partial, inferred, unavailable, cancelled, expired, and input-required nonvisual workflows across supported compatibility eras.
- [x] **NV-3.8** Add token and output-size budgets with summary-first pagination so screen-reader users and LLM clients can request detail without receiving an unbounded transcript.

**Acceptance:** A blind developer can complete NV-J1, NV-J2, and NV-J4 through a coding agent or terminal, and every visual artifact in an exported review has a stable textual equivalent.

### NV-4 — Runtime accessibility and navigation intelligence

- [x] **NV-4.1** Capture native accessibility hierarchies with names, roles, values, states, hints, headings, groups, landmarks, actions, frames, identifiers, and provenance where platform APIs permit.
- [x] **NV-4.2** Build reading-order, keyboard-focus, and predicted VoiceOver traversal sequences as separate graphs; report divergences only when they affect understanding or operation.
- [x] **NV-4.3** Capture rotor candidates and custom actions, and detect missing headings, unusable grouping, action-name conflicts, duplicate exposure, and excessive announcement text.
- [x] **NV-4.4** Record focus before and after modal presentation, dismissal, validation errors, navigation, async updates, and state restoration; detect loss, traps, hidden focus, and background escape.
- [x] **NV-4.5** Capture accessibility announcements and status changes in fixture workflows with throttling, ordering, and duplicate-announcement analysis.
- [x] **NV-4.6** Produce a predicted VoiceOver transcript clearly labeled as API-derived evidence, not a recording or proof of complete VoiceOver behavior.
- [x] **NV-4.7** Generate bounded manual verification steps for gestures, speech timing, pronunciation, braille output, rotor behavior, and platform behavior that cannot be automated reliably.
- [x] **NV-4.8** Run declared flows under VoiceOver-relevant states plus Dynamic Type, Increase Contrast, Differentiate Without Color, Reduce Motion, RTL, orientation, and window-size variants.
- [x] **NV-4.9** Redact secure fields and fixture secrets before hierarchy, transcript, logs, task state, resources, or exports are persisted.

**Acceptance:** A fixture workflow exports reproducible semantic and navigation graphs, identifies seeded traversal and focus defects, and marks unsupported assistive-technology behavior not evaluated.

### NV-5 — Semantic diff, source remediation, and verification

- [x] **NV-5.1** Implement semantic before/after diffing for elements, names, roles, values, states, actions, groups, reading order, focus order, and completeness independent of pixel SSIM.
- [x] **NV-5.2** Implement narrative visual diffing for added, removed, moved, resized, restyled, clipped, overlapped, and off-screen elements; separate material changes from cosmetic noise.
- [x] **NV-5.3** Rank changes by blocking accessibility impact, semantic impact, layout impact, and cosmetic-only impact with deterministic rationale.
- [x] **NV-5.4** Connect nonvisual nodes and mismatches to file, line, symbol, runtime identity, and relevant SwiftUI/UIKit accessibility modifiers where provenance exists.
- [x] **NV-5.5** Provide remediation context that includes current semantics, expected behavior, cited requirement, deterministic guidance, and a bounded source excerpt suitable for speech or braille.
- [x] **NV-5.6** Add patch-preview handoff with explicit affected nodes, expected semantic changes, scope, and rollback instructions; ViewLens does not apply the patch itself.
- [x] **NV-5.7** Add targeted verification that reruns affected states and announces resolved, remaining, introduced, not-evaluated, and visually changed results.
- [x] **NV-5.8** Generate accessible regression tests for hierarchy, focus order, names, roles, values, and critical visual relationships when deterministic assertions are possible.

**Acceptance:** A developer can move from a seeded defect to responsible source context and obtain a deterministic before/after verification without interpreting a screenshot or heatmap.

### NV-6 — Blind-developer validation and release gate

- [ ] **NV-6.1** Conduct formative usability sessions with blind developers after NV-1, NV-2, and NV-4 rather than waiting for final release.
- [ ] **NV-6.2** Test primary workflows with current macOS VoiceOver, keyboard-only navigation, and representative refreshable braille displays; track configuration and platform versions.
- [ ] **NV-6.3** Separately test low-vision accommodations such as zoom, contrast, text size, appearance, motion, and focus visibility without treating those sessions as substitutes for testing with blind participants.
- [ ] **NV-6.4** Measure independent journey completion, time to first blocking finding, navigation count, source-location success, fix-verification success, assistance requests, false confidence, and subjective trust against NV-0 baselines.
- [ ] **NV-6.5** Add automated regression gates for keyboard reachability, accessibility labels/values/actions, rotor inventories, focus restoration, nonvisual golden output, and visual/text artifact parity.
- [ ] **NV-6.6** Audit ViewLens against applicable WCAG, Apple accessibility guidance, and the ATAG Part A/Part B model; document supported, partially supported, and not-evaluated requirements.
- [ ] **NV-6.7** Complete privacy and threat review for captured accessibility values, screen text, source excerpts, transcripts, task persistence, and exported collaboration artifacts.
- [x] **NV-6.8** Publish accessible documentation and end-to-end examples for Mac app, CLI, MCP agent, report handoff, and manual VoiceOver verification workflows.

**Acceptance:** Blind developers complete all six primary journeys without sighted assistance in the release study; no blocking issue remains; unsupported evidence is never reported as passed; release documentation states tested assistive technologies and limitations.

## 5. First implementation slice — NV-A

Implement the smallest end-to-end text-first workflow before runtime automation:

1. **NV-0.4** deterministic nonvisual fixtures.
2. **NV-1.1–NV-1.4** shared model, stable references, relational geometry, and semantic mismatch categories.
3. **NV-1.5–NV-1.8** summary, presentation, provenance, and golden tests.
4. **NV-3.1** nonvisual summary and outline resources.
5. **NV-2.1–NV-2.2** synchronized Mac outline and selection contract.
6. **NV-2.10 / NV-3.7** VoiceOver, MCP, CLI, and serialization verification.

NV-A deliberately does not predict VoiceOver behavior from screenshots. It establishes the evidence contract and allows a blind developer to understand a static or rendered screen before M15–M16 runtime hierarchy capture is available.

## 6. Program-level definition of done

The workstream is complete only when a blind developer can independently:

1. Start or import a review and understand its source, state, progress, and evidence completeness.
2. Navigate a nonvisual screen outline and understand major visual relationships.
3. Compare visible content with captured accessibility semantics and navigation order.
4. Identify blocking findings and distinguish measured facts from inference or unavailable evidence.
5. Interpret material visual and semantic changes between reviews.
6. Reach responsible source context, review remediation, and verify a proposed change.
7. Export and discuss the same stable evidence with collaborators who are blind, have low vision, or are sighted.
8. Complete every operation with VoiceOver and keyboard and consume essential output efficiently on a refreshable braille display.
