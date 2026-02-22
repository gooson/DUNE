---
topic: activity-tab-redesign
date: 2026-02-22
status: draft
confidence: medium
related_solutions:
  - architecture/2026-02-21-wellness-section-split-patterns.md
  - architecture/2026-02-19-dry-extraction-shared-components.md
  - architecture/2026-02-19-unified-workout-row-review-fixes.md
  - architecture/2026-02-17-activity-tab-review-patterns.md
related_brainstorms:
  - 2026-02-22-activity-tab-ux-redesign.md
---

# Implementation Plan: Activity Tab UX Redesign

## Context

Activity 탭의 UX를 Wellness 탭 수준으로 개편합니다. 현재 문제:
- Muscle Recovery Map이 Front/Back 탭 전환으로 분리 — 전체 파악 어려움
- Hero Card 없이 바로 데이터 진입 — 핵심 지표(Training Readiness) 요약 부재
- Suggested Workout이 Muscle Map 안에 묻힘 — 발견성 낮음
- 주간 통계, PR, Streak 등 동기부여 요소 없음
- 디자인이 Wellness 탭과 일관성 부족

## Requirements

### Functional

1. **Training Readiness Hero Card**: HRV/RHR/Sleep/Fatigue 기반 0-100 점수 + Progress Ring
2. **Muscle Recovery Map**: Front/Back 좌우 나란히 배치
3. **Suggested Workout**: 독립 섹션 (Recent Workouts 위)
4. **Weekly Stats Grid**: 2열 VitalCard — Volume, Calories, Duration, Active Days
5. **Training Volume**: StandardCard + period picker (1W/1M/3M)
6. **Recent Workouts**: 디자인 개선 (Wellness 섹션 스타일)
7. **Personal Records**: 운동별 세션 최고 중량 2열 그리드
8. **Streak / Consistency**: 최소 시간 기준 연속일 + 월간 달성률
9. **Exercise Frequency**: 운동 종류별 빈도 분석
10. **탭 이름**: "Activity"로 통일

### Non-functional

