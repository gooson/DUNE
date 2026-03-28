---
tags: [watch, performance, validation, localization, chart, animation]
date: 2026-03-29
category: general
status: implemented
---

# Review Findings Batch Fix — 14 Items

## Problem

24h 머지 리뷰에서 발견된 14개 미수정 항목을 일괄 수정.

### Watch WC 데이터 손실 (P1)
- `sendSetCompletion`, `sendWorkoutCompletion`: `isReachable` 가드 + `sendMessage`만 사용 → phone이 background이면 데이터 무손실 전달 불가
- `requestWorkoutBulkSync`: 동일 패턴
- iOS `WatchSessionManager.isReachable`: stored property → activation 후 첫 delegate 호출 전까지 stale

### Performance (P2)
- `AllDataViewModel.groupedByDate`: computed property에서 매 render마다 Calendar + Dictionary(grouping:) + sort
- `PersonalRecordsDetailViewModel`: 5개 computed property가 체인으로 매 render마다 O(N) 재계산
- `SleepRegularityCard.formatTime`: FormatStyle + Calendar 매 render 할당
- `OpenMeteoArchiveService.makeDateFormatter()`: 매 호출마다 DateFormatter 할당

### UI/Chart (P2-P3)
- `HeartRateChartView`: `id: \.offset` positional identity, `areaGradient` not static
- `MetricSummaryHeader.badgeColor`: `.heartRate` 상승 시 잘못된 색상
- `MetricDetailView`: duplicate `staggeredAppear(index: 4)`
- `SettingsView`: `CLLocationManager()` @State 기본값에서 생성
- `PersonalRecordsDetailView`: chart `.clipped()` 시 상단 annotation 잘림

### Validation/L10N (P2-P3)
- `AggregateNocturnalVitalsUseCase`: HK 값 범위 검증 누락
- `NapDetectionCard`: 금지된 `String(format:)` 사용
- `AllDataView`: EmptyStateView 동적 l10n leak

## Solution

### Watch WC: sendMessage + transferUserInfo 이중 전달
```swift
if session.isReachable {
    session.sendMessage(message, replyHandler: nil, errorHandler: ...)
}
session.transferUserInfo(message)
```
`transferUserInfo`는 session activated 상태에서 queue에 들어가 phone이 available할 때 전달.

### Performance: stored property + invalidation
- `groupedByDate` → `private(set) var` + `invalidateGroupedByDate()` 호출
- `PersonalRecordsDetailViewModel` → `invalidateDerived()` 에서 모든 파생값 일괄 계산
- FormatStyle/Calendar/DateFormatter → `static let` 호이스트

### HK Range Validation
```swift
let hrValues = hrSamples.map(\.value).filter { (20...300).contains($0) }
let rrValues = rrSamples.map(\.value).filter { (4...60).contains($0) }
let spo2Values = spo2Samples.map(\.value).filter { (0.5...1.0).contains($0) }
```

## Prevention

1. **Watch WC**: `sendMessage`-only 패턴은 항상 `transferUserInfo` fallback 동반
2. **computed property in @Observable**: body에서 접근하는 computed가 O(N) 이상이면 stored + invalidation
3. **Formatter 캐싱**: `DateFormatter`, `FormatStyle`은 `private enum Cache { static let }` 또는 `static let`
4. **HK range validation**: 새 vitals query 추가 시 input-validation.md 범위표 필수 대조
5. **Chart identity**: `ForEach(enumerated(), id: \.offset)` 금지 → `.date` 또는 `Identifiable` 사용
