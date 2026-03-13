---
tags: [dashboard, briefing, coaching, morning, sheet, animation]
date: 2026-03-14
category: plan
status: draft
---

# Plan: 투데이탭 매일 아침 브리핑

## Overview

그날 첫 앱 실행 시 대시보드 데이터 로드 완료 후 모달 시트로 개인화된 아침 브리핑을 표시한다.
히어로 카드 아래에 축소형 재열람 엔트리를 항상 배치하여 다시 열 수 있도록 한다.

## Brainstorm Reference

`docs/brainstorms/2026-03-14-morning-briefing.md`

## Related Solutions

- `2026-02-28-coaching-engine-insight-cards.md`: CoachingEngine 9-priority 시스템, InsightCardData DTO 패턴
- `2026-03-01-weather-card-coaching-merge.md`: WeatherCard.InsightInfo 디커플링 패턴
- `2026-02-23-today-tab-ux-unification.md`: VitalCard/LazyVGrid 통일 패턴

## Affected Files

### New Files

| File | Layer | Purpose |
|------|-------|---------|
| `Domain/Models/MorningBriefingData.swift` | Domain | 브리핑 데이터 DTO (Sendable) |
| `Domain/UseCases/BriefingTemplateEngine.swift` | Domain | 조건별 문장 조합 엔진 |
| `Presentation/Dashboard/MorningBriefing/MorningBriefingView.swift` | Presentation | 브리핑 시트 UI |
| `Presentation/Dashboard/MorningBriefing/MorningBriefingViewModel.swift` | Presentation | 브리핑 데이터 가공 + 애니메이션 상태 |
| `Presentation/Dashboard/MorningBriefing/Sections/RecoverySummarySection.swift` | Presentation | 수면/컨디션 비교 섹션 |
| `Presentation/Dashboard/MorningBriefing/Sections/TodayGuideSection.swift` | Presentation | 운동 가이드 + 회복 조언 |
| `Presentation/Dashboard/MorningBriefing/Sections/WeeklyContextSection.swift` | Presentation | 주간 히트맵 + 목표 진행률 |
| `Presentation/Dashboard/MorningBriefing/Sections/WeatherAdviceSection.swift` | Presentation | 날씨 연동 조언 |
| `Presentation/Dashboard/Components/BriefingEntryCard.swift` | Presentation | 히어로 카드 아래 재열람 엔트리 |
| `DUNETests/BriefingTemplateEngineTests.swift` | Test | 템플릿 엔진 유닛 테스트 |
| `DUNETests/MorningBriefingViewModelTests.swift` | Test | ViewModel 상태/로직 테스트 |

### Modified Files

| File | Change |
|------|--------|
| `Presentation/Dashboard/DashboardView.swift` | `.sheet(isPresented: $showBriefing)` 추가, BriefingEntryCard 히어로 아래 삽입 |
| `Presentation/Dashboard/DashboardViewModel.swift` | `buildBriefingData()` 메서드 추가, `shouldShowBriefing` 로직 |
| `Shared/Resources/Localizable.xcstrings` | 브리핑 UI 문자열 en/ko/ja 추가 |

## Architecture

### Layer Boundaries

```
Domain Layer (Foundation only)
├─ MorningBriefingData     // Sendable struct — 브리핑에 필요한 모든 데이터
└─ BriefingTemplateEngine  // 순수 함수: MorningBriefingData → 4개 섹션 텍스트

Presentation Layer (SwiftUI)
├─ MorningBriefingViewModel  // @Observable — 애니메이션 상태 + 섹션 가시성
├─ MorningBriefingView       // Sheet 루트 — SheetWaveBackground
├─ Section Views (4개)       // 각 섹션 UI
├─ BriefingEntryCard         // 재열람 진입점
└─ DashboardView/ViewModel   // 기존 수정 — 트리거 + 데이터 전달
```

### Data Flow

```
DashboardViewModel.loadData()
  → 기존 데이터 모두 로드 (conditionScore, sleep, weather, recentScores...)
  → buildBriefingData() → MorningBriefingData 생성
  → shouldShowBriefing 판정 (conditionScore != nil && 오늘 첫 실행)
  → showBriefing = true

MorningBriefingView receives MorningBriefingData
  → MorningBriefingViewModel 생성
  → BriefingTemplateEngine.generate(from: data) → 4개 섹션 텍스트
  → 섹션별 stagger 애니메이션 재생
  → dismiss 시 @AppStorage("lastBriefingDate") 갱신
```

