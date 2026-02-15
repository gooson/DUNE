---
tags: [detail-view, activity-tab, charts, long-press, apple-fitness, D-W-M-6M-Y]
date: 2026-02-16
category: plan
status: draft
---

# Implementation Plan: 메트릭 상세 화면 + Activity 탭 재설계

## Context

현재 앱은 Dashboard 카드에서 메트릭을 보여주지만 **상세 화면(Detail View)** 이 없습니다. Apple Fitness/Health 앱처럼 각 카드를 탭하면 D/W/M/6M/Y 시간 단위로 차트를 볼 수 있고, 롱프레스로 추가 수치를 확인하고, "모든 수치 보기" 화면으로 진입하는 기능이 필요합니다.

또한 현재 "Activity" 탭(Exercise)은 단순 운동 기록 리스트인데, Apple Fitness 앱처럼 **최상단 요약 그래프 + 메트릭 카드** 구조로 재설계가 필요합니다.

### 레퍼런스: Apple Fitness/Health 패턴

| 요소 | Apple Health 패턴 | 적용 방식 |
|------|-------------------|----------|
| 시간 단위 전환 | `D / W / M / 6M / Y` Segmented Control | Navigation Bar 아래 Picker |
| 차트 인터랙션 | 드래그로 scrub + RuleMark 선택 | `chartXSelection` (iOS 17+) |
| 롱프레스 | Context Menu + Custom Preview | `.contextMenu(menuItems:preview:)` |
| 모든 데이터 보기 | Grouped List (날짜별 섹션) | Push Navigation |
| 요약 헤더 | 기간별 평균/합계 + 변화율 | 차트 위 Summary Section |
| Activity 요약 | Activity Rings + Weekly Summary | Condition Ring 재활용 + 주간 차트 |

## Requirements

### Functional
1. **MetricDetailView**: 6개 메트릭(HRV, RHR, Sleep, Exercise, Steps, Weight) 각각 상세 화면
2. **TimePeriod 전환**: D / W / M / 6M / Y 시간 단위 segmented picker
3. **메트릭별 최적 차트**: HRV(dot-line), RHR(range bar), Sleep(stacked bar), Steps(bar), Weight(area line), Exercise(bar)
4. **차트 인터랙션**: 드래그 scrub → 선택 지점 값 표시, RuleMark indicator
5. **롱프레스 Context Menu**: 카드 롱프레스 → preview 차트 + 메뉴(View Trend, Show All Data)
6. **AllDataView**: 날짜별 그룹 → 시간+값+소스 리스트, 무한 스크롤
7. **Activity 탭 재설계**: 상단 주간 요약 차트 + Activity 관련 메트릭 카드 그리드
8. **Highlights 섹션**: 주간 최고/최저, 트렌드 방향 요약 텍스트

### Non-functional
- 90일+ 데이터 차트 60fps 유지 (집계 전략)
- Accessibility: VoiceOver 차트 값 낭독, Dynamic Type 대응
- Reduced Motion: 차트 트랜지션 비활성화

## Architecture Overview

### 신규 파일 구조

