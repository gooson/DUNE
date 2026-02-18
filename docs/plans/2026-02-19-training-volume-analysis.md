---
topic: training-volume-analysis
date: 2026-02-19
status: draft
confidence: high
related_solutions:
  - performance/2026-02-15-healthkit-query-parallelization.md
  - performance/2026-02-16-computed-property-caching-pattern.md
  - performance/2026-02-16-review-triage-task-cancellation-and-caching.md
  - general/2026-02-17-chart-ux-layout-stability.md
  - general/2026-02-19-review-fix-chart-caching-error-propagation-value-validation.md
  - architecture/2026-02-17-activity-tab-review-patterns.md
related_brainstorms:
  - 2026-02-19-training-volume-analysis.md
---

# Implementation Plan: 훈련량 분석 시스템 고도화

## Context

현재 Train 대시보드(ActivityView)는 4개 섹션이 수직으로 나열되어 있다:
1. Weekly Summary Hero Chart (운동 시간/걸음수)
2. Muscle Activity Summary (근육 활동)
3. Training Load (28일 훈련량)
4. Today's Metrics (오늘 운동 시간/걸음수)

이를 하나의 **훈련량 통합 카드**로 압축하고, 탭 시 **종합 훈련량 분석 상세 화면**으로 진입한다.
상세 화면에서는 Apple Fitness 스타일로 운동 종류별 분석, 기간 비교, Activity Ring, 스택드 바 차트 등을 제공한다.
개별 운동 종류를 탭하면 해당 운동의 추세/PR/세션 히스토리를 보여주는 **운동 종류 상세 화면**으로 이동한다.

## Requirements

### Functional

- F1: 대시보드의 4개 훈련 관련 섹션을 1개 통합 카드로 교체
- F2: 통합 카드에 Activity Ring(주간 운동 일수 달성률) + Today 핵심 지표 + 7일 미니 바 차트 표시
- F3: 통합 카드 탭 → TrainingVolumeDetailView 진입
- F4: 상세 화면에서 기간 선택 (주/월/3개월)
- F5: 운동 종류별 비중 도넛 차트 (시간/칼로리/세션수 전환)
- F6: 기간 비교 (이번 기간 vs 이전 기간, 증감 표시)
- F7: 주간/월간 스택드 바 차트 (종류별 색상 구분)
- F8: Training Load 차트 상세 화면 통합
- F9: Muscle Map 상세 화면 통합
- F10: Today's Metrics 상세 화면 통합
- F11: 운동 종류별 리스트 (아이콘 + 이름 + 시간 + 세션 수 + 칼로리)
- F12: 운동 종류 탭 → ExerciseTypeDetailView (추세 차트, 기간 비교, PR, 최근 세션)
- F13: HealthKit 운동 + 수동 기록(ExerciseRecord) 통합 집계

### Non-functional

- NF1: HealthKit 3개월 쿼리 < 2초 (체감)
- NF2: 기간 전환 시 부드러운 crossfade (`.id()` + `.transition(.opacity)`)
- NF3: 차트 선택 시 레이아웃 시프트 없음 (`.overlay` 패턴)
- NF4: 빈 데이터 상태 처리 (모든 화면)
- NF5: 기존 DS 토큰 활용 (DS.Color.activity, DS.Spacing, DS.Radius)

## Approach

**점진적 구축 (Bottom-Up)**:
1. 먼저 데이터 레이어(집계 서비스)를 만들고 테스트
2. 상세 화면(TrainingVolumeDetailView) 구축
3. 운동 종류 상세(ExerciseTypeDetailView) 구축
4. 대시보드 통합 카드로 교체
5. 기존 4개 섹션 코드 정리

이 순서의 이유: 데이터 모델이 확정되어야 UI를 설계할 수 있고, 상세 화면이 먼저 있어야 통합 카드의 진입점을 연결할 수 있다.

### Alternative Approaches Considered

| Approach | Pros | Cons | Decision |
|----------|------|------|----------|
| Top-Down (카드 먼저) | 빠른 시각적 피드백 | 데이터 모델 확정 전 UI 변경 위험 | 기각 |
| Bottom-Up (데이터 먼저) | 안정적, 테스트 가능 | 중간에 시각적 결과 없음 | **채택** |
| 기존 화면 확장 | 변경 최소화 | 4개 섹션 유지로 복잡도 증가 | 기각 |

## Affected Files

### 신규 파일

