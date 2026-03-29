---
tags: [sleep, ux, section-group, consistency, description]
date: 2026-03-29
category: brainstorm
status: draft
---

# Brainstorm: 수면 상세 화면 UX 일관성 및 섹션 설명 추가

## Problem Statement

수면 상세 화면(MetricDetailView, category == .sleep)에 11개 카드가 flat하게 나열되어 있어 정보 계층 구조가 부재하다. Activity/Wellness 탭은 `SectionGroup`으로 카드를 그룹핑하지만, 수면 상세 화면은 이 패턴을 사용하지 않아 UX 일관성이 떨어진다. 또한 각 섹션/카드가 무엇을 보여주는지 설명이 없어 사용자가 데이터의 맥락을 파악하기 어렵다.

## Target Users

- 수면 데이터를 일상적으로 확인하는 건강 관리 사용자
- 수면 품질 개선을 위해 세부 지표를 분석하려는 사용자
- 처음 앱을 사용하여 각 지표의 의미를 이해해야 하는 신규 사용자

## Success Criteria

1. 11개 수면 카드가 4개 논리적 섹션으로 그룹핑됨
2. 각 섹션에 한 줄 기능 설명이 표시됨
3. Activity/Wellness와 동일한 `SectionGroup` 컴포넌트 사용
4. 기존 카드 내부 UI는 변경 없음

## Current State

### 카드 목록 (MetricDetailView.swift:98-121)

| # | 카드 | 데이터 소스 | 조건부 표시 |
|---|------|-----------|------------|
| 1 | AverageBedtimeCard | viewModel.averageBedtime | non-nil |
| 2 | SleepDeficitGaugeView | viewModel.deficitAnalysis | non-nil + level != .insufficient |
| 3 | WakeAnalysisCard | viewModel.wasoAnalysis | 항상 (nil이면 placeholder) |
| 4 | BreathingDisturbanceCard | viewModel.breathingAnalysis | 항상 (nil이면 placeholder) |
| 5 | SleepRegularityCard | viewModel.sleepRegularity | 항상 (nil이면 placeholder) |
| 6 | NapDetectionCard | viewModel.napAnalysis | 항상 (nil이면 placeholder) |
| 7 | SleepDebtRecoveryCard | viewModel.debtRecoveryPrediction | 항상 (nil이면 placeholder) |
| 8 | SleepExerciseCorrelationCard | viewModel.exerciseCorrelation | 항상 (nil이면 placeholder) |
| 9 | NocturnalVitalsChartView | viewModel.nocturnalVitals | 항상 (nil이면 placeholder) |
| 10 | VitalsTimelineCard | viewModel.vitalsTimeline | 항상 (nil이면 placeholder) |
| 11 | SleepEnvironmentCard | viewModel.sleepEnvironment | 항상 (nil이면 placeholder) |

### 현재 SectionGroup 컴포넌트

- 파라미터: `title`, `icon`, `iconColor`, `infoAction?`, `fillHeight`, `content`
- **subtitle 파라미터 없음** — 설명 텍스트 지원 불가
- Activity/Wellness에서 사용 중, 수면 상세에서는 미사용

## Proposed Approach

### 1. SectionGroup에 subtitle 파라미터 추가

```swift
struct SectionGroup<Content: View>: View {
    let title: LocalizedStringKey
    let icon: String
    let iconColor: Color
    var subtitle: LocalizedStringKey? = nil  // NEW
    var infoAction: (() -> Void)? = nil
    var fillHeight: Bool = false
    @ViewBuilder let content: () -> Content
}
```

기존 호출부는 subtitle 기본값 nil로 변경 없이 호환.

### 2. 4그룹 섹션 구조

#### Group 1: 수면 품질 (Sleep Quality)
- icon: `bed.double.fill`
- 설명: "수면 점수, 수면 부채, 각성 패턴을 분석합니다"
- 카드:
  - SleepDeficitGaugeView (수면 부채)
  - WakeAnalysisCard (각성 분석)
  - SleepDebtRecoveryCard (회복 예측)

#### Group 2: 수면 패턴 (Sleep Patterns)
- icon: `clock.badge.checkmark`
- 설명: "취침 시간 규칙성, 낮잠 패턴을 추적합니다"
- 카드:
  - AverageBedtimeCard (평균 취침 시간)
  - SleepRegularityCard (수면 규칙성)
  - NapDetectionCard (낮잠 감지)