- Wellness 탭과 시각적 일관성 (HeroCard, SectionGroup, VitalCard 재사용)
- 기존 HealthKit 쿼리 병렬화 패턴 유지 (Correction #5)
- iPhone SE ~ iPad 반응형 대응
- Cold start (데이터 없음) 대응

## Approach

10개 요구사항을 **7단계 순차 구현**으로 분리합니다. 각 단계는 독립적으로 빌드+테스트 가능합니다.

핵심 전략:
- Wellness 탭의 기존 컴포넌트(HeroCard, VitalCard, SectionGroup) 최대 재사용
- WellnessSectionGroup을 Shared로 이동하여 양쪽 탭에서 사용
- Training Readiness Score는 Domain 서비스로 구현 (WellnessScore 패턴 참조)
- ActivityViewModel에 새 데이터 소스 추가 (PR, Streak, Frequency, Readiness)

### Alternative Approaches Considered

| Approach | Pros | Cons | Decision |
|----------|------|------|----------|
| 전체 재작성 | 깔끔한 코드 | 기존 로직 유실 위험, 대규모 | **기각** |
| 점진적 리팩토링 | 안전, 각 단계 검증 가능 | 중간 상태 복잡 | **채택** |
| 별도 ViewModel 분리 | 관심사 분리 | 데이터 공유 복잡 | **기각** — 기존 VM 확장 |

## Affected Files

### 신규 생성

| File | Description |
|------|-------------|
| `Domain/Services/TrainingReadinessService.swift` | Readiness Score 계산 서비스 |
| `Domain/Models/TrainingReadiness.swift` | Readiness Score 모델 |
| `Domain/Services/PersonalRecordService.swift` | PR 추출 서비스 |
| `Domain/Models/PersonalRecord.swift` | PR 모델 |
| `Domain/Services/WorkoutStreakService.swift` | Streak 계산 서비스 |
| `Domain/Models/WorkoutStreak.swift` | Streak 모델 |
| `Domain/Services/ExerciseFrequencyService.swift` | 운동 빈도 분석 서비스 |
| `Domain/Models/ExerciseFrequency.swift` | 빈도 모델 |
| `Presentation/Activity/Components/TrainingReadinessHeroCard.swift` | Hero Card 뷰 |
| `Presentation/Activity/Components/WeeklyStatsGrid.swift` | 주간 통계 그리드 |
| `Presentation/Activity/Components/PersonalRecordsSection.swift` | PR 섹션 |
| `Presentation/Activity/Components/ConsistencyCard.swift` | Streak 카드 |
| `Presentation/Activity/Components/ExerciseFrequencySection.swift` | 빈도 분석 섹션 |
| `Presentation/Activity/Components/SuggestedWorkoutSection.swift` | 독립 추천 섹션 |
| `Presentation/Shared/Extensions/TrainingReadiness+View.swift` | Readiness 표시 확장 |
| `DailveTests/TrainingReadinessServiceTests.swift` | Readiness 계산 테스트 |
| `DailveTests/PersonalRecordServiceTests.swift` | PR 로직 테스트 |
| `DailveTests/WorkoutStreakServiceTests.swift` | Streak 로직 테스트 |
| `DailveTests/ExerciseFrequencyServiceTests.swift` | 빈도 분석 테스트 |

### 수정

| File | Change Type | Description |
|------|-------------|-------------|
| `ActivityView.swift` | **Major** | 전체 레이아웃 재구성 (10개 섹션) |
| `ActivityViewModel.swift` | **Major** | Readiness, PR, Streak, Frequency 데이터 로딩 추가 |
| `MuscleRecoveryMapView.swift` | **Major** | Front/Back 좌우 배치 + suggestion 분리 |
| `TrainingVolumeSummaryCard.swift` | **Minor** | StandardCard 래핑 + period picker |
| `ExerciseListSection.swift` | **Minor** | SectionGroup 스타일 적용 |
| `ContentView.swift` | **Minor** | 탭 이름 "Activity"로 변경 |
| `WellnessSectionGroup.swift` | **Move** | → `Shared/Components/SectionGroup.swift` |

### 삭제 (suggestion 분리 후 불필요)

| File | Reason |
|------|--------|
| `WeeklyProgressBar.swift` | Hero Card + Weekly Stats로 대체 |
| `SuggestedExerciseRow.swift` | SuggestedWorkoutSection으로 통합 |
| `MuscleMapSummaryCard.swift` | Muscle Map 직접 배치로 대체 (사용 여부 확인 필요) |

## Implementation Steps

### Step 1: Domain 서비스 + 모델 (Training Readiness Score)

- **Files**: `Domain/Services/TrainingReadinessService.swift`, `Domain/Models/TrainingReadiness.swift`, `DailveTests/TrainingReadinessServiceTests.swift`
- **Changes**:
  - `TrainingReadiness` 모델: `score: Int` (0-100), `status: ReadinessStatus` enum, `components: ReadinessComponents`
  - `ReadinessStatus`: `.ready` (80-100), `.moderate` (60-79), `.light` (40-59), `.rest` (0-39)
  - `ReadinessComponents`: `hrvScore, rhrScore, sleepScore, fatigueScore, trendBonus` (각 0-100)
  - `TrainingReadinessService` 프로토콜 + 구현:
    - 입력: HRV SDNN, RHR, Sleep duration/quality, Muscle fatigue states, 60-day baseline
    - 개인 baseline 대비 정규화: `score = clamp(50 + (current - mean) / SD * 15, 0, 100)`
    - 가중 합산: HRV 30% + RHR 20% + Sleep 25% + Fatigue 15% + Trend 10%
    - Cold start (< 14일): age/sex 기반 population reference 사용
  - `import Foundation` + `import HealthKit` only (Domain layer rule)
- **Verification**: Unit tests — 정상 범위, 경계값, cold start, NaN/Infinite 방어

### Step 2: Domain 서비스 + 모델 (PR, Streak, Frequency)

- **Files**: `PersonalRecordService.swift`, `PersonalRecord.swift`, `WorkoutStreakService.swift`, `WorkoutStreak.swift`, `ExerciseFrequencyService.swift`, `ExerciseFrequency.swift`, 각 Tests
- **Changes**:
  - **PersonalRecord**: `exerciseName, maxWeight, date, isRecent` (최근 7일 갱신 여부)
    - Service: ExerciseRecord 배열에서 운동별 세션 최고 중량 추출
  - **WorkoutStreak**: `currentStreak, bestStreak, monthlyCount, monthlyGoal, monthlyPercentage`
    - Service: 날짜 시퀀스에서 연속일 계산, 최소 시간 threshold 적용
    - 입력: workout dates + durations, minimumMinutes threshold (기본 20분)
  - **ExerciseFrequency**: `exerciseName, count, lastDate, percentage`
    - Service: 기간 내 운동별 빈도 집계 + 정렬
- **Verification**: Unit tests — 빈 배열, 단일 운동, 연속/비연속 streak, 0분 운동 필터

### Step 3: Shared 컴포넌트 이동 + 준비

- **Files**: `WellnessSectionGroup.swift` → `Shared/Components/SectionGroup.swift`, `TrainingReadiness+View.swift`
- **Changes**:
  - `WellnessSectionGroup`을 `SectionGroup`으로 rename + Shared로 이동
  - WellnessView의 참조 업데이트
  - `TrainingReadiness+View.swift`: `statusLabel`, `statusColor`, `statusIcon`, `guideMessage` computed properties
  - Correction #1/#20: Domain에 SwiftUI import 금지 — 표시 로직은 Extension으로
- **Verification**: Wellness 탭 기존 동작 유지 확인

### Step 4: Training Readiness Hero Card + Muscle Map 개편

- **Files**: `TrainingReadinessHeroCard.swift`, `MuscleRecoveryMapView.swift`, `ActivityViewModel.swift` (부분)
- **Changes**:
  - **Hero Card**: WellnessHeroCard 패턴 복제
    - ProgressRingView + score + statusLabel + guideMessage
    - Sub-indicators: HRV 변화, Sleep 상태, RHR 변화 (아이콘 + 색상)
    - NavigationLink → TrainingReadinessDetailView (Future — 지금은 기본 화면)
    - Empty state: "Start tracking to see readiness" + ring placeholder
  - **Muscle Map**: Front/Back 좌우 배치
    - `HStack` 내 두 개의 body diagram (각각 aspect ratio 유지)
    - `showingFront` @State 제거 — 항상 둘 다 표시
    - Suggestion section 코드 제거 (별도 섹션으로 이동)
    - SectionGroup 래핑
  - **ViewModel**: readiness 데이터 로딩 추가 (async let)
- **Verification**: Hero Card 렌더링, Muscle Map 양면 표시, 빈 상태

### Step 5: Weekly Stats + Suggested Workout + Training Volume 개선

- **Files**: `WeeklyStatsGrid.swift`, `SuggestedWorkoutSection.swift`, `TrainingVolumeSummaryCard.swift`, `ActivityViewModel.swift` (부분)
- **Changes**:
  - **Weekly Stats Grid**: 2열 LazyVGrid + VitalCard 재사용
    - 4개 카드: Total Volume (kg), Calories, Duration, Active Days
    - 각 카드: 값 + 변화율 + MiniSparklineView
    - VitalCardData 확장 또는 별도 ActivityCardData 모델
    - SectionGroup 래핑
  - **Suggested Workout**: MuscleRecoveryMapView에서 분리
    - StandardCard + 운동명 + 회복 근육 + "Start" 버튼
    - 추천 없으면 섹션 숨김
    - SectionGroup 래핑
  - **Training Volume**: period picker 추가 (1W/1M/3M Picker)
    - SectionGroup 래핑
  - **ViewModel**: 주간 통계 데이터 계산 추가
- **Verification**: 4개 카드 렌더링, sparkline, 빈 상태, period 전환

### Step 6: Recent Workouts + PR + Streak + Frequency

- **Files**: `ExerciseListSection.swift`, `PersonalRecordsSection.swift`, `ConsistencyCard.swift`, `ExerciseFrequencySection.swift`, `ActivityViewModel.swift` (부분)
- **Changes**:
  - **Recent Workouts**: SectionGroup 래핑 + 기존 UnifiedWorkoutRow 유지
  - **Personal Records**: 2열 LazyVGrid
    - 운동명 + 최고 중량 + 날짜 + 최근 갱신 badge
    - StandardCard 래핑
    - SectionGroup 래핑
  - **Streak**: InlineCard
    - 연속일 숫자 + "Best: N days" + 월간 progress bar
    - SectionGroup 래핑
  - **Exercise Frequency**: StandardCard
    - 운동별 횟수 bar chart 또는 리스트
    - SectionGroup 래핑
  - **ViewModel**: PR, Streak, Frequency 데이터 로딩 (TaskGroup에 추가)
- **Verification**: PR 표시, streak 계산, frequency 정렬, 빈 상태

### Step 7: ActivityView 레이아웃 재구성 + 탭 이름 변경 + 정리

- **Files**: `ActivityView.swift`, `ContentView.swift`, WeeklyProgressBar/SuggestedExerciseRow 삭제
- **Changes**:
  - **ActivityView**: 전체 레이아웃 순서 재배치
    ```
    ScrollView → VStack:
      1. TrainingReadinessHeroCard
      2. SectionGroup("Muscle Recovery") { MuscleRecoveryMapView }
      3. SectionGroup("Weekly Stats") { WeeklyStatsGrid }
      4. SectionGroup("Training Volume") { TrainingVolumeSummaryCard }
      5. SectionGroup("Suggested Workout") { SuggestedWorkoutSection }
      6. SectionGroup("Recent Workouts") { ExerciseListSection }
      7. SectionGroup("Personal Records") { PersonalRecordsSection }
      8. SectionGroup("Consistency") { ConsistencyCard }
      9. SectionGroup("Exercise Frequency") { ExerciseFrequencySection }
    ```
  - **ContentView**: 탭 라벨 "Train" → "Activity"
  - **삭제**: WeeklyProgressBar.swift (Hero로 대체), SuggestedExerciseRow.swift (통합됨)
  - NavigationDestination 업데이트
- **Verification**: 전체 레이아웃 렌더링, 빈 상태, iPad 반응형, 스크롤 성능

## Training Readiness Score — 계산식 상세

### 참조 플랫폼 분석

| 플랫폼 | HRV 비중 | 주요 특징 |
|--------|----------|----------|
| WHOOP | ~70% | 수면 중 HRV만 사용, 하루 1회 갱신 |
| Garmin | 6개 요소 균등 | 3일 수면 이력, 급성 훈련 부하 포함 |
| Oura | 7개 기여자 | 14일 가중 평균 vs 2개월 baseline |

### 우리 앱 계산식

```
readiness = (HRV_score * 0.30) + (RHR_score * 0.20) + (Sleep_score * 0.25)
          + (Fatigue_score * 0.15) + (Trend_bonus * 0.10)
```

**각 component 정규화** (개인 baseline 대비):
```
component_score = clamp(50 + (current - baseline_mean) / baseline_SD * 15, 0, 100)
```
- baseline: 60일 rolling mean/SD
- RHR, Fatigue: 부호 반전 (낮을수록 좋음)
- Cold start (< 14일): population reference 사용 + "Calibrating" badge

**Fatigue 집계**:
```
fatigue = weighted_avg(muscle_fatigues, weights: [24h: 1.0, 48h: 0.7, 72h: 0.4, older: 0.1])
fatigue_score = 100 - (fatigue * scale_factor)
```

**Status thresholds**:
| Range | Status | 색상 |
|-------|--------|------|
| 80-100 | Ready to Train | `DS.Color.scoreExcellent` |
| 60-79 | Moderate | `DS.Color.scoreGood` |
| 40-59 | Light Activity | `DS.Color.scoreFair` |
| 0-39 | Rest Day | `DS.Color.scoreWarning` |

## Edge Cases

| Case | Handling |
|------|----------|
| 첫 사용자 (데이터 0) | 모든 섹션 placeholder + "Start workout" CTA |
| HealthKit 권한 거부 | 가용 데이터만 표시, 없는 카드 숨김 |
| HRV 데이터 < 14일 | Population baseline + "Calibrating" badge |
| Streak 하루 놓침 | current=0 표시 + "Best streak: N days" 유지 |
| PR 없음 (근력 운동 미수행) | PR 섹션 숨김 |
| iPad 가로 모드 | 좌우 Muscle Map 더 크게, 4열 Stats Grid |
| 운동 시간 0분 | Streak 카운트에서 제외 (최소 시간 기준) |
| 극단적 HRV/RHR 값 | 범위 검증 (HRV 0-500ms, RHR 20-300bpm) — Correction #22 |

## Testing Strategy

- **Unit tests**:
  - `TrainingReadinessServiceTests`: 정상, 경계값, cold start, NaN 방어, component 가중치
  - `PersonalRecordServiceTests`: 빈 배열, 단일/복수 운동, 최고 중량 정확성
  - `WorkoutStreakServiceTests`: 연속/비연속, 최소 시간 필터, 월간 계산
  - `ExerciseFrequencyServiceTests`: 빈도 집계, 정렬, 기간 필터
- **Manual verification**:
  - Simulator에서 전체 레이아웃 스크롤
  - 빈 상태 → 데이터 있는 상태 전환
  - iPad 가로/세로 레이아웃
  - Dark mode 확인

## Risks

| Risk | Probability | Impact | Mitigation |
|------|-------------|--------|------------|
| 레이아웃 성능 (10개 섹션) | Medium | Medium | LazyVStack 검토, section별 visibility 제어 |
| HealthKit 쿼리 증가 (기존 6 → 10+) | Medium | Low | TaskGroup 유지, 실패 시 partial rendering |
| Muscle Map 좌우 배치 시 너무 작음 | Low | Medium | 최소 크기 제한, 탭 시 확대 검토 |
| Training Readiness baseline 부족 | High (초기) | Low | Population reference + calibrating badge |
| 대규모 변경 → merge conflict | Medium | Medium | Step별 커밋, main 수시 rebase |

## Confidence Assessment

- **Overall**: Medium
- **Reasoning**:
  - Wellness 탭의 검증된 패턴을 재사용하므로 UI/UX는 높은 확신
  - Training Readiness Score 계산은 리서치 기반이지만 실제 데이터 튜닝 필요 (추후 조정)
  - 10개 섹션 전체 한 번에 구현은 범위가 크지만, 각 단계가 독립적이라 위험 관리 가능
  - Muscle Map 좌우 배치의 실제 시각적 결과는 구현 후 확인 필요
