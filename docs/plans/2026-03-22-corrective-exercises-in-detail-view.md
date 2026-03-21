---
tags: [posture, corrective, detail-view, history]
date: 2026-03-22
category: plan
status: draft
---

# 교정 운동 추천을 히스토리 상세에서도 표시

## 목표

`PostureDetailView` (저장된 자세 평가 히스토리 상세)에서도 `PostureResultView`와 동일한 교정 운동 추천 섹션을 표시한다.

## 영향 파일

| 파일 | 변경 유형 | 설명 |
|------|----------|------|
| `Presentation/Posture/PostureDetailView.swift` | 수정 | correctiveExercisesSection 추가 |

## 구현 단계

### Step 1: PostureDetailView에 교정 운동 섹션 추가

- `record.allMetrics`로 `CorrectiveExerciseUseCase.recommendations()` 호출
- `metricsSection` 아래, `symmetryLink` 위에 섹션 배치
- UI 패턴은 `PostureResultView.correctiveExercisesSection`과 동일
- `PostureDetailView`는 `@State`가 아닌 `record` 기반이므로 computed property로 구현 가능 (record는 불변)

### 차이점

- `PostureResultView`: ViewModel의 stored `correctiveRecommendations` (assessment 변경 시 갱신)
- `PostureDetailView`: record 기반 계산 (1회, View init 시)

## 테스트 전략

- 기존 `CorrectiveExerciseUseCaseTests`가 로직을 커버
- 새 View 코드는 빌드 검증

## 리스크

| 리스크 | 대응 |
|--------|------|
| record.allMetrics가 JSON decode 비용 | View init 시 1회만 호출, `@State`로 캐시 |
