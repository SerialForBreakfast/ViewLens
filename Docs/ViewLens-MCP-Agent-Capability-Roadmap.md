# ViewLens MCP & Agent Capability Roadmap

**Status:** Proposed implementation backlog  
**Scope:** Milestones M14–M18  
**Purpose:** Give language models native Apple UI capabilities that source code and screenshots alone cannot provide, while keeping measurement deterministic, operations bounded, and consequential actions under user control.

## 1. Product boundary

ViewLens supplies native evidence and controlled runtime operations. The host agent interprets evidence, proposes code changes, and edits source files.

ViewLens must:

- Return measured frames, semantic properties, screenshots, diffs, scores, completeness, and provenance as structured evidence.
- Distinguish `passed`, `failed`, and `notEvaluated`; missing evidence must never become an implicit pass.
- Use allowlisted operations and explicit workspace, application, destination, and artifact scopes.
- Require user-visible approval before destructive operations, baseline replacement, external publication, or execution that expands the declared scope.
- Return opaque, expiring handles for durable review, task, and runtime state.
- Preserve a text result for legacy clients while providing typed structured results and artifact resources to modern clients.

ViewLens must not:

- Offer arbitrary shell execution through MCP.
- Apply source edits or patches directly as part of an audit tool.
- Infer successful accessibility semantics from pixels when a semantic hierarchy is unavailable.
- Store credentials in task state, logs, resources, tool arguments, or form-mode elicitation.
- Permit a session handle to bypass authorization or workspace boundaries.

## 2. Delivery sequence

```text
M14 Protocol foundation
  └─ M15 Live native sessions
       └─ M16 Interaction and accessibility graph
            └─ M17 Source provenance and fix verification
                 └─ M18 Interactive app and remote collaboration
```

M14 is a hard dependency for every later milestone. M15 and M16 may use fake runtime backends during development, but production runtime tools cannot ship without M14 compatibility and cancellation coverage. M17 instrumentation can be prototyped in parallel with M16 after the session and element identity contracts stabilize.

The cross-cutting **NV Nonvisual Authoring Experience** workstream begins during M14 and reuses the same evidence, runtime, provenance, and MCP App contracts through M18. Its detailed blind-developer journeys, dependency-ordered tasks, and release criteria are maintained in [ViewLens Nonvisual Authoring Experience Plan](ViewLens-Nonvisual-Authoring-Experience-Plan.md). NV-1 now provides the shared model, deterministic summaries, speech/braille/developer presentations, statement-level provenance, schema validation, and migration boundaries; NV-2 integrates that representation into the Mac authoring experience.

## 3. Shared definitions of done

Every task is complete only when:

- Public request, result, error, and resource schemas are documented and covered by golden JSON fixtures.
- Unit tests cover success, invalid input, unavailable evidence, cancellation, expiry, and authorization/scope rejection where applicable.
- Integration tests use a deterministic fixture app or fake backend; hardware- or permission-dependent tests are explicitly gated.
- Results report evidence completeness and never silently omit a requested check.
- Every essential visual artifact has a stable text equivalent, and nonvisual output identifies measured, derived, inferred, and unavailable evidence.
- New tools and workflows are added to `.agents/skills/viewlens/SKILL.md` and CLI/MCP help where applicable.
- `swift test`, MCP protocol fixtures, and relevant Xcode builds pass.
- Security-sensitive behavior is recorded in a threat-model or ADR update before release.

---

## M14 — Modern MCP Protocol & Structured Evidence

**Outcome:** A backward-compatible MCP foundation that returns typed, token-efficient evidence and supports long-running, interruptible workflows.

### Protocol and compatibility

