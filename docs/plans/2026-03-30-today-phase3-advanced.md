---
tags: [dashboard, today, phase3, time-aware, stress-score, daily-digest, notification]
date: 2026-03-30
category: plan
status: draft
---

# Today Tab Phase 3: Advanced Features

## Overview

Phase 2 완료 후, Today 탭을 시간 인지형 + AI 기반 코칭 허브로 진화시킨다.
3개 기능을 구현한다:

1. **Time-Aware Dashboard** — 시간대별 섹션 우선순위 자동 재배치
2. **Cumulative Stress Score** — 30일 윈도우 장기 스트레스 종합 지표
3. **AI Daily Digest** — 하루 끝 자동 1-paragraph 요약 + 푸시 알림

## Affected Files

| File | Change Type | Description |
|------|------------|-------------|
| `Domain/UseCases/CalculateCumulativeStressUseCase.swift` | **New** | 30일 스트레스 점수 계산 |
| `Domain/Models/CumulativeStressScore.swift` | **New** | 스트레스 점수 모델 |
| `Domain/UseCases/GenerateDailyDigestUseCase.swift` | **New** | AI 일일 요약 생성 |
| `Domain/Models/DailyDigest.swift` | **New** | 일일 요약 모델 |
| `Domain/Models/HealthInsight.swift` | Modify | `dailyDigest` InsightType 추가 |
| `Data/Services/DailyDigestScheduler.swift` | **New** | 저녁 요약 알림 스케줄링 |
| `Presentation/Dashboard/DashboardViewModel.swift` | Modify | 시간대 섹션 순서 + 스트레스 점수 + 다이제스트 통합 |
| `Presentation/Dashboard/DashboardView.swift` | Modify | 시간대별 섹션 재배치 적용 |
| `Presentation/Dashboard/Components/CumulativeStressCard.swift` | **New** | 스트레스 점수 카드 UI |
| `Presentation/Dashboard/Components/DailyDigestCard.swift` | **New** | 일일 요약 카드 UI |
| `Presentation/Shared/Extensions/CumulativeStressScore+View.swift` | **New** | 스트레스 레벨 → 색상/아이콘 매핑 |
| `App/DUNEApp.swift` | Modify | DailyDigestScheduler 초기화 |
| `Shared/Resources/Localizable.xcstrings` | Modify | en/ko/ja 번역 추가 |
| `DUNETests/CalculateCumulativeStressUseCaseTests.swift` | **New** | 스트레스 점수 테스트 |
| `DUNETests/GenerateDailyDigestUseCaseTests.swift` | **New** | 일일 요약 테스트 |

## Implementation Steps

### Step 1: Cumulative Stress Score — Domain Model + UseCase

**목표**: 30일 윈도우에서 HRV 변동성 + 수면 일관성 + 활동 부하를 종합한 장기 스트레스 지표

**Domain Model** (`CumulativeStressScore.swift`):
```swift
struct CumulativeStressScore: Sendable, Identifiable {
    let id = UUID()
    let score: Int                      // 0-100 (0=최소 스트레스, 100=최고 스트레스)
    let level: Level                    // low/moderate/elevated/high
    let contributions: [Contribution]   // 각 요인별 기여도
    let trend: TrendDirection           // improving/stable/worsening
    let date: Date
    let windowDays: Int                 // 30

    enum Level: String, Sendable, CaseIterable {
        case low, moderate, elevated, high
    }

    struct Contribution: Sendable, Identifiable {
        let id = UUID()
        let factor: Factor
        let value: Double  // 0-100 (해당 요인의 원시 점수)
        let weight: Double // 가중치
        let detail: String

        enum Factor: String, Sendable {
            case hrvVariability   // HRV coefficient of variation
            case sleepConsistency // Sleep regularity index 역전
            case activityLoad    // Training load ratio
        }
    }
}
```

