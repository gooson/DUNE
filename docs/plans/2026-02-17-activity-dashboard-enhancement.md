---
topic: activity-dashboard-enhancement
date: 2026-02-17
status: draft
confidence: high
related_solutions: [chart-ux-layout-stability, activity-tab-review-patterns]
related_brainstorms: [2026-02-17-activity-tab-redesign]
---

# Implementation Plan: Activity 대시보드 영역 강화

## Context

브레인스토밍 문서 Section 5("Activity 탭 레이아웃 개편안")에 따르면 Activity 탭 대시보드에 3개 핵심 컴포넌트가 배치되어야 한다:

1. **AI 추천 운동 카드** — 근육 피로도 기반 오늘의 추천
2. **주간 요약 차트** — 운동/걸음 이중 탭 차트 (이미 존재)
3. **근육 그룹 맵** — 주간 볼륨 기반 인체 시각화

현재 상태:
- `SuggestedWorkoutCard`, `MuscleMapView`, `VolumeAnalysisView` **모두 구현 완료**
- 그러나 `ExerciseView`(See All 목적지)에서만 접근 가능 — 탭 대시보드(`ActivityView`)에는 노출되지 않음
- 브레인스토밍의 목표 레이아웃과 현재 구현 사이에 **배치 격차**가 존재

## Requirements

### Functional

- ActivityView에 AI 추천 운동 카드 표시 (주간 요약 차트 위)
- ActivityView에 근육 맵 compact 버전 표시 (주간 차트와 오늘 메트릭 사이)
- 근육 맵 compact → 탭 시 MuscleMapView 전체 화면 이동
- 추천 운동 개별 exercise 탭 → WorkoutSessionView 이동
- 빈 데이터 상태 대응 (첫 사용자: 추천 없음, 근육 맵 비어있음)

### Non-functional

- ActivityView 로딩 시간 증가 최소화 (추천은 순수 계산, HK 쿼리 없음)
- 레이아웃 시프트 방지 (Correction Log #28, #30 준수)
- 기존 ActivityViewModel의 데이터 흐름과 일관성 유지

## Approach

**기존 컴포넌트 재사용 + compact 래퍼**: 이미 구현된 `SuggestedWorkoutCard`와 `MuscleMapView`를 직접 ActivityView에 삽입하되, MuscleMapView는 compact 요약(인라인 progress bar)으로 축약한 `MuscleMapSummaryCard`를 새로 만든다. 전체 맵은 NavigationLink로 연결.

### Alternative Approaches Considered

| Approach | Pros | Cons | Decision |
|----------|------|------|----------|
| A) 기존 컴포넌트 직접 embed | 변경량 최소 | MuscleMapView는 높이 400pt — 대시보드에 과다 | ❌ |
| B) compact 래퍼 + NavigationLink | 대시보드에 적합한 크기, 탭하면 상세 | MuscleMapSummaryCard 신규 필요 | ✅ 선택 |
| C) VolumeAnalysisView 미니 버전도 추가 | 정보 풍부 | 대시보드 과부하, 스크롤 과다 | ❌ (Phase 2) |

## Affected Files

| File | Change Type | Description |
|------|-------------|-------------|
| `Presentation/Activity/ActivityView.swift` | 수정 | SuggestedWorkoutCard + MuscleMapSummaryCard 삽입 |
| `Presentation/Activity/ActivityViewModel.swift` | 수정 | workoutSuggestion 프로퍼티 + updateSuggestion() 추가 |
| `Presentation/Activity/Components/MuscleMapSummaryCard.swift` | **신규** | 근육 맵 compact 요약 카드 (progress bar 형태) |
| `Dailve/project.yml` | 수정 | 신규 파일 자동 포함 확인 (sources glob) |

## Implementation Steps

### Step 1: ActivityViewModel에 추천 로직 추가

- **Files**: `ActivityViewModel.swift`
- **Changes**:
  - `var workoutSuggestion: WorkoutSuggestion?` 프로퍼티 추가
  - `func updateSuggestion(records: [ExerciseRecord])` 메서드 추가
  - ExerciseView의 `updateSuggestion()` 패턴 재사용: `ExerciseRecordSnapshot` 변환 → `WorkoutRecommendationService.recommend()`
  - `WorkoutRecommending` 의존성 주입 (init 파라미터)
  - `ExerciseLibraryQuerying` 의존성 주입 (init 파라미터)
- **Verification**: 빌드 성공, 기존 테스트 통과

