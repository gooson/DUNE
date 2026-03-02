---
tags: [activity-tab, ipad, sync-burst, mainactor, debounce, task-cancellation, toast-feedback]
category: performance
date: 2026-03-02
severity: important
related_files:
  - DUNE/Presentation/Activity/ActivityView.swift
  - DUNE/Presentation/Activity/ActivityViewModel.swift
  - DUNETests/ActivityViewModelTests.swift
related_solutions:
  - docs/plans/2026-03-02-activity-sync-lock-on-ipad.md
  - docs/solutions/general/2026-02-24-activity-pr-cardio-healthkit-review-fixes.md
  - docs/solutions/performance/2026-02-16-review-triage-task-cancellation-and-caching.md
---

# Solution: iPad Activity 탭 sync burst 중 UI 무반응 재발 완화

## Problem

iPad에서 앱 실행 직후 Activity 탭 진입 시, 백그라운드 sync(CloudKit/SwiftData) 구간에서 UI 무반응/스크롤 정지가 재발했다.

### Symptoms

- Activity 탭 진입 직후 스크롤 반응이 끊기거나 멈춤
- 동기화 이벤트가 연속 발생할 때 파생 계산(추천/PR/빈도)이 반복 실행됨
- 실패 피드백이 하단 텍스트라 사용자가 즉시 인지하기 어려움

### Root Cause

- `recentRecords` 변경마다 파생 계산이 연속 트리거되어 메인 actor 계산이 폭주
- 대량 루프(파생 snapshot, cardio seed)가 메인 점유를 길게 가져갈 수 있음
- sync 에러 피드백이 비가시적인 위치(하단)에 있어 재시도 흐름이 약함

## Solution

sync burst를 coalescing하고, 대량 계산을 chunked-yield로 분산하며, 상단 toast 기반 에러 피드백을 추가했다.

### Changes Made

| File | Change | Reason |
|------|--------|--------|
| `DUNE/Presentation/Activity/ActivityView.swift` | `recentRecords` 갱신을 `task(id: recordsUpdateKey)` + async refresh로 분리 | 동기화 폭주 시 중복 계산 취소/합치기 |
| `DUNE/Presentation/Activity/ActivityView.swift` | 상단 `ActivitySyncToast` overlay + Retry 버튼 추가 | sync 실패를 즉시 인지하고 재시도 가능 |
| `DUNE/Presentation/Activity/ActivityViewModel.swift` | `refreshSuggestionFromRecords`(debounce + cancellation + `Task.yield`) 추가 | 메인 스레드 starvation 완화 |
| `DUNE/Presentation/Activity/ActivityViewModel.swift` | cardio PR seed 루프에 배치 `Task.yield()` 적용, personal record 재계산 범위 축소 | 초기 진입 시 대용량 처리로 인한 프리징 완화 |
| `DUNETests/ActivityViewModelTests.swift` | async refresh 즉시 반영/취소 경로 테스트 추가 | coalescing 회귀 방지 |

### Key Code

```swift
// ActivityView: sync burst coalescing
.task(id: recordsUpdateKey) {
    await viewModel.refreshSuggestionFromRecords(recentRecords)
    recomputeInjuryConflicts()
}
```

```swift
// ActivityViewModel: debounce + cancellation + yield
func refreshSuggestionFromRecords(_ records: [ExerciseRecord], debounceNanoseconds: UInt64 = 180_000_000) async {
    try? await Task.sleep(nanoseconds: debounceNanoseconds)
    guard !Task.isCancelled else { return }
    var snapshots: [ExerciseRecordSnapshot] = []
    for (index, record) in records.enumerated() {
        snapshots.append(buildExerciseRecordSnapshot(from: record))
        if index > 0, index.isMultiple(of: 80) { await Task.yield() }
    }
    guard !Task.isCancelled else { return }
    manualRecordsCache = records
    exerciseRecordSnapshots = snapshots
    recomputeFatigueAndSuggestion()
    recomputeDerivedStats()
}
```

## Prevention

### Checklist Addition

- [ ] SwiftData sync 변화가 잦은 화면은 `onChange(count)` 직결 계산 대신 cancellable `task(id:)` + debounce를 우선 검토한다.
- [ ] `@MainActor` ViewModel의 대량 루프는 일정 배치마다 `Task.yield()`로 UI starvation을 완화한다.
- [ ] 취소 가능한 async 경로에서 상태 캐시는 원자적으로(부분 반영 없이) 갱신한다.
- [ ] sync 실패 피드백은 화면 상단의 즉시 인지 가능한 위치 + retry 액션을 제공한다.

### Rule Addition (if applicable)

현재는 새 rule 파일 추가 대신 성능/리뷰 체크리스트로 반영한다.

## Lessons Learned

트리거 분리만으로는 재발을 막기 어렵고, sync burst 상황에서는 “계산 호출 빈도 제어(coalescing)”와 “한 번의 계산 중 메인 점유 분산(yield)”을 함께 적용해야 체감 락을 줄일 수 있다.