### MorningBriefingData (Domain)

```swift
struct MorningBriefingData: Sendable {
    // Section 1: Recovery Summary
    let conditionScore: Int          // 0-100
    let conditionStatus: String      // excellent/good/fair/tired/warning
    let hrvDelta: Double?            // vs yesterday (ms)
    let rhrDelta: Double?            // vs yesterday (bpm)
    let sleepDuration: TimeInterval? // total sleep hours
    let deepSleepDuration: TimeInterval?
    let sleepDeltaMinutes: Int?      // vs previous night

    // Section 2: Today's Guide
    let recommendedIntensity: String // low/moderate/high
    let sleepDebtHours: Double?
    let recoveryInsight: String?     // from CoachingEngine
    let trainingInsight: String?     // from CoachingEngine

    // Section 3: Weekly Context
    let recentScores: [(date: Date, score: Int)] // last 7 days
    let weeklyAverage: Int
    let previousWeekAverage: Int?
    let activeDays: Int
    let goalDays: Int

    // Section 4: Weather
    let weatherCondition: String?
    let temperature: Double?
    let outdoorFitnessLevel: String?
    let weatherInsight: String?      // from CoachingEngine

    // Section visibility
    var hasSleepData: Bool { sleepDuration != nil }
    var hasWeatherData: Bool { weatherCondition != nil }
}
```

### BriefingTemplateEngine (Domain)

```swift
struct BriefingTemplateSections: Sendable {
    let recoveryTitle: String
    let recoveryMessage: String
    let guideTitle: String
    let guideMessage: String
    let weeklyTitle: String
    let weeklyMessage: String
    let weatherTitle: String?
    let weatherMessage: String?
}

enum BriefingTemplateEngine {
    static func generate(from data: MorningBriefingData) -> BriefingTemplateSections
}
```

- 조건 분기 기반 `String(localized:)` 문장 조합
- CoachingEngine 패턴 참조 (한국어/영어/일본어 3개 언어)
- 데이터 없는 섹션은 nil 반환

### Animation Strategy

시트 등장 시 감성적 애니메이션:

1. **시트 배경**: SheetWaveBackground 테마 적용
2. **Stagger fade-in**: 각 섹션이 0.15초 간격으로 순차 등장 (opacity 0→1 + slide up)
3. **숫자 카운트업**: 컨디션 점수가 0에서 실제 값까지 카운트업 (`.contentTransition(.numericText())`)
4. **주간 히트맵 드로잉**: 7개 원이 좌→우로 순차 scale-in
5. **CTA 버튼**: 마지막에 bounce-in

```swift
// 섹션별 stagger 타이밍
@State private var sectionAppeared = [false, false, false, false]

.task {
    for i in 0..<4 {
        try? await Task.sleep(for: .milliseconds(150 * i))
        withAnimation(.spring(duration: 0.5, bounce: 0.2)) {
            sectionAppeared[i] = true
        }
    }
}
```

### Trigger Logic (DashboardView)

```swift
// DashboardView
@AppStorage("lastBriefingDate") private var lastBriefingDate: String = ""
@AppStorage("morningBriefingEnabled") private var briefingEnabled: Bool = true
@State private var showBriefing = false

// loadData 완료 후 trigger
.onChange(of: viewModel.conditionScore) { _, newValue in
    guard newValue != nil, briefingEnabled else { return }
    let today = Date.now.formatted(.iso8601.year().month().day())
    if lastBriefingDate != today {
        showBriefing = true
    }
}

// sheet dismiss 시 날짜 기록
.sheet(isPresented: $showBriefing, onDismiss: {
    lastBriefingDate = Date.now.formatted(.iso8601.year().month().day())
}) {
    MorningBriefingView(data: viewModel.briefingData)
}
```

### BriefingEntryCard (재열람)

히어로 카드 아래에 배치. 브리핑을 본 후에도 항상 표시.

```swift
// 히어로 카드 아래, weather 카드 위
if let briefingData = viewModel.briefingData {
    BriefingEntryCard(data: briefingData)
        .onTapGesture { showBriefing = true }
}
```

