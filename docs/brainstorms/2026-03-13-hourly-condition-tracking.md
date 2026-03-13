---
tags: [condition, wellness, readiness, hourly, real-time, hero-card, sparkline, healthkit-observer]
date: 2026-03-13
category: brainstorm
status: draft
---

# Brainstorm: 시간별 컨디션 변화 추적 시스템

## Problem Statement

현재 3대 점수(Condition, Wellness, Readiness)는 앱 로드 시 1회 계산되며 일 단위로만 히스토리를 제공한다.
사용자는 하루 중 컨디션 변화를 체감하지만(수면 후 회복, 운동 후 하락 등) 앱은 이를 반영하지 못한다.

**목표**: 시간당 측정으로 3대 점수를 갱신하고, 히어로 카드와 상세 뷰에서 시간별 변화를 시각화한다.

## Target Users

- Apple Watch 착용자 (HRV/RHR 자동 수집)
- 하루 중 컨디션 변화를 추적하고 싶은 피트니스 사용자
- 운동 타이밍을 컨디션 기반으로 결정하려는 사용자

## Success Criteria

1. 새 HRV/RHR 샘플 도착 시 60초 이내 점수 갱신
2. 히어로 카드에서 직전 대비 델타와 오늘 추이 스파크라인 확인 가능
3. 상세 뷰에서 오늘 시간대별 점수 차트 확인 가능
4. 과거 일별 차트에서 특정 날짜 탭 시 해당 일의 시간별 차트로 드릴다운

## Current Architecture

### 점수 계산 파이프라인

```
HealthKit (HRV samples, RHR daily)
  → CalculateConditionScoreUseCase → ConditionScore (0-100)
  → CalculateWellnessScoreUseCase → WellnessScore (0-100)
  → CalculateTrainingReadinessUseCase → TrainingReadiness (0-100)
```

### 현재 제한사항

| 항목 | 현재 | 문제 |
|------|------|------|
| 갱신 시점 | `DashboardViewModel.loadData()` 1회 | 새 HRV 도착해도 반영 안 됨 |
| 데이터 해상도 | 일별 HRV 평균 | 시간대별 변동 소실 |
| 히스토리 저장 | 없음 (매번 재계산) | 시간별 히스토리 재계산 비용 큼 |
| 히어로 카드 | 각 탭 상단에 해당 히어로 카드 1개씩 | 시간별 변화(델타/스파크라인) 미표시 |
| Time-of-Day 보정 | 계산 시점 시각 기준 ±6pt | 과거 시간대 재계산 시 보정 불일치 |

## Proposed Approach

### A. 데이터 레이어: 시간별 점수 스냅샷

#### A1. HourlyScoreSnapshot 모델

```swift
/// 시간별 점수 스냅샷 (SwiftData 저장)
@Model
final class HourlyScoreSnapshot {
    var date: Date           // 시간 단위 truncated (e.g. 2026-03-13T14:00:00)
    var conditionScore: Double?
    var wellnessScore: Double?
    var readinessScore: Double?

    // 계산 입력값 (디버깅/재계산 용)
    var hrvValue: Double?
    var rhrValue: Double?
    var sleepScore: Double?

    var createdAt: Date
}
```

**설계 결정**: 재계산 vs 저장
- 일별 점수는 현행 유지 (재계산) — HealthKit 원본이 수정될 수 있음
- 시간별 점수는 **저장** — 과거 시간대의 HRV 샘플을 시간대별로 분리 재계산하는 것은 비용 과다
- CloudKit 동기화 포함 → 다른 기기에서도 시간별 히스토리 조회 가능

#### A2. 점수 계산 어댑터

현재 UseCase는 "오늘의 점수"를 계산한다. 시간별 점수를 위해:

- **ConditionScore**: 기존 baseline(14일) 대비 **최근 N시간 HRV 평균**으로 z-score 계산
  - 시간별 윈도우: 최근 3시간 HRV 샘플 평균 (샘플 수 부족 시 6시간까지 확대)
  - Time-of-Day 보정: 해당 시간대 기준 적용
- **WellnessScore**: Condition 변화 즉시 반영 + Sleep/Body는 최신 일별 값 유지
- **TrainingReadiness**: Condition 변화 반영 + MuscleFatigue는 최신 운동 기록 기준 유지

### B. 갱신 트리거: HealthKit Observer + Foreground Refresh

#### B1. HealthKit Observer Query

```
앱 설치 시 등록:
  - HKObserverQuery(HRV) → 새 샘플 도착 시 알림
  - HKObserverQuery(RHR) → 새 샘플 도착 시 알림
  - HKObserverQuery(SleepAnalysis) → 수면 데이터 변경 시 알림

알림 수신 → ScoreRefreshService.refresh()
  → 최신 HRV/RHR 가져오기
  → 3대 점수 재계산
  → HourlyScoreSnapshot 저장 (같은 시간대면 upsert)
  → DashboardViewModel에 통지 (@Published 업데이트)
  → Widget 데이터 갱신
```

#### B2. Foreground Refresh