- [x] **MCP-14.1** Replace the fixed protocol constant with negotiated protocol-version handling and explicit compatibility eras.
- [x] **MCP-14.2** Preserve support for the existing `2024-11-05` tool surface while adding modern request metadata and result envelopes behind negotiated capabilities.
- [ ] **MCP-14.3** Create golden initialize, discovery, list, call, error, input-required, task, and cancellation fixtures for every supported era. *(Initialize, discovery, list-envelope, call-error, progress, cancellation, task creation, task input-required, required-metadata, and unsupported-version coverage complete; comprehensive every-era conformance coverage remains.)*
- [ ] **MCP-14.4** Validate request IDs, method parameters, required metadata, schema dialects, pagination cursors, and unsupported-capability behavior without crashing the server loop.
- [ ] **MCP-14.5** Add a protocol conformance command/test target suitable for CI and MCP Inspector automation.

### Typed tools and evidence

- [x] **MCP-14.6** Extend `MCPTool` with title, icons, behavioral annotations, `outputSchema`, and strict JSON Schema 2020-12 inputs where supported.
- [x] **MCP-14.7** Return `structuredContent` for doctor, screenshot audit, template audit, accessibility audit, and design diff while retaining serialized JSON `TextContent` for legacy clients.
- [ ] **MCP-14.8** Add native image content, embedded resources, and resource links for previews, overlays, heatmaps, reports, and logs instead of embedding artifact paths only in prose. *(Generated overlays and heatmaps emit `resource_link` content and can be read as bounded binary MCP resources; embedded previews and task logs remain.)*
- [x] **MCP-14.9** Standardize a shared evidence envelope: schema version, review ID, source mode, target, environment, completeness, findings, artifacts, timing, warnings, and recovery actions.
- [x] **MCP-14.10** Define stable machine-readable error codes for invalid input, unsupported capability, unavailable evidence, expired handle, permission denial, cancellation, build failure, and runtime failure.

### Resources, prompts, and long-running operations

- [ ] **MCP-14.11** Implement resource discovery/read for `viewlens://reviews`, findings, semantic trees, screenshots, overlays, baselines, task logs, and exported reports. *(Review envelopes, findings, typed reports, overlays, heatmaps, and explicit empty-state catalogs are implemented; native semantic-tree, screenshot, baseline, task-log, and exported-report producers remain.)*
- [ ] **MCP-14.12** Add parameterized resource templates and bounded subscriptions for active reviews and task progress. *(Review, findings, report, and artifact URI templates are implemented; subscriptions remain.)*
- [x] **MCP-14.13** Publish prompt workflows for screenshot audit, design verification, release accessibility audit, regression triage, and fix verification.
- [x] **MCP-14.14** Implement progress reporting and cooperative cancellation for render matrices, batch audits, design diffs, and exports. *(The current MCP audit surface and overlay/heatmap exports have monotonic progress and cooperative checkpoints; task-aware calls use the durable MCP-14.15 state model.)*
- [x] **MCP-14.15** Implement durable task handles for long-running operations, including working, input-required, completed, failed, cancelled, TTL, polling, and recovery after reconnect. *(Modern task-capable clients can create durable screenshot, matrix, accessibility, and design-diff tasks; poll, update, cancel, and recover them after a server reconnect. Task records are private, bounded, expiring, and reject credential-like persisted inputs.)*
- [ ] **MCP-14.16** Add form-mode elicitation for non-sensitive ambiguity and approval decisions; reserve URL mode for authentication or sensitive external interactions.
- [ ] **MCP-14.17** Add deterministic list ordering, pagination, cache metadata, list-changed notifications, and compatibility tests for clients that ignore optional capabilities. *(Resource ordering, bounded pagination, cursor rejection, and modern private/public cache hints are implemented; tool-list parity and list-changed notifications remain.)*

**Acceptance:** Existing five tools remain usable by legacy clients; modern clients receive schema-valid structured evidence and artifact resources; a matrix audit can report progress, be cancelled, and be resumed through a durable task handle; protocol conformance fixtures pass in CI.

### First iteration slice — M14A

Implement this slice before other M14 work:

1. **MCP-14.1** protocol negotiation.
2. **MCP-14.3** golden compatibility fixtures.
3. **MCP-14.6** typed tool definitions and output schemas.
4. **MCP-14.7** structured results for `viewlens_doctor` and `viewlens_audit_screenshot`.
5. **MCP-14.10** stable error codes.

