---
tags: [workout, template, reorder, ux, drag-and-drop]
date: 2026-03-15
category: brainstorm
status: draft
---

# Brainstorm: 운동 중 운동 순서 변경

## Problem Statement

템플릿 기반 운동 세션에서 사용자가 장비 점유, 컨디션 등의 이유로 운동 순서를 실시간으로 변경하고 싶지만, 현재는 스킵/점프만 가능하고 순서 재배치는 불가능하다.

## Target Users

- 템플릿을 사용하는 중급 이상 운동 사용자
- 혼잡한 헬스장에서 장비 가용성에 따라 유연하게 운동하는 사용자
- 컨디션에 따라 고중량 운동 순서를 조정하고 싶은 사용자

## Success Criteria

1. 운동 중 미완료 운동의 순서를 drag-to-reorder로 변경할 수 있다
2. 완료된 운동은 고정되고 미완료 운동만 이동 가능하다
3. 순서 변경이 원본 템플릿에 영향을 주지 않는다
4. 현재 탭 UI와 자연스럽게 통합된다

## Competitive Analysis

| 앱 | 방식 | 장점 | 단점 |
|---|---|---|---|
| Strong | long-press drag 재정렬 | 직관적, 항상 가능 | 완료 운동도 이동 가능 (혼란) |
| Hevy | drag handle 노출 | 발견성 높음 | handle이 공간 차지 |
| JEFIT | "Reorder" 버튼 → 모드 | 명시적 | 추가 탭 필요 |

## Proposed Approach

### 현재 구조 분석

- `TemplateWorkoutViewModel`이 `config.exercises` 배열의 인덱스로 운동 추적
- `exerciseStatuses: [TemplateExerciseStatus]` — 인덱스 기반 상태 관리
- `exerciseViewModels: [WorkoutSessionViewModel]` — 병렬 배열
- `currentExerciseIndex`로 현재 운동 탐색
- UI는 수평 탭 스크롤로 운동 목록 표시 (TemplateWorkoutView)

### 핵심 설계 결정

**순서 변경 진입점**: 운동 목록 뷰에서 Edit 모드 또는 long-press context menu

**데이터 모델 변경**:
- `TemplateWorkoutViewModel`에 `displayOrder: [Int]` 인덱스 매핑 배열 추가
- 또는 병렬 배열 3개(exercises, statuses, viewModels)를 동시 재정렬
- 원본 config는 불변 유지

**UI 옵션**:
1. **탭 바 long-press → 재정렬 시트**: 현재 탭 UI를 유지하면서 별도 시트에서 List + .onMove
2. **탭 바 직접 drag**: 수평 탭에서 직접 drag-to-reorder (구현 복잡)
3. **운동 목록 시트 + 재정렬**: 전체 운동 목록을 시트로 열어 drag 재정렬

## Constraints

- Swift 6 concurrency (`@MainActor`, `Sendable`)
- 병렬 배열 동기화 필수 (`exercises`, `statuses`, `viewModels` 인덱스 일치)
- watchOS 동기화 불필요 (세션 한정 변경)
- CloudKit 영향 없음 (원본 템플릿 불변)

## Edge Cases

- 현재 진행 중인 운동(inProgress)을 이동하면? → 현재 운동은 이동 불가 또는 이동 시 currentIndex 추적
- 운동이 1개만 남았을 때 → 재정렬 비활성화
- 모든 운동이 완료되었을 때 → 재정렬 비활성화
- Draft 저장/복원 시 변경된 순서도 보존? → 세션 한정이므로 draft에는 현재 순서 반영

## Scope

### MVP (Must-have)
- 운동 중 미완료 운동의 순서 변경 (drag-to-reorder)
- 완료된 운동은 고정 (이동 불가)
- 변경된 순서가 탭 UI에 즉시 반영
- 원본 템플릿 불변

### Nice-to-have (Future)
- "이 순서를 템플릿에 저장" 옵션
- watchOS에서도 순서 변경
- 운동 시작 전 순서 조정 화면
- 자주 변경하는 패턴 학습하여 제안

## Open Questions

1. 재정렬 UI를 탭 바 내에서 처리할지, 별도 시트로 처리할지
2. 현재 진행 중(inProgress) 운동의 이동 허용 여부
3. 병렬 배열 동시 재정렬 vs displayOrder 인덱스 매핑 중 어느 접근이 안전한지

## Next Steps

- [ ] /plan 으로 구현 계획 생성
