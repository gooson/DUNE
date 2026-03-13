---
topic: hourly-condition-tracking
date: 2026-03-13
status: draft
confidence: high
related_solutions:
  - docs/solutions/general/2026-03-12-condition-score-rhr-baseline-and-chart-scroll.md
related_brainstorms:
  - docs/brainstorms/2026-03-13-hourly-condition-tracking.md
---

# Implementation Plan: 시간별 컨디션 변화 추적 시스템

## Context

현재 3대 점수(Condition, Wellness, Readiness)는 앱 로드 시 1회 계산되며 일 단위로만 히스토리를 제공한다. 사용자가 하루 중 체감하는 컨디션 변화(수면 후 회복, 운동 후 하락)를 앱이 반영하지 못한다.

**목표**: HealthKit Observer Query로 새 HRV/RHR 샘플 도착 시 점수를 자동 갱신하고, 시간별 스냅샷을 영구 저장하며, 각 탭 히어로 카드에 델타 배지+스파크라인을 추가하고, 상세 뷰에서 시간별 차트와 드릴다운을 제공한다.

## Requirements

### Functional

1. 새 HRV/RHR/Sleep 샘플 도착 시 3대 점수 자동 재계산 (throttled)
2. 시간 단위 점수 스냅샷 영구 저장 (SwiftData + CloudKit)
3. 각 탭 히어로 카드에 직전 대비 델타 배지 + 오늘 시간별 스파크라인 추가
4. 상세 뷰 "Today" 탭에서 시간별 점수 차트 표시
5. 일별 차트에서 특정 날짜 탭 시 해당 일의 시간별 드릴다운

### Non-functional

- 스냅샷: 영구 보관 (연 ~0.9MB)
- Observer 알림 → 점수 갱신 60초 이내
- throttle: HRV 5분, RHR/Sleep/Foreground 30분
- 배터리 영향 최소화 (HealthKit Observer 자체는 경량)

## Approach

**핵심 발견**: `TimePeriod.day`가 이미 존재하며 hourly aggregation 지원. `ConditionHeroView`에 이미 7일 스파크라인이 있음. 기존 구조를 최대한 확장하는 방식으로 진행.

1. `HourlyScoreSnapshot` SwiftData 모델 추가 (AppSchemaV15)
2. `ScoreRefreshService` 생성 — HealthKit Observer + throttle + 점수 계산 + 스냅샷 저장
3. 각 탭 ViewModel이 `ScoreRefreshService`를 구독하여 실시간 점수 갱신
4. 히어로 카드에 델타 배지 + 시간별 스파크라인 추가 (기존 recentScores 스파크라인과 병행)
5. 상세 뷰에서 `TimePeriod.day` 선택 시 `HourlyScoreSnapshot` 기반 차트 렌더링

### Alternative Approaches Considered

| Approach | Pros | Cons | Decision |
|----------|------|------|----------|
| 스냅샷 저장 없이 매번 재계산 | 저장 불필요 | 시간별 HRV 분리 재계산 비용 과다, 과거 데이터 불가 | **거부** |
| BackgroundTask 주기적 갱신 | Watch 미착용 시에도 갱신 시도 | iOS가 빈도 보장 안 함, 배터리 소모 | **Future** |
| HealthKit Observer (현재 선택) | 실제 데이터 도착 시만 갱신, 경량 | Watch 미착용 시 갱신 없음 (의도된 동작) | **채택** |

## Affected Files

