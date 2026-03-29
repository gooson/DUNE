---
tags: [dashboard, today, consolidation, ux, phase1]
date: 2026-03-29
category: plan
status: approved
---

# Today Tab Phase 1: Section Consolidation

## Summary

Today 탭의 13개 섹션을 9개로 통합하여 코칭/환경/수면 정보가 맥락별로 묶이고 스크롤 길이를 ~30% 감소시킵니다.

## Affected Files

| File | Action | Description |
|------|--------|-------------|
| `Presentation/Dashboard/DashboardView.swift` | **Modify** | 3개 통합 섹션 사용, 기존 개별 카드 교체 |
| `Presentation/Dashboard/DashboardViewModel.swift` | **Modify** | 수면 인사이트 필터링 computed property 추가 |
| `Presentation/Dashboard/Components/TodayBriefCard.swift` | **Create** | 통합 Brief 카드 (날씨+코칭+브리핑 엔트리) |
| `Presentation/Dashboard/Components/RecoverySleepCard.swift` | **Create** | 수면 부채 + 수면 인사이트 통합 |
| `Presentation/Dashboard/Components/SmartInsightsSection.swift` | **Create** | 인사이트 카드 + 템플릿 넛지 통합 |
| `Shared/Resources/Localizable.xcstrings` | **Modify** | 새 UI 문자열 en/ko/ja 추가 |

### Files NOT Modified (기존 유지)
| File | Reason |
|------|--------|
| `BriefingEntryCard.swift` | 삭제하지 않음 — TodayBriefCard 내부에서 import 없이 로직 재구현 |
| `WeatherCard.swift` | 유지 — WeatherDetailView 네비게이션에서 여전히 사용 가능 |
| `TodayCoachingCard.swift` | 유지 — standalone 사용 경로 보존 |
| `SleepDeficitBadgeView.swift` | 유지 — RecoverySleepCard 내부에서 재사용 |
| `InsightCardView.swift` | 유지 — SmartInsightsSection 내부에서 재사용 |
| `TemplateNudgeCard.swift` | 유지 — SmartInsightsSection 내부에서 재사용 |
| `HealthDataQACard.swift` | 유지 — 위치만 이동 (Zone B) |

## Implementation Steps

### Step 1: TodayBriefCard 생성

**새 파일**: `Presentation/Dashboard/Components/TodayBriefCard.swift`

통합 대상: BriefingEntryCard + WeatherCard + TodayCoachingCard

```swift
struct TodayBriefCard: View {
    // Weather data
    let weatherSnapshot: WeatherSnapshot?
    let weatherInsight: WeatherCard.InsightInfo?

    // Coaching
    let focusInsight: CoachingInsight?
    let coachingMessage: String?

    // Briefing
    let conditionStatus: ConditionScore.Status?
    let onOpenBriefing: () -> Void
    let onOpenWeatherDetail: () -> Void
    let onRequestLocationPermission: () -> Void
}
```

**레이아웃**:
1. 날씨 요약 줄 (기온, 체감, 위치, 대기질 뱃지, 아웃도어 뱃지) — 탭하면 WeatherDetail
2. 코칭 메시지 (포커스 인사이트 1줄 제목 + 2줄 메시지)
3. 환경 알림 (조건부: 습도>70%, 미세먼지 나쁨, UV 높음)
4. "자세히 보기" 버튼 → MorningBriefing 시트 열기

**날씨 없을 때**: WeatherCardPlaceholder 스타일 1줄 + 코칭만 표시

**Verification**: 빌드 성공, 카드가 InlineCard로 감싸짐

### Step 2: RecoverySleepCard 생성

**새 파일**: `Presentation/Dashboard/Components/RecoverySleepCard.swift`

통합 대상: SleepDeficitBadgeView + 수면 카테고리 InsightCards

```swift
struct RecoverySleepCard: View {
    let sleepDeficit: SleepDeficitAnalysis?
    let sleepInsights: [InsightCardData]
    let sleepMetric: HealthMetric?
    let onDismissInsight: (String) -> Void
}
```

**레이아웃**:
1. 헤더 (🛏️ 수면 회복)
2. SleepDeficitBadgeView 미니 게이지 (인라인)
3. 수면 관련 인사이트 (최대 2개, dismiss 가능)
4. "수면 상세" NavigationLink

**조건부 표시**: 수면 부채 > 0 또는 수면 인사이트 있을 때만

**Verification**: 빌드 성공, deficit 없고 insight 없으면 숨김

### Step 3: SmartInsightsSection 생성

**새 파일**: `Presentation/Dashboard/Components/SmartInsightsSection.swift`

통합 대상: insightCardsSection + TemplateNudgeCard