#### Group 3: 야간 건강 지표 (Nocturnal Health)
- icon: `heart.text.clipboard`
- 설명: "수면 중 심박수, 호흡, 산소포화도 변화를 모니터링합니다"
- 카드:
  - NocturnalVitalsChartView (야간 생체 신호)
  - VitalsTimelineCard (30일 생체 신호 추세)
  - BreathingDisturbanceCard (호흡 장애)

#### Group 4: 외부 요인 (External Factors)
- icon: `arrow.triangle.branch`
- 설명: "운동, 환경이 수면에 미치는 영향을 분석합니다"
- 카드:
  - SleepExerciseCorrelationCard (수면-운동 상관관계)
  - SleepEnvironmentCard (수면 환경)

### 3. subtitle 렌더링 위치

SectionGroup header 내, title 아래에 `.caption` + `DS.Color.textTertiary`로 표시:

```
┌─ [accent bar] [icon] Title            [info?] ─┐
│  Subtitle text here                              │
│                                                  │
│  [Card 1]                                        │
│  [Card 2]                                        │
│  ...                                             │
└──────────────────────────────────────────────────┘
```

## Constraints

- **SectionGroup 수정은 최소한으로**: 기존 Activity/Wellness 호출부에 영향 없어야 함 (optional subtitle)
- **카드 내부 변경 없음**: 각 카드의 기존 header/content 구조 유지
- **조건부 표시 유지**: AverageBedtimeCard, SleepDeficitGaugeView의 조건부 렌더링 로직 보존
- **다국어**: 섹션 제목과 설명 모두 en/ko/ja xcstrings 등록 필수

## Edge Cases

| 케이스 | 대응 |
|--------|------|
| 그룹 내 모든 카드가 nil (데이터 없음) | 각 카드가 이미 SleepDataPlaceholder를 표시하므로 그룹 자체는 항상 표시 |
| SleepDeficitGaugeView 조건 미충족 | Group 1에서 해당 카드만 생략, 나머지 카드는 정상 표시 |
| AverageBedtimeCard 데이터 없음 | Group 2에서 해당 카드만 생략 |
| iPad 가로 모드 | SectionGroup이 이미 sizeClass 대응 → 추가 작업 불필요 |
| subtitle이 긴 번역 (일본어) | `.caption` + `.lineLimit(2)` 또는 자연 줄바꿈 허용 |

## Scope

### MVP (Must-have)
- [ ] SectionGroup에 `subtitle: LocalizedStringKey?` 파라미터 추가
- [ ] MetricDetailView의 sleep 섹션을 4개 SectionGroup으로 리팩토링
- [ ] 4개 섹션의 제목/아이콘/설명 텍스트 정의
- [ ] xcstrings에 en/ko/ja 번역 등록 (섹션 제목 + 설명 = 8개 문자열)

### Nice-to-have (Future)
- [ ] Activity/Wellness 탭 섹션에도 subtitle 추가
- [ ] Dashboard 섹션에 subtitle 추가
- [ ] 섹션 접기/펼치기 (collapsible sections)
- [ ] 섹션별 데이터 충분성 인디케이터

## Open Questions

1. **섹션 제목 언어**: 섹션 제목을 영어로 유지할지 (Sleep Quality) vs 번역할지 (수면 품질) — 현재 앱의 다른 SectionGroup 제목 패턴 따름
2. **staggeredAppear 적용 단위**: 현재 카드별 → 섹션별로 변경할지, 카드별 유지할지
3. **카드 순서 재배치**: 현재 순서에서 그룹핑에 맞게 순서 변경 필요 (예: BreathingDisturbanceCard를 Group 3으로 이동)

## Affected Files

| 파일 | 변경 내용 |
|------|----------|
| `DUNE/Presentation/Shared/Components/SectionGroup.swift` | subtitle 파라미터 추가 |
| `DUNE/Presentation/Shared/Detail/MetricDetailView.swift` | sleep 섹션 4개 SectionGroup으로 재구성 |
| `Shared/Resources/Localizable.xcstrings` | 8개 문자열 (제목 4 + 설명 4) en/ko/ja |

## Next Steps

- [ ] `/plan sleep-detail-ux-consistency` 으로 구현 계획 생성
