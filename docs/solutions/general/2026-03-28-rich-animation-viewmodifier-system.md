---
tags: [animation, swiftui, viewmodifier, stagger, chart, performance, reduce-motion]
date: 2026-03-28
category: general
status: implemented
---

# Solution: Rich Animation ViewModifier System

## Problem

앱 전체에 일관된 등장 애니메이션이 없었음. Dashboard의 insight cards에만 인라인 stagger가 있었고, Activity/Wellness/Life 탭과 detail views는 데이터가 즉시 표시되어 시각적 품질이 낮았음.

## Solution

### 1. 공용 ViewModifier 3종

| Modifier | 용도 | 파일 |
|----------|------|------|
| `StaggeredAppearModifier` | slide-up + fade + scale 등장 | `ViewModifiers/StaggeredAppearModifier.swift` |
| `ChartDrawModifier` | 왼→오 mask reveal | `ViewModifiers/ChartDrawModifier.swift` |
| `PressableCardStyle` | press scale + haptic | `ViewModifiers/PressableModifier.swift` |

### 2. DS.Animation 프리셋 확장

```swift
static let cardEntrance = Animation.spring(duration: 0.5, bounce: 0.15)
static let pressDown = Animation.spring(duration: 0.2, bounce: 0.0)
static let pressUp = Animation.spring(duration: 0.4, bounce: 0.15)
static let chartDraw = Animation.easeOut(duration: 0.8)
static func staggerDelay(index:base:maxIndex:) -> Double
```

### 3. 적용 범위

- Dashboard: 12개 섹션 (body를 `dashboardUpperContent`/`dashboardLowerContent`로 분리)
- Activity: 13개 섹션
- Wellness: 8개 섹션
- Life: 4개 섹션
- Detail views: 5개 주요 화면
- Charts: 6개 차트 타입 (SleepStage 제외 — drawingGroup 비호환)

### 4. HeroScoreCard glow pulse

카운터 완료 후 ring에 shadow glow 1회 pulse. Task sleep 기반 타이밍.

## Key Decisions

| 결정 | 이유 |
|------|------|
| `.task` 사용 (`.onAppear` 아님) | swiftui-patterns.md 규칙: 부모 트랜잭션 간섭 방지 |
| maxIndex 기본값 12 | Activity 탭 13개 섹션 대응 |
| DashboardView body 분리 | 인라인 stagger 추가 시 type-checker 한계 초과 |
| SleepStageChart 스킵 | `.drawingGroup()` 위에 mask 애니메이션 비호환 |
| baseDelay/maxIndex 파라미터 제거 | YAGNI — 모든 call site가 기본값 사용 |

## Prevention

- 새 탭/화면 추가 시 섹션에 `.staggeredAppear(index:)` 적용
- 새 차트 추가 시 `.chartDrawAnimation()` 적용 (단, `.drawingGroup()` 사용 차트는 제외)
- 모든 Rich 애니메이션은 `reduceMotion` 대응 필수
- DashboardView body가 다시 커지면 추가 computed property 분리

## Lessons Learned

- SwiftUI body의 type-checker 한계: modifier를 많이 추가하면 "unable to type-check this expression" 에러 발생. `@ViewBuilder` computed property로 분리하면 해결.
- `.onAppear` 내 `withAnimation`은 부모 transition과 충돌 가능 → `.task` 사용이 안전.
- `DS.Animation.staggerDelay` 파라미터명 `max`는 stdlib `max()` 함수와 shadow → `maxIndex`로 변경.
