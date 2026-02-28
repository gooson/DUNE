---
tags: [design-system, DS-tokens, color-consistency, system-colors, xcassets, performance]
category: design
date: 2026-02-28
severity: important
related_files:
  - DUNE/Presentation/Shared/DesignSystem.swift
  - DUNE/Resources/Assets.xcassets/Colors/
  - DUNEWatch/DesignSystem.swift
related_solutions:
  - design/2026-02-26-warm-tone-visual-overhaul.md
  - design/2026-02-28-desert-warm-theme-audit.md
---

# Solution: Desert Warm Theme Full Audit — System Color Elimination

## Problem

`.foregroundStyle(.secondary)` 등 SwiftUI 시스템 색상이 268곳에 산재하여 Desert Warm 테마 일관성을 저해. 인라인 `Color(red:green:blue:)`도 2곳 존재.

### Symptoms

- 시스템 `.secondary`가 warm tone이 아닌 시스템 gray로 렌더링
- Share card 배경이 DS 토큰이 아닌 하드코딩된 RGB 값 사용
- Watch DS에 iOS DS 토큰이 누락
- `heroRingStart`/`heroRingEnd` 같은 dead code 잔존

### Root Cause

MVP 개발 중 SwiftUI 기본 색상을 사용하고, 후속 DS 토큰 전환이 완료되지 않음.

## Solution

### Phase 1: DS Token Expansion

| Token | Purpose | xcassets |
|-------|---------|---------|
| `DS.Color.textSecondary` | `.secondary` 대체 | TextSecondary.colorset |
| `DS.Color.textTertiary` | `.tertiary` 대체 | TextTertiary.colorset |
| `DS.Opacity.overlay` | 시스템 overlay 표준화 | - |
| `DS.Opacity.cardBorder` | 카드 테두리 표준화 | - |

### Phase 2: Bulk System Color Replacement

109개 파일에서 268개 시스템 색상을 DS 토큰으로 교체:
- `.foregroundStyle(.secondary)` → `.foregroundStyle(DS.Color.textSecondary)`
- `.foregroundStyle(.tertiary)` → `.foregroundStyle(DS.Color.textTertiary)`

### Phase 3: Hardcoded Color Extraction

`WorkoutShareCard.swift`의 `Color(red:green:blue:)` → xcassets colorset:
- `ShareCardGradientStart.colorset` (rgb: 0.12, 0.12, 0.18)
- `ShareCardGradientEnd.colorset` (rgb: 0.08, 0.08, 0.14)

### Phase 4: Performance Optimization

- `ProgressRingView`: `static func gradient()` → `static let gradient` (Correction #165)
- `GlassCard`: body 내 gradient allocation → file-scope `static let`
- `FatigueLevel`: stroke color caching

### Phase 5: Dead Code Removal

- `heroRingStart` / `heroRingEnd` unused color tokens
- `primaryTextStyle()` unused ViewModifier function

### Changes Made

| File | Change | Reason |
|------|--------|--------|
| DesignSystem.swift | `textSecondary`, `textTertiary`, `overlay`, `cardBorder` 추가 | 시스템 색상 대체 토큰 |
| 95 Presentation files | `.secondary` → `DS.Color.textSecondary` | 테마 일관성 |
| WorkoutShareCard.swift | ShareCardPalette → xcassets 참조 | Correction #177 |
| ProgressRingView.swift | static func → static let | Correction #165 |
| DUNEWatch/DesignSystem.swift | iOS 토큰 동기화 | Correction #138 |

### Key Code

```swift
// DS Token 정의 (DesignSystem.swift)
enum Color {
    static let textSecondary = SwiftUI.Color("TextSecondary")
    static let textTertiary = SwiftUI.Color("TextTertiary")
}

// 적용 패턴
.foregroundStyle(DS.Color.textSecondary)  // not .secondary

// ShareCardPalette — xcassets 참조
static let backgroundGradient = LinearGradient(
    colors: [Color("ShareCardGradientStart"), Color("ShareCardGradientEnd")],
    startPoint: .topLeading, endPoint: .bottomTrailing
)
```

## Prevention

### Checklist Addition

- [ ] 새 View 작성 시 `.secondary`, `.tertiary` 대신 `DS.Color.textSecondary/textTertiary` 사용
- [ ] `Color(red:green:blue:)` 인라인 사용 금지 — xcassets colorset 생성 (Correction #177)
- [ ] iOS DS 토큰 추가 시 Watch DS 동기화 확인 (Correction #138)

### Rule Addition

Correction #177이 이미 존재하며 이번 작업으로 완전 적용됨.

## Lessons Learned

1. **기계적 치환은 일괄 처리가 효율적**: 268곳을 개별 수정하면 누락 위험. `replace_all` 패턴으로 일괄 적용 후 검증이 안전
2. **DS 토큰은 xcassets 기반이어야 dark mode 대응 가능**: `Color(red:green:blue:)` 인라인은 dark mode variant를 지원하지 않음
3. **리뷰 에이전트에 diff 크기 제한 필요**: 158KB diff에서 3/6 에이전트가 turns 소진. Correction #91 (max_turns: 6, 2000줄 제한) 재확인 필요