| File | Description |
|------|-------------|
| `Domain/UseCases/TrainingVolumeAnalysisService.swift` | 훈련량 집계 로직 (종류별/기간별 그룹핑, 비교) |
| `Domain/Models/TrainingVolume.swift` | 집계 결과 모델 (TypeVolume, PeriodSummary 등) |
| `Presentation/Activity/TrainingVolume/TrainingVolumeDetailView.swift` | 종합 상세 화면 |
| `Presentation/Activity/TrainingVolume/TrainingVolumeViewModel.swift` | 상세 화면 VM |
| `Presentation/Activity/TrainingVolume/ExerciseTypeDetailView.swift` | 개별 운동 종류 상세 |
| `Presentation/Activity/TrainingVolume/ExerciseTypeDetailViewModel.swift` | 개별 운동 VM |
| `Presentation/Activity/TrainingVolume/Components/TrainingVolumeSummaryCard.swift` | 대시보드 통합 카드 |
| `Presentation/Activity/TrainingVolume/Components/ActivityRingView.swift` | Activity Ring |
| `Presentation/Activity/TrainingVolume/Components/VolumeDonutChartView.swift` | 종류별 도넛 차트 |
| `Presentation/Activity/TrainingVolume/Components/StackedVolumeBarChartView.swift` | 종류별 스택드 바 차트 |
| `Presentation/Activity/TrainingVolume/Components/PeriodComparisonView.swift` | 기간 비교 섹션 |
| `Presentation/Activity/TrainingVolume/Components/ExerciseTypeSummaryRow.swift` | 운동 종류 리스트 Row |
| `DailveTests/TrainingVolumeAnalysisServiceTests.swift` | 집계 서비스 테스트 |
| `DailveTests/TrainingVolumeViewModelTests.swift` | VM 테스트 |

### 수정 파일

| File | Change Type | Description |
|------|-------------|-------------|
| `Presentation/Activity/ActivityView.swift` | **Major** | 4개 섹션 → 통합 카드 교체, navigationDestination 추가 |
| `Presentation/Activity/ActivityViewModel.swift` | **Minor** | 통합 카드용 요약 데이터 추가 (기존 fetch 재활용) |
| `Dailve/project.yml` | **Minor** | 신규 파일 등록 (xcodegen) |

### 기존 파일 (통합 후 유지, 상세 화면에서 재사용)

| File | Status |
|------|--------|
| `Components/TrainingLoadChartView.swift` | 상세 화면에서 그대로 사용 |
| `Components/MuscleMapSummaryCard.swift` | 상세 화면에서 그대로 사용 |
| `Components/WeeklySummaryChartView.swift` | 상세 화면에서 그대로 사용 |

## Implementation Steps

### Step 1: Domain 모델 + 집계 서비스

- **Files**: `Domain/Models/TrainingVolume.swift`, `Domain/UseCases/TrainingVolumeAnalysisService.swift`
- **Changes**:

  ```swift
  // TrainingVolume.swift

  /// 기간 정의
  enum VolumePeriod: String, CaseIterable, Sendable {
      case week, month, threeMonths
      var days: Int { switch self { case .week: 7; case .month: 30; case .threeMonths: 90 } }
      var displayName: String { switch self { case .week: "주간"; case .month: "월간"; case .threeMonths: "3개월" } }
  }

  /// 운동 종류별 볼륨
  struct ExerciseTypeVolume: Identifiable, Sendable {
      var id: String { typeKey }
      let typeKey: String             // WorkoutActivityType.rawValue 또는 exerciseType
      let displayName: String
      let iconName: String
      let color: Color  // ← Presentation에서만 사용, Domain에는 colorHex: String
      let totalDuration: TimeInterval
      let totalCalories: Double
      let sessionCount: Int
      let totalDistance: Double?       // 유산소만
      let totalVolume: Double?         // 근력만 (kg × reps)
  }

  /// 기간 요약
  struct VolumePeriodSummary: Sendable {
      let period: VolumePeriod
      let startDate: Date
      let endDate: Date
      let totalDuration: TimeInterval
      let totalCalories: Double
      let totalSessions: Int
      let activeDays: Int             // 운동한 날 수
      let exerciseTypes: [ExerciseTypeVolume]
      let dailyBreakdown: [DailyVolumePoint]  // 스택드 바 차트용
  }

  /// 일별 볼륨 (스택드 바 차트용)
  struct DailyVolumePoint: Identifiable, Sendable {
      var id: Date { date }
      let date: Date
      let segments: [(typeKey: String, duration: TimeInterval)]
  }

  /// 기간 비교 결과
  struct PeriodComparison: Sendable {
      let current: VolumePeriodSummary
      let previous: VolumePeriodSummary?

      var durationChange: Double?     // 백분율
      var calorieChange: Double?
      var sessionChange: Double?
  }
  ```

  `TrainingVolumeAnalysisService`:
  - `func analyze(workouts: [WorkoutSummary], manualRecords: [ExerciseRecordSnapshot], period: VolumePeriod) -> PeriodComparison`
  - HealthKit `WorkoutSummary` → `activityType.rawValue` 기준 그룹핑
  - 수동 `ExerciseRecord` → `exerciseType` 기준 그룹핑
  - 양쪽 합산 후 duration/calories/sessions 집계
  - 이전 동일 기간 자동 계산 (주간이면 지난주, 월간이면 지난달)

