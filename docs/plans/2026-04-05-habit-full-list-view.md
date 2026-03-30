---
tags: [life-tab, habit, archive, list-view]
date: 2026-04-05
category: plan
status: draft
---

# Plan: 습관 전체 리스트 뷰 (아카이브 포함)

## Summary

"내 습관" 섹션 하단에 아카이브된 습관 N개 보기 링크를 추가하고, 활성/아카이브 탭 전환이 가능한 상세 리스트 화면을 구현한다. 각 습관 행에 통계(총 기록 횟수, 최장 스트릭, 생성일)를 표시하고, 아카이브된 습관에서 복원 및 히스토리 열람이 가능하도록 한다.

## Affected Files

| File | Change |
|------|--------|
| `DUNE/Presentation/Life/HabitManagementView.swift` | **새 파일** — 전체 습관 리스트 화면 (활성/아카이브 탭) |
| `DUNE/Presentation/Life/LifeView.swift` | habitsSection 하단에 아카이브 링크 추가 |
| `DUNE/Domain/UseCases/HabitStreakService.swift` | **새 파일** — 최장 스트릭 계산 유틸리티 (HabitHeatmapDetailView의 로직 추출) |
| `Shared/Resources/Localizable.xcstrings` | 새 문자열 en/ko/ja 등록 |
| `DUNE/DUNETests/HabitStreakServiceTests.swift` | **새 파일** — 스트릭 계산 테스트 |
| `DUNE/project.yml` | 새 파일 자동 포함 (xcodegen glob) |

## Implementation Steps

### Step 1: HabitStreakService 추출 (Domain)

HabitHeatmapDetailView.longestStreak의 로직을 Domain UseCase로 추출하여 재사용한다.

```swift
// DUNE/Domain/UseCases/HabitStreakService.swift
enum HabitStreakService {
    static func longestStreak(logs: [HabitLog], for habitID: UUID) -> Int
    static func totalCompletions(logs: [HabitLog], for habitID: UUID) -> Int
}
```

- logs를 날짜별로 그룹핑 → 연속 달성일 최대값 계산
- skip/snooze memo 제외 (기존 marker 활용)

### Step 2: HabitManagementView 구현 (Presentation)

```
┌─────────────────────────────────────┐
│  Habit Management                   │
│  [Active (5)] [Archived (3)]        │ ← Picker segmented
├─────────────────────────────────────┤
│  🏃 Exercise    12 times · 🔥7d    │
│  📖 Reading      8 times · Jan 2025 │
│  🧘 Meditation  24 times · 🔥14d   │
└─────────────────────────────────────┘
```

- `@Query` 2개: 활성 habits (`!isArchived`), 아카이브 habits (`isArchived`)
- `@State` Picker로 탭 전환
- 각 행: 아이콘 + 이름 + 총 기록 횟수 + 최장 스트릭 (>0일 때) + 생성일
- 아카이브 탭 액션: 복원 (swipe), 히스토리 (sheet)
- 활성 탭: 읽기 전용 통계 (편집은 LifeView에서)

### Step 3: LifeView에 진입 링크 추가

habitsSection 하단에 아카이브된 습관 링크 추가:
- 아카이브 count를 별도 `@Query`로 조회
- count > 0일 때만 표시
- `NavigationLink`로 HabitManagementView push

### Step 4: Localization

새 문자열을 xcstrings에 en/ko/ja 등록:
- "Habit Management" / "습관 관리" / "習慣管理"
- "Active" / "활성" / "アクティブ"
- "Archived" / "아카이브" / "アーカイブ"
- "%lld times" / "%lld회" / "%lld回"
- "Best streak %lld days" / "최장 %lld일 연속" / "最長%lld日連続"
- "Created %@" / "생성 %@" / "作成 %@"
- "Restore" / "복원" / "復元"
- "%lld archived habits" / "아카이브된 습관 %lld개" / "アーカイブ済み%lld個"

### Step 5: Unit Tests

HabitStreakService 테스트:
- 빈 로그 → 0
- 연속 3일 로그 → 3
- 중간 빠진 로그 → 올바른 최장 스트릭
- skip/snooze memo 제외
- totalCompletions 정확도

## Test Strategy

- **Unit**: HabitStreakService (streak 계산 정확도)
- **Build**: `scripts/build-ios.sh` 통과
- **UI**: HabitManagementView 기본 렌더링 검증

## Edge Cases

| Case | Handling |
|------|----------|
| 아카이브 습관 0개 | 하단 링크 숨김 |
| 활성 습관 0개 | 활성 탭에 EmptyStateView |
| 기록 0건 습관 | "0 times" 표시, 스트릭 배지 숨김 |
| 복원 시 sortOrder | `habits.count` (마지막에 추가) |
| 많은 습관 (50+) | LazyVStack으로 처리 |

## Risks

- **@Query 격리**: HabitManagementView는 독립 View이므로 `@Query`가 LifeView의 HabitListQueryView와 충돌하지 않음
- **아카이브 count Query**: LifeView에 추가 `@Query`를 넣으면 re-layout 유발 가능 → 별도 child view로 격리
