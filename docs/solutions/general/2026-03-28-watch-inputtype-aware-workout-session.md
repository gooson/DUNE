---
tags: [watch, inputType, durationIntensity, plank, MetricsView, SetInputSheet, workout-session]
date: 2026-03-28
category: solution
status: implemented
---

# Watch 운동 세션 inputType-aware 입력 UI

## Problem

Watch 운동 세션 UI(`MetricsView`, `SetInputSheet`)가 모든 운동에 weight+reps 입력을 하드코딩.
Plank 등 `durationIntensity` 운동도 "kg × reps"로 표시되어 시간 기반 운동에 무게 입력이 강제됨.

**증상**: Watch에서 플랭크 운동 시작 시 "0.0 kg × 10 reps" 입력이 표시됨.

**근본 원인**:
- `MetricsView.inputCard`가 inputType 분기 없이 weight/reps 하드코딩
- `SetInputSheet`이 weight+reps 모드만 지원
- `CompletedSetData`에 `duration` 필드 없음
- `SessionSummaryView`에서 `WatchSetData.duration`을 항상 nil로 전달

## Solution

### 1. CompletedSetData에 duration 추가 (`WorkoutManager.swift`)
- `duration: TimeInterval?` 필드 추가
- `completeSet()` 메서드에 `duration` 파라미터 추가 (7200초 상한 검증)

### 2. SetInputSheet inputType 분기 (`SetInputSheet.swift`)
- `inputType: ExerciseInputType` 파라미터 추가
- 3가지 모드: `weightRepsContent` / `repsOnlyContent` / `durationContent`
- Digital Crown: weight(setsRepsWeight), reps(setsReps), minutes(durationIntensity)
- Crown 안정성: duration은 stable `@State crownDurationDouble` + `onChange` sync 사용

### 3. MetricsView inputType 인식 (`MetricsView.swift`)
- `currentInputType` computed property로 `TemplateEntry.inputTypeRaw` → `ExerciseInputType` 변환
- `inputCard`: inputType별 표시 (kg×reps / reps / min)
- `prefillFromEntry()`: durationIntensity는 duration 프리필 (rounding 적용)
- `completeSet()`: inputType별 완료 로직 분기

### 4. SessionSummaryView duration 전달 (`SessionSummaryView.swift`)
- `CompletedSetData.duration` → `WatchSetData.duration` / `WorkoutSet.duration` 전달
- 운동 요약: duration 기반 운동은 "N sets · Xmin" 형태로 표시

## Key Design Decisions

- **ExerciseInputType 사용 가능**: Watch 타겟이 `ExerciseCategory.swift`를 공유하므로 rawValue 해석 불필요
- **inputTypeRaw 소스**: `TemplateEntry.inputTypeRaw` 사용 (WatchConnectivity 또는 CloudKit 경유)
- **Duration 단위**: UI는 분(minutes), 저장은 초(seconds) — `TimeInterval(minutes) * 60`
- **Crown Binding 안정성**: `Binding(get:set:)` inline 생성은 render마다 재생성되어 Crown accumulator 단절 → stable `@State` + `onChange` 패턴 필수

## Prevention

- Watch 운동 UI에 새 inputType 추가 시 `MetricsView.inputCard`, `SetInputSheet`, `completeSet()`, `prefillFromEntry()` 4곳 동시 업데이트 필수
- `ExerciseInputType` enum에 새 case 추가 시 Watch `switch` 문이 컴파일 에러로 알려줌 (exhaustive switch 사용)

## Lessons Learned

- iOS에서 exercises.json inputType을 수정해도 **Watch UI가 별도 코드 경로**를 가지면 반영되지 않음
- Watch 코드는 iOS와 달리 inputType 기반 분기가 없었음 — Watch/iOS parity 검증 시 **UI 렌더링 코드도** 확인 필요
- Digital Crown `Binding(get:set:)` inline 패턴은 watchOS에서 매 render마다 accumulator를 리셋하는 위험이 있음