M14A deliberately excludes runtime control and remote transport. It proves compatibility and the evidence contract with the smallest useful surface.

---

## M15 — Live Native Review Sessions

**Outcome:** An agent can open a bounded review session against a real macOS app or Apple simulator, capture native state, and query spatial and semantic evidence without arbitrary process control.

### Session and destination model

- [x] **MCP-15.1** Define `RuntimeSession`, opaque `session_id`, ownership, TTL, lease renewal, expiry, cleanup, and reconnect behavior.
- [x] **MCP-15.2** Implement destination discovery for supported macOS apps and booted/available Apple simulators with stable IDs and readiness diagnostics.
- [x] **MCP-15.3** Define a scoped launch descriptor: workspace root, project/workspace, scheme, configuration, destination, bundle identifier, launch arguments, and approved environment keys.
- [x] **MCP-15.4** Build a process abstraction with allowlisted `xcodebuild`/`simctl` operations; reject arbitrary executable names, shell fragments, unresolved paths, and out-of-scope targets.
- [x] **MCP-15.5** Add `viewlens_session_create`, `viewlens_session_get`, `viewlens_session_close`, and `viewlens_destinations_list` tools.

### Native capture and queries

- [x] **MCP-15.6** Add `viewlens_app_launch` and bounded relaunch/terminate behavior with explicit target verification.
- [ ] **MCP-15.7** Capture the current screenshot, window/scene metadata, orientation, scale, appearance, content size, safe-area data, and timestamp as one atomic state artifact.
- [ ] **MCP-15.8** Capture the available accessibility hierarchy with stable per-capture element IDs, names, roles, values, states, actions, frames, focus, and hierarchy relationships.
- [ ] **MCP-15.9** Correlate detected visual elements with accessibility nodes and report match confidence, conflicts, and unmatched nodes in both directions.
- [x] **MCP-15.10** Add token-efficient queries: element by ID, element at point, nearest element, descendants, ancestors, text search, role search, alignment, spacing, collision, and viewport containment.
- [x] **MCP-15.11** Add `viewlens_capture_state`, `viewlens_query_hierarchy`, and `viewlens_query_spatial` tools with structured outputs and resource links.

### Reliability and safety

- [ ] **MCP-15.12** Extend doctor diagnostics for Xcode, simulator, Accessibility, Screen Recording, Automation, signing, destination, and fixture readiness.
- [ ] **MCP-15.13** Create a deterministic fixture application covering navigation, forms, scroll content, dialogs, menus, validation, loading, failure, and accessibility states.
- [ ] **MCP-15.14** Implement fake runtime backends for unit tests and gated integration tests for macOS and simulator capture.
- [ ] **MCP-15.15** Add audit logs that record requested operation, resolved target, scope decision, timestamps, artifacts, and termination without storing typed user content by default.

**Acceptance:** From a clean connection, an agent can create a bounded session, launch the fixture app, capture pixels and semantics, query an element spatially, reconnect using the session handle, and close the session. Scope violations and missing permissions produce explicit recoverable errors. No tool accepts arbitrary shell commands.

---

## M16 — Interaction & Accessibility Graph

**Outcome:** An agent can safely exercise real UI workflows, inspect accessibility navigation, and discover important states under strict budgets.

### Controlled interaction

- [ ] **MCP-16.1** Define an allowlisted action vocabulary: activate element, type non-sensitive fixture text, clear, scroll, swipe, keyboard shortcut, move focus, resize window, rotate, wait for condition, and capture.
- [ ] **MCP-16.2** Add `viewlens_ui_perform` with element-ID-first targeting, optional coordinate fallback, preconditions, timeout, postcondition, and automatic before/after captures.
- [ ] **MCP-16.3** Redact secure fields and reject secrets, credentials, purchases, account deletion, permission escalation, and other high-impact actions unless a future separately reviewed policy allows them.
- [ ] **MCP-16.4** Record deterministic replay scripts with schema version, target state, actions, assertions, and artifact references.

### Accessibility and focus intelligence