**UseCase** (`CalculateCumulativeStressUseCase.swift`):
- Input: `hrvSamples: [HRVSample]` (30일), `sleepRegularity: SleepRegularityIndex?`, `trainingVolumes: [TrainingVolume]` (30일)
- 가중치: HRV 변동성 0.40, 수면 비일관성 0.35, 활동 과부하 0.25
- HRV 변동성 = CV(coefficient of variation) of daily averages → 높을수록 스트레스
- 수면 비일관성 = 100 - sleepRegularity.score → 높을수록 스트레스
- 활동 과부하 = acute:chronic ratio > 1.3 부분 → 초과분 정규화
- 최소 7일 데이터 필요 (미만이면 nil 반환)
- Trend: 최근 7일 평균 vs 이전 7일 평균 비교

**테스트**:
- 데이터 부족 (< 7일) → nil
- 모든 값 정상 → low score
- HRV 변동 큰 + 불규칙 수면 + 과부하 → high score
- 경계값: 정확히 7일 데이터

### Step 2: Cumulative Stress Score — Presentation

**CumulativeStressCard.swift**:
```
┌─ 📊 장기 스트레스 ──────────────────┐
│                                     │
│  ████████████████░░░░  68  보통     │  ← 게이지 + 점수 + 레벨
│                                     │
│  📈 지난주 대비 악화 추세            │  ← 트렌드
│                                     │
│  주요 요인:                          │
│  · HRV 변동성 높음 (CV 0.23)        │  ← 상위 기여 요인
│  · 수면 시간 불규칙                  │
│                                     │
│               자세히 보기 ›           │
└─────────────────────────────────────┘
```

- `InlineCard` 래퍼 사용
- 레벨별 색상: low=green, moderate=yellow, elevated=orange, high=red
- 기여 요인은 weight 순 상위 2개 표시
- 접근성: `"dashboard-stress-score"` identifier

**CumulativeStressScore+View.swift**:
- `displayName: String` (String(localized:))
- `color: Color` (DS 토큰 매핑)
- `iconName: String` (SF Symbol)

**DashboardView 배치**: RecoverySleepCard 이후, ExerciseIntelligenceCard 이전 (Zone B)

### Step 3: Time-Aware Dashboard — Section Reordering

**목표**: 시간대에 따라 Dashboard 섹션 우선순위를 동적으로 변경

**시간대 정의** (DashboardViewModel):
```swift
enum DashboardTimeBand: Sendable {
    case morning    // 06-10
    case daytime    // 10-17
    case evening    // 17-22
    case night      // 22-06
}
```

**섹션 우선순위 매트릭스**:

| 섹션 | Morning | Daytime | Evening | Night |
|------|---------|---------|---------|-------|
| Hero | 항상 1위 | 항상 1위 | 항상 1위 | 항상 1위 |
| Yesterday Recap | 2위 (표시) | 숨김 | 숨김 | 숨김 |
| Quick Actions | 3위 | 2위 | 2위 | 숨김 |
| Progress Rings | 4위 | 3위 | 2위 | 숨김 |
| Today's Brief | 5위 | 4위 | 숨김 | 숨김 |
| Recovery & Sleep | 6위 | 5위 | 3위 (강조) | 2위 (강조) |
| Stress Score | 7위 | 6위 | 4위 | 3위 |
| Exercise Intelligence | 8위 | 7위 | 숨김 | 숨김 |
| Smart Insights | 9위 | 8위 | 5위 | 4위 |
| Daily Digest | 숨김 | 숨김 | 6위 (표시) | 5위 |
| Health Q&A | 10위 | 9위 | 7위 | 6위 |

**구현 방식**:
- DashboardViewModel에 `currentTimeBand: DashboardTimeBand` computed property 추가
- `buildTimeBand(from hour: Int) -> DashboardTimeBand` 정적 메서드
- `shouldShowSection(_: DashboardSection) -> Bool` 메서드
- `sectionOrder: [DashboardSection]` computed property → 현재 시간대 기준 정렬된 섹션 목록

