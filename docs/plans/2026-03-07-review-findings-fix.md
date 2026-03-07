---
tags: [review, fix, localization, performance, dead-code]
date: 2026-03-07
category: plan
status: draft
---

# 리뷰 발견사항 일괄 수정

## Problem Statement

2026-03-07 15시 이후 머지된 16개 PR (145파일, +7550/-1960) 리뷰에서 P1 2건, P2 5건, P3 3건 발견.

## Implementation Steps

### Step 1: P1-1 — Watch 비활동 알림 문자열 로컬라이즈

**파일**: `DUNEWatch/Views/SessionPagingView.swift`
- `cardioAlertTitle` computed property: `String(localized:)` 래핑
- `cardioAlertMessage` computed property: `String(localized:)` 래핑
- Button 레이블 "Keep Running", "End Now", "Pause", "End Workout": 이미 SwiftUI Button이므로 자동 LocalizedStringKey
- `DUNEWatch/Resources/Localizable.xcstrings`에 ko/ja 번역 등록

### Step 2: P1-2 — shouldSuggestLevelUp() dead code 제거

**파일**: `DUNE/Presentation/Exercise/WorkoutSessionViewModel.swift`
- `shouldSuggestLevelUp()` 메서드 제거
- 관련 상수 `levelUpMinimumRepsAchievementRate` 제거 (다른 참조 없는 경우)
- `DUNETests/WorkoutSessionViewModelTests.swift`에서 관련 테스트 제거

### Step 3: P2-1 — BedtimeWatchReminderScheduler TaskGroup 병렬화

**파일**: `DUNE/Data/Services/BedtimeWatchReminderScheduler.swift`
- `for offset in 1...7` 순차 쿼리 → `withThrowingTaskGroup` 병렬 실행
- 결과 수집 후 순서 보장 (offset 순서 유지 불필요 — 모든 stages를 flat 수집)

### Step 4: P2-2 — WorkoutTemplateRecommendationService 미연결 표시

**판단**: 이 서비스는 테스트까지 작성된 의도적 구현. UI 연결은 별도 작업이므로 TODO 주석 추가.

### Step 5: P2-3 — Watch exercise helper 문자열 로컬라이즈

**파일**: `DUNEWatch/Helpers/WatchExerciseHelpers.swift`
- `exerciseSubtitle`: `"\(sets) sets · \(reps) reps"` → `String(localized:)`
- `routineMetaLabel`: `"\(entries.count) exercise(s)"`, `"sets"`, `"~\(mins)min"` → `String(localized:)`
- Watch xcstrings에 ko/ja 번역 등록

### Step 6: P2-4 — VitalsQueryService startDate→endDate 확인

**판단**: `endDate` 정렬은 의도적 변경 (VO2Max freshness fix). "가장 최신 endDate 샘플"이 올바른 의미. 수정 불필요 — 문서화만.

### Step 7: P2-5 — WorkoutTemplateRecommendationService 시간 레이블 로컬라이즈

**파일**: `DUNE/Domain/UseCases/WorkoutTemplateRecommendationService.swift`
- `timeBucketPrefix`: "Morning"/"Day"/"Evening"/"Night" → `String(localized:)`
- `title(for:)`: 보간 문자열 → `String(localized:)` 패턴
- iOS xcstrings에 ko/ja 번역 등록

### Step 8: P3-1 — SuggestedWorkoutSection 검색 debounce (skip)

**판단**: `rebuildFilteredExercises`는 in-memory 필터링이므로 debounce 불필요. 서버 호출이 아님.

### Step 9: P3-2 — CardioInactivityPolicy 타입 분리 (skip)

**판단**: 파일 분리는 코드 정리 수준. 현재 WorkoutManager.swift 내에 있는 것은 접근제어상 합리적.

### Step 10: P3-3 — preferredExerciseIDs 전달 (skip)

**판단**: SuggestedWorkoutSection은 이미 `popularExerciseIDs + recentExerciseIDs`로 정렬. preferred는 ExercisePickerView 전용.

## Affected Files

| 파일 | 변경 내용 |
|------|----------|
| `DUNEWatch/Views/SessionPagingView.swift` | String(localized:) 적용 |
| `DUNEWatch/Helpers/WatchExerciseHelpers.swift` | String(localized:) 적용 |
| `DUNEWatch/Resources/Localizable.xcstrings` | ko/ja 번역 추가 |
| `DUNE/Presentation/Exercise/WorkoutSessionViewModel.swift` | shouldSuggestLevelUp 제거 |
| `DUNETests/WorkoutSessionViewModelTests.swift` | 관련 테스트 제거 |
| `DUNE/Data/Services/BedtimeWatchReminderScheduler.swift` | TaskGroup 병렬화 |
| `DUNE/Domain/UseCases/WorkoutTemplateRecommendationService.swift` | 시간 레이블 로컬라이즈 |
| `Shared/Resources/Localizable.xcstrings` | ko/ja 번역 추가 |

## Test Strategy

- 기존 테스트 빌드 통과 확인
- shouldSuggestLevelUp 제거 후 관련 테스트도 제거

## Risks

- Watch xcstrings 번역 등록 누락 → 빌드 시 자동 감지
- shouldSuggestLevelUp 제거 시 다른 참조 누락 → Grep으로 사전 확인 완료 (UI 참조 없음)