- [ ] **MCP-16.5** Build keyboard traversal and focus-order graphs; detect traps, unreachable controls, focus loss, hidden focus, and incorrect restoration after dismissal.
- [ ] **MCP-16.6** Capture VoiceOver-relevant reading order, headings, landmarks/groups, values, selected/expanded state, custom actions, hints, and rotor candidates where platform APIs permit.
- [ ] **MCP-16.7** Validate Voice Control names and conflicts, activation-point containment, and visible-label/programmatic-name consistency.
- [ ] **MCP-16.8** Add explicit evidence completeness for platform features that cannot be automated; generate a bounded manual verification checklist instead of a pass.

### State exploration and accommodation matrices

- [ ] **MCP-16.9** Implement a bounded state crawler with maximum actions, maximum states, maximum duration, allowed regions, visited-state hashing, loop detection, and cancellation.
- [ ] **MCP-16.10** Discover and label empty, loading, content, validation, error, disabled, selected, expanded, modal, menu, hover, focused, permission, offline, and stale states.
- [ ] **MCP-16.11** Run interaction flows under Light/Dark, Increase Contrast, Differentiate Without Color, Reduce Motion, Dynamic Type/accessibility text sizes, RTL, and orientation variants.
- [ ] **MCP-16.12** Add pseudolocalization and locale stress cases for expansion, CJK, pluralization, number/date formatting, bidirectional text, and truncation.
- [ ] **MCP-16.13** Add `viewlens_flow_replay`, `viewlens_flow_crawl`, and `viewlens_accessibility_graph` tools.

**Acceptance:** A declared fixture workflow can be replayed deterministically, audited after every transition, cancelled within a bounded interval, and exported as a graph plus state artifacts. Keyboard traps and inaccessible focus restoration are reported with reproducible action paths. Unsupported VoiceOver evidence is marked not evaluated.

---

## M17 — Source Provenance & Fix Verification

**Outcome:** ViewLens can connect a runtime finding to responsible source and prove whether a host-agent change fixes the issue without introducing material regressions.

### Visual-to-source provenance

- [ ] **MCP-17.1** Design an opt-in debug instrumentation package for stable source IDs across SwiftUI and UIKit without affecting release behavior.
- [ ] **MCP-17.2** Capture file, line, symbol/view type, runtime identity, accessibility identity, and relevant modifier/property provenance where technically available.
- [ ] **MCP-17.3** Correlate visual detections, accessibility nodes, runtime hierarchy nodes, and source records into a provenance graph with confidence and ambiguity.
- [ ] **MCP-17.4** Add `viewlens_trace_to_source` and source-location fields to findings; uninstrumented targets must return unavailable or lower-confidence evidence rather than guessed locations.
- [ ] **MCP-17.5** Provide adapter points for Swift macros, generated metadata, UIKit swizzling-free debug hooks, and external symbol/source maps; record tradeoffs in an ADR.

### Closed-loop verification

- [ ] **MCP-17.6** Define a `ChangeSet` input using explicit changed-file paths, diff hash, expected review/session ID, and workspace scope; ViewLens does not edit the files.
- [ ] **MCP-17.7** Add `viewlens_verify_changes` to rebuild, reproduce the saved state/flow, recapture evidence, and compare before/after findings and visuals.
- [ ] **MCP-17.8** Report resolved, remaining, introduced, and not-retested findings with completeness and environment parity.
- [ ] **MCP-17.9** Detect material visual drift with baselines, heatmaps, structural differences, and configurable region masks.
- [ ] **MCP-17.10** Require elicited user approval before recording/replacing approved baselines or publishing verification results externally.

### Regression output

- [ ] **MCP-17.11** Generate reviewable XCTest UI flows, accessibility assertions, unit-test fixtures, and visual-baseline tests from an approved replay.
- [ ] **MCP-17.12** Add stable identifiers and generated-test provenance so regeneration updates only owned sections and never overwrites user code silently.
- [ ] **MCP-17.13** Extend quality gates and PR summaries with source-linked evidence, before/after artifacts, environment parity, and completeness.
- [ ] **MCP-17.14** Add a `viewlens-fix-verify` agent skill that keeps source editing in the host and requires ViewLens evidence before claiming completion.

