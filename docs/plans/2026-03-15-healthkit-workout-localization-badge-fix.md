---
tags: [healthkit, localization, badge, ui, workout-title]
date: 2026-03-15
category: plan
status: draft
---

# Plan: HealthKit 운동 이름 한국어화 + 뱃지 UI 수정

## Problem Statement

1. **영어 운동 이름**: HealthKit 커스텀 타이틀(Tempo Run, Upper Strength, Long Ride 등)이 `localizedDisplayName`에서 매칭되지 않아 영어 원문 그대로 표시됨
2. **뱃지 UI 깨짐**: 10K/PR 뱃지 텍스트가 공간 부족 시 줄바꿈되어 "10"+"K", "P"+"R"로 나뉨

## Root Cause Analysis

### 영어 이름 문제
- `WorkoutSummary.localizedTitle`은 `localizedDisplayName(forStoredTitle:)`로 `typeName` 매칭 시도
- "Tempo Run"은 어떤 `typeName`과도 일치하지 않아 nil 반환 → raw `type` fallback → 영어 그대로 표시
- 하지만 `activityType`은 `.running`으로 정확히 설정되어 있음 → 이를 활용하면 한국어 표시 가능

### 뱃지 UI 문제
- `WorkoutBadgeView.milestone()`과 `.personalRecord()`에 `fixedSize()` 미적용
- HStack 내에서 exercise name이 공간을 차지하면 뱃지가 압축되어 텍스트 줄바꿈 발생

## Affected Files

| File | Change | Risk |
|------|--------|------|
| `DUNE/Presentation/Shared/Extensions/WorkoutActivityType+View.swift` | `WorkoutSummary.localizedTitle` fallback에 `activityType.displayName` 추가 | Low — 기존 매칭 로직 유지, fallback만 개선 |
| `DUNE/Presentation/Exercise/Components/WorkoutBadgeView.swift` | 뱃지에 `.fixedSize()` 추가하여 줄바꿈 방지 | Low — 레이아웃 변경 최소 |

## Implementation Steps

### Step 1: WorkoutSummary.localizedTitle fallback 개선
- `localizedDisplayName`이 nil일 때, `activityType != .other`이면 `activityType.displayName` 사용
- 이렇게 하면 "Tempo Run" → `.running` → "달리기" (한국어)

### Step 2: 뱃지 UI fixedSize 적용
- `WorkoutBadgeView.milestone()`에 `.fixedSize()` 추가
- `WorkoutBadgeView.personalRecord()`에 `.fixedSize()` 추가

## Test Strategy
- 기존 `WorkoutTypeCorrectionStoreTests` 통과 확인
- 빌드 성공 확인

## Edge Cases
- `activityType == .other`인 경우 기존대로 raw `type` fallback 유지
- CorrectionStore에 저장된 커스텀 타이틀은 최우선 유지
- mock 데이터의 title은 영어 유지 (HealthKit이 전달하는 원래 값 시뮬레이션)

## Risks
- 사용자가 HealthKit 앱에서 직접 커스텀 타이틀을 설정한 경우, 해당 타이틀 대신 generic activity name이 표시됨 → CorrectionStore를 통해 사용자가 재수정 가능
