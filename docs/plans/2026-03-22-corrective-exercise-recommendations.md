---
tags: [posture, exercise, recommendation, corrective, flexibility]
date: 2026-03-22
category: plan
status: draft
---

# 교정 운동 추천 시스템 (#138)

## 목표

자세 분석 결과에서 caution/warning 메트릭을 식별하고, 해당 문제를 교정할 수 있는 운동을 추천한다.

## 영향 파일

| 파일 | 변경 유형 | 설명 |
|------|----------|------|
| `Domain/UseCases/CorrectiveExerciseUseCase.swift` | **신규** | 메트릭→운동 매핑 + 추천 로직 |
| `Domain/Models/CorrectiveRecommendation.swift` | **신규** | 추천 결과 모델 |
| `Presentation/Posture/PostureResultView.swift` | 수정 | 교정 운동 섹션 추가 |
| `Presentation/Posture/PostureAssessmentViewModel.swift` | 수정 | 추천 데이터 로드 |
| `Shared/Resources/Localizable.xcstrings` | 수정 | 3개 언어 번역 |
| `DUNETests/CorrectiveExerciseUseCaseTests.swift` | **신규** | UseCase 테스트 |

## 구현 단계

### Step 1: Domain 모델 + UseCase

**CorrectiveRecommendation 모델:**
```swift
struct CorrectiveRecommendation: Sendable, Identifiable {
    let id: String  // exercise ID
    let exercise: ExerciseDefinition
    let targetMetrics: [PostureMetricType]  // 이 운동이 도움되는 메트릭들
    let priority: Int  // 낮을수록 우선 (severity 기반)
}
```

**CorrectiveExerciseUseCase:**
- Input: `[PostureMetricResult]` (자세 분석 결과)
- Output: `[CorrectiveRecommendation]` (추천 운동 목록, 최대 8개)
- 의존성: `ExerciseLibraryQuerying` (protocol)

**매핑 테이블 (PostureMetricType → Exercise IDs):**

| 메트릭 | 추천 운동 ID | 근거 |
|--------|-------------|------|
| forwardHead | stretching, mobility-work, yoga | 목/상부 승모근 스트레칭 |
| roundedShoulders | band-pull-apart, reverse-fly, face-pull | 후면 어깨/승모근 강화 |
| thoracicKyphosis | foam-rolling, yoga, dead-bug | 흉추 확장, 코어 안정 |
| kneeHyperextension | stretching, bodyweight-squat, glute-bridge | 햄스트링/대퇴사두 균형 |
| shoulderAsymmetry | band-pull-apart, mobility-work | 편측 어깨 교정 |
| hipAsymmetry | glute-bridge-unilateral, plank, dead-bug | 편측 고관절 + 코어 |
| kneeAlignment | bodyweight-squat, glute-bridge, stretching | VMO/둔근 활성화 |
| lateralShift | plank, dead-bug, glute-bridge | 코어/고관절 안정화 |

**우선순위 로직:**
1. warning 메트릭의 운동이 caution보다 우선
2. 동일 severity면 metric scoreWeight 높은 순
3. 여러 메트릭에 도움되는 운동은 한 번만 표시 (targetMetrics 합산)
4. 최대 8개 추천

### Step 2: PostureResultView UI

- `metricsSection` 아래에 `correctiveExercisesSection` 추가
- caution/warning 메트릭이 없으면 섹션 자체 미표시
- 각 운동: 이름 + 대상 메트릭 태그 + 장비 아이콘
- bodyweight 운동 우선 표시 (접근성)

### Step 3: ViewModel 연결

- `PostureAssessmentViewModel`에 `correctiveRecommendations: [CorrectiveRecommendation]` 추가
- `combinedAssessment` 변경 시 UseCase 호출로 갱신

### Step 4: 테스트

- 모든 메트릭 caution → 올바른 운동 추천 확인
- warning 우선순위 > caution 확인
- 모든 normal → 빈 추천 확인
- 중복 운동 제거 확인
- 존재하지 않는 exercise ID 무시 확인

### Step 5: Localization

- "Recommended Exercises" / "추천 교정 운동" / "おすすめ矯正エクササイズ"
- "for {metric}" 설명 문자열

## 테스트 전략

- **Unit Test**: CorrectiveExerciseUseCaseTests — 매핑, 우선순위, 중복 제거, 엣지케이스
- **UI 검증**: PostureResultView에서 섹션 표시/미표시 확인 (빌드 검증)

## 리스크

| 리스크 | 대응 |
|--------|------|
| exercises.json에서 ID 변경 시 매핑 깨짐 | UseCase에서 ID 조회 실패 시 해당 운동 무시 (graceful) |
| 교정 운동이 부상 부위와 충돌 | MVP에서는 미처리, Future에서 InjuryConflictUseCase 연동 |
| 8개 메트릭 모두 warning이면 추천 과다 | 최대 8개 제한으로 방어 |

## 대안 비교

| 접근법 | 장점 | 단점 | 선택 |
|--------|------|------|------|
| UseCase + static mapping | 테스트 가능, 기존 패턴 | 매핑 변경 시 코드 수정 | **선택** |
| JSON 매핑 파일 | 유연 | 과잉 설계 (8개 메트릭) | - |
| ExerciseLibrary 자동 매핑 | 새 운동 자동 포함 | muscle group 매핑이 부정확 | - |
