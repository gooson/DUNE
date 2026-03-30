---
tags: [template-workout, exercise-transition, watch, ux]
date: 2026-03-30
category: brainstorm
status: draft
---

# Brainstorm: Template Exercise Transition Selection

## Problem Statement

템플릿 운동(A, B, C)을 순서대로 진행할 때, 현재는 A 완료 후 자동으로 B를 보여주고 "Start" 버튼만 제공한다. 사용자가 특정 운동을 건너뛰고 싶을 때 별도의 Skip 동작을 찾아야 하는 불편함이 있다.

**개선 방향**: A 완료 → "B 할래?" Yes/No → No → "C 할래?" Yes/No → 모두 No → 세션 종료

## Target Users

- 템플릿 기반으로 운동하는 사용자
- 컨디션에 따라 일부 운동을 건너뛰는 중급+ 사용자
- iPhone / Apple Watch 모두 사용

## Success Criteria

1. A 완료 후 다음 운동(B)을 할지 명시적으로 선택할 수 있다
2. 거절 시 그 다음 운동(C)을 제안한다
3. 모든 남은 운동을 거절하면 세션이 종료된다
4. iOS 탭 바를 통한 자유 이동은 그대로 유지된다
5. Watch에서도 동일한 선택 흐름이 동작한다

## Proposed Approach

### 전환 화면 디자인

**iOS (TemplateWorkoutView)**

```
┌─────────────────────────────┐
│  ✓ Bench Press Complete     │
│                             │
│     Up Next                 │
│     Squat                   │
│                             │
│  ┌─────────┐ ┌───────────┐ │
│  │  Start  │ │   Skip    │ │
│  └─────────┘ └───────────┘ │
└─────────────────────────────┘
```

- 기존 전환 오버레이에 **Skip 버튼 추가**
- Start → 해당 운동 시작 (기존과 동일)
- Skip → status를 `.skipped`로 설정 → 다음 pending 운동 제안
- 모든 운동 skipped → 세션 종료
- 상단 탭 바는 유지 (자유 이동 가능, 탭 클릭으로 skipped 운동 다시 선택 가능)

**watchOS (MetricsView)**

```
┌──────────────────┐
│   Next Exercise   │
│                   │
│     Squat         │
│                   │
│  ┌──────────────┐ │
│  │    Start     │ │
│  └──────────────┘ │
│  ┌──────────────┐ │
│  │    Skip      │ │
│  └──────────────┘ │
└──────────────────┘
```

- 기존 3초 자동진행 **제거** → 명시적 Start/Skip 버튼
- Start(초록) → 운동 시작
- Skip(회색) → 다음 pending 운동 제안
- 모든 운동 skipped → 세션 종료

### 상태 흐름

```
A 완료
  → 전환 화면: "B 할래?"
    → Start → B 시작
    → Skip → B를 .skipped
      → 전환 화면: "C 할래?"
        → Start → C 시작
        → Skip → C를 .skipped
          → 남은 운동 없음 → 세션 종료
```

### 탭 바와의 관계 (iOS)

- 전환 화면은 "완료 직후 자동 제안" 역할
- 탭 바는 독립적으로 동작: 사용자가 직접 원하는 운동 탭을 클릭 가능
- `.skipped` 운동도 탭으로 접근하면 다시 수행 가능
- 전환 화면에서 제안하는 순서: 템플릿 순서 기준 다음 `.pending` 운동

## Constraints

- iOS `TemplateWorkoutViewModel.advanceToNext()` 로직 수정 필요 (Skip 시 오버레이 유지)
- Watch `WorkoutManager`에 `.skipped` 상태 개념 추가 필요 (현재는 index만 관리)
- Watch 3초 자동진행을 명시적 선택으로 교체
- 기존 `ExerciseTransitionView`(레거시 컨테이너용)와 `TemplateWorkoutView` 내 전환 오버레이 두 곳 수정

## Edge Cases

| 케이스 | 처리 |
|--------|------|
| 모든 운동 Skip | 세션 종료 (완료된 운동만 저장) |
| Skip 후 탭 바로 다시 선택 | `.skipped` → `.inProgress` 전환 허용 |
| 운동 1개짜리 템플릿 | 완료 후 바로 세션 종료 (전환 화면 불필요) |
| 중간 운동만 Skip | 남은 pending 운동 중 다음 순서 제안 |
| Watch에서 마지막 운동 Skip | 완료된 운동이 있으면 세션 종료, 없으면 경고 |

## Scope

### MVP (Must-have)

- iOS 전환 오버레이에 Skip 버튼 추가
- Skip 시 다음 pending 운동 자동 제안
- 모든 운동 Skip 시 세션 종료
- Watch 전환 화면에 Start/Skip 버튼 2개
- Watch 3초 자동진행 → 명시적 선택으로 변경

### Nice-to-have (Future)

- Skip 사유 기록 ("컨디션 안좋음", "장비 사용중" 등)
- 스킵 패턴 분석 (자주 스킵하는 운동 통계)
- "전체 건너뛰기" 버튼 (남은 운동 일괄 Skip)
- Watch에서 스킵 시 haptic 피드백 차별화

## Affected Components

| 파일 | 변경 내용 |
|------|----------|
| `TemplateWorkoutView.swift` | 전환 오버레이에 Skip 버튼 추가, Skip 후 다음 제안 로직 |
| `TemplateWorkoutViewModel.swift` | `skipAndPropose()` 메서드 추가, 남은 pending 확인 로직 |
| `DUNEWatch/Views/MetricsView.swift` | 3초 자동진행 제거, Start/Skip 버튼 UI |
| `DUNEWatch/Managers/WorkoutManager.swift` | `skipExercise()` 상태 추적 강화 |
| `Localizable.xcstrings` (Shared + Watch) | "Skip" / "Start" 번역 (en/ko/ja) |

## Open Questions

1. Skip한 운동의 탭 아이콘 표시는 현재 `→`(forward arrow)인데 유지할지?
2. Watch에서 "세션 종료"는 즉시 종료? 확인 팝업?

## Next Steps

- [ ] `/plan template-exercise-transition` 으로 구현 계획 생성
