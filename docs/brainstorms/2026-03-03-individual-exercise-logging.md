---
tags: [exercise, template, workout-session, sequential-flow, individual-logging]
date: 2026-03-03
category: brainstorm
status: draft
---

# Brainstorm: 템플릿 워크아웃 개별 운동 기록

## Problem Statement

현재 템플릿에서 워크아웃을 시작하면 **첫 번째 운동만** 단일 세션(`WorkoutSessionView`)으로 열리고, 나머지 운동들은 무시된다. 사용자는 템플릿의 모든 운동을 순차적으로 기록하고 싶지만 현재 플로우에서는 불가능하다.

### 현재 동작

```
ExerciseView.startFromTemplate(template)
  → template.exerciseEntries.first 만 추출
  → selectedExercise = definition (첫 번째 운동만)
  → ExerciseStartView → WorkoutSessionView (단일 운동)
  → 나머지 운동은 무시됨
```

### 기대 동작

```
Template "Push Day" (3 exercises)
  → Exercise 1: Bench Press → 세트 기록 → 완료 → 즉시 저장
  → Exercise 2: Shoulder Press → 세트 기록 → 완료 → 즉시 저장
  → Exercise 3: Lateral Raise → 세트 기록 → 완료 → 즉시 저장
  → 전체 완료 화면 (총 요약)
```

## Target Users

- 루틴이 정해진 중급 이상 운동자
- 템플릿으로 워크아웃 구조를 미리 짜두고 따라가는 사용자
- 순서대로 운동하되, 상황에 따라 스킵/재배치가 필요한 사용자

## Success Criteria

1. 템플릿의 모든 운동을 순차적으로 기록할 수 있다
2. 각 운동 완료 시 즉시 `ExerciseRecord`가 저장된다 (크래시 방어)
3. 중간에 운동을 스킵하거나 순서를 변경할 수 있다
4. 기존 단일 운동 세션(`WorkoutSessionView`)을 최대한 재활용한다
5. 전체 워크아웃 완료 시 총 요약 화면이 표시된다

## Constraints

### 기술적 제약

- `WorkoutSessionView`는 단일 `ExerciseDefinition`을 받아 동작함 — 재사용하려면 외부 orchestrator가 필요
- `WorkoutSessionDraft`(UserDefaults 기반)는 단일 운동만 저장 — 템플릿 전체 진행 상태 저장 필요
- `ExerciseRecord`는 독립적 SwiftData 모델 — 세션 그룹핑 메커니즘 없음 (같은 날짜로 그룹핑 가능)
- iOS 26+ 타겟이므로 최신 SwiftUI API 사용 가능

### 설계 제약

- `CompoundWorkoutView`(슈퍼셋/서킷)와 역할이 겹치지 않아야 함
- 기존 `WorkoutSessionView`의 Watch-style UX(한 세트씩 진행)를 유지

## Proposed Approach

### 핵심 구조: TemplateWorkoutCoordinator

기존 `WorkoutSessionView`를 그대로 재활용하되, 상위에 **orchestrator**를 추가하여 운동 간 전환을 관리한다.

```
TemplateWorkoutView (orchestrator)
  ├── 운동 목록 헤더 (진행 상태 표시)
  ├── WorkoutSessionView (현재 운동) ← 기존 코드 재활용
  └── 운동 간 전환 UI (다음 운동 시작 버튼)
```

### 플로우

1. 템플릿 선택 → `TemplateWorkoutView` 진입
2. 첫 번째 운동의 `WorkoutSessionView` 표시
3. 운동 완료 → `ExerciseRecord` 즉시 저장 → 전환 화면
4. 전환 화면: 다음 운동 정보 + "Start" 버튼
5. 반복 (2~4)
6. 마지막 운동 완료 → 전체 요약 + RPE/공유

### 기존 코드 재활용 전략

| 기존 컴포넌트 | 재활용 방식 |
|-------------|----------|
| `WorkoutSessionView` | 개별 운동 기록 UI 그대로 사용 (내부 Save 로직만 callback 분리) |
| `WorkoutSessionViewModel` | 운동별 인스턴스 생성, `createValidatedRecord()` 패턴 유지 |
| `RestTimerView` / `RestTimerViewModel` | 세트 간 타이머 그대로 사용 |
| `WorkoutCompletionSheet` | 전체 완료 시 한 번만 표시 |
| `TemplateEntry.defaultSets/Reps/WeightKg` | 초기 세트 구성에 활용 |

### Save 시점 변경