**DashboardView에서 적용**:
- `dashboardUpperContent`를 `ForEach(viewModel.sectionOrder)` 기반으로 리팩터 → 각 섹션을 `@ViewBuilder` 함수로 추출하여 동적 순서로 렌더
- 단, SwiftUI ForEach with enum은 성능 영향 최소화를 위해 `id: \.self` 대신 `rawValue` 사용

**주의**: 실제 View 렌더링에서 ForEach를 쓸지 vs if-else 시퀀스를 시간대별로 분기할지는 구현 시 판단. ForEach가 type-checker 부하를 줄일 수 있음.

### Step 4: AI Daily Digest — Domain + Data

**목표**: 하루 끝에 AI가 자동 생성하는 1-paragraph 요약

**Domain Model** (`DailyDigest.swift`):
```swift
struct DailyDigest: Sendable, Identifiable {
    let id = UUID()
    let summary: String           // AI 생성 1-paragraph
    let date: Date
    let metrics: DigestMetrics

    struct DigestMetrics: Sendable {
        let conditionScore: Int?
        let conditionDelta: Int?      // vs yesterday
        let workoutSummary: String?   // "상체 운동 45분" 등
        let sleepMinutes: Double?
        let sleepDebtMinutes: Double?
        let stepsCount: Int?
        let stressLevel: CumulativeStressScore.Level?
    }
}
```

**UseCase** (`GenerateDailyDigestUseCase.swift`):
- Input: `DigestMetrics` (위 구조)
- FoundationModelReportFormatter 패턴 참조하여 자체 프롬프트 구성
- 기기에서 Foundation Models 사용 불가 시 템플릿 기반 fallback
- fallback 템플릿: "오늘은 컨디션 {score}로 시작하여, {workout}을 완료했습니다. 수면 {sleep}시간, 걸음 {steps}보. {advice}"
- Locale 지원: ko/ja/en

**DailyDigestScheduler** (`Data/Services/DailyDigestScheduler.swift`):
- `BedtimeWatchReminderScheduler` 패턴 따름
- 매일 21시에 `UNCalendarNotificationTrigger` 스케줄
- identifier: `"com.dune.dailyDigest"`
- `refreshSchedule(force:)` + `cancelSchedule()`
- 스케줄 시점에 `GenerateDailyDigestUseCase` 호출하여 요약 생성
- `NotificationInboxManager`에 아카이브
- `HealthInsight.InsightType.dailyDigest` 추가 필요

### Step 5: AI Daily Digest — Presentation

**DailyDigestCard.swift**:
```
┌─ 📝 오늘의 요약 ───────────────────┐
│                                     │
│  오늘은 컨디션 85로 시작해서 오전에   │
│  상체 운동 45분을 완료했어요. HRV가   │
│  운동 후 15% 떨어졌지만 오후에 빠르게 │
│  회복되었습니다. 수면 부채가 1시간     │
│  남아있으니 11시 전 취침을 추천합니다. │
│                                     │
└─────────────────────────────────────┘
```

- **저녁(17-22)과 밤(22-06)에만 표시** (Time-Aware Dashboard의 sectionOrder가 제어)
- 요약이 아직 생성되지 않았으면 카드 숨김
- `InlineCard` 래퍼
- 접근성: `"dashboard-daily-digest"` identifier

**DashboardViewModel 확장**:
- `dailyDigest: DailyDigest?` stored property
- `buildDailyDigest()` async method — `loadData()` 후반에 호출
- 17시 이후에만 생성 시도 (이전에는 데이터 불충분)

### Step 6: DashboardViewModel Integration

**loadData() 확장**:
1. 기존 병렬 fetch 이후, `CalculateCumulativeStressUseCase` 호출 추가
   - Input: 이미 로딩된 HRV samples, sleep regularity, training volumes
   - 기존 `sleepRegularity` fetch가 없으면 추가 (CalculateSleepRegularityUseCase 호출)
