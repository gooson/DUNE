---
tags: [template, recommendation, nudge, dashboard, activity]
date: 2026-03-14
category: plan
status: draft
---

# Plan: 템플릿 생성 넛지

## Summary

반복 운동 패턴이 감지되면 대시보드와 운동 시작 시 "템플릿으로 저장" 넛지를 표시하여 템플릿 전환율을 높인다.

## Brainstorm Reference

`docs/brainstorms/2026-03-14-template-creation-nudge.md`

## Related Solutions

- `docs/solutions/architecture/2026-03-07-windowed-workout-template-recommendation-system.md` — 추천 엔진 설계
- `docs/solutions/general/2026-03-08-recommended-routine-tap-start-flow.md` — 추천→시작 플로우 연결
- `docs/solutions/general/2026-03-04-recommended-workout-reality-filter-and-card-ux.md` — 추천 필터 UX

## Affected Files

| File | Change | Reason |
|------|--------|--------|
| `DUNE/Presentation/Dashboard/Components/TemplateNudgeCard.swift` | 신규 | 대시보드 넛지 카드 UI |
| `DUNE/Presentation/Dashboard/DashboardViewModel.swift` | 수정 | `templateRecommendations` 로딩 추가 |
| `DUNE/Presentation/Dashboard/DashboardView.swift` | 수정 | 넛지 카드 삽입 + sheet 연결 |
| `DUNE/Presentation/Activity/Components/SuggestedWorkoutSection.swift` | 수정 | 추천 루틴 카드에 "Save as Template" CTA 추가 |
| `DUNE/Presentation/Exercise/Components/CreateTemplateView.swift` | 수정 | pre-fill init 추가 (이름 + entries) |
| `DUNE/Domain/UseCases/TemplateNudgeDismissStore.swift` | 신규 | 넛지 dismiss 기록 (UserDefaults) |
| `DUNE/Domain/UseCases/TemplateOverlapChecker.swift` | 신규 | 추천↔기존 템플릿 중복 검사 |
| `DUNETests/TemplateOverlapCheckerTests.swift` | 신규 | 중복 검사 유닛 테스트 |
| `DUNETests/TemplateNudgeDismissStoreTests.swift` | 신규 | dismiss 기록 유닛 테스트 |
| `Shared/Resources/Localizable.xcstrings` | 수정 | 넛지 UI 문자열 en/ko/ja 추가 |

## Implementation Steps

### Step 1: TemplateOverlapChecker (Domain)

추천 시퀀스가 기존 템플릿과 겹치는지 판단하는 순수 함수.

```swift
struct TemplateOverlapChecker {
    static func isAlreadyCovered(
        recommendation: WorkoutTemplateRecommendation,
        existingTemplates: [TemplateSnapshot]
    ) -> Bool
}
```

- `TemplateSnapshot`: `WorkoutTemplate`에서 운동 ID 배열만 추출한 Sendable struct
- 비교: recommendation의 `sequenceLabels` ↔ template의 exercise IDs
- 임계값: 80%+ 겹침이면 covered

**Verification**: 유닛 테스트로 0%, 50%, 80%, 100% 겹침 케이스 검증.

### Step 2: TemplateNudgeDismissStore (Domain)

넛지 dismiss 기록 관리.

```swift
struct TemplateNudgeDismissStore {
    func isDismissed(_ recommendationID: String) -> Bool
    func dismiss(_ recommendationID: String)
}
```

- `UserDefaults`에 `[String: Date]` 딕셔너리 저장
- dismiss 후 7일간 동일 추천 미노출
- 7일 경과 시 자동 만료

**Verification**: 유닛 테스트로 dismiss/만료/미등록 케이스 검증.

### Step 3: TemplateNudgeCard (Presentation)

대시보드에 표시할 넛지 카드 UI.

- `InlineCard` 기반 (기존 `WorkoutRecommendationCard` 패턴 참조)
- 헤더: sparkles 아이콘 + "Your Routine"
- 본문: 운동 목록 (sequenceLabels, 최대 4개)
- 근거: "최근 {frequency}회 반복, 평균 {duration}분"
- CTA 2개: "Save as Template" (primary) + "Start Workout" (secondary)
- dismiss 버튼 (X)
- `accessibilityIdentifier`: "dashboard-template-nudge-card"

