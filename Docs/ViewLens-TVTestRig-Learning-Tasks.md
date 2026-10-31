# ViewLens improvement tasks from TVTestRig

Planned October 12, 2026. All tasks below are open. The first delivery priority is trustworthy evidence, followed by real-source verification, efficient agent workflows, and native scenario and journey testing. This is a ViewLens backlog, not permission to operate TVTestRig, capture private data, change accessibility settings, or launch experiments.

## Evidence and existing work

TVTestRig provides useful implementation patterns, not transferable qualification. Its tvOS trials do not establish iOS, macOS, SwiftUI, VoiceOver, or ViewLens behavior.

- [Named-route benchmark](../../TVTestRig/Docs/Testing/2026-09-27-nav-run-02-token-benchmark.md): five paired episodes on one two-step route reported median 61.5% input-token reduction. Fewer turns are worth testing here; savings are not guaranteed.
- [Native component qualification](../../TVTestRig/Docs/Testing/2026-10-05-uikit-component-catalog-qualification.md): native rendered geometry and semantic inventories provide a pattern for fixture evidence.
- [Physical focus evidence audit](../../TVTestRig/Docs/Testing/2026-10-11-physical-focus-evidence-audit.md): authored assertions, screenshots, native focus, and settled observations must remain distinct.
- [Producer storage hardening](../../TVTestRig/Docs/Testing/2026-10-12-hcf-producer-hardening.md): signed CLI/MCP pre-dispatch guards were qualified; mid-route exhaustion and crash restoration remain separate.
- [Real-world debugging reliability](../../TVTestRig/Docs/Plans/2026-10-07-real-world-debugging-reliability.md): readiness, freshness, command delivery, observed effect, and cleanup are separate states. Remaining live acceptance is not an established capability.
- [Seven-day synthesis](../../TVTestRig/Docs/Reports/2026-10-06-seven-day-synthesis-and-optimizations.md): headless rendering is an experiment candidate; proposed throughput is not a verified ViewLens result.

Design references: [nonvisual evidence model](ADR/ADR-010-Nonvisual-Evidence-Model.md), [durable task handles](ADR/ADR-009-Durable-MCP-Task-Handles.md), [platform roadmap](ViewLens-Intelligent-Accessibility-Platform-Roadmap.md), and [MCP roadmap](ViewLens-MCP-Agent-Capability-Roadmap.md). Each story inherits these references; no new visual design is required before evidence contracts are settled.

Existing MCP-19.8–19.12 own build, fixtures, rendering, and recapture. INT-20.7 owns compiler confirmation. M21 and M22 own scenarios and journeys. The tasks here add acceptance detail and cross-cutting hardening, not replacement implementations or duplicate completion claims.

## Tranche A — Trustworthy evidence

### LEARN-01 Correct capture provenance — P0

As a blind developer, I want measured facts distinguished from placeholders so that I can trust descriptions without seeing the screen.

- [x] Remove fabricated measured geometry from `StateCaptureEngine`; absent native frames remain absent or explicitly synthetic, never measured with confidence 1.0.
- [x] Do not derive an allegedly independent visual observation from accessibility nodes. Correlation requires independently acquired observations; otherwise report it unavailable.
- [x] Preserve supplied labels and values with their actual origin; disclose unavailable capture timing, device metrics, and reading-order evidence rather than inventing defaults as observations.
- [x] Add engine and actual MCP-handler regressions proving placeholder-only and empty captures cannot claim measured correlation or accessibility conformance.

Dependencies: none. Entry points: `StateCaptureEngine`, `VisualSemanticCorrelator`, `viewlens_capture_state`. This is the first implementation task.

### LEARN-02 Enforce evidence eligibility across consumers — P0

As a reviewer, I want the same evidence rules in every report so that synthetic data cannot become a verified pass elsewhere.

