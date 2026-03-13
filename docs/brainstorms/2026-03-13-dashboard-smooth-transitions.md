---
tags: [dashboard, animation, ux, swiftui, transitions]
date: 2026-03-13
category: brainstorm
status: draft
---

# Brainstorm: 투데이탭 부드러운 전환 UX 개선

## Problem Statement

투데이탭(DashboardView)에서 정보가 숨김/표시되거나 리로드될 때 레이아웃이 "덜컹덜컹" 점프한다.
원인은 5가지로 분석됨:

1. **`loadData()`에서 모든 상태를 nil로 리셋** → 섹션이 사라졌다 다시 나타남
2. **섹션 표시/숨김에 애니메이션/트랜지션 없음** → `if !cards.isEmpty` 토글이 즉시 반영
3. **Weather 카드 placeholder → 실제 카드 전환 시 높이 변화** → 주변 콘텐츠 밀림
4. **`sortedMetrics` 변경 시 카드 그리드 한꺼번에 재배치** → 점프
5. **리로드 시 skeleton 미표시** → `isLoading && !hasAppeared` 조건으로 첫 로딩에만 표시

## Target Users

- 매일 투데이탭을 반복 확인하는 사용자
- pull-to-refresh로 최신 데이터를 확인하는 사용자
- 섹션 핀/언핀을 통해 커스텀 레이아웃을 사용하는 사용자

## Success Criteria

1. pull-to-refresh 시 기존 데이터가 유지되고, 변경된 값만 부드럽게 전환
2. 섹션이 나타나거나 사라질 때 opacity + scale 트랜지션 적용
3. 카드 그리드 업데이트 시 staggered 애니메이션으로 순차 등장
4. placeholder와 실제 콘텐츠 높이가 일치하여 레이아웃 점프 없음
5. `reduceMotion` 접근성 설정 존중

## Proposed Approach

### A1. 낙관적 업데이트 (Optimistic Update)

**현재**: `loadData()`가 모든 상태를 nil/빈 배열로 초기화 → 로딩 → 재할당
**개선**: 기존 값을 유지한 채 새 데이터를 fetch → `withAnimation`으로 diff만 반영

```swift
// BEFORE (현재)
func loadData() async {
    isLoading = true
    conditionScore = nil     // ← 히어로 사라짐
    sortedMetrics = []       // ← 카드 전부 사라짐
    weatherSnapshot = nil    // ← 날씨 사라짐
    // ... fetch ...
    conditionScore = newScore  // ← 다시 나타남 (점프!)
}

// AFTER (개선)
func loadData() async {
    isLoading = true
    // 기존 값 유지 - nil 리셋 제거

    // ... fetch ...

    // 변경분만 애니메이션으로 적용
    withAnimation(DS.Animation.standard) {
        conditionScore = newScore
        sortedMetrics = newMetrics
        weatherSnapshot = newWeather
        // ...
    }
    isLoading = false
}
```

**핵심 원칙**: 첫 로딩(hasAppeared == false)에서만 nil → skeleton, 이후 리로드는 기존 값 유지.

### A2. 섹션 트랜지션 (Section Transitions)

모든 조건부 섹션에 `.transition(.opacity.combined(with: .scale(scale: 0.95)))` 적용:

```swift
// BEFORE
if !conditionCards.isEmpty {
    ConditionSection(cards: conditionCards)
}

// AFTER
if !conditionCards.isEmpty {
    ConditionSection(cards: conditionCards)
        .transition(.opacity.combined(with: .scale(scale: 0.95, anchor: .top)))
}
```

적용 대상: ConditionHero, WeatherCard, CoachingCard, InsightCards, SleepDeficit,
Pinned/Condition/Activity/Body 섹션, ErrorBanner

### A3. Staggered 카드 애니메이션

현재 첫 로딩에만 적용된 staggered 패턴을 리로드에도 확장:

```swift
// 카드 그리드에서 index 기반 delay
.animation(
    reduceMotion ? .none : .easeOut(duration: 0.35).delay(Double(min(index, 5)) * 0.05),
    value: cardIdentity  // hasAppeared 대신 카드 내용 변화 감지
)
```

### A4. Placeholder 높이 안정화

Weather 카드 등 placeholder와 실제 콘텐츠의 높이 차이를 `.frame(minHeight:)`로 통일:

```swift
// Weather 영역에 고정 최소 높이
Group {
    if let snapshot = weatherSnapshot {
        WeatherCard(snapshot: snapshot)
    } else {
        WeatherCardPlaceholder()
    }
}
.frame(minHeight: weatherCardMinHeight)  // placeholder == actual 높이 일치
```

## Constraints

- **기술**: SwiftUI의 `withAnimation`은 @Published 변경에 대해 main actor에서 호출 필요
- **성능**: staggered delay가 많은 카드에 적용되면 렌더 부하 → `min(index, 5)` cap 유지
- **접근성**: `@Environment(\.accessibilityReduceMotion)` 존중 → `.none` fallback
- **기존 패턴**: correction log의 SwiftUI patterns 준수 (`.id(period)` + `.transition(.opacity)` 등)

## Edge Cases

- **첫 로딩**: 데이터 없음 → skeleton 표시 (기존 유지)
- **리로드 실패**: 기존 데이터 유지 + 에러 배너만 추가 (낙관적 업데이트의 자연스러운 결과)
- **HealthKit 권한 없음**: 빈 섹션이 트랜지션 없이 숨겨짐 → 트랜지션 추가로 자연스럽게
- **빠른 연속 리로드**: `reloadTask?.cancel()` 패턴 유지 (performance-patterns.md)
- **카드 핀/언핀**: 그리드 재배치 시 `.animation` 자동 적용

## Scope

### MVP (Must-have)
- [ ] `loadData()`에서 nil 리셋 제거 → 낙관적 업데이트
- [ ] 모든 조건부 섹션에 `.transition()` 추가
- [ ] `sortedMetrics` 업데이트를 `withAnimation` 래핑
- [ ] Weather placeholder 높이 안정화
- [ ] `reduceMotion` 접근성 분기

### Nice-to-have (Future)
- 카드 값 변화 시 숫자 `.contentTransition(.numericText())` 확대 적용
- 섹션 순서 변경(드래그) 애니메이션
- Shimmer loading indicator (리로드 중 표시)
- 스크롤 위치 복원 (리로드 후 같은 위치 유지)

## Open Questions

없음 — 모든 결정 사항이 확정됨.

## Next Steps

- [ ] `/plan dashboard-smooth-transitions` 으로 구현 계획 생성
