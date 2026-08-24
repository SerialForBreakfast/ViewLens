# ViewLens Desktop Accessibility Verification Checklist

Use this checklist for release candidates after automated tests pass. Record the macOS and Xcode versions, tester, date, and any issue links with the release evidence.

## Automated evidence

- [x] `DesktopReviewWorkbench` is registered with programmatic name/role/value snapshots.
- [x] ViewLens WCAG 2.2 AA self-audit passes at 100%, including Name/Role/Value, target size, Light/Dark contrast, AX1/AX3/AX5 resize and reflow, and alternate viewport rendering.
- [x] Compact (820×680), standard (1180×760), and wide (1440×900) Light/Dark references are committed under `Tests/ReferenceImages/Desktop`.
- [x] `DesktopBaselineTests` compares all six references at SSIM ≥ 0.995 and pixel tolerance 0.01.
- [x] Findings communicate severity with symbols and text in addition to color; canvas overlays use solid, dashed, and dotted patterns.
- [x] Canvas animation observes Reduce Motion; increased-contrast appearances strengthen panel borders.

## Accessibility Inspector and VoiceOver

- [ ] Run Accessibility Inspector Audit on Current Status, AI Review, Playground, History, Settings, and each native import/export sheet. Resolve every critical issue or link an approved exception.
- [ ] With VoiceOver enabled, traverse each screen in reading order. Confirm headings, grouped cards, score values, status values, form labels, help text, and disabled controls are understandable out of visual context.
- [ ] On AI Review, use the Review Canvas custom actions for Previous Element and Next Element. Confirm selected findings and elements announce their selected state.
- [ ] Expand and collapse a finding, copy remediation guidance, switch inspector tabs, change every finding filter, and export a report using VoiceOver only.
- [ ] Confirm alerts and confirmation dialogs move VoiceOver focus to the dialog and return it to the invoking control when dismissed.

## Keyboard-only workflows

- [ ] Complete navigation with Command-1 through Command-5 and use Tab/Shift-Tab without a keyboard trap.
- [ ] Open Import with Command-O, select or cancel a file, run a Playground template, search/filter findings, navigate canvas elements with arrow keys, and export a report without a pointer.
- [ ] Start a review, cancel it from the keyboard, confirm the destructive action, and verify the cancelled state is announced.
- [ ] Confirm focus remains visible in Light, Dark, and Increase Contrast appearances.

## Display accommodations

- [ ] Enable Increase Contrast and inspect panel boundaries, selected navigation, focus rings, controls, charts, and overlay labels.
- [ ] Enable Differentiate Without Color and confirm error/warning/info remain distinguishable by text, symbol, and overlay pattern.
- [ ] Enable Reduce Motion and confirm zoom-to-selection does not animate and no essential status is conveyed by motion.
- [ ] Test the largest system text setting supported by macOS. Confirm all primary actions remain reachable and content can scroll without overlap, clipping, or truncation that changes meaning.
- [ ] Repeat primary screens in Light and Dark appearances at compact, standard, and wide window sizes.

## Release sign-off

- [ ] No unresolved critical accessibility defects.
- [ ] All primary workflows can be completed keyboard-only.
- [ ] The six visual references are reviewed and approved; intentional changes are recorded by rerunning with `VIEWLENS_RECORD_BASELINES=1` and reviewed in source control.
- [ ] `swift test`, macOS app unit tests, signed UI tests, and the macOS build pass on the release machine.