```
Presentation/
├── Shared/
│   ├── Charts/
│   │   ├── DotLineChartView.swift         (기존 - 수정)
│   │   ├── BarChartView.swift             (신규 - Steps, Exercise)
│   │   ├── RangeBarChartView.swift        (신규 - RHR min-max)
│   │   ├── AreaLineChartView.swift        (신규 - Weight)
│   │   ├── SleepStageChartView.swift      (신규 - Sleep stages)
│   │   └── ChartModels.swift             (신규 - 공유 데이터 모델)
│   │
│   └── Detail/
│       ├── MetricDetailView.swift         (신규 - 통합 상세 화면)
│       ├── MetricDetailViewModel.swift    (신규 - 상세 데이터 로딩)
│       ├── MetricSummaryHeader.swift      (신규 - 기간 요약 헤더)
│       ├── MetricHighlightsView.swift     (신규 - 주간 하이라이트)
│       ├── AllDataView.swift              (신규 - 전체 데이터 리스트)
│       └── AllDataViewModel.swift         (신규 - 페이지네이션 로딩)
│
├── Dashboard/
│   └── Components/
│       └── MetricCardView.swift           (수정 - NavigationLink + contextMenu)
│
├── Activity/                              (신규 - Exercise → Activity 확장)
│   ├── ActivityView.swift                 (신규 - 요약 차트 + 카드 그리드)
│   ├── ActivityViewModel.swift            (신규 - 다중 메트릭 로딩)
│   ├── Components/
│   │   ├── WeeklySummaryChartView.swift   (신규 - 주간 요약 차트)
│   │   ├── ActivityMetricCardView.swift   (신규 - Activity 전용 카드)
│   │   └── ExerciseListSection.swift      (신규 - 운동 기록 섹션)
│   └── (ExerciseView.swift 등 기존 → 서브뷰로 활용)
│
└── Domain/
    └── Models/
        └── TimePeriod.swift               (신규 - D/W/M/6M/Y enum)
```

### Layer 의존성 (변경 없음)

```
App → Presentation → Domain ← Data
```

