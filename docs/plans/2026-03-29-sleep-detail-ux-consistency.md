---
tags: [sleep, ux, section-group, subtitle, consistency]
date: 2026-03-29
category: plan
status: draft
---

# Plan: 수면 상세 화면 UX 일관성 — SectionGroup 그룹핑 + 섹션 설명

## Context

- Brainstorm: `docs/brainstorms/2026-03-29-sleep-detail-ux-consistency.md`
- 관련 해결책: `docs/solutions/architecture/2026-03-04-life-tab-ux-consistency-sectiongroup-refresh.md`
- 관련 해결책: `docs/solutions/architecture/2026-02-21-wellness-section-split-patterns.md`

## Objective

MetricDetailView의 수면 카드 11개를 4개 SectionGroup으로 그룹핑하고, 각 섹션에 한 줄 설명을 추가한다.

## Affected Files

| 파일 | 변경 내용 |
|------|----------|
| `DUNE/Presentation/Shared/Components/SectionGroup.swift` | `subtitle: LocalizedStringKey?` 파라미터 추가, header에 subtitle 렌더링 |
| `DUNE/Presentation/Shared/Detail/MetricDetailView.swift` | sleep 카드를 4개 SectionGroup으로 재구성 |
| `Shared/Resources/Localizable.xcstrings` | 섹션 제목 4개 + 설명 4개 = 8 문자열 (en/ko/ja) |

## Implementation Steps

### Step 1: SectionGroup subtitle 파라미터 추가

**파일**: `SectionGroup.swift`

1. `subtitle: LocalizedStringKey? = nil` 프로퍼티 추가
2. header VStack에서 title 아래에 subtitle 표시:
   - font: `.caption`
   - color: `DS.Color.textTertiary`
   - spacing: title과 subtitle 사이 2pt

```swift
// Header 영역 변경
VStack(alignment: .leading, spacing: 2) {
    HStack(spacing: DS.Spacing.xs) {
        // 기존 accent bar + icon + title + infoAction
    }

    if let subtitle {
        Text(subtitle)
            .font(.caption)
            .foregroundStyle(DS.Color.textTertiary)
            .padding(.leading, DS.Spacing.xs)
    }
}
```

**검증**: 기존 SectionGroup 호출부(Activity, Wellness, Dashboard, Life)는 subtitle 기본값 nil이므로 변경 없음.

### Step 2: MetricDetailView 수면 섹션 리팩토링

**파일**: `MetricDetailView.swift`

현재 flat하게 나열된 11개 카드를 4개 SectionGroup으로 재배치:

#### Group 1: Sleep Quality (수면 품질)
- icon: `bed.double.fill`, color: `DS.Color.sleep`
- subtitle: "Analyzes sleep score, sleep debt, and awakening patterns"
- 카드:
  - `SleepDeficitGaugeView` (조건부: deficitAnalysis non-nil + level != .insufficient)
  - `WakeAnalysisCard`
  - `SleepDebtRecoveryCard`

#### Group 2: Sleep Patterns (수면 패턴)
- icon: `clock.badge.checkmark`, color: `DS.Color.sleep`
- subtitle: "Tracks bedtime regularity and nap patterns"
- 카드:
  - `AverageBedtimeCard` (조건부: averageBedtime non-nil)
  - `SleepRegularityCard`
  - `NapDetectionCard`

#### Group 3: Nocturnal Health (야간 건강 지표)
- icon: `heart.text.clipboard`, color: `DS.Color.sleep`
- subtitle: "Monitors heart rate, breathing, and oxygen levels during sleep"
- 카드:
  - `NocturnalVitalsChartView`
  - `VitalsTimelineCard`
  - `BreathingDisturbanceCard`

#### Group 4: External Factors (외부 요인)
- icon: `arrow.triangle.branch`, color: `DS.Color.sleep`
- subtitle: "Analyzes how exercise and environment affect your sleep"
- 카드:
  - `SleepExerciseCorrelationCard`
  - `SleepEnvironmentCard`

**staggeredAppear**: 섹션 단위로 적용 (index 4~7).

### Step 3: Localizable.xcstrings 다국어 등록

8개 문자열 (en/ko/ja):

| 키 (영어) | 한국어 | 일본어 |
|-----------|--------|--------|
| "Sleep Quality" | 수면 품질 | 睡眠の質 |
| "Analyzes sleep score, sleep debt, and awakening patterns" | 수면 점수, 수면 부채, 각성 패턴을 분석합니다 | 睡眠スコア、睡眠負債、覚醒パターンを分析します |
| "Sleep Patterns" | 수면 패턴 | 睡眠パターン |
| "Tracks bedtime regularity and nap patterns" | 취침 시간 규칙성과 낮잠 패턴을 추적합니다 | 就寝時間の規則性と昼寝パターンを追跡します |
| "Nocturnal Health" | 야간 건강 지표 | 夜間の健康指標 |
| "Monitors heart rate, breathing, and oxygen levels during sleep" | 수면 중 심박수, 호흡, 산소포화도 변화를 모니터링합니다 | 睡眠中の心拍数、呼吸、酸素レベルの変化をモニタリングします |
| "External Factors" | 외부 요인 | 外的要因 |
| "Analyzes how exercise and environment affect your sleep" | 운동과 환경이 수면에 미치는 영향을 분석합니다 | 運動と環境が睡眠に与える影響を分析します |

**주의**: "Sleep Quality"는 이미 xcstrings에 존재하므로 번역이 정확한지 확인 후 재사용.

## Test Strategy

### 유닛 테스트
- SectionGroup subtitle 파라미터 추가는 순수 View 변경이므로 유닛 테스트 대상 아님
- 기존 DUNETests 회귀 확인

### UI 테스트
- MetricDetailView sleep 섹션의 SectionGroup 존재 확인
- 각 섹션 제목 + 설명 텍스트 존재 확인
- 기존 카드가 모두 렌더링되는지 확인

### 빌드 검증
- `scripts/build-ios.sh` 성공

## Risks & Edge Cases

| 리스크 | 대응 |
|--------|------|
| SectionGroup 기존 호출부 깨짐 | subtitle 기본값 nil — 호환 보장 |
| 조건부 카드(Deficit, Bedtime) 생략 시 빈 섹션 | 해당 카드가 nil이면 그룹에서 생략되지만, 같은 그룹의 다른 카드가 항상 표시 |
| iPad 레이아웃 | SectionGroup이 이미 sizeClass 대응 |
| 번역 길이 (일본어) | caption font + 자연 줄바꿈 허용 |

## Alternatives Considered

1. **카드별 subtitle 추가** — 기각: 기존 카드 헤더에 이미 Label이 있어 중복, SectionGroup 단위가 적절
2. **SectionGroup 대신 커스텀 섹션 헤더** — 기각: 앱 전체 일관성을 위해 기존 컴포넌트 확장이 적절
