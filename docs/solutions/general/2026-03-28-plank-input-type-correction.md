---
tags: [exercise, plank, inputType, isometric, data-fix, exercises-json]
date: 2026-03-28
category: solution
status: implemented
---

# Plank 운동 inputType 수정 (setsReps → durationIntensity)

## Problem

Plank(플랭크)과 4개 변형(tempo, paused, unilateral, volume)이 `inputType: "setsReps"`로 설정되어 있어, 운동 기록 시 REPS 입력 필드가 표시됨. Plank는 isometric hold 운동으로 시간(duration) 기반 측정이 올바름.

**증상**: 플랭크 운동 시작 시 "REPS" 입력이 표시되어 무게/렙 기반으로 기록하게 됨.

## Solution

`DUNE/Data/Resources/exercises.json`에서 5개 항목의 `inputType`을 `"setsReps"` → `"durationIntensity"`로 변경.

| ID | inputType 변경 |
|----|---------------|
| plank | setsReps → durationIntensity |
| plank-tempo | setsReps → durationIntensity |
| plank-paused | setsReps → durationIntensity |
| plank-unilateral | setsReps → durationIntensity |
| plank-volume | setsReps → durationIntensity |

`category`는 `"bodyweight"` 유지 — iOS에서 Bodyweight 그룹에 계속 표시.

**UI 결과**: MINUTES 스테퍼 입력 표시 (`WorkoutSessionView.durationIntensityInput()`).

## Side Effects

- **Watch 그룹핑**: `WatchExerciseCategory(durationIntensity)` → `.flexibility`로 분류됨 (inputType 기반 그룹핑의 기존 한계)
- **AI 템플릿**: `isTemplateSupported(.durationIntensity)` = false → 플랭크가 AI 템플릿 생성에서 제외 (isometric 운동에 적합)
- **기존 데이터**: SwiftData에 저장된 기존 플랭크 기록은 영향 없음 (새 기록만 durationIntensity 방식)

## Prevention

exercises.json에 새 운동을 추가할 때 isometric hold 운동(plank, wall sit, dead hang 등)은 `durationIntensity` inputType을 사용.

## Lessons Learned

- 운동의 `inputType`은 category(bodyweight/strength/cardio)와 독립적으로 결정해야 함
- Isometric hold 운동은 reps가 아닌 duration으로 측정
- exercises.json 변경은 코드 변경 없이 UI 동작이 바뀌므로, 전체 inputType-dependent 코드 경로를 사전 분석 필요