### Step 2: MuscleMapSummaryCard 신규 생성

- **Files**: `Presentation/Activity/Components/MuscleMapSummaryCard.swift`
- **Changes**:
  - `@Query` 기반 주간 볼륨 계산 (MuscleMapView의 `weeklyVolume` 로직 동일)
  - 상위 6개 근육 그룹을 horizontal progress bar로 표시
  - "Muscle Activity" 헤더 + "See Full Map" 링크
  - `StandardCard` 래퍼 사용
  - 빈 데이터: "Start recording workouts to see muscle activity" placeholder
- **Verification**: Preview 확인, 빌드 성공

### Step 3: ActivityView에 컴포넌트 배치

- **Files**: `ActivityView.swift`
- **Changes**:
  - VStack 내 순서 변경:
    1. `SuggestedWorkoutCard` (workoutSuggestion이 있고 exercises 비어있지 않을 때만)
    2. `WeeklySummaryChartView` (기존 위치 유지)
    3. `MuscleMapSummaryCard` + NavigationLink(MuscleMapView)
    4. `todaySection` (기존)
    5. `ExerciseListSection` (기존)
  - `viewModel.updateSuggestion(records: recentRecords)` 호출 — `.task` + `.onChange(of: recentRecords)`
  - `SuggestedWorkoutCard`의 `onStartExercise` → `selectedExercise = exercise`로 연결 (기존 navigation destination 활용)
  - `.frame(minHeight:)` 패턴으로 조건부 컴포넌트의 레이아웃 시프트 방지 (Correction Log #30)
- **Verification**: 빌드 + 시뮬레이터에서 레이아웃 확인

### Step 4: xcodegen 재생성 + 빌드/테스트

- **Files**: `project.yml`
- **Changes**: 신규 파일이 sources glob에 자동 포함되는지 확인 (기존 `Presentation/Activity/Components/**` 패턴)
- **Verification**:
  ```bash
  cd Dailve && xcodegen generate
  xcodebuild build -project Dailve.xcodeproj -scheme Dailve \
    -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.2' -quiet
  xcodebuild test -project Dailve.xcodeproj -scheme DailveTests \
    -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.2' \
    -only-testing DailveTests -quiet
  ```

## Edge Cases

| Case | Handling |
|------|----------|
| 운동 기록 없음 (첫 사용) | SuggestedWorkoutCard 숨김, MuscleMapSummaryCard에 placeholder 표시 |
| 추천 exercises가 빈 배열 | SuggestedWorkoutCard 전체 숨김 (reasoning만 있는 경우도 숨김) |
| 주간 근육 볼륨 모두 0 | MuscleMapSummaryCard에 "No muscle data this week" 표시 |
| 대시보드 로딩 중 | 기존 ProgressView 유지 — 추천 계산은 동기 처리라 추가 로딩 없음 |
| iPad sizeClass 변경 | 기존 GlassCard/StandardCard가 sizeClass 대응 → 추가 처리 불필요 |

## Testing Strategy

- **Unit tests**: 불필요 — 추천 로직(`WorkoutRecommendationService`)과 볼륨 계산은 이미 테스트됨. 새 코드는 View 계층의 조합만 변경
- **Manual verification**:
  - 빈 데이터 상태에서 ActivityView 렌더링
  - 운동 기록 후 추천 카드 + 근육 맵 표시 확인
  - 추천 exercise 탭 → WorkoutSessionView 이동 확인
  - 근육 맵 카드 탭 → MuscleMapView 전체 화면 확인
  - pull-to-refresh 후 추천 갱신 확인

## Risks

| Risk | Probability | Impact | Mitigation |
|------|-------------|--------|------------|
| MuscleMapSummaryCard의 `@Query` 성능 | Low | Medium | 주간 필터링으로 스캔 범위 제한, `weeklyVolume` 계산은 O(N) |
| 대시보드 스크롤 길이 과다 | Medium | Low | 추천 카드는 compact, 근육 맵은 progress bar 6줄로 제한 |
| ExerciseView와 추천 로직 중복 | Medium | Low | `WorkoutRecommendationService` 공유 — snapshot 변환 로직만 중복 (3줄) |

## Confidence Assessment

- **Overall**: High
- **Reasoning**: 모든 핵심 컴포넌트가 이미 구현되어 있고, View 계층의 배치 변경 + compact 래퍼 1개 신규 생성으로 충분. 아키텍처 변경 없음, 새 의존성 없음.
