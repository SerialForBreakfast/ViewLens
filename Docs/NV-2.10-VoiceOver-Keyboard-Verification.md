# NV-2.10 VoiceOver and Keyboard Verification

This checklist validates behavior that XCTest can inspect only partially. Automated tests verify the accessibility tree, stable identifiers, keyboard commands, synchronized selection, deterministic comparison output, minimum-window layout, and the test accommodation matrix. They do not prove spoken timing, rotor usability, pronunciation, or refreshable-braille behavior.

## Test record

- Tester:
- Date:
- ViewLens revision:
- macOS version:
- VoiceOver version:
- Keyboard layout:
- Braille display and firmware, if used:
- Window size:
- Appearance and accessibility settings:

Record `Pass`, `Fail`, or `Not evaluated` for every check. Attach the stable screen, element, and finding IDs to defects.

## Configuration matrix

Run NV-J1 through NV-J4 under each applicable configuration:

1. Default system settings, keyboard only.
2. VoiceOver enabled with speech.
3. VoiceOver enabled with a representative refreshable braille display.
4. Minimum ViewLens window size, 900 by 650 content points.
5. Increase Contrast enabled.
6. Reduce Motion enabled.
7. Differentiate Without Color enabled.
8. Increase Contrast, Reduce Motion, and Differentiate Without Color enabled together.

Do not infer a pass for a configuration that was not run.

## NV-J1 — Understand an unfamiliar screen

1. Launch the deterministic nonvisual fixture and open AI Review with Command-Option-2.
2. Switch to Nonvisual Outline with Command-2. Do not inspect the canvas.
3. Confirm VoiceOver announces the screen summary, evidence completeness, major region, element count, interactive count, and top finding without decorative image content.
4. Navigate the Authentication form region and its elements. Confirm names, roles, states, actions, issue counts, stable IDs, and evidence provenance are understandable.
5. Change Speech, Braille, and Developer profiles. Confirm the underlying evidence and stable IDs do not change.

Expected result: the screen can be understood without opening or interpreting the image.

## NV-J2 — Compare pixels with semantics

1. Switch to Split View with Command-3.
2. Use Command-Right Bracket and Command-Left Bracket to navigate elements.
3. Confirm outline and canvas selection stay synchronized without moving VoiceOver focus away from the current control.
4. Use Command-Shift-Right Bracket and Command-Shift-Left Bracket to navigate findings.
5. Confirm the missing Email name, missing Sign In semantic counterpart, semantic-only Legacy Sign In action, and reading-order divergence are described with measured or derived provenance.
6. Confirm unavailable evidence is announced as unavailable and never as passed.

Expected result: visual and semantic counterparts can be compared without relying on overlay color or position.

## NV-J3 — Inspect the screen-reader experience

1. In Nonvisual Outline, use the Findings, Interactive Controls, Regions, and Semantic Mismatches rotors.
2. Confirm each rotor lands on the intended stable node and does not expose duplicate or decorative entries.
3. Read the Reading Order and Predicted VoiceOver Traversal sections.
4. Confirm the predicted traversal is explicitly identified as API-derived and requires manual VoiceOver verification.
5. Verify the announced sequence against actual VoiceOver navigation, including the order of Welcome Back, Email, Sign In, and Legacy Sign In.
6. Verify custom actions have concise, unique names and that focus remains visible and recoverable after invoking or dismissing them.

Expected result: predicted behavior and observed VoiceOver behavior remain clearly distinguished.

## NV-J4 — Understand a visual regression

1. Open History with Command-Option-4 and select LoginForm Baseline plus LoginForm.
2. Open Compare without inspecting the heatmap.
3. Read the score, introduced/resolved finding counts, Textual Accessibility Diff, and Textual Visual Diff.
4. Confirm blocking accessibility changes are announced before material semantic changes and cosmetic pixel information.
5. Confirm the narrative does not claim that pixel evidence proves focus order or screen-reader behavior.

Expected result: the material regression can be understood from text while the heatmap remains decorative.

## Announcement and focus audit

- Phase announcements occur only for input required, new blocking findings, cancellation, failure, and completion.
- Percentage updates are not announced.
- Visual selection changes do not steal VoiceOver focus from the outline.
- Modal dismissal restores focus to the invoking control or a documented recovery target.
- Search and filtering announce concise result-count changes without repeating the entire outline.
- No secure field value appears in speech, braille, logs, or exports.

## Exit criteria

NV-2.10 is complete only when the automated `ViewLensUITests` NV-J1–NV-J4 cases pass on the supported macOS runner and this checklist has no blocking failure for keyboard and VoiceOver. Braille results must be recorded as tested or explicitly not evaluated; they must not be inferred from speech output.
