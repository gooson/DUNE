---
tags: [life-tab, habits, notifications, charts, analytics, templates]
date: 2026-03-22
category: plan
status: draft
---

# Plan: 라이프탭 전체 고도화

## Summary

라이프탭 10개 기능을 한 번에 구현한다. 스키마 변경 → 도메인 모델 → 로직 → UI 순서로 진행.

## Prerequisites

- brainstorm: `docs/brainstorms/2026-03-22-life-tab-enhancement.md`
- 현재 스키마: V16 (`AppSchemaVersions.swift`)
- 현재 HabitDefinition: 14 stored properties + 1 relationship

## Affected Files

| # | 파일 | 변경 유형 | 목적 |
|---|------|----------|------|
| 1 | `Domain/Models/HabitType.swift` | 수정 | HabitTimeOfDay enum 추가, HabitProgress에 timeOfDay 필드 추가 |
| 2 | `Domain/Models/HabitTemplate.swift` | **신규** | 습관 템플릿 모델 (static data, SwiftData 아님) |
| 3 | `Domain/UseCases/HabitAnalyticsService.swift` | **신규** | 완료율 계산, 주간 리포트 데이터 |
| 4 | `Data/Persistence/Models/HabitDefinition.swift` | 수정 | reminderHour/Minute, timeOfDayRaw 필드 추가 |
| 5 | `Data/Persistence/Migration/AppSchemaVersions.swift` | 수정 | V17 스키마 + lightweight migration |
| 6 | `Presentation/Life/LifeViewModel.swift` | 수정 | 알림 로직, 조기완료, 필터/정렬, 분석 데이터 |
| 7 | `Presentation/Life/LifeView.swift` | 수정 | 시간대 그룹핑, 카테고리 필터, 분석 섹션 |
| 8 | `Presentation/Life/HabitFormSheet.swift` | 수정 | 알림 시각 picker, 시간대 picker |
| 9 | `Presentation/Life/HabitRowView.swift` | 수정 | 조기 완료 상태 표시 |
| 10 | `Presentation/Life/HabitCompletionChartView.swift` | **신규** | 완료율 차트 (Swift Charts) |
| 11 | `Presentation/Life/HabitHeatmapView.swift` | **신규** | 히트맵/캘린더 뷰 |
| 12 | `Presentation/Life/WeeklyHabitReportView.swift` | **신규** | 주간 리포트 |
| 13 | `Presentation/Life/HabitTemplateSheet.swift` | **신규** | 템플릿 선택 시트 |
| 14 | `Shared/Resources/Localizable.xcstrings` | 수정 | 새 문자열 번역 (en/ko/ja) |
| 15 | `DUNETests/HabitAnalyticsServiceTests.swift` | **신규** | 분석 서비스 테스트 |
| 16 | `DUNETests/LifeViewModelTests.swift` | 수정 | 알림/조기완료 테스트 추가 |

## Implementation Steps

### Step 1: 스키마 변경 (V17)

HabitDefinition에 3개 필드 추가 (모두 default 값이 있으므로 lightweight migration):

```swift
// HabitDefinition.swift에 추가
var reminderHour: Int = 9
var reminderMinute: Int = 0
var timeOfDayRaw: String = "anytime"  // morning, afternoon, evening, anytime
```

V17 스키마 + `migrateV16toV17` lightweight migration stage 추가.

### Step 2: 도메인 모델 확장

**HabitTimeOfDay enum** (`HabitType.swift`):
```swift
enum HabitTimeOfDay: String, Sendable, CaseIterable {
    case morning    // 아침
    case afternoon  // 오후
    case evening    // 저녁
    case anytime    // 언제든
}
```

**HabitProgress 확장**: `timeOfDay: HabitTimeOfDay` 필드 추가.

**HabitTemplate 모델** (`HabitTemplate.swift`):
```swift
struct HabitTemplate: Sendable, Identifiable {
    let id: String
    let name: String               // 영어 (String(localized:) 사용)
    let iconCategory: HabitIconCategory
    let type: HabitType
    let suggestedGoalValue: Double
    let suggestedGoalUnit: String?
    let suggestedFrequency: HabitFrequency
    let suggestedTimeOfDay: HabitTimeOfDay
    let category: HabitTemplateCategory
}

enum HabitTemplateCategory: String, Sendable, CaseIterable {
    case health, fitness, productivity, mindfulness, lifestyle
}
```

