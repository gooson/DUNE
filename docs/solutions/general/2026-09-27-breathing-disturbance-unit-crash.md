---
tags: [healthkit, breathing-disturbances, unit-conversion, crash]
category: general
date: 2026-09-27
status: implemented
severity: critical
related_files:
  - DUNE/Data/HealthKit/BreathingDisturbanceQueryService.swift
  - DUNETests/BreathingDisturbanceTests.swift
related_solutions:
  - architecture/2026-03-28-sleep-analysis-5axis-enhancement.md
---

# Solution: Breathing Disturbance 단위 변환 크래시

## Problem

수면 상세 화면에서 HealthKit 호흡 장애 샘플을 읽으면 `Attempt to convert incompatible units: count, count/hr` NSException으로 앱이 종료됐다.

### Root Cause

`appleSleepingBreathingDisturbances`의 HealthKit 저장 단위는 `count`다. Xcode SDK의 `HKTypeIdentifiers.h`도 `count, Discrete (Arithmetic)`으로 명시한다. 화면의 시간당 표시 의미를 저장 단위로 해석하여 `count/hr`로 변환한 것이 원인이다. 이 Objective-C 예외는 Swift `do/catch`로 복구할 수 없다.

## Solution

| File | Change | Reason |
|------|--------|--------|
| BreathingDisturbanceQueryService.swift | `.count()`로 읽고 샘플 변환 메서드 분리 | 저장 단위 준수 및 실제 변환 경로 테스트 |
| BreathingDisturbanceTests.swift | count 단위 HKQuantitySample 회귀 테스트 | 값·날짜 보존, 10 경계, 0~100 범위 검사 |

```swift
let value = sample.quantity.doubleValue(for: .count())
```

샘플 길이가 8시간이어도 저장된 값을 다시 시간으로 나누지 않는다. 기존 범위와 상승 여부 계산은 유지한다.

## Prevention

### Validation

- `git diff --check` 통과.
- `scripts/test-unit.sh --ios-only --no-regen`: 앱·테스트 컴파일 후 시뮬레이터 실행이 진행되지 않아 중단. 테스트 통과는 미확인이다. 로그에 iOS 27.1 build 식별 관련 `invalidDigitCount(94401)`도 출력됐다.
- 실기기 재검증은 아직 수행하지 않았다.

- HealthKit 단위는 화면 레이블에서 추론하지 않고 SDK의 quantity type 계약을 확인한다.
- Domain 모델만 생성하는 테스트 외에 실제 HKQuantitySample을 변환하는 회귀 테스트를 유지한다.
- 실기기에서 호흡 장애 데이터가 존재하는 수면 상세 화면을 다시 열어 확인한다.

## Lessons Learned

표시 단위의 의미와 HealthKit 저장 단위는 다를 수 있다. 단위 오류는 일반 Swift 오류 처리에 도달하기 전에 앱을 종료할 수 있다.