```
ScenePhase .active 진입 시:
  - lastRefreshDate 확인 (기존 30분 throttle)
  - 경과 시 ScoreRefreshService.refresh() 실행
```

#### B3. Throttle 정책

| 트리거 | 최소 간격 | 근거 |
|--------|----------|------|
| Observer HRV | 5분 | Watch가 짧은 간격으로 여러 샘플 기록할 수 있음 |
| Observer RHR | 30분 | RHR은 일 1회 수준 |
| Observer Sleep | 30분 | 수면 중 단계별 누적 기록 |
| Foreground | 30분 | 기존 정책 유지 |

### C. 히어로 카드: 각 탭 상단 히어로에 시간별 변화 추가

#### C1. 탭별 히어로 카드 매핑

| 탭 | 뷰 | 히어로 카드 | 표시 점수 |
|---|---|---|---|
| Today | DashboardView | ConditionHeroCard | Condition |
| Train | ActivityView | ReadinessHeroCard | Training Readiness |
| Wellness | WellnessView | WellnessHeroCard | Wellness |

각 탭 상단의 기존 히어로 카드에 **델타 배지 + 스파크라인**을 추가하는 방식.
새 카드를 만드는 것이 아니라 기존 카드를 확장한다.

#### C2. 히어로 카드 확장 요소

```
┌─────────────────────────────┐
│  점수 링     ▲3              │  ← 델타 배지 추가
│   72                         │
│  Good    ▁▂▃▅▇▅▃▂▃▅        │  ← 스파크라인 추가
│  [기존 서브 정보 유지]        │
└─────────────────────────────┘
```

추가 요소:
- **델타 배지**: 직전 스냅샷 대비 변화량 (▲/▼/━ + 색상)
- **스파크라인**: 오늘 시간별 점수 추이 (Swift Charts AreaMark, 최대 24개 포인트)
- 기존 점수 링, 상태 텍스트, 내러티브 등은 유지
- 탭 → 각 점수 상세 뷰 (기존 NavigationLink 유지)

#### C2. 스파크라인 데이터

```swift
/// 히어로 카드용 경량 데이터
struct HourlySparklineData {
    let points: [(hour: Int, score: Double)]  // 0시~현재시
    let currentScore: Double
    let delta: Double          // 직전 스냅샷 대비
    let deltaDirection: DeltaDirection  // up, down, stable
}

enum DeltaDirection {
    case up, down, stable  // |delta| < 2 → stable
}
```

#### C3. 델타 계산 기준

- **직전 스냅샷**: 현재 시간 - 1시간의 스냅샷
- **스냅샷 없으면**: 가장 최근 스냅샷과 비교
- **오늘 첫 스냅샷**: 어제 마지막 스냅샷과 비교
- **데이터 없으면**: 델타 숨김

### D. 상세 뷰 변경

#### D1. Today 탭 추가

기존 Period Picker에 "Today" 옵션 추가:

```
[Today] [Week] [Month] [3M] [6M] [Year]
```

Today 선택 시:
- X축: 0시~현재시 (시간 단위)
- Y축: 점수 (0-100)
- 데이터: `HourlyScoreSnapshot` 쿼리
- 차트 타입: AreaMark + LineMark (기존 DotLineChart 패턴)
- 빈 시간대: 보간선으로 연결 (점선)

#### D2. 일별 → 시간별 드릴다운

기존 Week/Month 등 차트에서:
- 데이터 포인트 탭 (long press selection) → 해당 날짜의 시간별 차트로 전환
- 뒤로가기로 원래 기간 차트로 복귀
- 구현: `@State selectedDrilldownDate: Date?` → Today와 동일한 시간별 차트 렌더링

#### D3. 상세 뷰 공통화

Condition/Wellness/Readiness 3개 상세 뷰가 시간별 차트를 공유하므로:
- `HourlyScoreChartView` 공통 컴포넌트 추출
- `ScoreType` enum으로 어떤 점수를 표시할지 파라미터화

### E. 위젯 연동

- 시간별 갱신 시 `WidgetDataWriter` 호출
- Widget Timeline: 1시간 간격 갱신 정책
- 위젯에도 미니 스파크라인 표시 가능 (향후)

## Constraints

### 기술적

- **HealthKit Observer Query**: 백그라운드 알림은 iOS가 batching할 수 있어 정확히 1시간 간격 보장 불가
- **Apple Watch HRV 측정 주기**: 사용자가 착용 중일 때만, 보통 수면 중 + 간헐적 주간 측정
- **SwiftData + CloudKit**: `HourlyScoreSnapshot`은 CloudKit 동기화 대상 → Optional relationship 규칙 준수
- **배터리**: Observer Query 자체는 경량이나 잦은 HealthKit 쿼리 + 점수 계산은 주의

### 데이터 가용성

- Watch 미착용 시간대: HRV 샘플 없음 → 스냅샷 생성 불가 → 스파크라인에 gap
- RHR: Apple이 일 1회만 계산 → 시간별 변동 반영 어려움 (조정: RHR은 일별 값 유지)
- Sleep: 수면 종료 후 1회 반영 → 시간별보다는 이벤트 기반

### 성능

