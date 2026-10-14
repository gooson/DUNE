---
tags: [healthkit, workout-zones, watchos, heart-rate, swift-concurrency]
date: 2026-10-14
category: solution
status: implemented
---

# 운동 구간의 출처와 실시간 세션 보존

## Problem

기존 운동 상세와 Watch 심박 UI는 최대 심박수 기반의 고정 5구간만 계산했다. HealthKit이 기록한 개인화 구간은 개수와 경계가 다를 수 있고, 같은 번호의 구간도 설정 출처에 따라 의미가 달라진다. 이전 운동에는 저장된 구간 구성이 없을 수 있다.

## Solution

- `WorkoutZoneDistribution`이 HealthKit 구간 구성의 출처, 순서, BPM 경계, 각 구간의 시간을 보존한다. 비정상 시간은 0으로 정규화하고 백분율은 유효 시간의 합으로 계산한다.
- 운동 상세는 저장된 `HKWorkoutZoneGroup`을 우선 읽는다. 구간 구성이 없는 이전 운동은 기존 심박 표본 계산을 사용하고 `Estimated zones`로 표시한다.
- Watch는 `HKLiveWorkoutZoneUpdate`를 받아 현재 구간과 가변 구간 수를 표시한다. 콜백의 builder 식별자를 MainActor로 전달해, 이전 세션의 늦은 콜백이 새 세션의 UI를 바꾸지 않게 한다.
- HealthKit 실시간 구성과 앱의 추정 5구간을 섞지 않는다. 실시간 구성이 있을 때 현재 구간 값이 없으면 미확인 상태로 표시한다.

## Prevention

- 구간 번호만 저장하거나 고정 5구간으로 변환하지 않는다. 출처와 BPM 경계를 함께 전달한다.
- HealthKit 저장 구간이 없을 때만 추정값을 사용하고 UI에서 추정 출처를 밝힌다.
- Watch delegate에서 비동기 UI 갱신을 할 때 콜백의 세션 식별자를 확인한다.
- 가변 구간 수, 무효 시간, 이전 운동 fallback, Watch 화면을 각각 검증한다. 실제 HealthKit 개인화 설정과 실시간 업데이트는 실제 기기에서도 확인한다.
