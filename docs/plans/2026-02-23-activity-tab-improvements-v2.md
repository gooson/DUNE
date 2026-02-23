---
tags: [activity, training-readiness, recovery-map, weekly-stats, detail-view, iPad, layout]
date: 2026-02-23
category: plan
status: draft
related_brainstorm: docs/brainstorms/2026-02-23-activity-tab-improvements-v2.md
---

# Plan: Activity Tab Improvements v2

## Overview

Activity 탭의 4가지 개선:
1. Training Readiness Hero Card → 상세 화면 push (14일 sub-score 트렌드)
2. Recovery Map iPhone 센터 정렬
3. This Week → 상세 화면 push (일별 차트 + 타입별 breakdown + 기간 전환)
4. iPad 가로모드 Recovery Map + This Week 나란히 배치

## Architecture Decisions

### AD-1: Training Readiness Detail은 async ViewModel

기존 3개 detail VM(PR/Consistency/ExerciseMix)은 `[ExerciseRecord]`만 받아 synchronous 계산.
Training Readiness detail은 14일 HRV/RHR/Sleep 트렌드가 필요하므로 **async 패턴** 사용.

- `TrainingReadinessDetailViewModel`에 HRV/Sleep service 주입
- `loadData()` → async let 병렬 (HRV collection + Sleep daily + current readiness)
- cancel-before-spawn (Correction #16) + Task.isCancelled guard (Correction #17)

### AD-2: This Week Detail은 TrainingVolumeAnalysisService 재활용

`TrainingVolumeAnalysisService.analyze()`가 이미 일별 breakdown + 타입별 분류 제공.
기간 전환(이번 주/지난 주/이번 달)은 `VolumePeriod` 또는 커스텀 date range.

- `WeeklyStatsDetailViewModel`은 `WorkoutQuerying` + `TrainingVolumeAnalysisService` 사용
- View에서 `@Query` 결과를 `ManualExerciseSnapshot`으로 변환 후 전달

### AD-3: iPad 레이아웃은 ActivityView body에서 sizeClass 분기

Recovery Map + This Week만 나란히 배치. 나머지 섹션은 VStack 유지.

```
iPad Landscape (sizeClass == .regular):
┌──────────────────────────────────────┐
│ ① Training Readiness Hero (full)     │
├──────────────────────────────────────┤
│ ② Injury Warning (full, if any)      │
├──────────────────┬───────────────────┤
│ ③ Recovery Map   │ ④ This Week       │
│                  │ ⑤ Suggested       │
├──────────────────┴───────────────────┤
│ ⑥ Training Volume (full)             │
│ ... 나머지 섹션 (full)                │
└──────────────────────────────────────┘

iPhone (sizeClass == .compact):
현재와 동일 — VStack 순서 유지
```

**더 나은 iPad 대안**: Recovery Map 옆에 This Week만 붙이는 대신, This Week + Suggested Workout까지 오른쪽 컬럼에 배치하면 Recovery Map 높이와 균형이 맞음.

## Affected Files

### 새 파일 (8개)

| 파일 | 설명 |
|------|------|
| `Presentation/Activity/TrainingReadiness/TrainingReadinessDetailView.swift` | 상세 화면 View |
| `Presentation/Activity/TrainingReadiness/TrainingReadinessDetailViewModel.swift` | async ViewModel |
| `Presentation/Activity/WeeklyStats/WeeklyStatsDetailView.swift` | This Week 상세 View |
| `Presentation/Activity/WeeklyStats/WeeklyStatsDetailViewModel.swift` | ViewModel (period switching) |
| `Presentation/Activity/TrainingReadiness/Components/ReadinessTrendChartView.swift` | 14일 readiness score line chart |
| `Presentation/Activity/TrainingReadiness/Components/SubScoreTrendChartView.swift` | HRV/Sleep/Recovery 개별 trend |
| `Presentation/Activity/WeeklyStats/Components/DailyVolumeChartView.swift` | 일별 bar chart |
| `Presentation/Activity/WeeklyStats/Components/ExerciseTypeBreakdownView.swift` | 타입별 비율 |

### 수정 파일 (4개)

| 파일 | 변경 |
|------|------|
| `ActivityDetailDestination.swift` | `.trainingReadiness`, `.weeklyStats` case 추가 |
| `ActivityView.swift` | NavigationLink 래핑, iPad sizeClass 분기, navigationDestination 추가 |
| `MuscleRecoveryMapView.swift` | bodyDiagramSection 센터 정렬 수정 |
| `ActivityViewModel.swift` | 14일 HRV/RHR raw data 노출 프로퍼티 추가 |

### xcodegen 재생성 필요

새 파일 8개 추가 → `cd Dailve && xcodegen generate`

## Implementation Steps

### Step 1: ActivityDetailDestination 확장 + Recovery Map 센터 정렬

**변경 범위**: 2개 파일, 빌드 검증 가능

1. `ActivityDetailDestination.swift`에 2개 case 추가:
   ```swift
   enum ActivityDetailDestination: Hashable {
       case personalRecords
       case consistency
       case exerciseMix
       case trainingReadiness  // NEW
       case weeklyStats        // NEW
   }
   ```

2. `ActivityView.swift` — navigationDestination switch에 임시 placeholder:
   ```swift
   case .trainingReadiness: Text("Training Readiness Detail — WIP")
   case .weeklyStats: Text("Weekly Stats Detail — WIP")
   ```

3. `ActivityView.swift` — Hero Card를 NavigationLink로 래핑:
   ```swift
   // ① Training Readiness Hero Card
   NavigationLink(value: ActivityDetailDestination.trainingReadiness) {
       TrainingReadinessHeroCard(...)
   }
   .buttonStyle(.plain)
   ```

4. `ActivityView.swift` — This Week를 NavigationLink로 래핑:
   ```swift
   // ④ Weekly Stats Grid
   SectionGroup(title: "This Week", ...) {
       NavigationLink(value: ActivityDetailDestination.weeklyStats) {
           WeeklyStatsGrid(stats: viewModel.weeklyStats)
       }
       .buttonStyle(.plain)
   }
   ```

5. `MuscleRecoveryMapView.swift` — bodyDiagramSection 센터 정렬:
   ```swift
   private var bodyDiagramSection: some View {
       VStack(spacing: DS.Spacing.sm) {
           HStack(spacing: DS.Spacing.sm) {
               bodyDiagram(isFront: true)
               bodyDiagram(isFront: false)
           }
           .frame(maxWidth: .infinity, alignment: .center) // 추가
           legendRow
       }
   }
   ```

**검증**: 빌드 성공 + Hero Card / This Week 탭 시 placeholder 표시

### Step 2: ActivityViewModel 데이터 노출 확장

1. 14일 HRV daily averages 저장:
   ```swift
   var hrvDailyAverages: [(date: Date, average: Double)] = []
   ```

2. 14일 RHR daily data 저장:
   ```swift
   var rhrDailyData: [(date: Date, value: Double)] = []
   ```

3. 14일 sleep daily data 저장:
   ```swift
   var sleepDailyMinutes: [(date: Date, minutes: Double)] = []
   ```

4. `safeReadinessFetch()` 수정 — raw collection 데이터를 프로퍼티에 저장
5. `safeSleepFetch()` 수정 또는 새 fetch 추가 — 14일 daily sleep 쿼리

**검증**: 빌드 성공

### Step 3: Training Readiness Detail View + ViewModel

1. `TrainingReadinessDetailViewModel`:
   - `@Observable @MainActor final class`
   - `import Foundation`, `import Observation`
   - Properties: `readiness: TrainingReadiness?`, `hrvTrend: [DailyValue]`, `rhrTrend: [DailyValue]`, `sleepTrend: [DailyValue]`, `readinessTrend: [DailyValue]`, `isLoading`, `errorMessage`
   - `DailyValue` struct: `date: Date, value: Double` (Sendable)
   - `loadData(readiness:hrvDailyAverages:rhrDailyData:sleepDailyMinutes:)` — 데이터 변환 + readiness 일별 재계산
   - 14일 readiness 일별 계산: 각 날짜의 HRV z-score → component score 근사치

2. `TrainingReadinessDetailView`:
   - `@State private var viewModel = TrainingReadinessDetailViewModel()`
   - `@Environment(\.horizontalSizeClass)` for iPad 2-column
   - Sections:
     - Score ring (큰 버전) + status + guide message
     - 14일 Readiness Score trend (LineMark)
     - Sub-score breakdown: HRV / RHR / Sleep 각각 14일 trend (LineMark)
     - Component weights 설명
   - `.task` trigger로 parent VM 데이터 전달

3. `ReadinessTrendChartView`: 14일 line chart
   - `ChartSelectionOverlay` 패턴
   - `.chartXSelection(value:)` + `.overlay(alignment: .top)`
   - `.clipped()` (Correction #70)

4. `SubScoreTrendChartView`: 개별 sub-score chart (재사용 가능)
   - data: `[DailyValue]`, title, color 파라미터
   - LineMark + AreaMark gradient

**검증**: 빌드 성공 + Training Readiness 탭 → 상세 화면 표시

### Step 4: Weekly Stats Detail View + ViewModel

1. `WeeklyStatsDetailViewModel`:
   - `@Observable @MainActor final class`
   - `import Foundation`, `import Observation`
   - Properties: `selectedPeriod: StatsPeriod` (thisWeek/lastWeek/thisMonth), `dailyVolumes: [DailyVolumePoint]`, `exerciseTypeBreakdown: [ExerciseTypeVolume]`, `periodComparison: PeriodComparison?`, `summaryStats: [ActivityStat]`, `isLoading`
   - `StatsPeriod` enum with date range 계산
   - `loadData(manualRecords:)` async — `TrainingVolumeAnalysisService` + `WorkoutQuerying`
   - `selectedPeriod.didSet { triggerReload() }` (cancel-before-spawn)

2. `WeeklyStatsDetailView`:
   - `@State private var viewModel: WeeklyStatsDetailViewModel`
   - `@Query` for ExerciseRecord
   - Sections:
     - Period Picker (Segmented: This Week / Last Week / This Month)
     - Summary stats (4개 카드 — 현재 WeeklyStatsGrid 재사용)
     - Daily Volume Bar Chart (일별 breakdown)
     - Exercise Type Breakdown (donut 또는 horizontal bar)
     - 기간 비교 통계 (vs 이전 기간)
   - `.task(id: records.count)` + `.onChange(of: selectedPeriod)`

3. `DailyVolumeChartView`:
   - BarMark per day
   - Segmented Picker로 metric 전환 (Volume / Calories / Duration)
   - `.id(selectedMetric) + .transition(.opacity)` (Correction #29)

4. `ExerciseTypeBreakdownView`:
   - 타입별 비율 (horizontal bar 또는 donut)
   - 타입별 총 volume/duration 표시

**검증**: 빌드 성공 + This Week 탭 → 상세 화면 표시 + 기간 전환 동작

### Step 5: iPad 가로모드 레이아웃

1. `ActivityView.swift` — sizeClass 기반 레이아웃 분기:
   ```swift
   @Environment(\.horizontalSizeClass) private var sizeClass
   private var isRegular: Bool { sizeClass == .regular }
   ```

2. Recovery Map + This Week + Suggested Workout를 iPad에서 HStack:
   ```swift
   if isRegular {
       HStack(alignment: .top, spacing: DS.Spacing.lg) {
           // Left: Recovery Map
           SectionGroup(title: "Recovery Map", ...) {
               MuscleRecoveryMapView(...)
           }
           .frame(maxWidth: .infinity)

           // Right: This Week + Suggested
           VStack(spacing: DS.Spacing.lg) {
               SectionGroup(title: "This Week", ...) {
                   NavigationLink(value: ...) { WeeklyStatsGrid(...) }
               }
               SectionGroup(title: "Suggested Workout", ...) {
                   SuggestedWorkoutSection(...)
               }
           }
           .frame(maxWidth: .infinity)
       }
   } else {
       // iPhone: 현재와 동일 순서
       SectionGroup(title: "Recovery Map", ...) { ... }
       SectionGroup(title: "This Week", ...) { ... }
       SectionGroup(title: "Suggested Workout", ...) { ... }
   }
   ```

3. `MuscleRecoveryMapView` — iPad에서 maxHeight 조정:
   - `sizeClass == .regular`일 때 column 폭에 맞게 자동 조정 (GeometryReader가 처리)
   - `.frame(maxHeight: 300)` → `.frame(maxHeight: isRegular ? 400 : 300)` 고려

**검증**: iPad Simulator에서 가로모드 확인 + iPhone에서 기존 레이아웃 유지

### Step 6: xcodegen + 빌드 + 테스트

1. `cd Dailve && xcodegen generate`
2. `scripts/build-ios.sh` 또는 `xcodebuild build`
3. 기존 테스트 통과 확인

## Test Strategy

| 대상 | 테스트 종류 | 내용 |
|------|-----------|------|
| `TrainingReadinessDetailViewModel` | Unit | 데이터 변환, empty state, 14일 미만 데이터 처리 |
| `WeeklyStatsDetailViewModel` | Unit | 기간별 date range 계산, period 전환, empty records |
| `StatsPeriod` | Unit | dateRange 계산 정확성 (이번 주/지난 주/이번 달) |
| iPad layout | Manual | 가로/세로 전환, Split View multitasking |
| Recovery Map centering | Manual | iPhone SE ~ Pro Max 다양한 width |

## Edge Cases

- Training Readiness `nil` (데이터 없음) → Hero Card 탭 비활성 또는 empty detail
- HRV 7일 미만 (calibrating) → 상세에서 "Need more data" 메시지 + 있는 데이터만 표시
- This Week 데이터 0건 → empty state
- iPad multitasking resize → @State sizeClass capture (Correction #10)
- 기간 전환 중 취소 → cancel-before-spawn (Correction #16)

## Risks

| 위험 | 영향 | 대응 |
|------|------|------|
| ActivityViewModel 데이터 노출 변경이 기존 동작에 영향 | 중 | raw data 저장만 추가, 기존 로직 변경 없음 |
| iPad HStack에서 RecoveryMap GeometryReader 폭 변경 | 낮 | GeometryReader가 부모 폭에 적응 — 기존 패턴 |
| 14일 sleep daily 쿼리 추가로 로딩 시간 증가 | 낮 | async let 병렬화로 latency 최소화 |

## Correction Log 준수 체크

- [x] #7: ViewModel에 `import SwiftUI` 금지
- [x] #16: cancel-before-spawn
- [x] #17: Task.isCancelled guard
- [x] #28: Chart selection overlay 패턴
- [x] #29: Period 전환 .id() + .transition(.opacity)
- [x] #48: navigationDestination 조건 블록 밖
- [x] #61: Navigation enum 사용 (String 금지)
- [x] #70: Chart .clipped()
- [x] #80: Formatter static let 캐싱
- [x] #93: switch default: 금지
- [x] #97: formattedWithSeparator
- [x] #102: body 내 Calendar 연산 캐싱
