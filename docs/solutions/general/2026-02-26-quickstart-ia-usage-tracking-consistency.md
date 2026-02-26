---
tags: [swiftui, ios, watchos, quick-start, personalization, canonicalization, userdefaults, information-architecture, duplicate-counting]
category: general
date: 2026-02-26
severity: important
related_files:
  - DUNE/Presentation/Exercise/Components/ExercisePickerView.swift
  - DUNEWatch/Views/WorkoutPreviewView.swift
  - DUNEWatch/Managers/RecentExerciseTracker.swift
  - DUNEWatch/Views/QuickStartPickerView.swift
related_solutions:
  - 2026-02-18-watch-ios-review-p1-p3-comprehensive-fix.md
---

# Solution: Quick Start IA 일관성 및 사용량 집계 왜곡 수정

## Problem

Quick Start 개선(대표 운동 우선 노출 + canonical 통합) 이후, iPhone/Watch 간 동작 불일치와 인기 랭킹 왜곡 요인이 함께 남아 있었습니다.

### Symptoms

- Watch에서 운동 시작 시점과 저장 시점 모두 `usage`가 증가해 Popular 랭킹이 과대 집계됨
- iPhone Quick Start에서 동일 canonical 운동이 `Popular`와 `Recent`에 동시에 노출됨
- iPhone Quick Start가 기본 허브 상태에서도 검색으로 전체 목록에 바로 진입 가능해 `+` 진입 정책과 불일치
- Watch Recent 정렬 시 `UserDefaults`를 비교 과정마다 반복 조회함

### Root Cause

- 이벤트 카운트 책임이 단일 지점으로 고정되지 않아 `recordUsage`가 중복 호출됨
- iPhone 허브 섹션 구성에서 Popular canonical 제외 규칙이 누락됨
- 검색바 활성 조건이 Quick Start 허브 상태를 구분하지 않도록 설계됨
- 정렬 비교 클로저에서 `lastUsed(exerciseID:)`를 직접 호출해 조회 비용이 반복됨

## Solution

4개 파일에서 집계, IA, 조회 경로를 정리했습니다.

### Changes Made

| File | Change | Reason |
|------|--------|--------|
| `DUNEWatch/Views/WorkoutPreviewView.swift` | 시작 시 `recordUsage` 호출 제거 | 사용량 집계를 저장 시점 단일 경로로 고정 |
| `DUNE/Presentation/Exercise/Components/ExercisePickerView.swift` | Quick Start 허브에서 검색바 비활성, `Recent`에서 `Popular` canonical 제외, `Hide` 시 검색어 초기화 | iPhone IA를 Watch 정책과 일치 |
| `DUNEWatch/Managers/RecentExerciseTracker.swift` | `lastUsedTimestamps()` 스냅샷 API 추가 | 배치 정렬/필터에서 반복 조회 제거 |
| `DUNEWatch/Views/QuickStartPickerView.swift` | Recent 계산 시 스냅샷 기반 정렬/필터 사용 | 불필요한 `UserDefaults` 반복 접근 감소 |

### Key Code

```swift
// usage 집계를 저장 시점으로 단일화
try await workoutManager.startQuickWorkout(with: snapshot)
WKInterfaceDevice.current().play(.success)
```

```swift
private var shouldShowSearchBar: Bool {
    !isQuickStartMode || showingAllQuickStartExercises
}
```

```swift
let lastUsed = RecentExerciseTracker.lastUsedTimestamps()
let sorted = library
    .filter { lastUsed[$0.id] != nil }
    .sorted { (lastUsed[$0.id] ?? .zero) > (lastUsed[$1.id] ?? .zero) }
```

## Prevention

### Checklist Addition

- [ ] 사용자 행동 카운트(`usage`, analytics)는 단일 이벤트 소스에서만 증가시키는지 확인
- [ ] Quick Start `Popular`/`Recent` 섹션은 canonical 중복 제거 규칙을 공통 적용하는지 확인
- [ ] iPhone/Watch IA 정책(기본 허브 vs 전체 확장)이 동일하게 구현되었는지 확인
- [ ] 정렬 비교 클로저에서 저장소 조회를 직접 호출하지 않고 스냅샷/캐시를 사용하는지 확인

### Rule Addition (if applicable)

신규 규칙 파일 추가는 보류. 이번 케이스는 Quick Start 관련 리뷰 체크리스트 항목으로 관리합니다.

## Lessons Learned

- 개인화 랭킹 기능은 집계 이벤트가 한 번만 중복돼도 체감 결과가 빠르게 왜곡된다.
- IA 정책은 플랫폼별 구현 편차가 작아 보여도 실제 사용자 흐름에 큰 차이를 만든다.
- 저장소 조회 API는 편의 메서드와 배치용 스냅샷 메서드를 분리해야 성능 회귀를 막기 쉽다.
