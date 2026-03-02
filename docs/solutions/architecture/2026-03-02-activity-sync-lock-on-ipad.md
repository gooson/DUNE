---
tags: [swiftui, activity, sync, task-cancellation, ipad]
category: architecture
date: 2026-03-02
severity: important
related_files:
  - DUNE/Presentation/Activity/ActivityView.swift
related_solutions:
  - architecture/2026-02-28-coordinated-healthkit-refresh.md
---

# Solution: Activity 탭 동기화 중 로딩 락(아이패드) 완화

## Problem

아이패드에서 Activity 탭 진입 직후 SwiftData/CloudKit 동기화가 진행되면 화면이 "동기화 중" 상태처럼 오래 멈춘다는 제보가 있었다.

### Symptoms

- Activity 탭 최초 진입 시 로딩이 길게 지속됨
- 동기화 이벤트가 많은 계정에서 체감이 심함
- pull-to-refresh 없이는 화면이 갱신되지 않는 것처럼 보임

### Root Cause

`ActivityView`가 `.task(id: "\(recentRecords.count)-\(refreshSignal)")`를 사용해,
`recentRecords.count` 변경(동기화 중 연속 insert/delete)마다 task를 취소/재시작했다.

해당 task 내부에서 `loadActivityData()`(HealthKit 병렬 조회 포함)까지 수행하므로,
동기화 churn 동안 로드가 안정적으로 완료되지 못해 UI가 고착된 것처럼 보였다.

## Solution

무거운 재로드 경로와 동기화 변화 경로를 분리했다.

### Changes Made

| File | Change | Reason |
|------|--------|--------|
| `DUNE/Presentation/Activity/ActivityView.swift` | `.task(id:)`를 `refreshSignal` 전용으로 변경 | 동기화 이벤트에 의한 load 취소 폭주 차단 |
| `DUNE/Presentation/Activity/ActivityView.swift` | `recentRecords.count` 변경은 `onChange`에서 `updateSuggestion + recomputeInjuryConflicts`만 수행 | 동기화 시 파생 UI는 갱신하되 HealthKit 재질의는 회피 |

### Key Code

```swift
.task(id: refreshSignal) {
    viewModel.updateSuggestion(records: recentRecords)
    await viewModel.loadActivityData()
    recomputeInjuryConflicts()
}
.onChange(of: recentRecords.count) { _, _ in
    viewModel.updateSuggestion(records: recentRecords)
    recomputeInjuryConflicts()
}
```

## Prevention

리프레시 트리거를 설계할 때 "데이터 변화 감지"와 "원격/고비용 재질의"를 같은 task id에 묶지 않는다.

### Checklist Addition

- [ ] `.task(id:)` 키에 동기화 churn이 큰 값(`@Query.count`)을 넣을 때 취소 폭주 가능성 검토
- [ ] 파생 상태 갱신(`ViewModel` 계산)과 원격 조회(HealthKit/API)를 분리

### Rule Addition (if applicable)

반복 패턴이 확인되면 refresh 관련 룰 문서에 "heavy load는 coordinator signal 기반" 항목 추가를 검토한다.

## Lessons Learned

`task(id:)`는 간결하지만, ID 선택이 곧 취소 모델을 결정한다.
동기화 빈도가 높은 값과 고비용 async 로직을 직접 결합하면 UI 락으로 보이는 체감 문제가 빠르게 발생한다.