현재 `WorkoutSessionView.saveWorkout()`은 저장 + dismiss + 공유 시트를 한 번에 처리한다.
템플릿 플로우에서는:
- 저장만 수행 (dismiss 안 함)
- 공유 시트는 전체 완료 시에만 표시
- 콜백으로 상위 orchestrator에 완료 통보

### 스킵/재배치

- 운동 목록 헤더에서 탭하여 특정 운동으로 점프
- 스킵된 운동은 "미완료" 상태로 표시
- 완료/스킵 상태를 명확히 구분 (아이콘: ✓ / ○ / ⊘)

## Edge Cases

1. **앱 크래시/백그라운드 전환**: 각 운동 즉시 저장이므로 완료된 운동은 보존. 진행 중인 운동은 기존 `WorkoutSessionDraft` 메커니즘으로 복구 + 템플릿 진행 상태(현재 인덱스)도 별도 저장 필요.
2. **빈 세트로 완료 시도**: 기존 validation ("Complete at least one set") 그대로 적용.
3. **모든 운동 스킵**: 최소 1개 운동 완료 필요 — 전부 스킵 시 "Complete at least one exercise" 경고.
4. **템플릿 내 운동 개수 1개**: 기존 단일 운동 플로우로 fallback (불필요한 orchestrator 없이).
5. **커스텀 운동**: `exerciseDefinitionID.hasPrefix("custom-")` 처리 — 기존 `startFromTemplate` 로직 활용.
6. **운동 라이브러리에 없는 운동**: 템플릿 entry의 `exerciseName`으로 fallback definition 생성 (기존 패턴).

## Scope

### MVP (Must-have)

- [ ] `TemplateWorkoutView`: 순차 진행 orchestrator
- [ ] 운동 간 전환 UI (다음 운동 정보 + Start 버튼)
- [ ] 각 운동 완료 시 즉시 `ExerciseRecord` 저장
- [ ] 운동 목록 헤더 (진행 상태 표시, 탭으로 점프)
- [ ] 전체 완료 시 요약 화면
- [ ] `TemplateEntry.defaultSets/Reps/WeightKg`로 초기 세트 프리필
- [ ] 스킵 기능 (운동 건너뛰기)
- [ ] 템플릿 진행 상태 draft 저장 (크래시 복구)

### Nice-to-have (Future)

- [ ] 운동 순서 드래그 재배치 (워크아웃 중)
- [ ] 워크아웃 중 운동 추가 (템플릿 외 운동)
- [ ] 전체 워크아웃 시간 추적 (운동 간 전환 시간 포함)
- [ ] Watch 연동 (템플릿 기반 워크아웃)
- [ ] 운동 간 전환 시 추천 운동 표시
- [ ] 워크아웃 완료 후 템플릿 개선 제안 (미사용 운동 제거 등)

## Open Questions

1. **`WorkoutSessionView` 재활용 vs 새 View**: `WorkoutSessionView`를 직접 embed할 것인가, 아니면 핵심 로직(`WorkoutSessionViewModel`)만 재활용하고 UI는 새로 만들 것인가?
   - 직접 embed: 코드 재활용 극대화, 하지만 Save/Dismiss 로직 분리 필요
   - VM만 재활용: UI 자유도 높음, 하지만 중복 코드 발생 가능
2. **`ExerciseRecord` 그룹핑**: 같은 템플릿 세션에서 생성된 레코드를 그룹핑할 메커니즘이 필요한가?
   - 옵션 A: `sessionID: UUID?` 필드 추가 (SwiftData 마이그레이션 필요)
   - 옵션 B: 날짜+시간 근접성으로 그룹핑 (추가 필드 없음)
   - 옵션 C: MVP에서는 그룹핑 불필요 — 개별 레코드로 충분
3. **전체 완료 시 RPE/공유 범위**: RPE를 전체 워크아웃에 하나로 적용할 것인가, 운동별로 별도 적용할 것인가?

## Related Code

| 파일 | 역할 |
|------|------|
| `ExerciseView.swift:217` | `startFromTemplate()` — 현재 첫 운동만 시작 |
| `WorkoutSessionView.swift` | 단일 운동 세션 UI (Watch-style) |
| `WorkoutSessionViewModel.swift` | 세트 관리, validation, record 생성 |
| `CompoundWorkoutView.swift` | 슈퍼셋/서킷 UI (참고용) |
| `WorkoutTemplate.swift` | 템플릿 모델 (`exerciseEntries: [TemplateEntry]`) |
| `ExerciseStartView.swift` | 운동 시작 전 확인 화면 |

## Next Steps

- [ ] `/plan individual-exercise-logging` 으로 구현 계획 생성
