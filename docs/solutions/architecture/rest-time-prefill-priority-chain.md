---
tags: [rest-time, prefill, template, watch, ios, priority-chain]
date: 2026-03-03
category: solution
status: implemented
---

# Rest Time Prefill Priority Chain

## Problem

템플릿에서 운동을 시작할 때 휴식시간 설정이 무시되고 항상 전역 기본값(90초)만 사용됨.
이전 세션에서 사용한 휴식시간도 기록되지 않아 매번 수동 조정이 필요.

## Solution

### Priority Chain (iOS)

```
resolveRestDuration(forSetAt:)
├── 1. Previous session rest (WorkoutSet.restDuration from last ExerciseRecord)
├── 2. Template entry rest (TemplateEntry.restDuration)
└── 3. Global default (WorkoutDefaults.restSeconds)
```

### Priority Chain (Watch)

```
currentRestDuration
├── 1. Within-session carry-forward (lastRestTimerTotal — same UX purpose as previous session)
├── 2. Template entry rest (entry.restDuration)
└── 3. Global default (globalRestSeconds)
```

Watch는 이전 세션 SwiftData 레코드에 인라인 접근 불가 → `lastRestTimerTotal`로 같은 UX 제공.

### Data Flow

```
Timer complete/skip
    → capture timerTotal (including +30s adjustments)
    → store in EditableSet.restDuration (iOS) / CompletedSetData.restDuration (Watch)
    → persist to WorkoutSet.restDuration (SwiftData)
    → next session: loadPreviousSets() maps to PreviousSetInfo.restDuration
    → resolveRestDuration() returns it as first priority
```

### Template Rest Duration Threading (iOS)

```
ExerciseView.startFromTemplate()
    → captures firstEntry.restDuration → @State templateRestDuration
    → ExerciseStartView(templateRestDuration:)
    → WorkoutSessionView(templateRestDuration:)
    → vm.templateRestDuration = value
    → resolveRestDuration() uses as second priority
```

## Key Implementation Details

1. **Sanitization**: `resolveRestDuration` checks `isFinite` and clamps to 0...3600
2. **Backward compat**: `WatchSetData.restDuration` is `var` (not `let`) for Codable backward compat
3. **Draft persistence**: `templateRestDuration` is persisted in `WorkoutSessionDraft` for crash recovery
4. **Watch encapsulation**: `WorkoutManager.recordRestDuration()` method for proper layer boundary
5. **Index safety**: Watch uses `completedSetsData.count - 1` (not `currentSetIndex`) for correct set targeting

## Prevention

- 새 per-exercise 설정 추가 시 같은 priority chain 패턴 적용
- Watch ↔ iOS DTO에 새 optional 필드 추가 시 `var` 사용 (Codable backward compat)
- Timer 관련 값은 반드시 `isFinite` + 범위 검증
- View에서 Manager 데이터 직접 mutate 금지 → Manager에 전용 메서드 추가

## Files Changed

| File | Change |
|------|--------|
| WorkoutSessionViewModel.swift | resolveRestDuration, EditableSet.restDuration, PreviousSetInfo.restDuration, draft |
| WorkoutSessionView.swift | startRest/finishRest capture, templateRestDuration threading |
| ExerciseStartView.swift | templateRestDuration relay |
| ExerciseView.swift | startFromTemplate captures entry.restDuration |
| MetricsView.swift (Watch) | currentRestDuration priority, lastRestTimerTotal carry-forward |
| RestTimerView.swift (Watch) | onComplete/onSkip pass timerTotal |
| WorkoutManager.swift (Watch) | CompletedSetData.restDuration, recordRestDuration() |
| WatchConnectivityModels.swift | WatchSetData.restDuration |
| SessionSummaryView.swift (Watch) | sendWorkoutToPhone maps restDuration |