Static let 배열로 ~20개 프리셋 정의 (운동, 물 마시기, 명상, 독서, 코딩 등).

### Step 3: 알림 시스템 개선

**3-A. 간격 비례 오프셋 자동 조정** (`HabitReminderScheduler`):

```swift
private static func reminderOffsets(for intervalDays: Int) -> [Int] {
    switch intervalDays {
    case 1:       return [0]
    case 2...7:   return [1, 0]
    case 8...14:  return [3, 1, 0]
    case 15...30: return [7, 3, 1, 0]
    default:      return [14, 7, 3, 0]
    }
}
```

Daily/Weekly frequency는 `[0]`만 (당일 알림).

**3-B. 사용자 커스텀 알림 시각**:
- `HabitReminderScheduler.reschedule()`에서 9시 하드코딩 → `habit.reminderHour`, `habit.reminderMinute` 사용
- HabitFormSheet에 시간 picker 추가

**3-C. 조기 완료 시 알림 취소**:
- `toggleCheck()` 완료 후 해당 habit의 현재 사이클 알림 전체 제거
- `UNUserNotificationCenter.removePendingNotificationRequests(withIdentifiers:)` 호출

### Step 4: 조기 완료 + 앵커 유지

**`makeCycleSnapshot()` 변경**:

현재:
```swift
canComplete = isDue || lastAction == nil
```

변경:
```swift
// 언제든 완료 가능 (단, 이미 현재 사이클 완료 상태가 아닌 경우만)
canComplete = !isAlreadyCompletedThisCycle
```

앵커 유지 로직:
- 완료 시점과 관계없이 `anchorDate`는 원래 due date 기준으로 advance
- 예: anchor=3/1, interval=7 → due=3/8 → 3/5에 완료 → anchor를 3/8로 advance → 다음 due=3/15
- `isDue`, `isOverdue`는 유지 (UI 힌트용) — 하지만 `canComplete`는 항상 true

**HabitRowView 변경**:
- 미리 완료 시 "Done · Next {date}" + 완료 체크 표시
- `isToggleDisabled` 조건에서 `!canCompleteCycle` 제거 (cycle 기반)

### Step 5: 분석 서비스

**HabitAnalyticsService** (Domain/UseCases, pure Swift, Sendable):

```swift
enum HabitAnalyticsService {
    // 주간 완료율: 최근 N주 각각의 완료 횟수 / 목표 횟수
    static func weeklyCompletionRates(
        logs: [HabitLogSnapshot],
        habits: [HabitSnapshot],
        weekCount: Int = 8
    ) -> [WeeklyCompletionRate]

    // 월간 완료율: 최근 N개월
    static func monthlyCompletionRates(
        logs: [HabitLogSnapshot],
        habits: [HabitSnapshot],
        monthCount: Int = 6
    ) -> [MonthlyCompletionRate]

    // 히트맵 데이터: 최근 N일의 일별 완료 수
    static func dailyCompletionCounts(
        logs: [HabitLogSnapshot],
        dayCount: Int = 90
    ) -> [DailyCompletionCount]

    // 주간 리포트 요약
    static func weeklyReport(
        logs: [HabitLogSnapshot],
        habits: [HabitSnapshot],
        referenceDate: Date = Date()
    ) -> WeeklyHabitReport
}
```

Input 타입은 lightweight Sendable snapshot (SwiftData 의존 없음).

### Step 6: 완료율 차트

**HabitCompletionChartView** (Swift Charts):
- BarMark로 주간/월간 완료율 표시
- Segmented picker: Week / Month
- 바 색상: DS.Color.tabLife
- 100% 기준선 RuleMark
- `.clipped()` 적용
- 격리된 child view (부모 re-layout 방지)

### Step 7: 히트맵/캘린더 뷰

**HabitHeatmapView**:
- GitHub-style contribution grid
- 7행(요일) × 13열(주) = 최근 ~90일
- 색상 강도: 0 completions → DS.Color.tabLife.opacity(0.1), max → DS.Color.tabLife
- 셀 크기: 12×12, gap 2
- 요일 레이블 (Mon, Wed, Fri)
- 월 레이블 상단
- LazyVGrid 기반 구현 (Chart 불필요)

