---
tags: [exercise, plank, inputType, durationIntensity, data-fix]
date: 2026-03-28
category: plan
status: approved
---

# Plank 운동 입력 타입 수정: setsReps → durationIntensity

## Problem

Plank(플랭크) 및 모든 변형 운동이 `inputType: "setsReps"` (세트 × 렙)로 설정되어 있어
무게/렙 기반 입력 UI가 표시됨. Plank는 isometric hold 운동으로 시간(duration) 기반 측정이 적합.

## Affected Exercises (exercises.json)

| ID | Name | Current | Target |
|----|------|---------|--------|
| plank | Plank | setsReps | durationIntensity |
| plank-tempo | Plank Tempo | setsReps | durationIntensity |
| plank-paused | Plank Paused | setsReps | durationIntensity |
| plank-unilateral | Single-Arm Plank | setsReps | durationIntensity |
| plank-volume | Plank Volume | setsReps | durationIntensity |

## Affected Files

| File | Change |
|------|--------|
| `DUNE/Data/Resources/exercises.json` | 5개 항목의 inputType 변경 |

## Implementation Steps

### Step 1: exercises.json inputType 변경

5개 plank 항목의 `"inputType": "setsReps"` → `"inputType": "durationIntensity"` 변경.
`category`는 `"bodyweight"` 유지 (plank는 bodyweight 운동).

## UI 영향 분석

- **iOS 운동 세션**: `WorkoutSessionView.durationIntensityInput()` — MINUTES 스테퍼 표시 ✓
- **iOS 컬럼 헤더**: `ExerciseSetColumnHeaders` — "MIN" 헤더 표시 ✓
- **iOS 운동 그룹핑**: `ExerciseCategory.bodyweight` 유지 — Bodyweight 카테고리에 표시 ✓
- **Watch 그룹핑**: `WatchExerciseCategory(durationIntensity)` → `.flexibility` — Flexibility 그룹으로 이동 (inputType 기반 그룹핑의 기존 한계)
- **AI 템플릿**: `isTemplateSupported(.durationIntensity)` = false — 템플릿 생성에서 제외 (isometric 운동은 세트/렙 기반 템플릿에 부적합하므로 수용)

## Test Strategy

- 기존 유닛 테스트(`CorrectiveExerciseUseCaseTests`)는 플랭크 ID만 참조하며 inputType에 의존하지 않음 → 변경 불필요
- exercises.json 변경 후 빌드 검증으로 충분 (inputType enum은 이미 코드에서 완전히 처리됨)

## Risks & Edge Cases

1. **기존 사용자 데이터**: 기존에 setsReps로 기록한 플랭크 워크아웃은 SwiftData에 저장되어 있으며, inputType 변경은 새 워크아웃에만 적용. 기존 기록의 표시에는 영향 없음.
2. **Watch 카테고리 이동**: Bodyweight → Flexibility 그룹으로 이동하지만, 검색으로 접근 가능하므로 접근성 문제 없음.
3. **Template 제외**: 플랭크가 AI 워크아웃 템플릿에서 제외되지만, isometric 운동에 세트/렙 기반 템플릿은 부적합.
