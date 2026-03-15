---
tags: [watch, template, reorder, exercise, ux]
date: 2026-03-15
category: brainstorm
status: draft
---

# Brainstorm: Watch 템플릿 운동 순서 변경

## Problem Statement

워치에서 템플릿 기반 운동 시작 시, 운동 순서를 임시로 변경할 수 없음.
iOS에서는 `ExerciseReorderSheet`로 세션 중 드래그앤드롭 재정렬이 가능하지만,
Watch는 프리뷰/세션 모두 고정 순서로만 동작.

사용자가 당일 컨디션/장비 상황에 따라 운동 순서를 바꿔 시작하고 싶은 니즈가 있음.

## Target Users

- 템플릿을 사용하는 Watch 단독 운동 사용자
- 당일 상황에 따라 운동 순서를 유연하게 조정하려는 사용자

## Success Criteria

- 운동 시작 전 프리뷰에서 순서 변경 가능
- 운동 중에도 남은 운동 순서 변경 가능
- 원본 템플릿은 변경되지 않음 (임시 순서)
- 10개 이상 운동 템플릿에서도 원활히 동작

## Proposed Approach

### A. 프리뷰 화면 재정렬 (운동 시작 전)

**현재**: `WorkoutPreviewView` — 읽기 전용 번호 리스트
**변경**: 롱프레스 → 위/아래 이동 버튼 활성화

- `WorkoutPreviewView`의 운동 리스트에 롱프레스 제스처 추가
- 선택된 운동에 위/아래 화살표 버튼 표시
- 변경된 순서로 `entries` 배열을 재구성하여 세션 시작
- 원본 `WatchWorkoutTemplateInfo`는 수정하지 않음

### B. 세션 중 재정렬 (운동 중)

**현재**: `WorkoutManager.currentExerciseIndex`로 순차 진행
**변경**: 남은 운동 리스트에서 순서 변경 가능

- 세션 중 운동 리스트 접근 경로 추가 (버튼 또는 메뉴)
- 완료된 운동은 고정 (iOS `ExerciseReorderSheet` 동일 정책)
- 진행 중/미시작 운동만 이동 가능
- `WorkoutSessionTemplate.entries` 배열 재정렬 → `currentExerciseIndex` 동기화

### UI 패턴 (롱프레스 → 위/아래 버튼)

```
┌─────────────────────┐
│ 1. Bench Press    ✓ │  ← 완료 (고정)
│ 2. Squat          ▶ │  ← 진행 중
│ 3. [Deadlift]     ↑↓│  ← 롱프레스 선택됨
│ 4. Overhead Press    │
│ 5. Barbell Row       │
└─────────────────────┘
```

- 롱프레스하면 해당 행이 하이라이트 + ↑↓ 버튼 표시
- ↑↓ 탭 시 인접 항목과 위치 교환
- 다른 곳 탭 또는 타임아웃으로 편집 모드 해제

## Constraints

- watchOS 화면 크기: 복잡한 드래그앤드롭 불가 → 버튼 기반 이동
- `WorkoutSessionTemplate`은 plain struct → 배열 재정렬은 단순
- 원본 템플릿 불변 → CloudKit 동기화 영향 없음
- `currentExerciseIndex` 기반 진행 → 재정렬 시 인덱스 재계산 필요

## Edge Cases

- 운동 1개 템플릿: 재정렬 불필요 → UI 비활성화
- 운동 2개: 위/아래 중 하나만 표시
- 모든 운동 완료 상태: 이동 가능 항목 없음 → 편집 모드 진입 방지
- 세션 중 현재 운동을 이동: 현재 운동 identity 추적 필요 (iOS `moveExercise` 패턴 참조)
- 10개+ 운동: 스크롤 + 롱프레스 충돌 → 롱프레스 시간 조정 또는 전용 편집 모드 버튼

## Scope

### MVP (Must-have)
- 프리뷰 화면에서 롱프레스 → ↑↓ 버튼으로 순서 변경
- 변경된 순서로 세션 시작
- 세션 중 남은 운동 순서 변경
- 완료된 운동 고정
- 원본 템플릿 불변

### Nice-to-have (Future)
- 변경된 순서를 "이 순서로 템플릿 저장" 옵션
- 특정 운동 건너뛰기(skip) 프리셋
- 자주 사용하는 순서 변경 패턴 학습

## Key Files

| 파일 | 역할 | 변경 필요 |
|------|------|----------|
| `DUNEWatch/Views/WorkoutPreviewView.swift` | 프리뷰 운동 리스트 | ✅ 롱프레스 + 이동 UI |
| `DUNEWatch/Managers/WorkoutManager.swift` | 세션 관리 | ✅ entries 재정렬 + 인덱스 동기화 |
| `DUNE/Presentation/Exercise/TemplateWorkoutViewModel.swift` | iOS 재정렬 참조 | 참조만 |
| `DUNE/Presentation/Exercise/Components/ExerciseReorderSheet.swift` | iOS 재정렬 UI 참조 | 참조만 |

## Open Questions

- 세션 중 재정렬 진입점: 별도 버튼 vs 운동 리스트 화면에서 직접?
- Digital Crown 활용 가능성: 선택된 운동을 Crown으로 이동?

## Next Steps

- [ ] `/plan watch-template-exercise-reorder` 로 구현 계획 생성
