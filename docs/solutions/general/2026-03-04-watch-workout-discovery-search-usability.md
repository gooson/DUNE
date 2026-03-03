---
tags: [watchos, quick-start, exercise-search, category-filter, aliases, equipment-keywords]
category: general
date: 2026-03-04
severity: important
related_files:
  - DUNE/Domain/Models/WatchConnectivityModels.swift
  - DUNE/Data/WatchConnectivity/WatchSessionManager.swift
  - DUNEWatch/Helpers/WatchExerciseHelpers.swift
  - DUNEWatch/Views/QuickStartAllExercisesView.swift
  - DUNEWatchTests/WatchExerciseHelpersTests.swift
related_solutions:
  - docs/solutions/architecture/2026-02-28-watch-carousel-home-pattern.md
  - docs/solutions/general/2026-03-02-title-policy-watch-localization-fixes.md
  - docs/solutions/general/2026-03-03-watch-reinstall-exercise-sync-feedback.md
---

# Solution: Apple Watch 운동 탐색 정확도 개선 (카테고리 필터 + 별칭/기구 검색)

## Problem

### Symptoms

- Watch `All Exercises`에서 운동명을 정확히 모르면 원하는 운동을 빠르게 찾기 어려웠다.
- 기존 검색이 `exercise.name` 단순 contains만 사용해, 기구명/동의어 기반 탐색이 자주 실패했다.
- 탐색 범위를 즉시 좁히는 카테고리 필터가 없어 리스트 스캔 비용이 높았다.

### Root Cause

watch exercise payload(`WatchExerciseInfo`)에 검색 보조 메타데이터(alias)가 없었고, UI 레벨 검색 로직도 이름 문자열 1개만 비교했다. 또한 카테고리 선택 상태가 별도로 존재하지 않아 검색과 필터를 결합한 탐색 경로가 없었다.

## Solution

검색 데이터 확장(aliases) + 순수 검색 헬퍼 + View 필터 UI를 결합해 탐색 정확도를 올렸다.

### Changes Made

| File | Change | Reason |
|------|--------|--------|
| `WatchConnectivityModels.swift` | `WatchExerciseInfo.aliases` optional 필드 추가 | watch 검색 시 동의어 매칭 지원 |
| `WatchSessionManager.swift` | iPhone→Watch sync payload에 `ExerciseDefinition.aliases` 전달 | watch가 source-of-truth alias를 직접 보유 |
| `WatchExerciseHelpers.swift` | `WatchExerciseCategory`, 검색 토큰 정규화, `filterWatchExercises`, `groupedWatchExercisesByCategory` 추가 | View 로직을 테스트 가능한 순수 함수로 분리 |
| `QuickStartAllExercisesView.swift` | 카테고리 Picker 도입 + helper 기반 검색/그룹핑 교체 | 카테고리 필터와 검색을 결합한 UX 제공 |
| `WatchExerciseHelpersTests.swift` | category mapping, alias/equipment 검색, filter 결합 테스트 추가 | 회귀 방지 |

### Key Code

```swift
cachedFiltered = filterWatchExercises(
    exercises: unique,
    query: searchText,
    category: selectedCategory
)
```

## Prevention

### Checklist Addition

- [ ] Watch 검색 기능 변경 시 `name` 단독 매칭이 아닌 alias/equipment/category 토큰 포함 여부 확인
- [ ] watchOS 전용 UI 제어(`Menu` 등) 추가 전 플랫폼 가용성 검증
- [ ] 검색/필터 로직은 View body가 아닌 helper 순수 함수로 유지하고 단위 테스트 추가

### Rule Addition (if applicable)

기존 `testing-required.md`, `watch-navigation.md`, `localization.md` 범위에서 관리 가능하여 신규 규칙 파일 추가는 생략했다.

## Lessons Learned

- watch 검색 UX는 입력 방식(키보드/Dictation)보다 매칭 품질이 체감 속도에 더 큰 영향을 준다.
- payload에 최소한의 검색 메타데이터를 싣고, watch에서 이를 조합해 필터링하면 iPhone 의존 없이도 탐색 품질을 안정적으로 높일 수 있다.