축소형 카드: 컨디션 점수 + 한 줄 요약 + "자세히 보기" 표시.

## Implementation Steps

### Step 1: Domain Models + Template Engine

1. `MorningBriefingData.swift` 생성 — Sendable struct
2. `BriefingTemplateEngine.swift` 생성 — 조건별 문장 조합
3. `BriefingTemplateEngineTests.swift` 작성 — 각 조건 분기 테스트

**Verification**: 테스트 통과

### Step 2: ViewModel + Data Building

1. `DashboardViewModel`에 `briefingData: MorningBriefingData?` 프로퍼티 추가
2. `buildBriefingData()` 메서드 구현 — 기존 로드된 데이터로 조합
3. `MorningBriefingViewModel` 생성 — 애니메이션 상태, 섹션 가시성 관리
4. `MorningBriefingViewModelTests.swift` 작성

**Verification**: 테스트 통과

### Step 3: Briefing Sheet UI

1. `MorningBriefingView.swift` — SheetWaveBackground + ScrollView + 4개 섹션
2. `RecoverySummarySection.swift` — 수면/컨디션 비교
3. `TodayGuideSection.swift` — 운동 강도 추천 + 회복 조언
4. `WeeklyContextSection.swift` — 7일 히트맵 + 주간 목표
5. `WeatherAdviceSection.swift` — 날씨 연동 조언
6. Stagger 애니메이션 + 숫자 카운트업 + 히트맵 드로잉

**Verification**: 빌드 성공

### Step 4: Dashboard Integration

1. `DashboardView`에 `showBriefing` @State + `.sheet` 추가
2. `@AppStorage("lastBriefingDate")` 트리거 로직
3. `BriefingEntryCard.swift` — 히어로 아래 재열람 엔트리
4. 히어로 섹션과 weather 카드 사이에 BriefingEntryCard 삽입

**Verification**: 빌드 성공

### Step 5: Localization

1. `Localizable.xcstrings`에 브리핑 관련 문자열 en/ko/ja 추가
2. 모든 UI 문자열이 `String(localized:)` 또는 `Text()` 경유 확인

**Verification**: 빌드 성공, localization leak 체크

### Step 6: Settings Toggle

1. SettingsView에 "아침 브리핑" on/off 토글 추가
2. `@AppStorage("morningBriefingEnabled")` 연동

**Verification**: 빌드 성공

## Test Strategy

### Unit Tests

| Test | Coverage |
|------|----------|
| `BriefingTemplateEngineTests` | 모든 조건 분기 (excellent/good/fair/tired/warning), 데이터 없음 시 nil, 다국어 |
| `MorningBriefingViewModelTests` | 섹션 가시성 (sleep 없음→숨김, weather 없음→숨김), 애니메이션 상태 초기화 |

### Manual Verification

- 첫 실행 시 시트 등장 확인
- dismiss 후 재실행 시 미등장 확인
- 재열람 카드 탭으로 시트 재오픈 확인
- 설정에서 끈 후 다음 날 실행 시 미등장 확인
- 수면/날씨 데이터 없을 때 해당 섹션 숨김 확인

## Risks & Mitigations

| Risk | Probability | Impact | Mitigation |
|------|-------------|--------|------------|
| 시트가 대시보드 로딩 지연 | Low | Medium | conditionScore 로드 완료 후 trigger — 병렬 아님 |
| 매일 시트가 귀찮다는 피드백 | Medium | Low | 설정 토글 + dismiss 쉬움 (swipe down) |
| Baseline 미형성 시 빈 브리핑 | Low | Medium | conditionScore == nil이면 브리핑 미표시 |
| 긴 문장으로 레이아웃 깨짐 | Low | Low | 문자열 길이 제한 + Dynamic Type 대응 |

## Edge Cases

1. **conditionScore == nil**: 브리핑 미표시 (baseline 수집 중)
2. **sleepDuration == nil**: RecoverySummarySection에서 수면 부분만 숨김
3. **weatherSnapshot == nil**: WeatherAdviceSection 전체 숨김
4. **recentScores.count < 7**: 있는 날만 히트맵에 표시
5. **weeklyGoalProgress == (0, 5)**: "이번 주 아직 운동을 시작하지 않았어요" 표시
6. **오후 첫 실행**: 정상 표시 (시간 무관, 날짜 기준)
