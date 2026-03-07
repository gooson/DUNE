---
tags: [exercise, canonicalization, quick-start, watchos, ios, search, duplicates]
category: general
date: 2026-03-07
severity: important
related_files:
  - DUNE/Data/ExerciseLibraryService.swift
  - DUNE/Domain/Protocols/ExerciseLibraryQuerying.swift
  - DUNE/Domain/UseCases/QuickStartPopularityService.swift
  - DUNE/Presentation/Exercise/Components/ExercisePickerView.swift
  - DUNEWatch/Managers/RecentExerciseTracker.swift
related_solutions:
  - docs/solutions/general/2026-02-26-quickstart-ia-usage-tracking-consistency.md
---

# Solution: 운동 변형 노출을 canonical 대표 1개로 정리

## Problem

운동 라이브러리에서 같은 본운동이 `intervals`, `endurance`, `recovery`, `recovery-flow` 같은 변형 ID로 함께 노출되어 선택 목록이 과도하게 길어지고, cardio/flexibility 계열에서 중복 체감이 커졌다.

### Symptoms

- `Running`, `Running Intervals`, `Running Endurance`, `Running Recovery`가 동시에 보였다.
- `Yoga`와 `Yoga Recovery Flow`가 별도 운동처럼 같이 노출됐다.
- Quick Start recent/popular이 과거 variant ID를 그대로 보여 주어 대표 운동이 아닌 변형 이름이 다시 드러났다.

### Root Cause

기존 canonical 규칙은 `tempo`, `paused`, `endurance` 중심으로 설계되어 있었고, Exercise library의 `allExercises/search/filter`는 원본 JSON 엔트리를 그대로 노출했다. 원본 variant ID는 기록/템플릿 호환성 때문에 유지해야 하지만, 노출 계층이 raw 데이터를 그대로 사용한 것이 중복의 직접 원인이었다.

## Solution

원본 exercise definition과 exact ID lookup은 유지하고, 외부에 노출하는 목록/검색만 canonical 대표 exercise 기준으로 축약했다. 동시에 iPhone/Watch canonical 규칙을 `interval`, `recovery`, `recovery-flow`까지 확장해 dedup 기준을 맞췄다.

### Changes Made

| File | Change | Reason |
|------|--------|--------|
| `DUNE/Data/ExerciseLibraryService.swift` | canonical representative index 추가, `allExercises/search/exercises(for*)`를 대표 exercise 기준으로 노출 | iPhone/Watch/설정/추천 경로를 서비스 레이어 한 곳에서 정리 |
| `DUNE/Domain/Protocols/ExerciseLibraryQuerying.swift` | `representativeExercise(byID:)` 추가 | 과거 variant ID를 recent/popular에 표시할 때도 대표 운동으로 치환 |
| `DUNE/Domain/UseCases/QuickStartPopularityService.swift` | canonical suffix/name 규칙에 interval/recovery 계열 추가 | iPhone Quick Start와 검색 dedup 기준 확장 |
| `DUNEWatch/Managers/RecentExerciseTracker.swift` | Watch canonical ID 규칙 동일 확장 | Watch personalized/recent dedup 기준 parity 유지 |
| `DUNETests/*`, `DUNEWatchTests/*` | canonical rule, exact lookup, representative lookup, search dedup 테스트 추가 | 회귀 방지 |

### Key Code

```swift
func allExercises() -> [ExerciseDefinition] {
    visibleExercises
}

func search(query: String) -> [ExerciseDefinition] {
    guard !query.isEmpty else { return visibleExercises }

    var seenCanonicalKeys = Set<String>()
    var results: [ExerciseDefinition] = []

    for exercise in exercises where Self.matchesSearchQuery(query, exercise: exercise) {
        let canonicalKey = Self.canonicalKey(for: exercise)
        guard seenCanonicalKeys.insert(canonicalKey).inserted else { continue }
        results.append(representativeByCanonicalKey[canonicalKey] ?? exercise)
    }

    return results
}
```

## Prevention

### Checklist Addition

- [ ] exercise library에 새 variant ID를 추가할 때 `allExercises/search`가 canonical 대표 1개만 노출하는지 확인
- [ ] iPhone `QuickStartCanonicalService`와 Watch `RecentExerciseTracker`의 canonical suffix 세트가 동일한지 확인
- [ ] raw ID lookup 유지가 필요한 화면(기록 상세, 템플릿 복원)과 대표 노출이 필요한 화면(선택/검색/추천)을 구분했는지 확인

### Rule Addition (if applicable)

새 규칙 파일 추가는 보류. 이번 패턴은 exercise library canonicalization 체크리스트로 충분하다.

## Lessons Learned

- 원본 데이터 호환성이 필요한 경우, JSON 삭제보다 서비스 레이어의 “visible vs exact lookup” 분리가 안전하다.
- canonical 규칙이 iPhone/Watch 중 한쪽에만 반영되면 중복 노출이 다시 생기므로 suffix 세트를 함께 관리해야 한다.
- 검색은 대표 exercise만 보여주더라도 raw variant를 검색 소스로 유지해야 `interval`, `recovery` 같은 키워드 유입을 잃지 않는다.
