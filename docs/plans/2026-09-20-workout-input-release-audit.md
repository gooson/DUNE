---
topic: workout-input-release-audit
date: 2026-09-20
status: approved
confidence: high
related_solutions:
  - docs/solutions/general/2026-03-28-watch-inputtype-aware-workout-session.md
---

# 운동 기록 입력 1.0 점검

## Context

워치부터 폰까지 운동 특성과 입력/수정/저장 동작을 조사하고 개선한다. 시작 시 작업 트리는 깨끗했다.

## Requirements

- 133개 기본 운동의 입력 유형을 조사한다.
- 크런치 등 맨몸 운동은 횟수가 기본이고 추가 중량을 운동 중 선택/제거할 수 있다.
- 템플릿의 오래된 분류가 최신 라이브러리와 다른 입력 화면을 만들지 않는다.
- 숨긴 필드가 검증 없이 저장되거나, 제거한 중량이 다음 세트에 되살아나지 않는다.
- 폰 단독/루틴 입력도 같은 정책을 적용한다. 기존 기록은 보존한다.

## Approach

기존 inputType 및 optional weight 계약을 유지한다. 세션 시작 시 메타데이터를 최신 라이브러리로 보강하고 추가 중량은 명시적 UI로 노출한다. 영속 모델 변경은 하지 않는다.

## Implementation Steps

1. WatchExerciseHelpers/WorkoutPreviewView: 템플릿 메타데이터 보강, 회귀 테스트.
2. WatchSetInputPolicy/SetInputSheet/MetricsView: 추가 중량 수정/제거, Crown 입력, 프리필 및 저장 일관성.
3. exercises.json: 명확한 운동 분류 오류 수정, 전체 목록 검사.
4. WorkoutSessionView/SetRowView/WorkoutSessionViewModel: 폰 추가 중량과 검증/저장, 단위 변경 검사.
5. 유닛/UI 검증, 다관점 리뷰, 조사 결과와 잔여 출시 검증 문서화.

## Edge Cases

레거시 inputType alias, 라이브러리 미수신, 0/nil 중량, 이전 가중 맨몸 기록, 단위 변경, NaN/Infinity, 세트 전환, 라운드/시간 운동을 검사한다.

## Testing Strategy

기존 Watch/iOS Swift Testing suites에 회귀 사례 추가. iOS 시뮬레이터 UI 회귀 및 빌드. 설치된 watchOS runtime이 없어 워치 UI 실행은 별도 제약으로 기록하고 가능한 빌드/정책 검증을 수행한다.

## Risks

운반 운동의 거리+중량 등 기존 5개 입력 유형이 표현하지 못하는 운동은 조사 결과에 명시한다. 기존 기록의 해석을 바꾸는 자동 데이터 마이그레이션은 피한다.
