---
tags: [watchos, cardio, stair-climber, machine-level, ui]
date: 2026-03-15
category: plan
status: draft
---

# Plan: Watch 스텝 클라이머 시작 레벨 입력 추가

## Problem

Watch에서 천국의계단(스텝 클라이머) 운동을 선택하면 Indoor 버튼만 표시되고, 시작 전에 머신 레벨을 설정할 수 없다. 세션 중 CardioSecondaryPage(4번째 탭)에서 레벨 조절은 가능하지만, 운동 시작 시 기본 레벨이 nil이라 사용자가 시작 직후 탭을 스와이프해서 레벨을 설정해야 한다.

## Root Cause

- `WorkoutPreviewView.cardioStartContent`에 `supportsMachineLevel` 분기가 없어서 레벨 피커가 표시되지 않음
- `WorkoutManager.startCardioSession`에 초기 레벨 파라미터가 없음

## Affected Files

| File | Change | Risk |
|------|--------|------|
| `DUNEWatch/Views/WorkoutPreviewView.swift` | 레벨 피커 UI 추가 | Low — UI-only |
| `DUNEWatch/Managers/WorkoutManager.swift` | `startCardioSession`에 `initialLevel` 파라미터 추가 | Low — optional param |
| `DUNEWatchTests/WatchExerciseHelpersTests.swift` | 기존 테스트 영향 확인 | Low |

## Implementation Steps

### Step 1: WorkoutManager에 initialLevel 파라미터 추가

- `startCardioSession(activityType:isOutdoor:secondaryUnit:)` → `initialLevel: Int? = nil` 파라미터 추가
- `initialLevel`이 있으면 세션 시작 직후 `setMachineLevel(initialLevel)` 호출
- 기존 호출자는 default nil로 영향 없음

### Step 2: WorkoutPreviewView에 레벨 피커 추가

- `cardioStartContent`에서 `cardioUnit.supportsMachineLevel`이면 레벨 피커 표시
- `@State private var selectedLevel: Int = 5` (기본 레벨 5 — 1-20 범위 중간값)
- Stepper 또는 +/- 버튼 UI (CardioSecondaryPage 패턴 재사용)
- `startCardio` 호출 시 `initialLevel: selectedLevel` 전달

### Step 3: UI 검증

- 스텝 클라이머 선택 시 레벨 피커가 표시되는지 확인
- 레벨 설정 후 시작 시 세션에 레벨이 반영되는지 확인
- 거리 기반 카디오(러닝 등)에는 레벨 피커가 표시되지 않는지 확인

## Test Strategy

- 기존 `WatchExerciseHelpersTests` 통과 확인
- `WorkoutManager.startCardioSession` 호출 시 initialLevel 반영 검증은 수동(시뮬레이터)

## Risks / Edge Cases

- 레벨 범위는 `CardioSecondaryUnit.machineLevelRange` (1-20)에서 가져옴
- `timeOnly` 유닛도 `supportsMachineLevel == true`이므로 엘립티컬 등에서도 레벨 피커가 표시됨 — 이는 의도된 동작
- 기존 `startCardioSession` 호출자(recovery state 등)는 `initialLevel` 기본값 nil로 영향 없음

## Localization

- `Level` 문자열은 이미 등록됨 (`CardioSecondaryPage`에서 사용 중)
- 새 문자열 추가 필요 없음 (기존 "Level", "Indoor" 재사용)
