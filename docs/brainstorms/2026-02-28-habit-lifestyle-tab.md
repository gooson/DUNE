---
tags: [habit, lifestyle, tab, streak, swiftdata, auto-link]
date: 2026-02-28
category: brainstorm
status: draft
---

# Brainstorm: 습관 형성 라이프스타일 탭 (4번째 탭)

## Problem Statement

현재 DUNE 앱은 건강(Today), 운동(Activity), 웰니스(Wellness) 3개 탭으로 "측정" 중심 트래킹에 집중되어 있다. 그러나 사용자의 일상 라이프스타일 습관(비타민 복용, 학습, 코딩, 운동 등)을 추적하고 습관 형성을 도울 수 있는 기능이 없다.

**핵심 문제**: 건강 지표 모니터링만으로는 실제 행동 변화를 이끌기 어려움. 일상 습관을 체크하고 연속 달성(streak)을 시각화하여 습관 형성 동기를 부여해야 함.

## Target Users

- DUNE 앱 기존 사용자 (건강/운동 트래킹 활용 중)
- 비타민, 학습, 코딩 등 개인 습관을 기록하고 싶은 사람
- 운동 기록과 일상 습관을 하나의 앱에서 관리하고 싶은 사람

## Success Criteria

1. 사용자가 3종류(체크/시간/횟수) 습관을 생성하고 매일 기록할 수 있다
2. 운동 습관은 기존 ExerciseRecord에서 자동으로 체크된다
3. 연속 달성일(streak)이 습관별로 표시된다
4. 전 디바이스 CloudKit 동기화가 동작한다

## Proposed Approach

### 탭 위치 및 아이덴티티

- **4번째 탭**: AppSection enum에 `.lifestyle` case 추가
- **탭 아이콘**: `"checkmark.circle"` 또는 `"list.bullet.clipboard"` (SF Symbol)
- **탭 이름**: "Lifestyle" 또는 "Habits"
- **WavePreset**: 기존 탭과 구분되는 새 프리셋 컬러

### 습관 유형 (3종류)

| 유형 | 설명 | 목표 형태 | 예시 |
|------|------|-----------|------|
| **체크형 (Boolean)** | 했다/안했다 | 완료 여부 | 비타민 복용, 스트레칭 |
| **시간형 (Duration)** | 몇 분 했는지 | 최소 N분 | 코딩 60분, 어학 30분 |
| **횟수형 (Count)** | 몇 회 했는지 | 최소 N회 | 물 8잔, 독서 1챕터 |

### 데이터 모델 (SwiftData + CloudKit)

```swift
// Data Layer: @Model
@Model
final class HabitDefinition {
    var id: UUID
    var name: String           // "비타민 복용"
    var icon: String           // SF Symbol name
    var color: String          // hex or named color
    var habitType: String      // "check" | "duration" | "count"
    var goalValue: Double      // check=1, duration=분, count=횟수
    var goalUnit: String?      // "분", "잔", "챕터" 등
    var isAutoLinked: Bool     // 운동 자동 연동 여부
    var autoLinkSource: String? // "exercise" (향후 확장: "sleep", "steps")
    var sortOrder: Int         // 표시 순서
    var isArchived: Bool       // 삭제 대신 보관
    var createdAt: Date

    @Relationship(deleteRule: .cascade, inverse: \HabitLog.habitDefinition)
    var logs: [HabitLog]? = [] // CloudKit: Optional 필수 (#32)
}

@Model
final class HabitLog {
    var id: UUID
    var date: Date             // 날짜 (시간 제거, calendar day 기준)
    var value: Double          // check=1.0, duration=분, count=횟수
    var isAutoCompleted: Bool  // 자동 연동으로 완료된 경우
    var completedAt: Date?     // 실제 완료 시각
    var memo: String?

    var habitDefinition: HabitDefinition?  // inverse
}
```

### Domain 모델

```swift
// Domain Layer
struct Habit: Sendable {
    let id: UUID
    let name: String
    let icon: String
    let type: HabitType
    let goal: HabitGoal
    let isAutoLinked: Bool
    let autoLinkSource: AutoLinkSource?
}

enum HabitType: String, Sendable {
    case check
    case duration
    case count
}

struct HabitGoal: Sendable {
    let value: Double     // 목표값
    let unit: String?     // 단위 (nil이면 체크형)
}

enum AutoLinkSource: String, Sendable {
    case exercise
    // 향후: case sleep, steps
}

struct HabitProgress: Sendable {
    let habit: Habit
    let todayValue: Double
    let isCompleted: Bool   // todayValue >= goal.value
    let streak: Int         // 연속 달성일
    let completionRate: Double // 최근 30일 달성률
}
```

### 운동 자동 연동 로직

```
1. HabitDefinition.isAutoLinked == true && autoLinkSource == "exercise"
2. ViewModel.loadData() 시:
   - @Query로 오늘 날짜의 ExerciseRecord 존재 여부 확인
   - 존재하면 → HabitLog 자동 생성 (isAutoCompleted = true)
   - 미존재 → HabitLog 없음 (미완료 상태)
3. 사용자가 운동 기록을 삭제하면 → auto HabitLog도 삭제
```

### UI 구조