- **Verification**: `TrainingVolumeAnalysisServiceTests` — 빈 데이터, 단일 운동, 다종 운동, 기간 비교, 중복 제거

### Step 2: 대시보드 통합 카드 + Activity Ring

- **Files**: `Components/TrainingVolumeSummaryCard.swift`, `Components/ActivityRingView.swift`
- **Changes**:

  **ActivityRingView**:
  - SwiftUI `Circle` + `.trim(from:to:)` + `.rotation(.degrees(-90))` 패턴
  - 입력: `progress: Double` (0.0 ~ 1.0+), `ringColor: Color`, `lineWidth: CGFloat`
  - 1.0 초과 시 두 번째 레이어로 초과분 표시

  **TrainingVolumeSummaryCard**:
  - `HeroCard(tintColor: DS.Color.activity)` 래핑
  - 상단: Activity Ring (작게, 60pt) + 오늘 핵심 지표 (운동 시간, 걸음수, 칼로리) HStack
  - 하단: 7일 미니 바 차트 (종류별 색상, 높이 60pt)
  - 전체를 `NavigationLink(value: TrainingVolumeDestination.overview)` 로 래핑
  - 데이터: `weeklyExerciseMinutes`, `todayExercise`, `todaySteps`, `weeklyTypeBreakdown`

- **Verification**: Preview에서 데이터 유/무 상태 확인

### Step 3: TrainingVolumeDetailView (종합 상세)