| File | Change Type | Description |
|------|-------------|-------------|
| `Domain/Models/HourlyScoreSnapshot.swift` | **NEW** | 시간별 스냅샷 SwiftData 모델 |
| `Domain/Models/HourlySparklineData.swift` | **NEW** | 히어로 카드용 경량 스파크라인 데이터 |
| `Data/Services/ScoreRefreshService.swift` | **NEW** | Observer Query + throttle + 점수 갱신 서비스 |
| `Data/Persistence/Migration/AppSchemaVersions.swift` | MODIFY | V15 추가 (HourlyScoreSnapshot) |
| `Presentation/Shared/Components/ScoreDeltaBadge.swift` | **NEW** | 델타 배지 컴포넌트 |
| `Presentation/Shared/Components/HourlySparklineView.swift` | **NEW** | 시간별 스파크라인 컴포넌트 |
| `Presentation/Dashboard/DashboardViewModel.swift` | MODIFY | ScoreRefreshService 구독, 스파크라인 데이터 |
| `Presentation/Dashboard/Components/ConditionHeroView.swift` | MODIFY | 델타 배지 + 시간별 스파크라인 추가 |
| `Presentation/Dashboard/ConditionScoreDetailViewModel.swift` | MODIFY | day 기간 시 스냅샷 쿼리, 드릴다운 |
| `Presentation/Dashboard/ConditionScoreDetailView.swift` | MODIFY | 드릴다운 UI |
| `Presentation/Activity/ActivityViewModel.swift` | MODIFY | ScoreRefreshService 구독 |
| `Presentation/Activity/Components/TrainingReadinessHeroCard.swift` | MODIFY | 델타 + 스파크라인 |
| `Presentation/Wellness/WellnessViewModel.swift` | MODIFY | ScoreRefreshService 구독 |
| `Presentation/Wellness/Components/WellnessHeroCard.swift` | MODIFY | 델타 + 스파크라인 |
| `App/DUNEApp.swift` | MODIFY | ScoreRefreshService 초기화 + Observer 등록 |
| `Data/Services/WidgetDataWriter.swift` | MODIFY | 시간별 갱신 시 Widget 업데이트 |
| `Tests/ScoreRefreshServiceTests.swift` | **NEW** | throttle, 스냅샷 저장 테스트 |
| `Tests/HourlyScoreSnapshotTests.swift` | **NEW** | 모델 테스트 |

## Implementation Steps

### Step 1: HourlyScoreSnapshot 모델 + Schema V15

- **Files**: `Domain/Models/HourlyScoreSnapshot.swift`, `Data/Persistence/Migration/AppSchemaVersions.swift`
- **Changes**:
  - `HourlyScoreSnapshot` @Model: `date` (hour-truncated), `conditionScore`, `wellnessScore`, `readinessScore`, `hrvValue`, `rhrValue`, `sleepScore`, `createdAt` (모두 Optional, CloudKit 호환)
  - `AppSchemaV15` 추가, models에 `HourlyScoreSnapshot` 포함
  - `MigrationPlan`에 lightweight migration stage 추가
- **Verification**: 빌드 성공, 앱 삭제→설치→실행→종료→재실행 crash 없음

### Step 2: HourlySparklineData 도메인 모델

- **Files**: `Domain/Models/HourlySparklineData.swift`
- **Changes**:
  ```swift
  struct HourlySparklineData: Sendable {
      let points: [(hour: Int, score: Double)]
      let currentScore: Double
      let delta: Double
      let deltaDirection: DeltaDirection
  }
  enum DeltaDirection: Sendable { case up, down, stable }
  ```
- **Verification**: 빌드 성공

### Step 3: ScoreRefreshService

- **Files**: `Data/Services/ScoreRefreshService.swift`
- **Changes**:
  - `@MainActor @Observable class ScoreRefreshService`
  - HealthKit Observer Query 등록: HRV, RHR, SleepAnalysis
  - Throttle 정책: HRV 5분, RHR 30분, Sleep 30분
  - `refresh()` → 3대 점수 계산 → HourlyScoreSnapshot upsert → @Published 상태 갱신
  - `conditionScore`, `wellnessScore`, `readinessScore` Published 프로퍼티
  - `todaySparkline(for: ScoreType)` → HourlySparklineData
  - Widget 갱신 호출
- **Verification**: 빌드 성공, 유닛 테스트 (throttle 로직, upsert 로직)

### Step 4: ScoreDeltaBadge 공통 컴포넌트

- **Files**: `Presentation/Shared/Components/ScoreDeltaBadge.swift`
- **Changes**:
  - `ScoreDeltaBadge(delta: Double, direction: DeltaDirection)`
  - ▲/▼/━ + 색상 (green/red/gray), |delta| < 2 → stable
  - 콤팩트 디자인 (기존 `BaselineTrendBadge` 참고)
- **Verification**: Preview 확인

### Step 5: HourlySparklineView 공통 컴포넌트

- **Files**: `Presentation/Shared/Components/HourlySparklineView.swift`
- **Changes**:
  - Swift Charts `AreaMark` + `LineMark`, 최대 24 포인트
  - `.frame(height: 32)` 콤팩트 크기
  - 빈 구간: 점선 보간
- **Verification**: Preview 확인

### Step 6: 히어로 카드 확장 (Condition)

- **Files**: `Presentation/Dashboard/Components/ConditionHeroView.swift`, `DashboardViewModel.swift`
- **Changes**:
  - `DashboardViewModel`: `ScoreRefreshService` 구독, `conditionSparkline: HourlySparklineData?` 프로퍼티
  - `ConditionHeroView`: 점수 링 옆에 `ScoreDeltaBadge` + `HourlySparklineView` 추가
  - 기존 7일 recentScores 스파크라인과 함께 표시 (또는 교체)
