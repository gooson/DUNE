---
tags: [localization, xcstrings, i18n, String(localized:), LocalizedStringKey, SwiftUI]
date: 2026-03-01
category: solution
status: implemented
---

# Localization Gap Audit & Fix

## Problem

앱 전반에 다수의 사용자 대면 문자열이 영어 하드코딩 상태로 존재하여 ko/ja locale에서 미번역 상태로 표시됨.

### 영향 범위

- Activity 탭: Training readiness, weekly stats, suggested workout, training load
- Muscle detail: fatigue level, weekly volume, last trained, sleep modifier
- Injury: 상세/편집/통계 화면
- Shared: baseline delta comparisons (vs yesterday, vs 14d avg, vs 60d avg)
- Info sheets: fatigue algorithm 설명

## Root Causes

1. **Pattern A**: View helper 함수가 `String` 파라미터를 받아 `Text(string)` 렌더링 → `Text.init(_ content: some StringProtocol)` 사용되어 LocalizedStringKey 미적용
2. **Pattern B**: ViewModel/Model의 `String` 프로퍼티에 영어 리터럴 직접 할당 → `String(localized:)` 누락

## Solution

### Pattern A Fix — Helper 파라미터 `LocalizedStringKey`

Helper View 함수의 `String` 파라미터를 `LocalizedStringKey`로 변경하여 `Text(LocalizedStringKey)` init이 사용되도록 함.

```swift
// BEFORE
private func sectionHeader(title: String) -> some View {
    Text(title) // Text.init(_ content: some StringProtocol) — NO localization
}

// AFTER
private func sectionHeader(title: LocalizedStringKey) -> some View {
    Text(title) // Text.init(_ key: LocalizedStringKey) — auto-localizes
}
```

**적용 파일**: InfoSheetHelpers, FatigueAlgorithmSheet, MuscleDetailPopover, PeriodComparisonView, InjuryStatisticsView, InjuryHistoryView

### Pattern B Fix — `String(localized:)` 래핑

`String` 타입 프로퍼티/변수에 할당되는 사용자 대면 텍스트를 `String(localized:)` 로 래핑.

```swift
// BEFORE
title: "Volume"

// AFTER
title: String(localized: "Volume")
```

**적용 파일**: ActivityStat, WeeklyStatsDetailViewModel, MetricBaselineDelta, SuggestedWorkoutSection, TrainingLoadChartView, TrainingReadinessHeroCard

### xcstrings 번역 추가

`Localizable.xcstrings`에 ~70개 키의 ko/ja 번역 추가.

## Key Decisions

### `LocalizedStringKey` vs `String(localized:)` in Sendable Structs

`ActivityStat`은 `Sendable` conformance가 필요. `LocalizedStringKey`는 Swift 6 strict concurrency에서 `Sendable`이 아님. 따라서 `String(localized:)` 패턴이 올바른 선택.

```swift
// LocalizedStringKey는 Sendable struct에 저장 불가
struct ActivityStat: Sendable {
    let title: LocalizedStringKey  // ❌ 컴파일 에러
    let title: String              // ✅ String(localized:)로 생성
}
```

### Static Label Hoisting

`HeroScoreCard` 등 `String` 파라미터를 받는 컴포넌트에 전달하는 상수 레이블은 `private enum Labels { static let }` 패턴으로 호이스트하여 per-render allocation 방지.

## Prevention

1. 새 UI 문자열 추가 시 xcstrings에 3개 언어 번역 포함 (기존 rule)
2. `Sendable` struct의 사용자 대면 `String` 필드 → `String(localized:)` 생성자 필수
3. Helper View 함수가 `Text()`에 전달할 레이블을 받을 때 → `LocalizedStringKey` 타입 사용
4. 상수 레이블이 body에서 매번 생성되면 → `private enum` static let으로 호이스트

## Files Changed

| 파일 | 변경 유형 |
|------|----------|
| InfoSheetHelpers.swift | Pattern A (String → LocalizedStringKey) |
| FatigueAlgorithmSheet.swift | Pattern A |
| MuscleDetailPopover.swift | Pattern A + B |
| PeriodComparisonView.swift | Pattern A |
| InjuryStatisticsView.swift | Pattern A |
| InjuryHistoryView.swift | Pattern A + B |
| ActivityStat.swift | Pattern B |
| WeeklyStatsDetailViewModel.swift | Pattern B + displayName 추가 |
| WeeklyStatsDetailView.swift | rawValue → displayName 참조 |
| MetricBaselineDelta.swift | Pattern B |
| SuggestedWorkoutSection.swift | Pattern B |
| TrainingLoadChartView.swift | Pattern B |
| TrainingReadinessHeroCard.swift | Pattern B + static hoisting |
| Localizable.xcstrings | ~70 ko/ja 번역 추가 |