- [x] Define a shared eligibility policy for measured, inferred, synthetic, unavailable, and human-confirmed fields, with capture identity and freshness where applicable.
- [x] Apply it to nonvisual descriptions, correlation, baselines, fix verification, exports, and quality gates; unknown required evidence yields not evaluated or incomplete, not pass.
- [x] Keep predicted input focus, native keyboard focus, accessibility focus, and human VoiceOver observations separate.
- [x] Test mixed provenance, stale/mismatched captures, missing observations, and legacy stored reports; surface safe migration limitations in CLI/MCP/Mac output.

Dependencies: LEARN-01. Extends ADR-010 and existing nonvisual work rather than redefining its terminology.

### LEARN-03 Match fixes by stable finding identity — P0

As a developer, I want a resolved finding tied to the same element and scenario so that an unrelated change cannot appear to fix it.

- [x] Define finding identity from rule, target, stable element/source anchor, and matrix/scenario context, with explicit uncertain matching.
- [x] Replace issue-kind-only resolution claims with per-finding comparison; retain ambiguous and missing comparisons as not retested.
- [x] Test duplicate rule kinds on different controls, renamed/moved elements, partial matrices, and unrelated new findings.
- [x] Expose matching reasons and uncertainty consistently in verification results, dashboard, and exports.

Dependencies: LEARN-02. Coordinates with MCP-19.12; does not itself prove changed source was executed.

## Tranche B — Real source and reliable execution

### LEARN-04 Bind verification to build and capture receipts — P0

As a developer, I want proof that my changed source was tested rather than a pre-existing template.

- [ ] Under MCP-19.8, record approved workspace/target, source content digest including uncommitted changes, dependency pins, toolchain, build configuration, and artifact digest; reject source drift during the build.
- [ ] Under MCP-19.9–19.12, bind fixture/resource provenance and each fresh capture to that artifact and its actual runtime/matrix configuration.
- [ ] Set source-change verification true only when the required source/build/capture chain and finding comparison are complete; synthetic substitutes remain fidelity-baseline-ineligible.
- [ ] Test stale artifacts, changed source during execution, wrong target, missing dependencies, build failure, and partial recapture through production callers.

Dependencies: LEARN-02/03 and MCP-19.8–19.12. Break implementation into existing build, fixture, render, and verification packets; no second build engine.

### LEARN-05 Capability based preflight and guided repair — P0

As a user, I want to know exactly what blocks my chosen review without triggering device actions during diagnosis.

- [ ] Return ready, blocked, unknown, or not required for only the requested workflow's prerequisites: access, toolchain, target, runtime, model, source context, storage, and ownership.
- [ ] Keep preflight read-only; preview build/install/launch/capture effects separately and require their authorized scope.
- [ ] Share typed causes and actionable repairs across dashboard, Playground, CLI, and MCP; model-unavailable must not block supported native-only checks.
- [ ] Test partial discovery, unavailable tools, denied access, wrong target, stale replies, and pending cleanup with zero preflight launch/input effects.

Dependencies: existing readiness owners; receipt fields align with LEARN-04. Design: existing dashboard and Playground surfaces, not a new setup wizard.

### LEARN-06 Bound execution and preserve uncertain outcomes — P1

As an agent user, I want cancellation and reconnect to preserve the truth about what ran.

- [ ] Extend durable tasks with queued, running, cleanup-pending, and terminal evidence as needed without breaking existing handle/TTL contracts.
- [ ] Use operation/generation identity to reject late results; timeout does not imply the build/render/provider stopped or authorize automatic action replay.
- [ ] Admit work through shared renderer/target ownership and resource limits; report contention separately from a stalled target.
- [ ] Test cancellation during capture, reconnect, TTL expiry, overlapping requests, late callbacks, and failed cleanup; retain the original failure and recovery receipt.

Dependencies: ADR-009 and LEARN-05. Extend existing scheduler/task owners, not a separate background coordinator.

## Tranche C — Agent efficiency and operational safeguards

### LEARN-07 Bounded end to end agent workflows — P1

As an LLM user, I want one review request to perform the approved sequence and return a concise outcome.