- **Verification**: 빌드 성공, UI 확인

### Step 7: 히어로 카드 확장 (Readiness + Wellness)

- **Files**: `TrainingReadinessHeroCard.swift`, `ActivityViewModel.swift`, `WellnessHeroCard.swift`, `WellnessViewModel.swift`
- **Changes**:
  - 동일 패턴: ViewModel에서 ScoreRefreshService 구독, 히어로 카드에 델타+스파크라인 추가
- **Verification**: 빌드 성공, 3개 탭 모두 확인

### Step 8: 상세 뷰 시간별 차트 (Today/Day 기간)

- **Files**: `ConditionScoreDetailViewModel.swift`, `ConditionScoreDetailView.swift`
- **Changes**:
  - `TimePeriod.day` 선택 시: `HourlyScoreSnapshot` 쿼리로 차트 데이터 생성
  - 기존 `computeDailyScores()` 대신 `loadHourlySnapshots(for date:)` 호출
  - 일별 차트에서 날짜 탭 시 `drilldownDate: Date?` → 해당 일의 시간별 차트로 전환
- **Verification**: Day 기간 선택 시 시간별 차트 표시, 드릴다운 동작

### Step 9: 앱 초기화 + Observer 등록

- **Files**: `App/DUNEApp.swift`, `App/ContentView.swift`
- **Changes**:
  - `DUNEApp`에서 `ScoreRefreshService` 초기화, `.environment()`로 주입
  - `ContentView`의 scenePhase .active 핸들러에서 `scoreRefreshService.refreshIfNeeded()` 호출
  - Observer Query는 앱 시작 시 1회 등록
- **Verification**: 앱 시작 시 Observer 등록 로그, foreground 복귀 시 갱신

### Step 10: 테스트 작성

- **Files**: `Tests/ScoreRefreshServiceTests.swift`, `Tests/HourlyScoreSnapshotTests.swift`
- **Changes**:
  - ScoreRefreshService: throttle 정책 테스트 (5분 이내 중복 호출 무시)
  - HourlyScoreSnapshot: upsert 로직 (같은 시간대 덮어쓰기)
  - HourlySparklineData: 델타 계산 (직전 대비, 오늘 첫 vs 어제 마지막)
- **Verification**: 테스트 전체 통과

## Edge Cases

| Case | Handling |
|------|----------|
| Watch 미착용 (HRV 없음) | Observer 트리거 안 됨 → 마지막 스냅샷 유지, 스파크라인 gap |
| 오늘 스냅샷 0개 | 앱 진입 시 즉시 계산하여 첫 스냅샷 생성 |
| baseline 부족 (7일 미만) | 기존 동작 유지: "데이터 수집 중" |
| 시간대 변경 (여행) | Date UTC 저장, 표시는 로컬 |
| 동일 시간대 중복 | upsert: 같은 시간대면 최신으로 |
| RHR 일 1회 | 일별 값 유지, 시간별 점수에서는 가장 최근 RHR 사용 |
| Sleep 수면 종료 후 1회 | Observer 트리거 시 Wellness 점수만 갱신 |

## Testing Strategy

- **Unit tests**:
  - ScoreRefreshService throttle 정책
  - HourlyScoreSnapshot upsert 로직
  - HourlySparklineData 델타 계산
  - DeltaDirection 판정 (|delta| < 2 → stable)
- **Manual verification**:
  - 시뮬레이터에서 앱 실행 → 히어로 카드 델타/스파크라인 표시 확인
  - Day 기간 선택 시 시간별 차트 렌더링
  - 일별 차트에서 날짜 탭 → 드릴다운 동작

## Risks

| Risk | Probability | Impact | Mitigation |
|------|-------------|--------|------------|
| Schema V15 migration 실패 | Low | High | Lightweight migration only, 앱 삭제→재설치 테스트 |
| Observer Query 배터리 소모 | Low | Medium | Throttle 정책으로 방어, Observer 자체는 경량 |
| 스파크라인 데이터 없을 때 UI crash | Low | High | nil-safe 렌더링, placeholder 처리 |
| CloudKit 동기화 충돌 | Low | Medium | upsert by hour-truncated date, conflict resolution |

## Confidence Assessment

- **Overall**: High
- **Reasoning**: 기존 `TimePeriod.day`가 hourly aggregation을 지원하고, 히어로 카드에 이미 스파크라인이 있어 확장 패턴이 명확. SwiftData 모델 추가와 Observer Query 등록은 검증된 패턴. 주요 위험은 Schema migration뿐이며 lightweight migration으로 충분.