- **Files**: `TrainingVolumeDetailView.swift`, `TrainingVolumeViewModel.swift`, `Components/VolumeDonutChartView.swift`, `Components/StackedVolumeBarChartView.swift`, `Components/PeriodComparisonView.swift`, `Components/ExerciseTypeSummaryRow.swift`
- **Changes**:

  **TrainingVolumeViewModel**:
  - `@Observable @MainActor` (import Observation, not SwiftUI — Correction #7)
  - `selectedPeriod: VolumePeriod` → `didSet { triggerReload() }` (cancel-before-spawn — Correction #16)
  - `comparison: PeriodComparison?`
  - `trainingLoadData: [TrainingLoadDataPoint]`
  - 서비스: `WorkoutQuerying`, `StepsQuerying`, `TrainingVolumeAnalysisService`
  - `loadData()`: `async let`로 workouts + steps + trainingLoad 병렬 fetch → `TrainingVolumeAnalysisService.analyze()`
  - `weeklyGoal: Int = 5` (기본값, 추후 사용자 설정)

  **TrainingVolumeDetailView** ScrollView 레이아웃:
  1. Period Picker (`.segmented`) → `.id(selectedPeriod).transition(.opacity)` (Correction #29)
  2. Summary: Activity Ring (큰, 120pt) + 핵심 지표 카드 3개 (시간/칼로리/세션) + PeriodComparisonView
  3. VolumeDonutChartView: 종류별 비중 (Picker로 시간/칼로리/세션 전환)
  4. StackedVolumeBarChartView: 일별 스택드 바 (상위 5개 종류 + 기타)
  5. TrainingLoadChartView: 기존 컴포넌트 그대로 사용
  6. MuscleMapSummaryCard: 기존 컴포넌트 그대로 사용
  7. 운동 종류별 리스트: `ForEach(types) { ExerciseTypeSummaryRow → NavigationLink }`

  **VolumeDonutChartView**:
  - Swift Charts `SectorMark` (iOS 17+) 사용
  - `@State var selectedMetric: VolumeMetric` (.duration, .calories, .sessions)
  - `.chartAngleSelection(value:)` 로 탭 시 해당 운동 강조
  - 중앙에 총합 텍스트 overlay

  **StackedVolumeBarChartView**:
  - Swift Charts `BarMark` + `.foregroundStyle(by: .value("Type", typeKey))`
  - 상위 5개 운동 종류 + 나머지는 "기타"로 합산
  - `.chartForegroundStyleScale(mapping:)` 으로 종류별 색상 매핑

  **PeriodComparisonView**:
  - HStack: 이전 기간값 → 화살표 → 현재 기간값 + 증감 % 배지
  - 증감: `DS.Color.positive` (↑) / `DS.Color.negative` (↓) / `.secondary` (동일)

  **ExerciseTypeSummaryRow**:
  - HStack: 아이콘(색상 원) + 이름 + Spacer + 시간 + 세션수 + chevron
  - `NavigationLink(value: TrainingVolumeDestination.exerciseType(typeKey))` 래핑

- **Verification**: Preview + 빈 데이터/단일 운동/다종 운동 시나리오 확인

### Step 4: ExerciseTypeDetailView (개별 운동 상세)

- **Files**: `ExerciseTypeDetailView.swift`, `ExerciseTypeDetailViewModel.swift`
- **Changes**:

  **ExerciseTypeDetailViewModel**:
  - 입력: `typeKey: String`, `displayName: String`
  - `selectedPeriod: VolumePeriod`
  - `trendData: [ChartDataPoint]` (일별 시간/칼로리/거리/볼륨)
  - `selectedMetric: ExerciseVolumeMetric` (.duration, .calories, .distance, .volume)
  - `recentSessions: [WorkoutSummary]`
  - 기간 비교: 현재 vs 이전 동일 기간
  - PR 목록: `[PersonalRecordType]` (해당 운동에서의 PR)

  **ExerciseTypeDetailView**:
  1. 헤더: 아이콘(큰) + 이름 + 총합 통계 (기간 내 시간/세션/칼로리)
  2. Metric Picker + 추세 차트 (기존 `DotLineChartView` 또는 `BarChartView` 재사용)
  3. PeriodComparisonView 재사용
  4. PR 배지 섹션 (있을 경우)
  5. 최근 세션 리스트 → 기존 `HealthKitWorkoutDetailView` / `ExerciseSessionDetailView` 진입

- **Verification**: Preview + 유산소(거리 메트릭) / 근력(볼륨 메트릭) / 기타(시간만) 시나리오

### Step 5: ActivityView 통합 + Navigation 연결

- **Files**: `ActivityView.swift`, `ActivityViewModel.swift`
- **Changes**:

  **ActivityView 변경**:
  ```swift
  // Before: 4개 섹션
  WeeklySummaryChartView(...)
  MuscleMapSummaryCard(...)
  TrainingLoadChartView(...)
  todaySection

  // After: 1개 통합 카드
  TrainingVolumeSummaryCard(
      weeklyData: viewModel.weeklyExerciseMinutes,
      todayExercise: viewModel.todayExercise,
      todaySteps: viewModel.todaySteps,
      weeklyTypeBreakdown: viewModel.weeklyTypeBreakdown
  )
  ```

  **Navigation 추가**:
  ```swift
  // 새 Destination enum
  enum TrainingVolumeDestination: Hashable {
      case overview
      case exerciseType(typeKey: String, displayName: String, iconName: String)
  }

  // ActivityView에 등록
  .navigationDestination(for: TrainingVolumeDestination.self) { dest in
      switch dest {
      case .overview:
          TrainingVolumeDetailView()
      case .exerciseType(let key, let name, let icon):
          ExerciseTypeDetailView(typeKey: key, displayName: name, iconName: icon)
      }
  }
  ```

  **ActivityViewModel 추가**:
  - `weeklyTypeBreakdown: [(typeKey: String, color: Color, minutes: Double)]` — 통합 카드의 미니 바 차트용
  - 기존 `safeWorkoutsFetch()` 결과에서 종류별 그룹핑 (추가 쿼리 없음)

- **Verification**:
  - 대시보드 → 통합 카드 표시 확인
  - 카드 탭 → 상세 화면 진입 확인
  - 상세 화면 → 운동 종류 탭 → 개별 상세 진입 확인
  - 기존 Recent Workouts 섹션 정상 동작 확인

### Step 6: 테스트 + 빌드 검증

- **Files**: `DailveTests/TrainingVolumeAnalysisServiceTests.swift`, `DailveTests/TrainingVolumeViewModelTests.swift`
- **Changes**:

  **TrainingVolumeAnalysisServiceTests**:
  - 빈 데이터 → 모든 값 0
  - 단일 운동 종류 → 해당 종류만 100%
  - 다종 운동 → 비율 정확성
  - 기간 비교 → 증감 계산 정확성
  - HK + 수동 기록 통합 → 중복 없이 합산
  - 경계값: 0 duration, NaN calories, 음수 distance

  **TrainingVolumeViewModelTests**:
  - 기간 변경 시 reload 트리거
  - 빈 데이터 상태 처리
  - partial failure 메시지
  - weeklyGoal 달성률 계산

- **Verification**: `xcodebuild test` 전체 통과 + 빌드 성공

## Edge Cases

| Case | Handling |
|------|----------|
| 데이터 0건 (선택 기간) | 빈 상태 일러스트 + "이 기간에 기록된 운동이 없습니다" |
| HealthKit 권한 거부 | 수동 기록만 분석 + 상단 배너 "HealthKit 연동 시 더 많은 데이터 표시" |
| 운동 종류 20+ | 도넛/스택드 바에서 상위 5개 + "기타", 리스트는 전체 표시 |
| 기간 경계 (연초/월초) | Calendar.current 기준 정확한 날짜 계산, force-unwrap 금지 (Correction #21) |
| 0 duration 운동 | 집계에서 제외 (`guard duration > 0`) |
| NaN/Infinity 칼로리 | `.isFinite` 체크 후 0으로 대체 (Correction #18) |
| 중복 (HK + 수동 동일 운동) | 기존 `filteringAppDuplicates(against:)` 로직 재활용 |
| 3개월 쿼리 느림 | 로딩 인디케이터 + 결과 `@State` 캐싱 (기간별) |

## Testing Strategy

- **Unit tests**:
  - `TrainingVolumeAnalysisServiceTests` — 순수 로직 테스트 (Mock 데이터)
  - `TrainingVolumeViewModelTests` — Mock 서비스 주입, 상태 전이 테스트
- **Manual verification**:
  - 시뮬레이터에서 HealthKit 데이터 + 수동 기록 조합 확인
  - 기간 전환 애니메이션 확인
  - 빈 상태 → 데이터 있는 상태 전환 확인
  - 대시보드 → 상세 → 개별 운동 → 세션 디테일 전체 네비게이션 플로우

## Risks

| Risk | Probability | Impact | Mitigation |
|------|-------------|--------|------------|
| HealthKit 3개월 쿼리 성능 | Medium | Medium | 로딩 UI + 결과 캐싱, 필요 시 `HKStatisticsCollectionQuery` 사용 |
| SectorMark iOS 17+ 제한 | Low | Low | 프로젝트 타겟 iOS 26+ (문제 없음) |
| 대시보드 레이아웃 변경으로 기존 네비게이션 깨짐 | Medium | High | Step 5에서 기존 navigationDestination 모두 유지, 통합 후 전체 플로우 수동 테스트 |
| 종류별 색상 충돌 (비슷한 운동) | Low | Low | ActivityCategory 기반 색상 이미 정의됨, 차트에서는 상위 5개만 색상 구분 |
| ExerciseRecord + WorkoutSummary 통합 집계 복잡도 | Medium | Medium | TrainingVolumeAnalysisService에 로직 집중, 테스트로 검증 |

## Confidence Assessment

- **Overall**: High
- **Reasoning**:
  - 기존 차트 컴포넌트(BarChartView, DotLineChartView, ChartSelectionOverlay)를 재사용
  - 기존 데이터 서비스(WorkoutQueryService, StepsQueryService) 그대로 활용
  - 새로운 인프라 없이 Domain 집계 서비스 + Presentation 뷰만 추가
  - WorkoutActivityType+View.swift에 displayName/iconName/color 이미 완비
  - Correction Log의 차트 UX 패턴이 풍부하여 실수 가능성 낮음

## Summary: Step 실행 순서

| Step | 설명 | 예상 파일 수 | 의존성 |
|------|------|-------------|--------|
| 1 | Domain 모델 + 집계 서비스 | 2 신규 | 없음 |
| 2 | 통합 카드 + Activity Ring | 2 신규 | Step 1 |
| 3 | 종합 상세 화면 + 차트 컴포넌트 | 6 신규 + 1 VM | Step 1 |
| 4 | 개별 운동 상세 화면 | 2 신규 | Step 1, 3 |
| 5 | ActivityView 통합 + Navigation | 2 수정 | Step 2, 3, 4 |
| 6 | 테스트 + 빌드 검증 | 2 신규 테스트 | 전체 |
