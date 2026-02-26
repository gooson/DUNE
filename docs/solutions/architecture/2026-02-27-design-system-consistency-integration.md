---
tags: [design-system, color-tokens, opacity, watchos, accentColor, xcodegen, DS]
category: architecture
date: 2026-02-27
severity: important
related_files:
  - DUNE/Presentation/Shared/DesignSystem.swift
  - DUNEWatch/DesignSystem.swift
  - DUNE/Presentation/Shared/Components/GlassCard.swift
  - DUNE/Presentation/Shared/Components/ProgressRingView.swift
  - DUNE/Presentation/Shared/Components/WaveShape.swift
related_solutions:
  - architecture/2026-02-21-wellness-section-split-patterns.md
---

# Solution: Design System Consistency Integration (iOS + watchOS)

## Problem

### Symptoms

- 앱 전반에 `Color.accentColor`, `.green`, `.red`, `.yellow`, `.gray`, magic number opacity가 산재
- iOS와 watchOS 간 색상 토큰 불일치 — Watch 뷰가 하드코딩된 SwiftUI 기본 색상 사용
- AccentColor에 dark variant 추가 시 score ring의 "사막 느낌" gradient 소실
- `DS.Opacity` 토큰 부재로 opacity 매직넘버(0.06, 0.08, 0.10, 0.15, 0.30) 중복

### Root Cause

1. **`Color.accentColor` ≠ `Color("AccentColor")` in xcodegen**: `ASSETCATALOG_COMPILER_GLOBAL_ACCENT_COLOR_NAME` 미설정 시 `Color.accentColor`는 시스템 파란색 반환. `Color("AccentColor")`는 asset catalog에서 직접 로드하여 warm golden 반환
2. **Score ring의 의도적 system blue 사용**: ProgressRingView의 AngularGradient에서 system blue가 status color와 혼합되어 다채로운 "사막 느낌" 생성. 이를 warm golden으로 교체하면 단조로운 gradient가 됨
3. **AccentColor dark variant의 시각적 영향**: 밝은 dark variant(0.859, 0.659, 0.502)가 opacity 0.6에서 적용되면 warm glow가 사실상 투명해짐
4. **watchOS 타겟 격리**: iOS DesignSystem.swift를 watchOS에서 import 불가, 별도 DS 파일 필요

## Solution

### Changes Made

| File | Change | Reason |
|------|--------|--------|
| DesignSystem.swift | `DS.Opacity` enum 추가 (subtle/light/medium/border/strong) | 매직넘버 제거, 일괄 조정 가능 |
| GlassCard.swift | `Color.accentColor` → `DS.Color.warmGlow` + `DS.Opacity.*` | asset catalog 직접 참조로 색상 보장 |
| WaveShape.swift | `Color.accentColor` → `DS.Color.warmGlow` | 동일 이유 |
| ProgressRingView.swift | `Color.accentColor` **유지** (revert) | system blue blending이 의도된 시각 효과 |
| HeroScoreCard.swift | `Color.accentColor` **유지** (revert) | ring과 동일한 이유 |
| AccentColor.colorset | dark variant 제거 → universal only | Correction #120 준수, ring 시각 효과 보존 |
| DUNEWatch/DesignSystem.swift | 신규 생성 (Color + Opacity) | Watch 전용 DS 토큰 |
| Watch Views (7개) | `.green/.red/.yellow/.gray` → `DS.Color.*` | 28개 하드코딩 색상 토큰화 |
| Watch heart icons | `DS.Color.negative` → `DS.Color.heartRate` | 시맨틱 정확성 |

### Key Code

**Score ring — 의도적 `Color.accentColor` 유지:**
```swift
// ProgressRingView.swift — system blue가 status color와 혼합되어 "사막 느낌" 생성
private enum Cache {
    static func warmGradientColors(base: Color) -> [Color] {
        [Color.accentColor.opacity(0.6), base, Color.accentColor.opacity(0.8)]
    }
}
```

**Cards, waves — `DS.Color.warmGlow` 사용:**
```swift
// GlassCard.swift — asset catalog 직접 참조로 warm golden 보장
DS.Color.warmGlow.opacity(DS.Opacity.border)  // 0.15, dark mode border
DS.Color.warmGlow.opacity(DS.Opacity.strong)   // 0.30, hero highlight
```

**Color.accentColor vs Color("AccentColor") 판별 기준:**
```
Color.accentColor    → 의도적 system blue blend가 필요한 곳 (ring gradient)
DS.Color.warmGlow    → 확정된 warm golden이 필요한 곳 (cards, waves, text)
```

## Prevention

### Checklist Addition

- [ ] `Color.accentColor` 사용 시 "system blue 의도인가?" 확인. xcodegen 환경에서 asset AccentColor와 다름
- [ ] AccentColor.colorset에 dark variant 추가 시 ring gradient에서 시각 테스트 필수
- [ ] Watch 뷰에 새 색상 추가 시 `DUNEWatch/DesignSystem.swift`의 DS.Color에 토큰 존재 확인

### Rule Addition

**Correction #136 확장 — `Color.accentColor` 예외 조건 명시:**
- 기본 원칙: `Color.accentColor` 사용 금지, `DS.Color.warmGlow` 사용
- 예외: ProgressRingView, HeroScoreCard처럼 system blue blending이 의도된 gradient에서는 `Color.accentColor` 유지
- 이유: xcodegen이 `ASSETCATALOG_COMPILER_GLOBAL_ACCENT_COLOR_NAME` 미설정 → `Color.accentColor` = system blue

## Lessons Learned

1. **`Color.accentColor`의 이중성**: xcodegen 환경에서 system blue를 반환하지만, 이것이 오히려 시각적으로 유리한 경우가 있음 (ring gradient의 multi-tonal blending). "버그"가 "피처"였던 케이스
2. **AccentColor dark variant의 cascade 효과**: 하나의 colorset 변경이 warm glow를 사용하는 모든 gradient에 영향. opacity가 적용된 상태에서의 시각 차이는 preview로 확인하기 어려움
3. **Watch DS는 iOS DS의 부분 집합이 아닌 독립 파일**: 타겟 격리로 인해 공유 불가. 향후 shared Swift package로 통합 필요
4. **DS.Opacity 토큰은 용도 기반 네이밍이 더 효과적**: `emphasis`(강도)보다 `border`(용도)가 코드 검색 및 의미 전달에 유리