**Acceptance:** For an instrumented fixture defect, ViewLens identifies the responsible source location, a host-applied change can be verified against the saved state, and the result differentiates resolved, introduced, and untested findings. Uninstrumented targets never receive fabricated file/line provenance.

---

## M18 — Interactive MCP App & Remote Collaboration

**Outcome:** Users can inspect and approve rich ViewLens evidence inside compatible MCP hosts, and teams can run the same workflows through a secure remote service.

### Interactive review application

- [ ] **MCP-18.1** Publish a sandboxed `ui://viewlens/review` MCP App resource bound to review and task resources.
- [ ] **MCP-18.2** Implement synchronized canvas overlays, hierarchy tree, finding inspector, state graph, before/after slider, heatmap, completeness, environment metadata, and task progress.
- [ ] **MCP-18.3** Add accessible keyboard/VoiceOver navigation, non-color status encoding, zoom/pan, reduced motion, and responsive layouts to the MCP App itself.
- [ ] **MCP-18.4** Allow the app to request scoped MCP calls for selecting elements, replaying approved steps, cancelling tasks, exporting evidence, and approving baselines.
- [ ] **MCP-18.5** Keep consequential actions host-mediated and show resolved target, scope, and expected effect before confirmation.

### Remote service and collaboration

- [ ] **MCP-18.6** Add Streamable HTTP transport alongside stdio without changing core audit behavior.
- [ ] **MCP-18.7** Implement OAuth-based authorization, exact audience validation, short-lived credentials, per-request scopes, and explicit prohibition of token passthrough.
- [ ] **MCP-18.8** Define organization/project/review authorization and ensure handles are names, not bearer capabilities.
- [ ] **MCP-18.9** Add encrypted artifact storage, retention controls, deletion, audit trails, tenant isolation, and signed artifact URLs.
- [ ] **MCP-18.10** Add OpenTelemetry-compatible traces and privacy-preserving metrics for tool latency, task state, failures, cache effectiveness, and detector performance.
- [ ] **MCP-18.11** Implement deterministic caching keyed by source, environment, model, rules, schema, and tool version; expose cache provenance in results.

### Distribution and skills

- [ ] **MCP-18.12** Package and validate local and remote server manifests, icons, metadata, version compatibility, and automated upgrade checks.
- [ ] **MCP-18.13** Publish agent skills for live debugging, release accessibility, flow crawling, design-system extraction, regression authoring, and PR verification.
- [ ] **MCP-18.14** Add end-to-end examples for supported hosts and an interoperability matrix showing tools, resources, tasks, elicitation, and MCP App support.
- [ ] **MCP-18.15** Complete a remote-service threat model, abuse cases, penetration review, disaster recovery exercise, and data-handling documentation before general availability.

**Acceptance:** A compatible host renders the ViewLens review app and keeps it synchronized with task/resource updates; users can inspect and approve bounded operations accessibly; local stdio behavior remains available; remote clients are scope-authorized and isolated; security and retention tests pass.

---

## 4. Deferred ideas and non-goals

These ideas require separate product decisions and are not implied by M14–M18:

- Direct autonomous source editing by the ViewLens MCP server.
- Unrestricted device control, arbitrary shell execution, or generalized browser automation.
- Production-device interaction containing real customer credentials or personal data.
- Automatic App Store submission, PR publication, issue creation, or baseline approval.
- Claims of full VoiceOver or assistive-technology conformance when platform APIs cannot provide complete evidence.
- Replacing deterministic rule results with LLM-generated pass/fail decisions.

## 5. Initial iteration order

The next implementation conversation should start with **M14A**. Break it into reviewable changes in this order:

1. Protocol negotiation and compatibility fixtures.
2. Shared evidence and error envelopes.
3. Tool output schemas and structured results for doctor/screenshot audit.
4. Artifact image/resource result blocks.
5. Conformance tests and skill documentation.

Do not begin simulator control during M14A. The purpose of the first iteration is to stabilize the contract every later capability will depend on.
