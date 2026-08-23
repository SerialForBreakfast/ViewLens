# 🔍 ViewLens UI Quality Gate: ❌ FAILED

**Gate**: `pull-request` | **Policy**: `fail_on: warning` | **Template**: `Sub44ptButtonBug`

> ⚠️ **Quality Gate Alert**: 12 error(s) and 0 warning(s) detected under strict policy.

### 📐 Device & Appearance Matrix (12 Permutations)

| Matrix Variant | Target Device | Dimensions | Status | Issues |
|---|---|---|---|---|
| `iPadPro11_accessibility3_dark` | iPad Pro 11-inch | 1668×2420px @2x | ❌ Fail | **1** |
| `iPadPro11_accessibility3_light` | iPad Pro 11-inch | 1668×2420px @2x | ❌ Fail | **1** |
| `iPadPro11_large_dark` | iPad Pro 11-inch | 1668×2420px @2x | ❌ Fail | **1** |
| `iPadPro11_large_light` | iPad Pro 11-inch | 1668×2420px @2x | ❌ Fail | **1** |
| `iPhone16Pro_accessibility3_dark` | iPhone 16 Pro | 1179×2556px @3x | ❌ Fail | **1** |
| `iPhone16Pro_accessibility3_light` | iPhone 16 Pro | 1179×2556px @3x | ❌ Fail | **1** |
| `iPhone16Pro_large_dark` | iPhone 16 Pro | 1179×2556px @3x | ❌ Fail | **1** |
| `iPhone16Pro_large_light` | iPhone 16 Pro | 1179×2556px @3x | ❌ Fail | **1** |
| `iPhoneSE_accessibility3_dark` | iPhone SE (3rd gen) | 750×1334px @2x | ❌ Fail | **1** |
| `iPhoneSE_accessibility3_light` | iPhone SE (3rd gen) | 750×1334px @2x | ❌ Fail | **1** |
| `iPhoneSE_large_dark` | iPhone SE (3rd gen) | 750×1334px @2x | ❌ Fail | **1** |
| `iPhoneSE_large_light` | iPhone SE (3rd gen) | 750×1334px @2x | ❌ Fail | **1** |

### 🛠️ Detected Defects & Suggested SwiftUI Fixes

<details open>
<summary><b>View 12 Detected Issue(s)</b></summary>

#### [🔴 Error] `tappableTargetTooSmall` on `iPadPro11_accessibility3_dark`
- **Description**: primaryButton height 24pt is below Apple HIG minimum requirement of 44x44pt.
- **Guidance**: Increase frame dimensions to at least 44x44pt.
```swift
.frame(minWidth: 44, minHeight: 44)
```

#### [🔴 Error] `tappableTargetTooSmall` on `iPadPro11_accessibility3_light`
- **Description**: primaryButton height 24pt is below Apple HIG minimum requirement of 44x44pt.
- **Guidance**: Increase frame dimensions to at least 44x44pt.
```swift
.frame(minWidth: 44, minHeight: 44)
```

#### [🔴 Error] `tappableTargetTooSmall` on `iPadPro11_large_dark`
- **Description**: primaryButton height 24pt is below Apple HIG minimum requirement of 44x44pt.
- **Guidance**: Increase frame dimensions to at least 44x44pt.
```swift
.frame(minWidth: 44, minHeight: 44)
```

#### [🔴 Error] `tappableTargetTooSmall` on `iPadPro11_large_light`
- **Description**: primaryButton height 24pt is below Apple HIG minimum requirement of 44x44pt.
- **Guidance**: Increase frame dimensions to at least 44x44pt.
```swift
.frame(minWidth: 44, minHeight: 44)
```

#### [🔴 Error] `tappableTargetTooSmall` on `iPhone16Pro_accessibility3_dark`
- **Description**: primaryButton height 24pt is below Apple HIG minimum requirement of 44x44pt.
- **Guidance**: Increase frame dimensions to at least 44x44pt.
```swift
.frame(minWidth: 44, minHeight: 44)
```

#### [🔴 Error] `tappableTargetTooSmall` on `iPhone16Pro_accessibility3_light`
- **Description**: primaryButton height 24pt is below Apple HIG minimum requirement of 44x44pt.
- **Guidance**: Increase frame dimensions to at least 44x44pt.
```swift
.frame(minWidth: 44, minHeight: 44)
```

#### [🔴 Error] `tappableTargetTooSmall` on `iPhone16Pro_large_dark`
- **Description**: primaryButton height 24pt is below Apple HIG minimum requirement of 44x44pt.
- **Guidance**: Increase frame dimensions to at least 44x44pt.
```swift
.frame(minWidth: 44, minHeight: 44)
```

#### [🔴 Error] `tappableTargetTooSmall` on `iPhone16Pro_large_light`
- **Description**: primaryButton height 24pt is below Apple HIG minimum requirement of 44x44pt.
- **Guidance**: Increase frame dimensions to at least 44x44pt.
```swift
.frame(minWidth: 44, minHeight: 44)
```

#### [🔴 Error] `tappableTargetTooSmall` on `iPhoneSE_accessibility3_dark`
- **Description**: primaryButton height 24pt is below Apple HIG minimum requirement of 44x44pt.
- **Guidance**: Increase frame dimensions to at least 44x44pt.
```swift
.frame(minWidth: 44, minHeight: 44)
```

#### [🔴 Error] `tappableTargetTooSmall` on `iPhoneSE_accessibility3_light`
- **Description**: primaryButton height 24pt is below Apple HIG minimum requirement of 44x44pt.
- **Guidance**: Increase frame dimensions to at least 44x44pt.
```swift
.frame(minWidth: 44, minHeight: 44)
```

#### [🔴 Error] `tappableTargetTooSmall` on `iPhoneSE_large_dark`
- **Description**: primaryButton height 24pt is below Apple HIG minimum requirement of 44x44pt.
- **Guidance**: Increase frame dimensions to at least 44x44pt.
```swift
.frame(minWidth: 44, minHeight: 44)
```

#### [🔴 Error] `tappableTargetTooSmall` on `iPhoneSE_large_light`
- **Description**: primaryButton height 24pt is below Apple HIG minimum requirement of 44x44pt.
- **Guidance**: Increase frame dimensions to at least 44x44pt.
```swift
.frame(minWidth: 44, minHeight: 44)
```

</details>

---
*Generated automatically by [ViewLens](https://github.com/SerialForBreakfast/ViewLens) Pure Swift Agent Engine.*