```swift
struct SmartInsightsSection: View {
    let insightCards: [InsightCardData]
    let templateNudge: WorkoutTemplateRecommendation?
    let onDismissInsight: (String) -> Void
    let onSaveTemplate: () -> Void
    let onDismissNudge: () -> Void
}
```

**레이아웃**:
1. 섹션 헤더 "💡 Insights" (인사이트+넛지 합산 > 0 일 때만)
2. 비수면 InsightCardView 스택 (최대 3개)
3. TemplateNudgeCard (있을 때)
4. 전체 없으면 섹션 숨김

**Verification**: 빌드 성공, 빈 상태에서 섹션 미표시

### Step 4: DashboardViewModel 확장

**수정 파일**: `DashboardViewModel.swift`

새 computed properties 추가:

```swift
/// 수면 카테고리 인사이트 (RecoverySleepCard용)
var sleepInsightCards: [InsightCardData] {
    insightCards.filter { $0.category == .sleep }
}

/// 비수면 인사이트 (SmartInsightsSection용)
var nonSleepInsightCards: [InsightCardData] {
    insightCards.filter { $0.category != .sleep }
}
```

**Verification**: 기존 insightCards 분배가 누락 없이 이루어지는지 확인

### Step 5: DashboardView 통합

**수정 파일**: `DashboardView.swift`

`dashboardUpperContent` 변경:
```
Before: Hero → BriefingEntry → Weather → Coaching → HealthQA → InsightCards
After:  Hero → TodayBriefCard → RecoverySleepCard → SmartInsightsSection → HealthQA
```

`dashboardLowerContent` 변경:
```
Before: TemplateNudge → SleepDeficit → Pinned → Updated → Error → Condition → Activity → Body
After:  Pinned → Updated → Error → Condition → Activity → Body
```

- TemplateNudge → SmartInsightsSection으로 이동
- SleepDeficit → RecoverySleepCard로 이동
- staggeredAppear index 재배정

**Verification**: 빌드 성공, 모든 기존 기능(시트, 네비게이션)이 동작

### Step 6: Localization

**수정 파일**: `Shared/Resources/Localizable.xcstrings`

새 문자열:

| Key (en) | ko | ja |
|----------|----|----|
| "Today's Brief" | "오늘의 브리핑" | "今日のブリーフィング" |
| "View Details" | "자세히 보기" | "詳細を見る" |
| "Recovery & Sleep" | "회복 & 수면" | "回復 & 睡眠" |
| "Sleep Details" | "수면 상세" | "睡眠の詳細" |
| "Insights" | "인사이트" | "インサイト" |

**Verification**: xcstrings에 en/ko/ja 3개 언어 등록 확인

### Step 7: Unit Tests

**수정 파일**: `DUNETests/` (기존 또는 새 파일)

- `sleepInsightCards` / `nonSleepInsightCards` 분배 테스트
- 수면 인사이트 + 비수면 인사이트 합이 전체 insightCards와 일치 확인
- TodayBriefCard이 날씨 없을 때 코칭만 표시하는지 (snapshot test 대신 빌드 검증)

**Verification**: `xcodebuild test ... DUNETests` 통과

## Test Strategy

- **Unit**: DashboardViewModel의 sleepInsightCards/nonSleepInsightCards 분배
- **Build**: `scripts/build-ios.sh` 전체 빌드 통과
- **Manual**: 시뮬레이터에서 Today 탭 스크롤하여 3개 통합 카드 확인

## Risks & Edge Cases

| Risk | Mitigation |
|------|-----------|
| 날씨 데이터 없을 때 Brief 카드 비어 보임 | 코칭 메시지만으로 충분한 콘텐츠 보장, 브리핑 엔트리는 항상 표시 |
| 수면 부채 0 + 수면 인사이트 0 → RecoverySleepCard 숨김 | 의도된 동작. 빈 카드를 표시하지 않음 |
| 인사이트 0 + 넛지 없음 → SmartInsightsSection 숨김 | 의도된 동작. 빈 섹션 미표시 |
| 기존 UI 테스트 AXID 변경 | 기존 `briefing-entry-card`, `dashboard-weather-card` AXID를 새 카드에서 보존 |
| 기존 네비게이션 경로 깨짐 | WeatherSnapshot NavigationDestination 유지, SleepMetric NavigationLink 유지 |

## Dependencies

- Brainstorm: `docs/brainstorms/2026-03-29-today-tab-evolution.md`
- Related solution: `docs/solutions/architecture/2026-03-01-weather-card-coaching-merge.md`
- Related solution: `docs/solutions/general/2026-03-14-morning-briefing-feature.md`
