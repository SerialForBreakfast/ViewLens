# ADR-010: First-Class Nonvisual Evidence Model and Provenance Contract

- **Status:** Accepted
- **Date:** 2026-08-29
- **Deciders:** Joseph McCraw, ViewLens Architecture Team
- **Tags:** `accessibility`, `nonvisual`, `voiceover`, `braille`, `provenance`, `w3c-atag`

## Context

Traditional UI review and accessibility linters treat nonvisual accessibility as an afterthought—either reducing the screen to raw coordinates, generating superficial visual alt-text with LLMs, or conflating a visual detection with proof of an accessible experience.

For blind and low-vision engineers, understanding an unfamiliar screen, diagnosing layout defects, and verifying code changes requires structured, token-efficient, and non-visual representations of user interfaces. In accordance with the W3C Authoring Tool Accessibility Guidelines (ATAG 2.0 Part A & Part B), ViewLens itself must be accessible, and its evidence model must actively empower authors to build accessible Apple interfaces.

## Decision

ViewLens establishes `NonvisualScreenModel` as an equal, first-class representation of every review alongside the visual pixel canvas:

1. **Relational Geometry Over Pixel Coordinates**:
   - Spatial relationships are expressed relationally (`inside NavigationBar`, `below PasswordField`, `trailing to SubmitButton`) with measured point bounding boxes available on demand.

2. **Strict Four-Tier Statement Provenance**:
   Every nonvisual statement, finding, and hierarchy node must declare its evidence provenance:
   - `measured`: Platform runtime facts directly captured from Apple accessibility APIs or view hierarchy introspection.
   - `derived`: Deterministic computations based on measured values (e.g. contrast luminance ratios, spatial containment).
   - `inferred`: Heuristic or machine-learning outputs (e.g. CoreML YOLO element detections).
   - `unavailable`: Unprobed platform characteristics or screenshot-only inputs where semantic trees cannot be measured.

3. **Inferred Evidence Invariant**:
   - Machine learning detections and static screenshot audits must **never** report WCAG 4.1.2 (Name, Role, Value) or VoiceOver reading-order criteria as `passed`. They must be explicitly flagged as `notEvaluated` with `unavailable` provenance.
   - VoiceOver traversal sequences are explicitly labeled as *API-Derived Predictions* and never claim complete VoiceOver runtime conformance.

4. **Multi-Modal Presentation Profiles**:
   - `speech`: Concise, spoken-optimized descriptions with priority sorting and polite announcements.
   - `braille`: Compact, 40-cell/80-cell display formatted summaries prioritizing state, role, and contracted markers.
   - `developer`: Full relational, geometric, and source-provenance diagnostic detail.

5. **Cross-Representation Stable Identifiers**:
   - `elementId`, `findingId`, `regionId`, and `sourceId` remain stable across JSON reports, MCP resource URIs, visual canvas overlays, and source-code trace annotations.

## Consequences

- Blind developers can independently navigate screens, understand visual and semantic discrepancies, locate source code, and verify fixes without sighted assistance.
- AI agents consuming ViewLens MCP resources receive unambiguous distinction between verified facts and heuristic predictions.
- Eliminates silent false-positive accessibility passes across CI/CD and pre-commit quality gates.
