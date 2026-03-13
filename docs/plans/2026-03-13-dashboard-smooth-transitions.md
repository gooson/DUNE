---
tags: [dashboard, animation, ux, swiftui, transitions, optimistic-update]
date: 2026-03-13
category: plan
status: approved
---

# Plan: 투데이탭 부드러운 전환 UX 개선

## Summary

DashboardView에서 리로드/섹션 토글 시 레이아웃 점프를 제거하고, 부드러운 애니메이션 전환을 적용한다.

## Related Documents

- `docs/brainstorms/2026-03-13-dashboard-smooth-transitions.md`
- `docs/solutions/architecture/2026-03-08-dashboard-first-load-appearance-gate.md` (hasAppeared gate 패턴)
- `docs/solutions/general/2026-02-17-chart-ux-layout-stability.md` (overlay + minHeight 패턴)

## Affected Files

| File | Change | Risk |
|------|--------|------|
| `DashboardViewModel.swift` | loadData()에서 nil 리셋 제거 → 낙관적 업데이트 | Medium — 첫 로딩과 리로드 분기 주의 |
| `DashboardView.swift` | 섹션별 .transition() 추가, withAnimation 래핑, staggered 카드 확장 | Low — View-only 변경 |

## Implementation Steps

### Step 1: ViewModel — 낙관적 업데이트 (DashboardViewModel.swift)

**목표**: 리로드 시 기존 데이터를 유지하고, 새 데이터가 도착하면 교체.

**변경 사항**:
- `loadData()`에서 첫 로딩(`sortedMetrics.isEmpty`)일 때만 nil 리셋
- 이후 리로드에서는 nil 리셋 생략 → 기존 값 유지
- `errorMessage = nil`은 항상 리셋 (새 에러 상태 반영 위해)
- `sortedMetrics` 할당 등 UI 상태 변경을 `withAnimation(DS.Animation.standard)` 래핑

**핵심 코드**:
```swift
func loadData(canLoadHealthKitData: Bool = true) async {
    guard !isLoading else { return }
    isLoading = true

    let isFirstLoad = sortedMetrics.isEmpty && conditionScore == nil

    // 첫 로딩에서만 nil 리셋 (skeleton 표시를 위해)
    if isFirstLoad {
        conditionScore = nil
        baselineStatus = nil
        recentScores = []
        coachingMessage = nil
        focusInsight = nil
        insightCards = []
        heroBaselineDetails = []
        baselineDeltasByMetricID = [:]
        activeDaysThisWeek = 0
        weatherSnapshot = nil
        weatherAtmosphere = .default
    }

    // errorMessage는 항상 리셋
    errorMessage = nil

    // ... 기존 fetch 로직 유지 ...

    // 결과 적용 시 애니메이션 래핑
    withAnimation(DS.Animation.standard) {
        weatherSnapshot = weatherResult
        weatherAtmosphere = weatherResult.map { WeatherAtmosphere.from($0) } ?? .default
        sortedMetrics = allMetrics.sorted { ... }
        // ... 나머지 상태 할당 ...
    }

    isLoading = false
}
```

**Verification**:
- 첫 로딩: skeleton → 데이터 (기존 동작 유지)
- 리로드: 기존 데이터 유지 → 새 데이터로 부드럽게 전환
- 에러 시: 기존 데이터 유지 + 에러 배너만 추가

### Step 2: View — 섹션 트랜지션 (DashboardView.swift)

**목표**: 모든 조건부 섹션에 `.transition()` 적용.

**변경 사항**:
모든 `if` 조건 블록의 콘텐츠에 `.transition(.opacity.combined(with: .scale(scale: 0.95, anchor: .top)))` 추가.

적용 대상:
1. ConditionHeroView / BaselineProgressView (line 90-106)
2. WeatherCard / WeatherCardPlaceholder (line 109-119)
3. TodayCoachingCard (line 122-127)
4. insightCardsSection (line 134-136)
5. sleepDeficitSection (line 332-341)
6. pinnedSection (line 142-144)
7. conditionCards section (line 159-167)
8. activityCards section (line 170-178)
9. bodyCards section (line 181-189)
10. errorBanner (line 154-156)
11. lastUpdated text (line 147-152)

**핵심 코드**:
```swift
if !viewModel.conditionCards.isEmpty {
    cardSection(...)
        .transition(.opacity.combined(with: .scale(scale: 0.95, anchor: .top)))
}
```

### Step 3: View — 콘텐츠 전체를 `.animation` 래핑

**목표**: 섹션 변경에 대해 부모 VStack이 자동으로 레이아웃 애니메이션 적용.

**변경 사항**:
DashboardView의 콘텐츠 VStack에 `.animation(reduceMotion ? .none : DS.Animation.standard, value: viewModel.sortedMetrics.count)` 추가.

`sortedMetrics.count`를 value로 사용하여 O(1) 비교 (correction #8 준수).

### Step 4: View — Staggered 카드 애니메이션 확장

**목표**: 첫 로딩뿐 아니라 카드 콘텐츠 변경 시에도 staggered 애니메이션 적용.

**변경 사항**:
`cardGrid`의 기존 `hasAppeared` 기반 애니메이션을 유지하되, `withAnimation` 래핑된 상태 변경이 자동으로 `.animation` modifier와 연계되도록 함. 추가 코드 변경 없이 Step 1의 `withAnimation` 래핑으로 달성.

## Test Strategy

- UI 수동 검증 (제스처 변경 포함이므로 testing-required.md 준수):
  1. 첫 앱 실행 → skeleton → 데이터 표시 (부드러운 전환)
  2. Pull-to-refresh → 기존 데이터 유지 → 변경분만 전환
  3. HealthKit 일부 실패 → 에러 배너만 부드럽게 추가
  4. 핀 편집 → 섹션 추가/제거 시 부드러운 전환
  5. `reduceMotion` 켠 상태에서 점프 없는지 확인
- 빌드 검증: `scripts/build-ios.sh`

## Risks & Edge Cases

| Risk | Mitigation |
|------|-----------|
| `withAnimation` 내 async 코드 실행 | `@MainActor` 클래스이므로 안전. withAnimation은 상태 할당만 래핑 |
| 첫 로딩과 리로드 분기 로직 오류 | `isFirstLoad = sortedMetrics.isEmpty && conditionScore == nil` 조건으로 명확 분리 |
| `hasAppeared` gate와 충돌 | 기존 gate 로직 유지 — 첫 로딩에서만 적용 |
| transition 중복 적용으로 과도한 애니메이션 | `reduceMotion` 체크 + 표준 DS.Animation 사용 |