- [ ] Compose existing impact/context/preflight/review/verification owners into bounded workflows with declared scope, budgets, durable progress, and cancellation.
- [ ] Return findings, coverage, evidence limitations, and next actions first; retain detailed evidence behind access-checked resources.
- [ ] Preserve per-step failures and authorization boundaries; no hidden dependency downloads, source mutation, setting changes, or expanded targets.
- [ ] Exercise complete and partial workflows through actual MCP handlers, CLI, and Mac callers; avoid a parallel implementation of audit logic.

Dependencies: LEARN-04–06; builds on INT-20.8/09 and existing MCP tools.

### LEARN-08 Real client compatibility and paired efficiency benchmark — P1

As an integrator, I want proof that clients discover and successfully use our tools, not just connect.

- [ ] Define a versioned matrix of supported real clients and negotiated protocol behavior; verify discovery, schema acceptance, structured output, resource access, task polling, reconnect, and a completed audit.
- [ ] Retain client/server versions, wire-level sanitized receipts, discovered tool counts, and observed completion; distinguish connected from usable.
- [ ] Compare stepwise and composed workflows on identical resettable tasks with alternating order and at least five pairs; report provider usage, turns, calls, duration, and failures separately.
- [ ] Require equivalent coverage and no false completion before claiming efficiency; keep unavailable provider token counts unavailable and obtain scope before paid/external client trials.

Dependencies: LEARN-07 for comparative benchmark; client conformance work can begin earlier under M14. TVTestRig's benchmark is motivation, not our acceptance threshold.

### LEARN-09 Storage budgets and evidence retention — P1

As a user, I want long reviews to stop safely before exhausting storage without losing prior results.

- [ ] Check bounded per-run/workspace quotas and free capacity before builds, capture, and export; account for retained and recovery data without double counting paths.
- [ ] Reserve bounded cleanup/finalization capacity, reject symlink/path escapes, and report nonretryable capacity problems with actionable repairs.
- [ ] Preserve originals and failed attempts; archive only under the configured policy, with no automatic deletion/offload or silent quota increase.
- [ ] Test pre-dispatch exhaustion, mid-run exhaustion, concurrent reservations, interrupted finalization, and recovery; qualify these separately rather than inferring runtime success from a unit check.

Dependencies: LEARN-05/06 and existing storage owners.

### LEARN-10 Privacy safe evidence export — P1

As a reviewer, I want to share useful evidence without exposing source paths, secrets, or private screenshots unintentionally.

- [ ] Preview an export manifest with artifact types, sensitivity, provenance, and selected redactions; raw screenshots/source require explicit inclusion.
- [ ] Preserve original bytes privately; mark redacted derivatives and their ancestry so they cannot silently replace measurement baselines.
- [ ] Record schema/version, hashes, sizes, and exact artifact references; separate byte delivery from receiver review or semantic acceptance.
- [ ] Test secrets/path exclusion, malformed archives, access denial, expired resources, and redacted geometry limitations; provide a keyboard and nonvisual review path.

Dependencies: LEARN-02/09 and existing private context-capsule access controls. No new external delivery service is implied.

## Tranche D — Native scenarios and journeys

### LEARN-11 Native scenario inventory and resource intake — P1

As a UI author, I want repeatable realistic states whose measured output is distinguishable from fixture intent.

- [ ] Extend MCP-19.9/10 and M21 with deterministic loading, empty, error, populated, offline, permission, and authentication fixtures using target-compatible types and stable IDs.
- [ ] Emit declared inventory separately from rendered/visible observations, with settled native bounds and explicit absent/occluded/unavailable states.
- [ ] Validate resource decoding, dimensions, aspect, real alpha, origin, and ancestry; structural/generated substitutes are visibly synthetic and baseline-ineligible.
- [ ] Test missing dependencies, invalid assets, duplicate IDs, animation, RTL, AX5, localization expansion, contrast, motion, and orientation; unsupported permutations remain not evaluated.

Dependencies: MCP-19.9–19.11, LEARN-02/04. M21 remains the scenario owner.

### LEARN-12 Guarded journeys and independent accessibility focus — P1

As a blind developer, I want to test navigation and announcements without mistaking a dispatched action for a successful accessible journey.

