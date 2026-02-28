---
tags: [swiftdata-query, fetchlimit, calendar-optimization, streak, location-timeout, checkedcontinuation, swift6-concurrency, workout-intensity, tuple-pattern, weather-permission]
category: performance
date: 2026-02-28
severity: important
related_files:
  - DUNE/Presentation/Life/LifeView.swift
  - DUNE/Domain/UseCases/HabitStreakService.swift
  - DUNE/Data/Weather/LocationService.swift
  - DUNE/Data/Weather/WeatherDataService.swift
  - DUNE/Domain/UseCases/WorkoutIntensityService.swift
  - DUNE/Presentation/Life/LifeViewModel.swift
  - DUNE/Presentation/Dashboard/DashboardViewModel.swift
  - DUNE/Presentation/Dashboard/Components/WeatherCard.swift
related_solutions: []
---

# Solution: 리뷰 기반 7건 일괄 수정 (P1×2, P2×5)

## Problem

15시 이후 머지된 102파일 변경에 대한 5관점 리뷰에서 P1 2건, P2 5건 발견.

### Symptoms

1. **P1-1**: TodayExerciseCheckView가 모든 ExerciseRecord를 메모리에 로드 (fetchLimit 없음)
2. **P1-2**: LifeViewModel.applyUpdate에서 `isSaving` 리셋이 View의 `didFinishSaving()` 패턴과 불일치
3. **P2-1**: LocationService에 timeout 없어 GPS 불량 환경에서 무한 대기 가능
4. **P2-2**: WeatherProvider가 fetch 시 자동으로 permission 요청 (사용자 명시 액션 없이)
5. **P2-3**: HabitStreakService weekly streak 계산이 O(52×7) Calendar 연산 수행
6. **P2-4**: LifeView에서 edit sheet 닫힘, exercise 존재 여부 변경 시 recalculate 미호출
7. **P2-5**: WorkoutIntensityService에 5개 모드별 dispatch 함수가 동일 구조 반복

### Root Cause

각각 독립적인 원인:
- P1-1: `@Query` 매크로가 `fetchLimit` 직접 파라미터를 지원하지 않아 누락
- P1-2: Correction #43 패턴 미준수 (isSaving 리셋은 View 책임)
- P2-1: CLLocationManager delegate 콜백이 오지 않는 edge case 미고려
- P2-2: UX 원칙 위반 — permission은 사용자 명시 액션에서만
- P2-3: Calendar.date(byAdding:) 반복 호출 비효율
- P2-4: onChange 트리거 조건 불충분
- P2-5: Correction #148 미적용

## Solution

### Changes Made

| File | Change | Reason |
|------|--------|--------|
| LifeView.swift | `@Query` init에서 `FetchDescriptor(fetchLimit: 20)` 사용 | @Query 매크로는 fetchLimit 미지원 → `Query(FetchDescriptor)` init 필요 |
| LifeView.swift | edit sheet onChange + exercise onChange 추가 | recalculate 누락 시나리오 해소 |
| LifeViewModel.swift | applyUpdate에서 `isSaving = false` 제거 | View가 didFinishSaving() 호출 |
| LocationService.swift | continuation 내부 Task로 30초 timeout | withThrowingTaskGroup은 Swift 6 region checker 호환 안 됨 |
| WeatherDataService.swift | WeatherProviding에 requestLocationPermission() 추가, 자동 호출 제거 | 사용자 명시 액션으로 전환 |
| HabitStreakService.swift | Calendar day offset 정수 연산으로 전환 | O(N) 1회 계산 → Set<Int> O(1) lookup |
| WorkoutIntensityService.swift | 5개 signal 함수 + buildResult 통합 | Correction #148 튜플 반환 단일 함수 |

### Key Code

**SwiftData @Query fetchLimit (매크로 미지원 우회)**:
```swift
// @Query(sort:order:fetchLimit:) 는 컴파일 에러
// FetchDescriptor init을 사용해야 함
@Query private var recentRecords: [ExerciseRecord]

init(exists: Binding<Bool>) {
    _exists = exists
    var descriptor = FetchDescriptor<ExerciseRecord>(
        sortBy: [SortDescriptor(\.date, order: .reverse)]
    )
    descriptor.fetchLimit = 20
    _recentRecords = Query(descriptor)
}
```

**Swift 6 호환 CheckedContinuation timeout**:
```swift
// withThrowingTaskGroup + @MainActor addTask → region checker 에러
// 대신: continuation 내부 Task로 timeout 스케줄
return try await withCheckedThrowingContinuation { continuation in
    self.locationContinuation = continuation
    self.manager.requestLocation()

    Task { @MainActor [weak self] in
        try? await Task.sleep(for: .seconds(30))
        guard let self, self.locationContinuation != nil else { return }
        self.locationContinuation?.resume(throwing: WeatherError.locationTimeout)
        self.locationContinuation = nil
    }
}
```

**Calendar 최적화 — day offset 패턴**:
```swift
// Before: O(52×7) Calendar.date(byAdding:) 호출
// After: O(N) dayOffset 사전 계산 + Set<Int> O(1) lookup
private func dayOffset(from base: Date, to target: Date, calendar: Calendar) -> Int? {
    let components = calendar.dateComponents([.day], from: base, to: target)
    return components.day
}
```

## Prevention

### Checklist Addition

- [ ] `@Query`에 fetchLimit 필요 시 `Query(FetchDescriptor)` init 사용 (매크로 직접 파라미터 미지원)
- [ ] Swift 6 @MainActor 클래스에서 `withThrowingTaskGroup` 내 `@MainActor addTask` 금지 → continuation 내부 Task 패턴 사용
- [ ] `isSaving` 리셋은 항상 View의 `didFinishSaving()` 경유 확인 (Correction #43)
- [ ] onChange 트리거: sheet 닫힘, 외부 데이터 변경 시나리오 점검

### Rule Addition (if applicable)

**swiftui-patterns.md 추가 고려**:
- `@Query` fetchLimit → `Query(FetchDescriptor)` init 패턴 (매크로 미지원)

**performance-patterns.md 추가 고려**:
- Swift 6 `@MainActor` + `withThrowingTaskGroup` 비호환 → continuation 내부 Task timeout 패턴

## Lessons Learned

1. **@Query 매크로 한계**: SwiftData의 `@Query` 매크로는 `fetchLimit`을 직접 파라미터로 지원하지 않음. `FetchDescriptor`를 통해 우회해야 함. 이 제약은 문서에 명시적이지 않아 빌드 시 발견됨.

2. **Swift 6 region-based isolation**: `withThrowingTaskGroup` 내에서 `@MainActor` isolated 프로퍼티 접근이 region checker에 의해 거부됨. `group.addTask { @MainActor in }` 패턴이 "pattern that the region based isolation checker does not understand" 에러 발생. 더 단순한 continuation + scheduled Task 패턴이 호환됨.

3. **리뷰→수정 일괄 적용 효율**: 7건을 priority 순서로 처리하되, 빌드 검증은 마지막에 1회 수행. 빌드 에러 2건 (fetchLimit 매크로, Swift 6 region checker) 발생했으나 순차적으로 해결.

4. **P3 검증 습관**: P3 (minor) 3건 중 3건 모두 false positive 또는 negligible. 실제 코드를 읽고 검증하는 것이 중요 — uvIndex는 이미 Int, color mapping은 의도적 차이, division 캐싱은 불필요.
