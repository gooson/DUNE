---
tags: [watchos, healthkit, workout-route, authorization, crash, nsinvalidargumentexception]
category: general
date: 2026-11-02
status: implemented
severity: critical
related_files:
  - DUNEWatch/Managers/WorkoutManager.swift
  - DUNEWatchTests/WorkoutManagerAuthorizationTests.swift
---

# Solution: 모든 Watch 운동 시작에서 발생한 HealthKit 권한 요청 크래시

## Problem

러닝의 실내 시작과 랫풀다운 등 운동 종류에 관계없이 시작 버튼을 누르면 Watch 앱이 종료됐다.

### Root Cause

운동 경로 기능에서 공통 권한 요청의 읽기 집합에 `HKSeriesType.workoutRoute()`를 추가하면서 상위 타입인 `HKObjectType.workoutType()`을 빠뜨렸다. 쓰기 집합에는 두 타입이 모두 있었지만 HealthKit은 읽기와 쓰기 집합의 의존성을 각각 검사한다.

2026-10-31 16:09 및 16:11 실기기 로그의 앱 바이너리 UUID를 대조해 심볼화한 결과, 첫 앱 프레임은 기존 `WorkoutManager.requestAuthorization(timeout:)`의 `healthStore.requestAuthorization(toShare:read:)` 호출이었다. 운동 세션 생성과 화면 전환 이전에 발생했다.

같은 타입 집합으로 HealthKit의 `statusForAuthorizationRequest(toShare:read:)`를 호출해 다음 예외를 재현했다.

```text
NSInvalidArgumentException:
Authorization for HKWorkoutTypeIdentifier should also be requested
when requesting authorization to read HKWorkoutRouteTypeIdentifier
```

Objective-C 예외이므로 기존 Swift `do/catch`와 timeout은 앱 종료를 막지 못했다. 일반 Watch UI 테스트는 시뮬레이터에서 HealthKit 권한 요청을 건너뛰므로 이 문제를 발견하지 못했다.

## Solution

- 읽기 집합에 `HKObjectType.workoutType()`을 추가했다.
- 실제 요청에 쓰는 집합을 `WorkoutManager.authorizationReadTypes`와 `authorizationShareTypes`로 분리해 테스트가 동일한 입력을 검사하도록 했다.
- 읽기·쓰기 각각의 경로/운동 타입 의존성 검사와 실제 HealthKit 요청 타입 검증을 추가했다.

[Apple의 운동 경로 문서](https://developer.apple.com/documentation/healthkit/creating-a-workout-route)는 `HKWorkout`과 `HKWorkoutRoute` 모두에 읽기·쓰기 권한을 요청하도록 명시한다.

## Prevention

- 경로 권한을 요청할 때 각 읽기·쓰기 집합에 상위 운동 타입이 있는지 확인한다. 한쪽 집합의 권한이 다른 쪽의 의존성을 충족한다고 가정하지 않는다.
- 시뮬레이터용 운동 우회 경로와 별개로 실제 HealthKit 타입 검증을 유지한다.
- 검증 API는 권한 창을 열지 않는 `statusForAuthorizationRequest`를 사용한다. 서명 없는 시뮬레이터에서 타입 검증 뒤 발생하는 정확한 HealthKit entitlement 누락 오류만 허용하며, 다른 오류는 실패로 처리한다.
- 크래시 원문은 개인정보가 포함될 수 있으므로 ignored `.xcodebuild/watch-start-crashes/`에 보관하고 저장소에 커밋하지 않는다.

### Validation

- 수정 전 회귀 테스트에서 상위 운동 읽기 권한 누락과 위 HealthKit 예외를 모두 재현했다.
- 최종 검사: `scripts/test-unit.sh --watch-only --no-regen --only-testing DUNEWatchTests/WorkoutManagerAuthorizationTests`로 watchOS 27.2 전용 시뮬레이터에서 3개 테스트 통과. 로그: `.xcodebuild/watch-authorization-final.log`.
- 수정한 실기기 빌드의 재설치 및 러닝·근력 운동 시작은 아직 검증하지 않았다. 권한 타입 변경은 앱 화면 배치나 내비게이션을 변경하지 않는다.

## Lessons Learned

HealthKit의 타입 의존성 오류는 일반 Swift 오류가 아닌 예외로 앱을 종료할 수 있다. 실제 권한 요청에 사용하는 타입 집합을 테스트해야 시뮬레이터용 세션이 가리는 실기기 시작 오류를 방지할 수 있다.