- [ ] Under M22, define versioned routes with allowed actions, stable states, preconditions, bounded budgets, and destination assertions; check policy before every action.
- [ ] Separate dispatch receipt, observed effect, settled screen, input focus, accessibility focus, announcements, and cleanup; unsupported AT observations stay unavailable.
- [ ] Persist visited/frontier/blocked/unreached states; only observed transitions establish edges and missing observations never trigger hidden replay.
- [ ] Test duplicate labels, scrolling, cycles, no-op boundaries, missing announcements, focus races, late results, interruption, and cleanup; generate manual verification steps where native evidence is unavailable.

Dependencies: LEARN-02/05/06/11. No automatic VoiceOver changes or unannounced audible human trials.

### LEARN-13 Nonvisual evidence browser and release review — P1

As a blind or low-vision reviewer, I want to inspect differences, uncertainty, and recovery actions without relying on overlays.

- [ ] Extend AI Review, Current Status, History, and Playground with text-first before/after findings, provenance, coverage, build/capture identity, and actionable evidence links.
- [ ] Provide stable headings, keyboard navigation, concise braille-oriented summaries, and non-color state labels; retain detailed expansion without repetitive announcements.
- [ ] Distinguish predicted AT behavior from observed and human-confirmed behavior; make unknown and not-retested items discoverable rather than hiding them behind scores.
- [ ] Add automated UI/state tests and complete scoped keyboard/VoiceOver/braille review under NV-2.10/NV-6; automated checks alone cannot close human release acceptance.

Dependencies: LEARN-02/04; journey views additionally depend on LEARN-12. Reuse the existing ViewLens theme and components.

## Tranche E — Optional calibrated experiments

### LEARN-14 Calibrated headless fixture generation — P2 experiment

As a maintainer, I want cheaper fixture generation without misrepresenting it as native app behavior.

- [ ] Prototype a deterministic recipe renderer using existing supported native tooling; keep generated geometry and measured native observations distinct.
- [ ] Freeze a representative golden set spanning text, assets, clipping, scaling, RTL, and focus styling; choose geometric/perceptual acceptance tolerances before evaluating.
- [ ] Compare against exact native artifact/runtime captures and report parity failures, throughput, memory, and storage; fail admission outside the declared calibrated scope.
- [ ] Decide adopt, narrow, or reject from measured results. Headless output never establishes VoiceOver behavior, actual-source execution, or native conformance.

Dependencies: LEARN-11 and approved experiment scope. TVTestRig's throughput projections are not targets or established results.

### LEARN-15 Model shadow evaluation and failure corpus — P2

As a maintainer, I want to measure model mistakes without letting predictions alter native truth or control.

- [ ] Run optional predictions beside immutable native observations with model/preprocessing/version identity; no prediction feedback into navigation or measured labels.
- [ ] Retain clean, challenge, and rejected cases with reasons, ancestry, and uncertainty; distinguish absent features from unavailable observations.
- [ ] Split evaluation by source/family ancestry before review, preventing related generated variants and reviewed examples from leaking into held-out evaluation.
- [ ] Evaluate competing highlights, no-op/content-change controls, focus/unfocus pairs, confidence and abstention; claims remain scoped to the frozen corpus and runtime.

Dependencies: LEARN-02/10/11; optional model availability and explicitly scoped evaluation. No training, model downloads, or cross-project transfers are authorized by this plan.

## Delivery and completion rules

Recommended first implementation tranche: LEARN-01–03 end to end, including production MCP callers, quality gates, nonvisual output, regression tests, and evidence-model documentation. Next: LEARN-04–06 through the existing MCP-19 build/fixture/render packets. LEARN-09/10 should precede large-scale corpus or long-running capture work. LEARN-07/08 then validate agent usability; LEARN-11–13 deliver scenarios and journeys. LEARN-14/15 are optional and must not block core reliability.

Every delivery records acceptance criterion, actual evidence, artifact/source identity, and result. Distinguish source inspection, unit tests, compiled integration, signed application, Simulator, physical-device, real-client, and human AT checks. Preserve failures and incomplete criteria. Planning and regression-test source are not executed validation. No code changes, builds, captures, client billing, or model experiments are part of this planning tranche.