- `TimePeriod`는 **Domain** (Foundation만 사용)
- Chart View들은 **Presentation/Shared/Charts/**
- Detail View/ViewModel은 **Presentation/Shared/Detail/**
- ViewModel은 `import Observation` (SwiftUI 금지)

## Affected Files

| File | Change Type | Description |
|------|-------------|-------------|
| **Domain - 신규** | | |
| `Domain/Models/TimePeriod.swift` | CREATE | D/W/M/6M/Y enum + 날짜 범위 계산 |
| **Presentation/Shared/Charts - 신규** | | |
| `Shared/Charts/ChartModels.swift` | CREATE | `ChartDataPoint` 확장 + `RangeDataPoint`, `StackedDataPoint` |
| `Shared/Charts/BarChartView.swift` | CREATE | Steps/Exercise용 바 차트 |
| `Shared/Charts/RangeBarChartView.swift` | CREATE | RHR min-max 캡슐 바 차트 |
| `Shared/Charts/AreaLineChartView.swift` | CREATE | Weight 영역 라인 차트 |
| `Shared/Charts/SleepStageChartView.swift` | CREATE | Sleep stage 스택 바 차트 |
| **Presentation/Shared/Detail - 신규** | | |
| `Shared/Detail/MetricDetailView.swift` | CREATE | 통합 상세 화면 (차트 분기) |
| `Shared/Detail/MetricDetailViewModel.swift` | CREATE | 시간 기반 데이터 로딩 |
| `Shared/Detail/MetricSummaryHeader.swift` | CREATE | 평균/합계 + 변화율 |
| `Shared/Detail/MetricHighlightsView.swift` | CREATE | 주간 최고/최저/트렌드 |
| `Shared/Detail/AllDataView.swift` | CREATE | 날짜별 그룹 리스트 |
| `Shared/Detail/AllDataViewModel.swift` | CREATE | 페이지네이션 HealthKit 로딩 |
| **Presentation/Activity - 신규** | | |
| `Activity/ActivityView.swift` | CREATE | Activity 탭 메인 화면 |
| `Activity/ActivityViewModel.swift` | CREATE | 다중 메트릭 로딩 |
| `Activity/Components/WeeklySummaryChartView.swift` | CREATE | 주간 요약 복합 차트 |
| `Activity/Components/ActivityMetricCardView.swift` | CREATE | Activity 전용 카드 |
| `Activity/Components/ExerciseListSection.swift` | CREATE | 운동 기록 섹션 |
| **수정 파일** | | |
| `Shared/Charts/DotLineChartView.swift` | MODIFY | `chartXSelection` 업그레이드, Period→TimePeriod 연동 |
| `Dashboard/Components/MetricCardView.swift` | MODIFY | NavigationLink 래핑 + contextMenu 추가 |
| `Dashboard/DashboardView.swift` | MODIFY | navigationDestination 등록 |
| `App/ContentView.swift` | MODIFY | Activity 탭 연결 (Exercise → Activity 교체) |
| `App/AppSection.swift` | MODIFY | activity case 추가/변경 |
| `Shared/Charts/ChartDataPoint` | MODIFY | `DotLineChartView.swift`에서 `ChartModels.swift`로 이동 |

## Implementation Steps

---

### Phase 1: Foundation (차트 모델 + TimePeriod)

#### Step 1.1: TimePeriod 모델 생성
- **File**: `Domain/Models/TimePeriod.swift`
- **Changes**:
  ```swift
  enum TimePeriod: String, CaseIterable, Sendable {
      case day = "D"
      case week = "W"
      case month = "M"
      case sixMonths = "6M"
      case year = "Y"

      var dateRange: (start: Date, end: Date) { ... }
      var strideComponent: Calendar.Component { ... }
      var strideCount: Int { ... }
      var aggregationUnit: Calendar.Component { ... }
  }
  ```
- **Verification**: 유닛 테스트 — 각 period의 dateRange, stride 검증

#### Step 1.2: Chart 공통 모델 추출
- **File**: `Shared/Charts/ChartModels.swift`
- **Changes**:
  - `ChartDataPoint` → `ChartModels.swift`로 이동
  - `RangeDataPoint` 추가 (min/max for RHR)
  - `StackedDataPoint` 추가 (stages for Sleep)
  - `AggregatedDataPoint` 추가 (period 집계용)
- **Verification**: 기존 `DotLineChartView` 빌드 성공

---

### Phase 2: 차트 컴포넌트 (메트릭별 최적 차트)

#### Step 2.1: BarChartView (Steps, Exercise)
- **File**: `Shared/Charts/BarChartView.swift`
- **Changes**:
  - `BarMark` + rounded corner clip
  - `chartXSelection` 기반 선택
  - Period별 X축 stride 자동 조정
  - 선택 시 `RuleMark` + annotation popover
  - Scrollable for Day view (24 bars)
- **Verification**: Preview에서 7일/30일 데이터 렌더링

#### Step 2.2: RangeBarChartView (RHR)
- **File**: `Shared/Charts/RangeBarChartView.swift`
- **Changes**:
  - `BarMark(yStart:yEnd:)` + Capsule clip
  - 평균 라인 오버레이 (`LineMark`)
  - Apple Health 스타일 min-max 범위 표시
- **Verification**: Preview에서 RHR 60-80 범위 렌더링

#### Step 2.3: AreaLineChartView (Weight)
- **File**: `Shared/Charts/AreaLineChartView.swift`
- **Changes**:
  - `LineMark` + `AreaMark` gradient fill
  - Catmull-Rom interpolation
  - Y축 auto-range (min-2 ~ max+2)
- **Verification**: Preview에서 3개월 체중 트렌드 렌더링

#### Step 2.4: SleepStageChartView (Sleep)
- **File**: `Shared/Charts/SleepStageChartView.swift`
- **Changes**:
  - Day: 수평 타임라인 (stage 전환 시각화)
  - Week/Month: 일별 총 수면 시간 바 차트 (stage별 색상 스택)
  - Legend 자동 생성
- **Verification**: Preview에서 stage 데이터 렌더링

#### Step 2.5: DotLineChartView 업그레이드
- **File**: `Shared/Charts/DotLineChartView.swift`
- **Changes**:
  - `chartOverlay` → `chartXSelection(value:)` 마이그레이션
  - `Period` enum → `TimePeriod` 연동 (backward compat 유지하되 새 API 추가)
  - 90일+ 데이터: PointMark 자동 제거 (30개 초과 시)
  - Selection RuleMark + annotation popover
- **Verification**: 기존 Dashboard sparkline 동작 유지 확인

---

### Phase 3: Detail View 시스템

#### Step 3.1: MetricSummaryHeader
- **File**: `Shared/Detail/MetricSummaryHeader.swift`
- **Changes**:
  - 현재 값 (대형 숫자)
  - 기간 평균/합계
  - 전 기간 대비 변화율 (Capsule badge)
  - 마지막 업데이트 날짜
- **Verification**: Preview에서 각 메트릭 타입별 렌더링

#### Step 3.2: MetricHighlightsView
- **File**: `Shared/Detail/MetricHighlightsView.swift`
- **Changes**:
  - 기간 내 최고/최저값 + 날짜
  - 트렌드 방향 (상승/하락/안정) 텍스트
  - InlineCard 스타일
- **Verification**: Preview에서 highlights 렌더링

#### Step 3.3: MetricDetailViewModel
- **File**: `Shared/Detail/MetricDetailViewModel.swift`
- **Changes**:
  ```swift
  @Observable @MainActor
  final class MetricDetailViewModel {
      var selectedPeriod: TimePeriod = .week
      var chartData: [ChartDataPoint] = []
      var summaryStats: MetricSummary?
      var highlights: [Highlight] = []
      var isLoading = false

      func loadData(for category: HealthMetric.Category, period: TimePeriod) async
  }
  ```
  - `import Observation` (SwiftUI 금지!)
  - HealthKit 서비스 주입 (protocol)
  - Period 변경 시 자동 리로드
  - 집계 전략: Day=raw, Week=daily, Month=daily, 6M=weekly, Year=monthly
- **Verification**: 유닛 테스트 — 집계 로직 검증

#### Step 3.4: MetricDetailView
- **File**: `Shared/Detail/MetricDetailView.swift`
- **Changes**:
  ```
  NavigationStack-aware View:
  ├── MetricSummaryHeader
  ├── TimePeriod Picker (.segmented)
  ├── Chart (category별 분기)
  │   ├── .hrv → DotLineChartView
  │   ├── .rhr → RangeBarChartView
  │   ├── .sleep → SleepStageChartView
  │   ├── .steps → BarChartView
  │   ├── .exercise → BarChartView
  │   └── .weight → AreaLineChartView
  ├── MetricHighlightsView
  └── NavigationLink("Show All Data") → AllDataView
  ```
  - Haptic: period 전환 시 `.selection`
  - 차트 높이: 250pt (iPhone), 300pt (iPad)
  - `sensoryFeedback` on chart selection
- **Verification**: 시뮬레이터에서 6개 메트릭 상세 화면 전환 확인

#### Step 3.5: AllDataView + ViewModel
- **Files**: `Shared/Detail/AllDataView.swift`, `AllDataViewModel.swift`
- **Changes**:
  - Grouped List (날짜별 Section)
  - 각 행: 시간 + 값 + 소스 아이콘 (Watch/iPhone/Manual)
  - Lazy loading (HealthKit anchored query 기반)
  - Navigation title: 메트릭명
  - 최신 순 정렬
- **Verification**: 시뮬레이터에서 스크롤 성능 확인

---

### Phase 4: 카드 인터랙션 (Navigation + Long Press)

#### Step 4.1: MetricCardView에 Navigation 연결
- **File**: `Dashboard/Components/MetricCardView.swift`
- **Changes**:
  - MetricCardView 자체는 변경 최소화
  - DashboardView에서 `NavigationLink(value:)` 래핑
  - `.navigationDestination(for: HealthMetric.self)` 등록
- **Verification**: 카드 탭 → MetricDetailView push 확인

#### Step 4.2: Context Menu (Long Press)
- **File**: `Dashboard/Components/MetricCardView.swift`, `Dashboard/DashboardView.swift`
- **Changes**:
  - `.contextMenu(menuItems:preview:)` 추가
  - Preview: 해당 메트릭의 주간 미니 차트 (DotLineChartView 축소판)
  - Menu items:
    - "View Trend" → MetricDetailView push
    - "Show All Data" → AllDataView push
    - "About This Metric" → 간단 설명 alert
  - Haptic: `.impact(.medium)` on long press
- **Verification**: 롱프레스 → 프리뷰 차트 + 메뉴 동작 확인

---

### Phase 5: Activity 탭 재설계

#### Step 5.1: ActivityViewModel
- **File**: `Activity/ActivityViewModel.swift`
- **Changes**:
  ```swift
  @Observable @MainActor
  final class ActivityViewModel {
      var weeklyExerciseMinutes: [ChartDataPoint] = []
      var weeklySteps: [ChartDataPoint] = []
      var weeklyCalories: [ChartDataPoint] = []
      var todayMetrics: [HealthMetric] = []
      var recentWorkouts: [WorkoutSummary] = []
      var isLoading = false

      func loadActivityData() async
  }
  ```
  - `import Observation` (SwiftUI 금지!)
  - 3개 독립 쿼리: `async let` 병렬화
  - 주간 데이터 + 오늘 요약
- **Verification**: 유닛 테스트 — 데이터 로딩 검증

#### Step 5.2: WeeklySummaryChartView
- **File**: `Activity/Components/WeeklySummaryChartView.swift`
- **Changes**:
  - 복합 차트: Exercise Minutes (bar) + Steps (line) overlay
  - 또는 탭으로 전환 가능한 3개 미니 차트 (Exercise / Steps / Calories)
  - HeroCard 스타일 배경
  - 주간 목표 대비 진행률 표시
- **Verification**: Preview에서 7일 데이터 렌더링

#### Step 5.3: ActivityView
- **File**: `Activity/ActivityView.swift`
- **Changes**:
  ```
  ScrollView:
  ├── WeeklySummaryChartView (HeroCard)
  ├── "Today" 섹션
  │   └── SmartCardGrid (Exercise, Steps, Calories 카드)
  │       └── 각 카드 탭 → MetricDetailView
  ├── "Recent Workouts" 섹션
  │   └── ExerciseListSection (최근 5개)
  │       └── "See All" → ExerciseView (기존)
  └── Add Exercise FAB / 버튼
  ```
  - 기존 `ExerciseView`는 "전체 운동 기록" 서브 화면으로 유지
  - NavigationDestination 등록
- **Verification**: 시뮬레이터에서 Activity 탭 전체 플로우 확인

#### Step 5.4: ExerciseListSection
- **File**: `Activity/Components/ExerciseListSection.swift`
- **Changes**:
  - 최근 N개 운동 compact list
  - 각 행: 운동 타입 아이콘 + 이름 + 시간 + 칼로리
  - "See All" NavigationLink → ExerciseView
- **Verification**: Preview에서 리스트 렌더링

#### Step 5.5: ContentView + AppSection 업데이트
- **File**: `App/ContentView.swift`, `App/AppSection.swift`
- **Changes**:
  - `.exercise` case → `.activity`로 교체 (또는 추가)
  - Activity 탭에 `ActivityView` 연결
  - 기존 ExerciseView는 ActivityView 내부 NavigationLink로 접근
- **Verification**: 4개 탭 모두 정상 동작 확인

---

### Phase 6: Data Layer 확장

#### Step 6.1: HealthKit 쿼리 서비스 확장
- **Files**: 기존 Query Service 파일들
- **Changes**:
  - `HRVQueryService`: period 기반 쿼리 메서드 추가 (기존 today/week 외에 month/6m/year)
  - `SleepQueryService`: period 기반 집계 쿼리
  - `StepsQueryService`: period 기반 쿼리 (hourly for Day, daily for Week 등)
  - `WorkoutQueryService`: period 기반 쿼리
  - `BodyCompositionQueryService`: period 기반 쿼리
  - 공통 프로토콜: `func fetchData(for period: TimePeriod) async throws -> [ChartDataPoint]`
- **Verification**: 유닛 테스트 (Mock) — period별 날짜 범위 정확성

#### Step 6.2: 데이터 집계 유틸리티
- **File**: `Domain/UseCases/AggregateHealthDataUseCase.swift` (또는 Extension)
- **Changes**:
  - Raw 데이터 → 기간별 집계 (daily average, weekly average, monthly average)
  - Min/Max/Average/Sum 계산
  - `isNaN`, `isInfinite` 방어
- **Verification**: 유닛 테스트 — 경계값, 빈 데이터, NaN 케이스

---

### Phase 7: 테스트 + 마무리

#### Step 7.1: 유닛 테스트
- **Files**: `DailveTests/` 하위
- **Tests**:
  - `TimePeriodTests.swift`: dateRange, stride, aggregation unit
  - `MetricDetailViewModelTests.swift`: period 전환, 집계, 빈 데이터
  - `ActivityViewModelTests.swift`: 병렬 로딩, fallback
  - `AggregateHealthDataTests.swift`: 평균/합계, 경계값, NaN
  - `AllDataViewModelTests.swift`: 페이지네이션

#### Step 7.2: 접근성
- 모든 차트에 `accessibilityLabel`, `accessibilityValue`
- VoiceOver로 차트 값 낭독 가능
- Dynamic Type 대응 (`@ScaledMetric` 차트 높이)

#### Step 7.3: 성능 최적화
- 90일+ 데이터: 주간 평균 집계 (최대 ~13 포인트)
- Year 데이터: 월간 평균 집계 (12 포인트)
- Chart 렌더링: `drawingGroup()` modifier 고려
- Lazy loading in AllDataView

---

## Edge Cases

| Case | Handling |
|------|---------|
| 메트릭 데이터 0건 | EmptyStateView + "Start tracking" 안내 |
| HealthKit 권한 거부 | 차트 영역에 권한 요청 CTA |
| 특정 기간 데이터 없음 | "No data for this period" placeholder |
| Day view에서 아직 오늘 데이터 없음 | 어제 데이터 fallback + "Showing yesterday" 배너 |
| RHR min == max (단일 측정) | Capsule 높이 최소 4pt 보장 |
| Sleep stage 데이터 없음 (총 시간만 있음) | 단순 duration bar로 fallback |
| 6M/Y에서 데이터 매우 sparse | 실제 데이터 포인트만 표시 (빈 날짜 건너뜀) |
| iPad Split View 전환 | Detail view는 NavigationStack 내부이므로 안전 |
| 수학 함수 방어 | 평균 계산 시 count == 0 체크, log/sqrt 미사용 확인 |

## Data Flow

```
[카드 탭]
  → NavigationLink(value: HealthMetric)
    → MetricDetailView(metric:)
      → MetricDetailViewModel.loadData(category:, period:)
        → HealthKit Query Service (period 기반)
          → Raw samples
        → Aggregation (Day=raw, W=daily, M=daily, 6M=weekly, Y=monthly)
          → [ChartDataPoint]
        → Summary 계산 (avg, min, max, sum)
          → MetricSummary
      → Chart 렌더링 (category에 따라 차트 타입 분기)

[롱프레스]
  → .contextMenu(preview:)
    → Mini DotLineChartView (최근 7일)
  → Menu: "View Trend" → NavigationLink → MetricDetailView
  → Menu: "Show All Data" → NavigationLink → AllDataView

[Activity 탭]
  → ActivityView
    → ActivityViewModel.loadActivityData()
      → async let: exercise + steps + calories (병렬)
    → WeeklySummaryChartView (주간 데이터)
    → SmartCardGrid (Today 메트릭)
      → 각 카드 → MetricDetailView
    → ExerciseListSection (최근 운동)
      → "See All" → ExerciseView (기존)
```

## 차트 타입별 데이터 집계 전략

| 메트릭 | Day | Week | Month | 6 Months | Year |
|--------|-----|------|-------|----------|------|
| HRV | 시간별 raw | 일별 평균 | 일별 평균 | 주별 평균 | 월별 평균 |
| RHR | 시간별 min-max | 일별 min-max | 일별 min-max | 주별 min-max | 월별 min-max |
| Sleep | stage 타임라인 | 일별 총 시간(stacked) | 일별 총 시간 | 주별 평균 | 월별 평균 |
| Steps | 시간별 합계 | 일별 합계 | 일별 합계 | 주별 합계 | 월별 합계 |
| Exercise | 시간별 분 | 일별 합계 분 | 일별 합계 분 | 주별 합계 분 | 월별 합계 분 |
| Weight | raw 측정 | raw 측정 | 주별 평균 | 주별 평균 | 월별 평균 |

## Testing Strategy

| 유형 | 대상 | 도구 |
|------|------|------|
| Unit Test | TimePeriod, Aggregation, ViewModels | Swift Testing |
| Preview Test | 모든 차트 컴포넌트, Detail View | Xcode Preview |
| 시뮬레이터 | Navigation flow, 탭 전환, iPad | iPhone 17 + iPad Pro |
| 성능 | 90일 차트 스크롤 60fps | Instruments Time Profiler |
| 접근성 | VoiceOver, Dynamic Type, Reduced Motion | Accessibility Inspector |

## Risks

| Risk | Probability | Impact | Mitigation |
|------|-------------|--------|------------|
| HealthKit 쿼리 수 증가로 성능 저하 | 중간 | 높음 | Period별 캐싱, 결과 memoization |
| 차트 컴포넌트 6종 유지보수 부담 | 중간 | 중간 | 공통 modifier/style 추출, Chart protocol |
| 기존 Exercise 탭 → Activity 전환 시 회귀 | 낮음 | 중간 | ExerciseView를 서브뷰로 유지, 기존 로직 보존 |
| contextMenu preview에서 async 데이터 로딩 불가 | 중간 | 낮음 | 캐시된 최근 7일 데이터 사용 |
| 6M/Y 기간의 대량 데이터 집계 지연 | 중간 | 중간 | Background actor에서 집계 + loading indicator |
| iPad에서 Detail View가 Split View 충돌 | 낮음 | 높음 | AdaptiveNavigation 패턴 준수 |

## Estimation

| Phase | 파일 수 | 복잡도 |
|-------|---------|--------|
| Phase 1: Foundation | 2 | Low |
| Phase 2: Charts | 5 | High |
| Phase 3: Detail System | 6 | High |
| Phase 4: Card Interaction | 2 (수정) | Medium |
| Phase 5: Activity Tab | 5 | High |
| Phase 6: Data Layer | 2-3 (수정) | Medium |
| Phase 7: Tests | 5+ | Medium |
| **Total** | **~25-28 파일** | **High** |

## Confidence Assessment

- **Overall**: High
- **Reasoning**:
  - 기존 아키텍처(MVVM, Protocol-based services, GlassCard)가 이 확장에 잘 맞음
  - DotLineChartView, SmartCardGrid 등 기존 컴포넌트 재활용 가능
  - Domain/Data 레이어 변경이 최소 (주로 쿼리 메서드 추가)
  - iOS 26+ 타겟이므로 최신 Swift Charts API 제약 없음
  - Apple Fitness 패턴이 명확한 레퍼런스 → 디자인 결정 불확실성 낮음

## Priority Order (병렬 가능 Phase 표시)

```
Phase 1 (Foundation)
    ↓
Phase 2 (Charts)  ←→  Phase 6 (Data Layer)   [병렬 가능]
    ↓                      ↓
Phase 3 (Detail System)    |
    ↓                      |
Phase 4 (Card Interaction) |
    ↓                      ↓
Phase 5 (Activity Tab)  ←  (Phase 6 완료 필요)
    ↓
Phase 7 (Tests + 마무리)
```
