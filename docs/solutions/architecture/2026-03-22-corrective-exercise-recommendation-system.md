---
tags: [posture, exercise, recommendation, corrective, use-case, exercise-library]
date: 2026-03-22
category: solution
status: implemented
---

# 교정 운동 추천 시스템

## Problem

자세 분석 후 caution/warning 메트릭이 발견되어도 사용자가 어떤 운동을 해야 하는지 알 수 없었다. 측정 결과만 보여주고 행동 가능한 다음 단계가 없는 상태.

## Solution

`PostureMetricType → Exercise ID` 정적 매핑을 통해 기존 운동 라이브러리에서 교정 운동을 추천하는 시스템.

### 핵심 구조

```
PostureMetricResult[] (caution/warning만 필터)
    ↓ CorrectiveExerciseUseCase
ExerciseLibraryQuerying.exercise(byID:)
    ↓ 해상도 → 정렬 → 중복 제거 → 최대 8개
[CorrectiveRecommendation]
    ↓ PostureResultView.correctiveExercisesSection
UI 표시 (운동명 + 대상 메트릭 + 장비 + 카테고리)
```

### 파일

| 파일 | 역할 |
|------|------|
| `Domain/Models/CorrectiveRecommendation.swift` | 추천 결과 모델 (exercise + targetMetrics) |
| `Domain/UseCases/CorrectiveExerciseUseCase.swift` | 매핑 테이블 + 추천 로직 |
| `Presentation/Posture/Components/CorrectiveExercisesSectionView.swift` | 공유 UI 컴포넌트 |
| `Presentation/Posture/PostureResultView.swift` | 결과 화면에서 공유 컴포넌트 사용 |
| `Presentation/Posture/PostureDetailView.swift` | 히스토리 상세에서 공유 컴포넌트 사용 |
| `Presentation/Posture/PostureAssessmentViewModel.swift` | refreshCombinedAssessment() 헬퍼 |

### 설계 결정

1. **정적 매핑** 선택 (JSON 파일이나 자동 매핑 대신) — 8개 메트릭에 대해 과잉 설계 방지
2. **UseCase DI** — `ExerciseLibraryQuerying` 프로토콜 주입으로 테스트 가능
3. **priority 필드 제거** — 정렬 후 배열 순서가 곧 우선순위이므로 모델에 노출 불필요
4. **refreshCombinedAssessment()** 헬퍼 — `combinedAssessment` + `correctiveRecommendations` 동시 갱신을 단일 함수로 DRY

### 매핑 테이블

```swift
static let exerciseIDsByMetric: [PostureMetricType: [String]] = [
    .forwardHead:        ["stretching", "mobility-work", "yoga"],
    .roundedShoulders:   ["band-pull-apart", "reverse-fly", "face-pull"],
    .thoracicKyphosis:   ["foam-rolling", "yoga", "dead-bug"],
    .kneeHyperextension: ["stretching", "bodyweight-squat", "glute-bridge"],
    .shoulderAsymmetry:  ["band-pull-apart", "mobility-work"],
    .hipAsymmetry:       ["glute-bridge-unilateral", "plank", "dead-bug"],
    .kneeAlignment:      ["bodyweight-squat", "glute-bridge", "stretching"],
    .lateralShift:       ["plank", "dead-bug", "glute-bridge"],
]
```

## Prevention

- 새 `PostureMetricType` case 추가 시 `exerciseIDsByMetric`에도 엔트리 추가 필수
- Exercise ID 변경 시 이 매핑도 함께 갱신 (테스트 `allMetricsMapped`가 누락 감지)
- `combinedAssessment` 갱신 시 반드시 `refreshCombinedAssessment()` 사용 (직접 할당 금지)

## Lessons Learned

- 리뷰에서 `priority` 필드가 구현 세부사항 누출로 지적됨 — 정렬 후 배열 순서로 충분한 경우 별도 필드 불필요
- 2곳에서 동일 코드 반복 → 헬퍼 추출이 3번째 사이트 추가 전에 선제적으로 필요
- exercises.json ID와의 결합 → `guard let` + graceful skip으로 방어, 테스트에서 커버리지 보장