### Step 8: 시간대별 그룹핑

LifeView의 habits 섹션을 시간대로 분리:

```
Morning (아침)
├── 물 한 잔
├── 스트레칭
Afternoon (오후)
├── 독서
Evening (저녁)
├── 명상
├── 일기
Anytime (언제든)
├── 코딩
```

- `viewModel.habitProgresses`를 `timeOfDay`로 그룹핑
- 빈 그룹은 표시하지 않음
- 그룹 헤더: 시간대 아이콘 + 이름 + 완료 카운트

### Step 9: 카테고리 필터/정렬

Habits 섹션 상단에 수평 스크롤 필터 칩:

```
[All] [Health] [Fitness] [Study] [Coding] ...
```

- 현재 선택된 카테고리로 `habitProgresses` 필터
- "All"이 기본
- `@State private var selectedCategory: HabitIconCategory?`
- 필터는 그룹핑과 조합 가능 (필터 후 시간대별 그룹핑)

### Step 10: 주간 리포트

**WeeklyHabitReportView** (NavigationDestination):
- 이번 주 vs 지난 주 비교
- 전체 완료율 (%)
- 가장 잘 지킨 습관 Top 3
- 가장 놓친 습관 Top 3
- 총 완료 횟수
- 스트릭 현황

히어로 섹션 또는 별도 "리포트" 버튼에서 진입.

### Step 11: 습관 템플릿

**HabitTemplateSheet**:
- 카테고리별 그룹 (health, fitness, productivity 등)
- 각 템플릿 카드: 아이콘 + 이름 + 추천 빈도
- 탭 → HabitFormSheet 열기 (필드 프리필)
- "+" 버튼 메뉴에서 "템플릿에서 추가" 옵션

### Step 12: 번역

모든 새 문자열을 `Shared/Resources/Localizable.xcstrings`에 en/ko/ja 3개 언어 등록.

### Step 13: 테스트

- `HabitAnalyticsServiceTests`: 완료율 계산, 히트맵 데이터, 주간 리포트 로직
- `LifeViewModelTests`: 간격 비례 알림 오프셋, 조기 완료 + 앵커 유지

## Edge Cases

| 상황 | 처리 |
|------|------|
| 간격 1일(매일) + 알림 | 당일 알림만 [0] |
| 조기 완료 후 같은 사이클 재체크 | 이미 완료 → toggle off (로그 삭제) |
| 앵커 날짜가 먼 과거 | 정상 — 다음 due date는 현재 기준으로 가장 가까운 미래 날짜 |
| 템플릿 선택 후 수정 | 템플릿은 프리필만 — 사용자가 자유롭게 수정 가능 |
| 카테고리 필터 + 시간대 그룹 동시 | 필터 먼저 적용 → 결과를 시간대로 그룹핑 |
| 습관 0개 상태에서 분석 섹션 | 빈 상태 표시 ("습관을 추가하면 분석을 볼 수 있어요") |
| reminderHour 마이그레이션 | default 9 — 기존 습관은 기존과 동일 동작 |

## Risks

| 위험 | 완화 |
|------|------|
| V17 스키마 마이그레이션 실패 | 모든 신규 필드에 default 값 → lightweight migration 보장 |
| LifeView 복잡도 증가 | 분석 섹션은 별도 child view로 격리 |
| 성능: 90일 히트맵 계산 | HabitAnalyticsService는 pure function, .task(id:)로 비동기 계산 |

## Verification

```bash
# 빌드
scripts/build-ios.sh

# 테스트
xcodebuild test -project DUNE/DUNE.xcodeproj -scheme DUNETests \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro Max,OS=26.3.1' \
  -only-testing DUNETests
```

## Implementation Order

1. Schema V17 + HabitDefinition fields → commit
2. Domain models (HabitTimeOfDay, HabitTemplate, HabitAnalyticsService) → commit
3. ViewModel logic (notifications, early completion) → commit
4. Form UI (reminder time, time-of-day picker) → commit
5. LifeView (grouping, filtering, analytics sections) → commit
6. New views (chart, heatmap, report, templates) → commit
7. Localization + tests → commit