```
LifestyleView (Tab Root)
├── Hero Section: 오늘 달성률 (N/M 완료)
├── Habit List (ForEach)
│   ├── HabitRowView (체크형: 탭으로 토글)
│   ├── HabitRowView (시간형: 값 입력 → 진행 바)
│   └── HabitRowView (횟수형: +/- 버튼 → 진행 바)
├── Streak Overview: 전체 습관 연속 달성 요약
└── NavigationDestination
    ├── HabitDetailView (히스토리, 통계)
    └── HabitFormSheet (추가/편집)
```

### ViewModel 패턴

```swift
// Presentation Layer
@Observable
final class LifestyleViewModel {
    // State
    private(set) var habitProgresses: [HabitProgress] = []
    private(set) var overallCompletionRate: Double = 0
    private(set) var isLoading = false
    var validationError: String?

    // Habit CRUD (createValidatedRecord 패턴 #43)
    func createValidatedHabit() -> HabitDefinition? { ... }
    func createValidatedLog(for habit: HabitDefinition, value: Double) -> HabitLog? { ... }
    func didFinishSaving() { ... }

    // Auto-link
    func checkAutoLinkedHabits(exerciseRecords: [ExerciseRecord]) { ... }

    // Streak 계산
    func calculateStreak(logs: [HabitLog]) -> Int { ... }
}
```

## Constraints

### 기술적 제약
- **CloudKit**: `@Relationship`은 `Optional` 필수 (#32)
- **SwiftData**: `@Model` 스키마 변경 후 2회 실행 테스트 (#33)
- **레이어 경계**: ViewModel에 `import SwiftUI` 금지 (#7), `ModelContext` 전달 금지 (#2)
- **Navigation**: 탭 root `NavigationStack`은 ContentView에서만 생성 (navigation-ownership.md)

### 성능 제약
- Streak 계산: 최대 365일 탐색 (O(N) 허용, N ≤ 365)
- 습관 수 제한: MVP에서 최대 20개 권장 (ForEach 성능)
- 자동 연동: @Query 기반 반응형 (별도 polling 없음)

## Edge Cases

1. **첫 사용자 (습관 0개)**: 빈 상태 + "첫 습관 추가하기" CTA 표시
2. **자정 넘김**: `Calendar.startOfDay(for:)` 기준으로 날짜 구분. 타임존 변경 시 동일 날짜 중복 로그 방지
3. **CloudKit 동기화 충돌**: 같은 날짜+같은 습관 로그 2개 도착 시 → latest `completedAt` 우선
4. **운동 자동 연동 타이밍**: 운동 기록 후 습관 탭 방문 시 즉시 반영 (@Query reactive)
5. **습관 삭제**: `isArchived = true` 처리 (기존 로그 보존). 완전 삭제는 확인 다이얼로그 (#50)
6. **날짜 건너뛰기**: streak 중간에 빠진 날 → streak 리셋. 단, 미래 날짜 로그 입력 금지
7. **시간형 값 0분 입력**: 0분은 미완료 취급. 음수 입력 불가 (범위 검증)

## Scope

### MVP (Must-have)
- [ ] `HabitDefinition` + `HabitLog` SwiftData 모델
- [ ] Domain 모델 (`Habit`, `HabitType`, `HabitProgress`)
- [ ] `LifestyleViewModel` (CRUD + streak 계산)
- [ ] `LifestyleView` (탭 root, 오늘 습관 리스트)
- [ ] `HabitRowView` (3종류 유형별 입력 UI)
- [ ] `HabitFormSheet` (습관 추가/편집 폼)
- [ ] 운동 자동 연동 (ExerciseRecord 기반)
- [ ] 습관별 연속 달성일(streak) 표시
- [ ] 오늘 전체 달성률 Hero 섹션
- [ ] AppSection.lifestyle 추가 + ContentView 탭 등록
- [ ] WavePreset 새 컬러 추가
- [ ] 유닛 테스트 (ViewModel, streak 계산, validation)

### Nice-to-have (Future)
- [ ] 주간/월간 히스토리 캘린더 뷰
- [ ] 습관별 상세 통계 (달성률 차트, 평균값 추이)
- [ ] 수면 자동 연동 (HealthKit sleep → 수면 습관)
- [ ] 걸음수 자동 연동 (HealthKit steps → 만보 습관)
- [ ] 리마인더 알림 (UNUserNotification)
- [ ] 습관 카테고리/그룹핑
- [ ] Watch 앱 습관 체크 지원
- [ ] 습관 템플릿 (추천 습관 세트)
- [ ] GitHub contribution 스타일 히트맵
- [ ] 위젯 (iOS Widget)

## Open Questions

1. **탭 이름**: "Lifestyle" vs "Habits" vs "Daily" — 기존 탭(Today/Activity/Wellness)과의 톤 통일
2. **습관 아이콘**: 사용자가 SF Symbol을 직접 선택? 또는 카테고리별 고정 아이콘?
3. **습관 색상**: DS 토큰에서 선택? 또는 자유 색상 선택?
4. **과거 날짜 입력**: 어제 깜빡한 습관을 오늘 체크할 수 있어야 하는가?
5. **주간 목표**: 매일이 아닌 주 N회 목표(예: 주 3회 운동)도 MVP에 포함?

## Next Steps

- [ ] `/plan habit-lifestyle-tab` 으로 구현 계획 생성
- [ ] 탭 이름/아이콘 최종 결정
- [ ] HabitDefinition 스키마 확정 후 xcodegen 반영
