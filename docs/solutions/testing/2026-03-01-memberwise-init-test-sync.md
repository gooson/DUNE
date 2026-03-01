---
tags: [swift, memberwise-init, test-helper, struct-field, compilation-error]
category: testing
date: 2026-03-01
severity: minor
related_files: [DUNETests/OutdoorFitnessScoreAirQualityTests.swift, DUNE/Domain/Models/WeatherSnapshot.swift]
related_solutions: []
---

# Solution: Struct 필드 추가 시 테스트 헬퍼 memberwise init 동기화

## Problem

### Symptoms

- CI에서 `OutdoorFitnessScoreAirQualityTests.swift:201` 컴파일 에러 24개 발생
- `missing argument for parameter 'locationName' in call`

### Root Cause

`WeatherSnapshot` struct에 `locationName: String?` 필드가 추가되었으나, 테스트 파일의 `makeSnapshot()` 헬퍼에서 memberwise initializer 호출 시 해당 파라미터를 누락.

Swift struct의 memberwise init은 **모든 stored property 순서대로** 파라미터를 요구하므로, 중간에 필드를 추가하면 그 이후 파라미터만 누락된 것처럼 보이는 에러가 발생.

## Solution

### Changes Made

| File | Change | Reason |
|------|--------|--------|
| `DUNETests/OutdoorFitnessScoreAirQualityTests.swift` | `locationName: nil` 파라미터 추가 | memberwise init 호출 동기화 |

### Key Code

```swift
// Before: locationName 누락
WeatherSnapshot(
    ...
    dailyForecast: [],
    airQuality: airQuality  // locationName이 dailyForecast와 airQuality 사이에 위치
)

// After: locationName 추가
WeatherSnapshot(
    ...
    dailyForecast: [],
    locationName: nil,
    airQuality: airQuality
)
```

## Prevention

### Checklist Addition

- [ ] Domain struct에 새 stored property 추가 시, 테스트 헬퍼(`make{Type}()` 패턴)에서 해당 struct를 직접 생성하는 모든 곳을 검색하여 동기화

### Rule Addition (if applicable)

기존 Correction Log `#34` "새 필드 추가 시 전체 파이프라인 점검"이 이 케이스를 커버. 추가 규칙 불필요.

## Lessons Learned

- Swift struct memberwise init은 default value가 없는 필드가 추가되면 모든 호출처가 깨짐
- `Optional` 필드라도 memberwise init에서는 자동 default가 제공되지 않음 (명시적 `= nil` 선언이 struct 정의에 없으면)
- 테스트 헬퍼에서 struct를 직접 생성하는 패턴이 많을수록, 필드 추가 시 변경 범위가 넓어짐 — factory method나 builder 패턴이 테스트에서 유리할 수 있음 (단, 현재 규모에서는 과잉 설계)