**Verification**: Preview에서 렌더링 확인.

### Step 4: DashboardViewModel 확장

```swift
// 추가 프로퍼티
var templateNudgeRecommendation: WorkoutTemplateRecommendation?

// loadData() 내에서
// 1. WorkoutTemplateRecommendationService로 recommendations 로드
// 2. TemplateOverlapChecker로 기존 템플릿과 비교
// 3. TemplateNudgeDismissStore로 dismiss 여부 확인
// 4. 남은 것 중 최고 score 1개만 노출
```

- `@Query`는 ViewModel에서 사용 불가 → 기존 템플릿 목록은 View에서 주입
- 또는 `loadData`에 `existingTemplateSnapshots: [TemplateSnapshot]` 파라미터 추가

**Verification**: ViewModel 테스트에서 각 필터 단계 검증.

### Step 5: DashboardView 넛지 삽입

- Insight Cards 아래, Sleep deficit 위에 넛지 카드 배치
- `@Query(sort: \WorkoutTemplate.updatedAt) private var templates: [WorkoutTemplate]`로 기존 템플릿 조회
- "Save as Template" 탭 → `TemplateFormView` sheet (pre-fill)
- "Start Workout" 탭 → Activity 탭 `startRecommendation` 기존 플로우 재사용
- dismiss → `TemplateNudgeDismissStore.dismiss(id)`

### Step 6: TemplateFormView pre-fill init 추가

```swift
/// Pre-fill mode from recommendation nudge
init(
    prefillName: String,
    prefillEntries: [TemplateEntry],
    generator: any NaturalLanguageWorkoutGenerating = ...,
    workoutService: any WorkoutQuerying = ...
)
```

### Step 7: SuggestedWorkoutSection CTA 추가

기존 추천 루틴 카드에 "Save" 아이콘 버튼 추가:
- 현재: 카드 탭 → 즉시 시작
- 변경: 카드 탭 → 즉시 시작 (유지) + 카드 우상단 bookmark 아이콘 → 템플릿 저장
- `onSaveAsTemplate: (WorkoutTemplateRecommendation) -> Void` 콜백 추가

### Step 8: Localization

새 UI 문자열을 `Localizable.xcstrings`에 en/ko/ja 등록:
- "Your Routine" / "나의 루틴" / "あなたのルーティン"
- "Save as Template" / "템플릿으로 저장" / "テンプレートとして保存"
- "Repeated %lld times, avg %lld min" / "%lld회 반복, 평균 %lld분" / "%lld回繰り返し、平均%lld分"
- "Start Workout" — 기존 번역 재사용 가능 여부 확인

### Step 9: xcodegen + Build 확인

1. `scripts/build-ios.sh` 실행하여 새 파일 포함 빌드 통과 확인

## Test Strategy

| 테스트 | 대상 | 파일 |
|--------|------|------|
| TemplateOverlapChecker 겹침 판단 | 0/50/80/100% 케이스 | `DUNETests/TemplateOverlapCheckerTests.swift` |
| TemplateNudgeDismissStore 만료 | dismiss/만료/미등록 | `DUNETests/TemplateNudgeDismissStoreTests.swift` |
| DashboardViewModel 넛지 필터 | overlap+dismiss 조합 | 기존 DashboardViewModel 테스트 확장 |

## Risks & Edge Cases

| Risk | Mitigation |
|------|-----------|
| 대시보드 카드 과다 | 넛지 카드는 조건부 노출 (추천 있음 + 기존 템플릿 미겹침 + 미dismiss) |
| WorkoutTemplate @Query in ViewModel | View에서 `@Query` 결과를 ViewModel에 전달하는 기존 패턴 사용 |
| 사용자가 템플릿 저장 후 카드 잔존 | 저장 완료 시 dismiss + OverlapChecker가 다음 로드에서 필터 |
| 대시보드 startRecommendation 누락 | Activity의 기존 `startRecommendation` 로직을 shared helper로 추출 |