2. `buildDailyDigest()` 호출 (17시 이후만)
3. `currentTimeBand` 기반 섹션 가시성 관리

**새 프로퍼티**:
- `cumulativeStressScore: CumulativeStressScore?`
- `dailyDigest: DailyDigest?`
- `currentTimeBand: DashboardTimeBand` (computed)

**sectionVisibilityHash 확장**:
- `cumulativeStressScore != nil` 추가
- `dailyDigest != nil` 추가
- `currentTimeBand.rawValue` 추가

### Step 7: Localization

모든 새 UI 문자열을 `Shared/Resources/Localizable.xcstrings`에 en/ko/ja 3개 언어 동시 등록.

주요 문자열:
- 스트레스 레벨: Low/Moderate/Elevated/High → 낮음/보통/높음/매우 높음
- 카드 제목: "Cumulative Stress" / "장기 스트레스" / "累積ストレス"
- 다이제스트 제목: "Today's Summary" / "오늘의 요약" / "今日のまとめ"
- 트렌드: "Improving" / "개선 중" / "改善中"
- 시간대 인사: 기존 `AdaptiveHeroMessage`가 처리하므로 추가 불필요

### Step 8: Unit Tests

**CalculateCumulativeStressUseCaseTests.swift**:
- 데이터 부족 (< 7일) → nil
- 모든 값 정상 (HRV CV 낮음, 수면 규칙적, 활동 적정) → score < 30 (low)
- HRV 변동 높음 + 불규칙 수면 + 과부하 → score > 70 (high)
- 경계값: 정확히 7일 데이터
- 가중치 합산 검증 (0.40 + 0.35 + 0.25 = 1.0)
- trend 계산: 최근 7일 vs 이전 7일

**GenerateDailyDigestUseCaseTests.swift**:
- 모든 메트릭 존재 → 요약 문자열 비어있지 않음
- Foundation Models 불가 → 템플릿 fallback 동작
- 메트릭 부분 누락 → graceful degradation

## Final Section Order (Phase 3)

| Zone | Time Band | Components (in order) |
|------|-----------|----------------------|
| A | Morning (06-10) | Hero, Recap, Quick Actions, Rings, Brief |
| A | Daytime (10-17) | Hero, Quick Actions, Rings, Brief |
| A | Evening (17-22) | Hero, Quick Actions, Rings |
| A | Night (22-06) | Hero |
| B | Morning | Recovery, Stress, Intelligence, Insights, Q&A |
| B | Daytime | Recovery, Stress, Intelligence, Insights, Q&A |
| B | Evening | Recovery (강조), Stress, Insights, Digest, Q&A |
| B | Night | Recovery (강조), Stress, Insights, Digest, Q&A |
| C | All | Pinned, Condition, Activity, Body |

## Test Strategy

1. **Unit Tests**: CumulativeStressUseCase 계산 로직, DailyDigest 생성 로직
2. **Build Verification**: `scripts/build-ios.sh`
3. **UI Tests**: 새 카드 존재 확인 (CumulativeStressCard, DailyDigestCard)
4. **시간대 테스트**: DashboardTimeBand 분류 로직 유닛 테스트

## Risks & Edge Cases

| Risk | Mitigation |
|------|-----------|
| HRV 데이터 30일 미만 | 최소 7일 요구, 미만이면 카드 숨김 |
| Foundation Models 미지원 기기 | 템플릿 기반 fallback 텍스트 |
| 시간대 전환 시 섹션 깜빡임 | `sectionVisibilityHash`에 timeBand 포함, `withAnimation` 래핑 |
| 다이제스트 알림 권한 미부여 | 알림 없이 인앱 카드만 표시 |
| sleepRegularity nil | 스트레스 점수에서 수면 가중치 재분배 |
| trainingVolume 빈 배열 | 활동 가중치 재분배 (WellnessScore 패턴) |
| 스크롤 길이 증가 | Time-Aware로 섹션 숨김/표시 동적 제어 |
