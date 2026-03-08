---
tags: [swiftui, swiftdata, wellness, body-composition, empty-state, ui-regression]
category: architecture
date: 2026-03-08
severity: important
related_files:
  - DUNE/Presentation/Wellness/WellnessView.swift
  - DUNEUITests/Smoke/WellnessSmokeTests.swift
related_solutions:
  - docs/solutions/performance/2026-02-28-wellness-scrollview-infinite-bounce.md
  - docs/solutions/testing/2026-03-02-nightly-full-ui-test-hardening.md
---

# Solution: Wellness manual body record empty state

## Problem

웰니스 탭에서 `+ > Body Record`로 수동 신체기록을 저장해도 화면에 아무 카드나 링크가 나타나지 않았다.

### Symptoms

- HealthKit 기반 wellness card가 하나도 없는 상태에서 body record를 저장해도 웰니스 탭이 계속 `No Wellness Data` empty state에 머문다.
- 저장은 정상적으로 되지만 사용자가 body history 화면으로 진입할 경로가 보이지 않는다.

### Root Cause

`WellnessView`는 empty-state 여부를 `WellnessViewModel`의 `physicalCards`, `activeCards`, `wellnessScore`만으로 결정했다. 반면 수동 body record와 injury record는 이전 성능 수정에서 부모 re-layout을 막기 위해 isolated `@Query` child view로 분리되어 있었다. 그 결과 SwiftData 기반 기록이 존재해도 부모 분기가 계속 empty state를 선택했고, child view가 마운트되지 않아 body history 링크가 숨겨졌다.

## Solution

HealthKit-driven root gate는 유지하고, "HealthKit card는 없지만 SwiftData 수동 기록은 있는 상태"만 처리하는 `WellnessFallbackStateView`를 추가했다. 이 fallback child view가 자체 `@Query`로 body/injury record 존재 여부를 판단해 empty state 또는 수동 기록 entry UI를 렌더링한다. 동시에 body history link에 AXID를 부여하고, 저장 직후 링크가 나타나는 smoke UI test를 추가했다.

### Changes Made

| File | Change | Reason |
|------|--------|--------|
| `DUNE/Presentation/Wellness/WellnessView.swift` | empty-state 분기에서 `WellnessFallbackStateView` 사용, body history link AXID 추가 | 수동 기록만 있는 상태에서도 UI entry를 노출하면서 root `@Query` 회귀를 피하기 위해 |
| `DUNEUITests/Smoke/WellnessSmokeTests.swift` | body record 저장 후 history link 노출 검증 추가 | 동일 regression 재발 방지 |

### Key Code

```swift
} else if viewModel.physicalCards.isEmpty &&
            viewModel.activeCards.isEmpty &&
            viewModel.wellnessScore == nil &&
            !viewModel.isLoading {
    WellnessFallbackStateView(
        isMirroredReadOnlyMode: viewModel.isMirroredReadOnlyMode,
        onEditInjury: { record in injuryViewModel.startEditing(record) },
        onAddInjury: { startAddingInjury() }
    )
}
```

## Prevention

향후 성능 이유로 `@Query`를 child view로 분리할 때는, 부모의 empty-state gating이 그 child-backed content 존재 여부를 여전히 반영하는지 반드시 함께 검토해야 한다.

### Checklist Addition

- [ ] SwiftData `@Query`를 child view로 격리한 뒤, 부모 empty-state 조건이 숨겨진 child content를 놓치지 않는지 확인한다.
- [ ] 수동 입력으로만 진입 가능한 fallback UI에는 저장 직후 노출을 검증하는 smoke test를 추가한다.

### Rule Addition (if applicable)

이번 패턴은 solution doc으로 우선 축적하고, 동일 유형이 반복되면 `.claude/rules/` 승격을 검토한다.

## Lessons Learned

성능 최적화를 위해 관찰 범위를 분리할 때는 "데이터를 누가 관찰하느냐"뿐 아니라 "화면 진입 조건이 그 데이터를 알고 있느냐"도 같이 설계해야 한다. root gate와 isolated child view가 서로 다른 데이터 소스를 기준으로 판단하면 저장 성공 후에도 UI가 비어 있는 상태가 발생한다.
