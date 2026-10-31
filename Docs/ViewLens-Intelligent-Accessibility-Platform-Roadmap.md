# ViewLens Intelligent Accessibility Platform Roadmap

**Objective:** Evolve ViewLens from a screen auditor into an evidence-aware UI understanding, accessibility-contract, and change-verification platform.

## Cross cutting reliability priorities

The [TVTestRig learning backlog](ViewLens-TVTestRig-Learning-Tasks.md) adds prioritized acceptance detail without replacing M19–M24 owners. All LEARN tasks are planned, not implemented. Start with LEARN-01–03 (capture provenance, evidence eligibility, stable finding identity), then LEARN-04–06 (real-source receipts, preflight, bounded execution). Agent workflows, storage/privacy safeguards, native scenarios, nonvisual review, and optional calibrated experiments follow in the linked delivery order.

## Delivery principles

- Preserve the distinction between evaluated, unavailable, inferred, and human-confirmed evidence.
- Keep discovery bounded and read-only by default; builds, generated fixtures, patches, and approvals require explicit scope.
- Never treat synthetic resources, predicted assistive-technology behavior, or lexical source inference as fidelity or conformance proof.
- Make every workflow usable through keyboard, VoiceOver-oriented text, braille-efficient output, CLI, and MCP.

## M20 — Intelligent Change Targeting and Context Capsules

**Outcome:** A code change produces the smallest explainable set of affected screens, scenarios, and audit permutations.

- [x] **INT-20.1** Define a bounded change-impact report with affected source files, root views, dependency distance, confidence, diagnostics, and evidence limitations.
- [x] **INT-20.2** Build a lexical reverse-dependency graph for local Swift declarations and view composition.
- [x] **INT-20.3** Trace changed named resources to Swift references and their transitive parent views.
- [x] **INT-20.4** Generate deterministic device, Dynamic Type, appearance, and accommodation audit recommendations.
- [x] **INT-20.5** Expose change-impact analysis through `viewlens impact`.
- [x] **INT-20.6** Expose synchronous `viewlens_change_impact` through modern MCP with a strict read-only schema. Impact-selected verification supports durable tasks through INT-20.9.
- [ ] **INT-20.7** Add compiler/Index Store confirmation of target membership, conditional compilation, and symbol ownership. *(Existing SwiftPM build descriptions and Xcode Swift file lists now confirm scoped target membership without launching a build; Index Store symbol ownership and conditional/overload resolution remain.)*
- [x] **INT-20.8** Publish private, retained, bounded context-capsule MCP resources containing only affected source facts and evidence summaries, with opaque IDs and no source bodies or workspace-root disclosure.
- [x] **INT-20.9** Integrate shared impact selection with Git gates, durable `viewlens_verify_changes` tasks, and the Mac dashboard. Partial/unregistered coverage is explicit and cannot pass verification. Registered templates execute device, Dynamic Type, and appearance matrices; source rebuild/recapture remains MCP-19.12 and additional accommodations remain M21.

**INT-20.9 validation (2026-10-01):** `swift test --no-parallel` passed (231 library tests across 48 suites, with two opt-in simulator tests skipped, plus the CLI smoke test). Mac `build-for-testing` succeeded and all three `CurrentStatusStoreTests` passed. CLI checks confirmed that unknown templates and Git discovery failures cannot silently pass. VoiceOver/braille release verification remains tracked in NV-2.10/NV-6.

## M21 — Scenario Forge and Accessibility Stress Lab

- [ ] Discover loading, empty, error, populated, offline, permission, and authentication states from source and runtime evidence.
- [ ] Define typed, target-compatible scenario fixtures for initializers, bindings, environment values, and observable models.
- [ ] Run deterministic AX5, RTL, localization expansion, Increase Contrast, Differentiate Without Color, Reduce Motion, and orientation matrices.
- [ ] Track scenario provenance, sensitive-data exclusion, fixture lifecycle, and baseline eligibility.

## M22 — Accessibility Contracts and Journey Auditing

- [ ] Define declarative contracts for reading order, announcements, focus movement, labels, state, errors, and completion outcomes.
- [ ] Record and validate multi-screen journeys with bounded actions and deterministic assertions.
- [ ] Add announcement timelines for duplicates, interruptions, stale messages, and focus/announcement races.
- [ ] Generate regression tests and manual-verification steps for evidence unavailable to automation.

## M23 — Fix Preview Sandbox and UI Intent Diff

- [ ] Represent design and accessibility intent independently from pixel baselines.
- [ ] Generate bounded candidate remediations as reviewable patches without autonomous application.
- [ ] Build and render candidates in isolated approved environments.
- [ ] Rank candidates by contract satisfaction, WCAG/HIG findings, design fidelity, regression risk, and evidence completeness.

## M24 — Accessibility Intelligence and Collaboration

- [ ] Accessibility Time Machine across commits, semantic snapshots, focus order, speech, braille, and visual evidence.
- [ ] Design-System Archaeologist for recurring tokens, components, labels, interaction patterns, and high-leverage defects.
- [ ] Accessibility Debt Map ranked by user impact, reach, recurrence, component ownership, and fix leverage.
- [ ] Unified assistive-technology preview for predicted VoiceOver, braille, Voice Control, Switch Control, and keyboard behavior.
- [ ] Accessible collaboration reviews with nonvisual before/after navigation, approvals, evidence provenance, and handoff artifacts.