- 60일 HRV 재로드 없이 incremental 계산 필요 → baseline 캐싱
- 스파크라인: 최대 24개 포인트 → 렌더링 부담 없음
- SwiftData 쿼리: 시간별 스냅샷은 `@Query` predicate로 당일만 필터

## Edge Cases

| 케이스 | 대응 |
|--------|------|
| Watch 미착용 (HRV 없음) | 마지막 유효 스냅샷 유지 + "최근 측정: N시간 전" 표시 |
| 오늘 스냅샷 0개 (새벽 앱 첫 실행) | 즉시 계산하여 첫 스냅샷 생성 |
| baseline 부족 (7일 미만) | 기존 동작 유지: "데이터 수집 중" 표시 |
| 시간대 변경 (여행) | `Date`는 UTC 저장, 표시는 로컬 시간 |
| 24시간 넘는 스냅샷 (어제~오늘) | Today 뷰는 calendar day 0시 기준 필터 |
| 동일 시간대 중복 스냅샷 | upsert: 같은 시간대면 최신으로 덮어쓰기 |
| 점수 급변 (수동 HRV 입력 등) | 이상치 필터링은 기존 범위 검증(0-500ms)으로 충분 |

## Scope

### MVP (Must-have)

- [ ] `HourlyScoreSnapshot` SwiftData 모델 + VersionedSchema
- [ ] `ScoreRefreshService`: Observer Query 등록 + throttled 갱신 + 스냅샷 저장
- [ ] Condition/Wellness/Readiness UseCase에 "시간별 윈도우" 계산 모드 추가
- [ ] 각 탭 히어로 카드에 델타 배지 + 스파크라인 추가 (기존 카드 확장)
- [ ] 상세 뷰 "Today" 탭 (시간별 차트)
- [ ] Foreground refresh + HealthKit Observer 통합
- [ ] 기존 일별 차트에서 드릴다운 → 시간별 차트

### Nice-to-have (Future)

- [ ] watchOS 컴플리케이션에 시간별 점수 표시
- [ ] Widget 스파크라인
- [ ] BGTaskScheduler 백그라운드 갱신
- [ ] Push 알림: 컨디션 급변 시 ("컨디션이 Tired로 떨어졌습니다")
- [ ] 시간별 점수와 운동/수면 이벤트 오버레이 (상관관계 시각화)
- [ ] visionOS 히어로 카드 적용

## Resolved Questions

1. **RHR 시간별 반영** → 구현 시 최적화 판단에 위임. RHR은 일 1회이므로 일별 값 유지하되, 가능하면 최신 heart rate 샘플을 보조 지표로 활용
2. **스냅샷 보존 기간** → **영구 보관**. 연 ~9K 레코드 ≈ 0.9MB로 CloudKit 부담 미미
3. **히어로 카드 순서** → 해당 없음. 각 탭(Today/Train/Wellness) 상단에 해당 점수 히어로 카드가 1개씩 배치되는 구조
4. **Wellness 시간별 의미** → **의미 있음**. Sleep/Body가 일단위여도 Condition 변화분이 Wellness에 반영되어 사용자가 종합 추이를 파악할 수 있음

## Architecture Impact

### 새로 추가되는 파일 (예상)

| 레이어 | 파일 | 역할 |
|--------|------|------|
| Domain/Models | `HourlyScoreSnapshot.swift` | 시간별 스냅샷 모델 |
| Domain/Models | `HourlySparklineData.swift` | 히어로 카드용 경량 데이터 |
| Domain/UseCases | `RefreshHourlyScoresUseCase.swift` | 시간별 점수 계산 오케스트레이터 |
| Data/Services | `ScoreRefreshService.swift` | Observer + throttle + 스냅샷 저장 |
| Presentation/Shared | `ScoreDeltaBadge.swift` | 델타 배지 공통 컴포넌트 |
| Presentation/Shared | `HourlyScoreChartView.swift` | 시간별 차트 공통 뷰 |
| Presentation/Shared | `SparklineView.swift` | 미니 스파크라인 컴포넌트 |

### 변경되는 파일 (예상)

| 파일 | 변경 |
|------|------|
| `DashboardViewModel.swift` | ScoreRefreshService 구독, 스파크라인 데이터 제공 |
| `DashboardView.swift` | ConditionHeroCard에 델타+스파크라인 추가 |
| `ConditionScoreDetailView.swift` | Today 탭 + 드릴다운 추가 |
| `ConditionScoreDetailViewModel.swift` | 시간별 스냅샷 쿼리 + Today 모드 |
| `WellnessDetailView/ViewModel` | 동일 Today 탭 + 드릴다운 |
| `ReadinessDetailView/ViewModel` | 동일 Today 탭 + 드릴다운 |
| `CalculateConditionScoreUseCase.swift` | 시간별 윈도우 모드 파라미터 |
| `VersionedSchema` | HourlyScoreSnapshot 추가 |
| `WidgetDataWriter.swift` | 시간별 갱신 시 Widget 업데이트 |

## Next Steps

- [ ] `/plan hourly-condition-tracking` 으로 구현 계획 생성
- [ ] VersionedSchema 마이그레이션 전략 확정
