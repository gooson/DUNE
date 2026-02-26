---
tags: [wave-background, environment-key, swiftui, design-system, scrollContentBackground, theming, watchos]
category: architecture
date: 2026-02-27
severity: important
related_files:
  - DUNE/Presentation/Shared/Components/WaveShape.swift
  - DUNE/Presentation/Shared/Components/WavePreset.swift
  - DUNE/Presentation/Shared/DesignSystem.swift
  - DUNEWatch/Views/WatchWaveBackground.swift
related_solutions:
  - 2026-02-26-visual-overhaul-warm-tone-alignment.md
  - 2026-02-27-design-system-consistency-integration.md
---

# Solution: Wave Expansion to All Screens + Desert Horizon Palette

## Problem

### Symptoms

- Exercise 목록/상세, 근육맵, 운동 템플릿, 완료 시트 등 다수 화면에 웨이브 배경이 없음
- 웨이브가 있는 ExerciseView에서도 List의 기본 배경이 웨이브를 가림
- `DetailWaveBackground`만 `overrideColor` init 파라미터를 가져 Tab/Sheet 변형과 API 불일치
- `WavePreset`에 `.injury`, `.watch` 등 소비자 없는 dead case 존재
- Watch 웨이브 매직넘버 산재

### Root Cause

1. **누락된 `.scrollContentBackground(.hidden)`**: SwiftUI `List`/`Form`은 기본적으로 불투명 배경을 가짐. `.background { WaveBackground() }`만 추가하면 List 배경 뒤에 웨이브가 가려짐
2. **점진적 기능 추가로 인한 불일치**: 새 화면 추가 시 웨이브 배경 적용이 체크리스트에 없어 누락
3. **overrideColor 패턴 혼재**: DetailWaveBackground만 init 파라미터, 나머지는 Environment — 호출 방식 불일치
4. **미래 대비 enum case**: 실제 소비자 없이 "나중에 쓸 것" 패턴으로 추가된 case가 모든 switch에 분기 추가

## Solution

### Changes Made

| File | Change | Reason |
|------|--------|--------|
| WavePreset.swift | `.injury`, `.watch` case 삭제 | Dead code 제거 — 소비자 없는 case |
| WaveShape.swift (DetailWaveBackground) | `overrideColor` 파라미터 삭제 | Environment 전용 API로 통일 |
| WaveShape.swift (Tab/Detail/Sheet) | `color.opacity()` 호출을 `let`으로 호이스트 | body 렌더마다 Color allocation 방지 |
| WaveShape.swift (SheetWaveBackground) | `DS.Gradient.sheetBackgroundEnd` 토큰 사용 | 매직넘버 UnitPoint 제거 |
| DesignSystem.swift | `DS.Gradient.sheetBackgroundEnd` 토큰 추가 | UnitPoint(x:0.5, y:0.5) 일관 관리 |
| WatchWaveBackground.swift | `WatchWaveDefaults` enum으로 상수 추출 | 매직넘버 제거, 변경 용이성 |
| ExerciseView.swift | `.scrollContentBackground(.hidden)` 추가 | 기존 TabWaveBackground 노출 |
| ExerciseHistoryView.swift | `DetailWaveBackground()` 추가 | Push detail에 웨이브 배경 부여 |
| MuscleMapView.swift | `DetailWaveBackground()` 추가 | Push detail에 웨이브 배경 부여 |
| WorkoutTemplateListView.swift | `DetailWaveBackground()` + `.scrollContentBackground(.hidden)` | Push detail에 웨이브 + List 투명화 |
| CompoundWorkoutSetupView.swift | `SheetWaveBackground()` + `.scrollContentBackground(.hidden)` | Sheet에 웨이브 + List 투명화 |
| WorkoutCompletionSheet.swift | `SheetWaveBackground()` 추가 | Sheet에 웨이브 배경 부여 |
| ShareImageSheet.swift | `SheetWaveBackground()` 추가 | Sheet에 웨이브 배경 부여 |
| BodyCompositionFormSheet.swift | `SheetWaveBackground()` + `.scrollContentBackground(.hidden)` | Sheet에 웨이브 + Form 투명화 |
| MetricDetailView 외 3개 | `.environment(\.waveColor, ...)` 패턴으로 전환 | overrideColor 제거에 따른 호출부 수정 |

### Key Code

**3-tier 웨이브 배경 적용 패턴:**

```swift
// Tab root — 강한 웨이브
TabWaveBackground()  // amplitude 100%, opacity 100%

// Push detail — 중간 웨이브
DetailWaveBackground()  // amplitude 50%, opacity 70%

// Sheet/modal — 약한 웨이브
SheetWaveBackground()  // amplitude 40%, opacity 60%
```

**List/Form 투명화 필수:**

```swift
List { ... }
    .scrollContentBackground(.hidden)  // 없으면 웨이브가 가려짐
    .background { DetailWaveBackground() }
```

**색상 오버라이드 — Environment 패턴:**

```swift
// BAD: init 파라미터 (API 불일치)
DetailWaveBackground(overrideColor: .red)

// GOOD: Environment (3-tier 모두 동일 패턴)
DetailWaveBackground()
    .environment(\.waveColor, .red)
```

**Watch 상수 관리:**

```swift
private enum WatchWaveDefaults {
    static let amplitude: CGFloat = 0.03
    static let frequency: CGFloat = 1.5
    static let verticalOffset: CGFloat = 0.6
    static let bottomFade: CGFloat = 0.5
    static let frameHeight: CGFloat = 80
}
```

## Prevention

### Checklist Addition

- [ ] 새 View 추가 시 웨이브 배경 적용 여부 확인 (Tab root → `TabWaveBackground`, Push → `DetailWaveBackground`, Sheet → `SheetWaveBackground`)
- [ ] `List`/`Form` 사용 시 `.scrollContentBackground(.hidden)` 누락 여부 확인
- [ ] `WavePreset`에 새 case 추가 시 실제 소비자(environment setter)가 있는지 확인
- [ ] Environment 기반 API만 사용 — init 파라미터로 색상/프리셋 전달 금지

### Rule Addition (if applicable)

`.claude/rules/` 에 wave-background 규칙 추가 고려:

```
# Wave Background Rules
- 모든 화면에 3-tier 웨이브 배경 적용 (Tab/Detail/Sheet)
- List/Form 사용 시 .scrollContentBackground(.hidden) 필수
- 색상 오버라이드는 .environment(\.waveColor, ...) 패턴만 사용
- WavePreset에 소비자 없는 case 추가 금지
```

## Lessons Learned

1. **`.scrollContentBackground(.hidden)`은 웨이브의 전제조건**: 배경을 추가해도 List/Form의 기본 불투명 배경이 가리면 보이지 않음. 웨이브 배경과 `.scrollContentBackground(.hidden)`은 항상 세트로 적용
2. **Environment 패턴이 init 파라미터보다 일관적**: 3가지 변형(Tab/Detail/Sheet)이 동일한 Environment Key를 읽으므로 호출 패턴이 통일됨. 특정 변형에만 init 파라미터를 추가하면 API 불일치 발생
3. **Dead case는 추가 시점이 아니라 소비 시점에 생성**: "나중에 쓸 것"이라고 미리 추가한 enum case는 모든 switch에 분기를 추가하고 리뷰 비용을 높임. 실제 consumer가 생길 때 추가하는 것이 올바름
4. **Watch 매직넘버는 enum으로 집중 관리**: iOS는 DS 토큰 시스템이 있지만 Watch는 파일 내 상수가 산재되기 쉬움. `WatchWaveDefaults` 패턴으로 한 곳에서 관리
