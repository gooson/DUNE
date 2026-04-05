---
tags: [observation, feedback-loop, swiftui, NavigationStack, focusInsight, coachingMessage]
date: 2026-04-06
category: plan
status: implemented
---

# Plan: 4th Instance of @Observable Feedback Loop in NavigationStack

## Problem Statement

`UIObservationTrackingFeedbackLoopDetected` 재발. NavigationStackHostingController에서 반복 layout invalidation 발생.

이전 3번의 수정:
1. `weatherAtmosphere` → `@State` 캐시 + `.onChange` 동기화
2. `conditionSparkline` → computed에서 stored property로 변환
3. `heroFrame` preference → `.backgroundPreferenceValue` 패턴으로 교체

## Root Cause Analysis

### 직접 원인: `focusInsight`/`coachingMessage` 직접 body 읽기 + async 변경

DashboardView body에서 직접 읽는 volatile 프로퍼티:
- `viewModel.focusInsight` (line 319, 323)
- `viewModel.coachingMessage` (line 319, 324)
- `viewModel.weatherCardInsight` (computed → reads `focusInsight`, line 322)

`enhanceCoachingMessageIfAvailable()`가 async Task에서 둘 다 변경:
```swift
enhanceCoachingTask = Task {
    let enhanced = await enhancer.enhance(...)
    focusInsight = enhanced      // ← body invalidation
    coachingMessage = enhanced.message  // ← body invalidation
}
```

### 왜 이번에 재발했는가

SectionGroup 래핑 변경(PR #760)이 DashboardView body의 view hierarchy를 깊게 만듦:
- SectionGroup마다 3개 gradient 계산 (`sectionSurfaceGradient`, `sectionTopBloom`, `sectionBorderGradient`)
- `@Environment(\.appTheme)`, `@Environment(\.colorScheme)` 읽기 추가
- Body 평가 비용 증가 → 기존 한계점 돌파 → feedback loop 감지 임계값 초과

### Feedback Loop 메커니즘

1. NavigationStack push animation 시작 (Settings 진입 등)
2. DashboardView body 재평가 → `viewModel.focusInsight` 읽기 (observation tracking)
3. `enhanceCoachingTask` 완료 → `focusInsight = enhanced`
4. Observation tracking → body re-evaluation 트리거
5. 하지만 NavigationStack이 아직 layout 중 → re-entrant invalidation
6. SwiftUI가 `UIObservationTrackingFeedbackLoopDetected` 감지

## Affected Files

| File | Change | Reason |
|------|--------|--------|
| `DashboardViewModel.swift` | `weatherCardInsight` computed → stored | 관찰 체인 제거 |
| `DashboardViewModel.swift` | sync in `refreshCoachingData()` + `enhanceCoachingMessageIfAvailable()` | 안정 시점에서만 업데이트 |
| `DashboardView.swift` | `focusInsight`, `coachingMessage` @State 캐시 + .onChange | body에서 직접 @Observable 읽기 제거 |

## Implementation Steps

### Step 1: ViewModel — `weatherCardInsight` stored property로 변환

```swift
// BEFORE: computed — reads focusInsight (observation tracked)
var weatherCardInsight: WeatherCard.InsightInfo? {
    guard let insight = focusInsight, insight.category == .weather,
          weatherSnapshot != nil else { return nil }
    return WeatherCard.InsightInfo(...)
}

// AFTER: stored — synced at stable points
private(set) var weatherCardInsight: WeatherCard.InsightInfo?

private func syncWeatherCardInsight() {
    guard let insight = focusInsight, insight.category == .weather,
          weatherSnapshot != nil else {
        weatherCardInsight = nil
        return
    }
    weatherCardInsight = WeatherCard.InsightInfo(...)
}
```

호출 위치: `refreshCoachingData()` 끝, `enhanceCoachingMessageIfAvailable()` Task 끝.

### Step 2: ViewModel — `standaloneCoachingInsight` stored property로 변환

동일 패턴. `syncStandaloneCoachingInsight()` 추가.

### Step 3: DashboardView — `focusInsight`/`coachingMessage` @State 캐시

```swift
@State private var cachedFocusInsight: CoachingInsight?
@State private var cachedCoachingMessage: String?

// body에서:
if viewModel.shouldShowTodaysBrief,
   !isBriefingDisabled || viewModel.weatherSnapshot != nil || cachedFocusInsight != nil || cachedCoachingMessage != nil {
    TodayBriefCard(
        ...
        focusInsight: cachedFocusInsight,
        coachingMessage: cachedCoachingMessage,
        ...
    )
}

// .onChange:
.onChange(of: viewModel.focusInsight) { _, new in cachedFocusInsight = new }
.onChange(of: viewModel.coachingMessage) { _, new in cachedCoachingMessage = new }
```

`weatherSnapshot`도 async 변경 가능 → 동일하게 캐시.

## Test Strategy

- 빌드 성공 확인
- 기존 DUNETests 통과 확인
- 시뮬레이터에서 Settings 진입/복귀 시 feedback loop 경고 미발생 검증

## Risks / Edge Cases

- `@State` 캐시와 ViewModel 동기화 지연 (1 frame) → 허용 가능 (coaching 데이터)
- `weatherSnapshot` 캐시 누락 시 brief card 깜빡임 → init에서 nil 시작이므로 기존과 동일
