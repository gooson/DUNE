---
tags: [watchos, localization, cardio, activity-type, inference]
category: general
date: 2026-03-10
severity: important
related_files:
  - DUNE/Domain/Models/WorkoutActivityType.swift
  - DUNEWatch/Resources/Localizable.xcstrings
  - DUNETests/WorkoutActivityTypeTests.swift
related_solutions:
  - general/2026-03-02-phone-watch-cardio-parity.md
---

# Solution: Watch Stair Climber가 Mixed Cardio로 보이는 문제

## Problem

watch에서 `천국의계단` 운동을 열면 activity type이 `Mixed Cardio`로 표시되고, 한국어 환경에서도 영어 키가 그대로 노출되는 문제가 있었다.

## Root Cause

1. `WorkoutActivityType.infer(from:)` 키워드 테이블에 `천국의 계단`/`천국의계단` 매핑이 없어 stair 유형으로 추론되지 못함.
2. watch 전용 String Catalog(`DUNEWatch/Resources/Localizable.xcstrings`)에 `Mixed Cardio`, `Stair Climbing`, `Stair Stepper` 키가 없어 `String(localized:)`가 영어 키 fallback을 표시함.

## Solution

- `infer(from:)`에 한국어 stair 키워드 2종을 추가하여 `stairClimbing`으로 우선 매핑.
- watch String Catalog에 3개 activity label 번역(ko/ja) 추가.
- 회귀 방지를 위해 `WorkoutActivityTypeTests`에 한국어 stair 키워드 테스트 추가.

## Prevention Checklist

- [ ] cardio 이름 기반 추론 로직 변경 시 ko/en 대표 별칭 테스트를 같이 추가한다.
- [ ] Shared에서 사용하는 `String(localized:)` 키가 watch에서도 필요한 경우 watch xcstrings 동시 반영한다.
