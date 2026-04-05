---
tags: [habit, archive, list-view, navigation, query-isolation]
date: 2026-04-05
category: solution
status: implemented
---

# Habit Archive Management View

## Problem

아카이브된 습관은 `@Query(filter: !$0.isArchived)` 필터에 의해 완전히 숨겨지며, 복원하거나 과거 기록을 열람할 수 있는 UI가 없었다. 사용자가 예전에 생성한 습관이 보이지 않아 데이터가 사라진 것으로 오해할 수 있었다.

## Solution

### 1. ArchivedHabitCountView (격리된 @Query)

```swift
private struct ArchivedHabitCountView: View {
    @Query(filter: #Predicate<HabitDefinition> { $0.isArchived })
    private var archivedHabits: [HabitDefinition]
    // NavigationLink(value: LifeRoute.habitManagement) ...
}
```

- Correction #179 패턴에 따라 별도 View로 격리
- "내 습관" 섹션 하단에 배치 (habits.isEmpty 분기 바깥)
- 아카이브 0개이면 자동 숨김

### 2. HabitManagementView (활성/아카이브 탭 전환)

- 2개의 `@Query`: 활성 (`!isArchived`) + 아카이브 (`isArchived`)
- `Picker(.segmented)` 로 탭 전환
- 각 행: 아이콘 + 이름 + 총 기록 횟수 + 최장 스트릭 + 생성일
- 아카이브 탭: 복원 + 히스토리 열람

### 3. HabitStreakService 확장

기존 `calculateStreak(completedDates:frequency:referenceDate:)`에 snapshot 기반 메서드 추가:
- `longestStreak(logs:for:)`: 최장 연속 달성일 계산
- `totalCompletions(logs:for:)`: skip/snooze 제외 총 완료 횟수

### 4. 성능 최적화

`logSnapshots` 를 body path에서 계산하지 않고 `.task(id:)` + `@State` 캐싱:
```swift
@State private var cachedStats: [UUID: (total: Int, bestStreak: Int)] = [:]
.task(id: logSignature) { /* batch compute */ }
```

## Prevention

- `isArchived` 같은 soft-delete 플래그를 사용하는 기능에는 반드시 복원 경로를 함께 구현
- `@Query` 격리 패턴은 새 쿼리 추가 시마다 적용 (Correction #179)
- 리스트 통계 계산은 `.task(id:)` 캐싱으로 body 재평가 비용 제거

## Lessons Learned

- `habits.isEmpty` 분기 안에 아카이브 링크를 넣으면 모든 활성 습관이 아카이브된 후 링크 자체가 사라지는 edge case 발생
- UI 테스트에서 in-session archive → @Query 관찰은 타이밍 불안정 — archive flow는 수동 검증 권장
