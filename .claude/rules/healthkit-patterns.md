# HealthKit Query Patterns

## 쿼리 병렬화

| 상황 | 패턴 | 예시 |
|------|------|------|
| 독립 쿼리 2-3개 | `async let` | HRV + RHR today + RHR yesterday |
| 독립 쿼리 4개+ | `withThrowingTaskGroup` | 7일치 수면 데이터 |
| 순차 필요 | 순차 `await` | 이전 결과에 의존하는 쿼리 |

## 금지 패턴

```swift
// BAD: for 루프 내 await (순차 실행)
for day in 0..<7 {
    let data = try await service.fetch(for: day)
}

// GOOD: TaskGroup으로 병렬 실행
try await withThrowingTaskGroup(of: Result.self) { group in
    for day in 0..<7 {
        group.addTask { [service] in
            try await service.fetch(for: day)
        }
    }
}
```

## TaskGroup 주의사항

- Actor-isolated 프로퍼티 접근 시 `[service]` capture list 사용
- 결과 수집 후 정렬 필요 (TaskGroup은 완료 순서가 비결정적)
- `Optional` 결과는 `of: Result?.self`로 선언, 수집 시 `if let` 필터

## Watch 소스 감지

`bundleIdentifier.contains("watch")` 단독 사용 금지. Apple Watch → iPhone 동기화 경로에서 `com.apple.health.{UUID}` 패턴 사용.

```swift
// GOOD: productType 우선 → bundleID fallback
private func isWatchSource(_ sample: HKSample) -> Bool {
    if let productType = sample.sourceRevision.productType,
       productType.hasPrefix("Watch") { return true }
    return sample.sourceRevision.source.bundleIdentifier
        .localizedCaseInsensitiveContains("watch")
}
```

## Watch Workout Bundle ID

Watch companion 앱이 HealthKit에 저장한 워크아웃은 parent iOS 앱의 bundle ID를 사용.
`isFromThisApp` 판정만으로 Watch vs iOS를 구분할 수 없음.
Dedup 시 `isFromThisApp`을 단독 필터 조건으로 사용 금지.

```swift
// BAD: Watch 워크아웃이 ExerciseRecord 없으면 사라짐
if workout.isFromThisApp { return false }

// GOOD: type + date proximity (±2min) 매칭 필수
if workout.isFromThisApp {
    let hasProbableMatch = records.contains { record in
        record.exerciseType == workout.activityType.rawValue
            && abs(record.date.timeIntervalSince(workout.date)) < 120
    }
    if hasProbableMatch { return false }
}
```

## Sleep 데이터 중복 제거

- 정렬 후 sweep-line 방식 사용
- **동일 소스** overlap: 유지 (수면 단계 전환기의 겹침은 정상)
- **동일 소스 unspecified** + 구체적 stage overlap: unspecified skip (과다 집계 방지)
- **다른 소스** overlap: Watch 우선, 동일 우선순위면 더 긴 duration 유지
- 시간 겹침 판정: `a.startDate < b.endDate && b.startDate < a.endDate`
