---
tags: [habit, tab, swiftdata, cloudkit, streak, auto-link]
date: 2026-02-28
category: solution
status: implemented
---

# Habit Tab Implementation Patterns

## Problem

4번째 탭 "Life"를 추가하여 습관(체크/시간/횟수) 추적 + 운동 자동 연동 + streak 시각화를 구현해야 함.

## Solution

### 1. 새 탭 추가 체크리스트

새 탭 추가 시 수정해야 하는 파일 목록:

| File | Change |
|------|--------|
| `App/AppSection.swift` | enum case 추가 (title, icon) |
| `App/ContentView.swift` | Tab 등록, scrollToTopSignal @State, tabSelection switch |
| `Presentation/Shared/Components/WavePreset.swift` | wave case 추가 (amplitude, frequency, opacity) |
| `Presentation/Shared/DesignSystem.swift` | `DS.Color.tab{Name}` 토큰 |
| `Resources/Assets.xcassets/Colors/Tab{Name}.colorset/` | 색상 정의 |
| `App/DUNEApp.swift` | ModelContainer(for:) 양쪽 path (try + catch) |
| `Data/Persistence/Migration/AppSchemaVersions.swift` | 새 Schema version + migration stage |

### 2. 3종류 습관 유형 패턴

```swift
enum HabitType: String, CaseIterable {
    case check    // Boolean: goal = 1.0
    case duration // Minutes: goal = N분
    case count    // Count: goal = N회
}
```

- 모든 타입은 `goalValue: Double` 단일 필드로 통합
- `goalUnit: String?`로 유연한 단위 표시
- UI 입력은 타입별 분기: check=탭 토글, duration=값 입력, count=스테퍼

### 3. 운동 자동 연동 패턴

```
HabitDefinition.isAutoLinked == true
  + autoLinkSourceRaw == "exercise"
  → ViewModel.calculateProgresses()에서 todayExerciseExists 파라미터로 판단
  → 실제 HabitLog 생성 없이 UI에서 완료 표시 (effectiveValue)
```

장점: ExerciseRecord 삭제/추가 시 자동 반영, 별도 sync 불필요.

### 4. Streak 계산 패턴

- Daily: 오늘부터 역방향 연속 달성일 카운트 (startOfDay 기준)
- Weekly: 현재 주부터 역방향 연속 달성 주 카운트 (주 내 N일 이상)
- 중복 날짜 dedup: `Set<Date>`로 처리
- 최대 52주(365일) 탐색 제한

### 5. Isolated @Query Child View 패턴

```swift
// Parent: 순수 UI + ViewModel
struct LifeView: View { ... }

// Child 1: @Query for habits — isolated re-render scope
private struct HabitListQueryView: View {
    @Query var habits: [HabitDefinition]
    ...
}

// Child 2: @Query for exercise check — independent observation
private struct TodayExerciseCheckView: View {
    @Query var recentRecords: [ExerciseRecord]
    @Binding var exists: Bool
    ...
}
```

이유: Correction #179 — @Query + ScrollView 동일 View에서 bounce loop 방지.

### 6. O(1) Lookup Dictionary 패턴

```swift
@State private var habitsByID: [UUID: HabitDefinition] = [:]

private func recalculate() {
    habitsByID = Dictionary(habits.map { ($0.id, $0) }, uniquingKeysWith: { _, last in last })
    // ForEach 내 contextMenu에서 habitsByID[progress.id]로 O(1) 접근
}
```

## Prevention

- 새 탭 추가 시 이 문서의 체크리스트를 따를 것
- `@Query`는 반드시 isolated child view에 배치
- ForEach 내 lookup은 항상 Dictionary 캐시 사용 (Correction #68)
- 새 `@Model` 추가 시 Schema version 증가 + DUNEApp ModelContainer 양쪽 path 업데이트
