---
tags: [swiftui, healthkit, wellness, body-composition, body-record, refresh]
category: architecture
date: 2026-03-08
severity: important
related_files:
  - DUNE/Data/HealthKit/BodyCompositionWriteService.swift
  - DUNE/Presentation/Wellness/WellnessView.swift
  - DUNE/Presentation/Wellness/WellnessViewModel.swift
  - DUNETests/BodyCompositionWriteServiceTests.swift
  - DUNETests/WellnessViewModelTests.swift
related_solutions:
  - docs/solutions/performance/2026-02-28-wellness-scrollview-infinite-bounce.md
---

# Solution: Wellness manual body record HealthKit sync

## Problem

웰니스 탭에서 `+ > Body Record`로 수동 신체기록을 저장해도 `Physical` 섹션 카드가 갱신되지 않았다.

### Symptoms

- body record를 추가해도 weight/body fat/lean body mass 카드가 새로 나타나지 않았다.
- Wellness는 HealthKit body metrics를 읽는데, form 저장은 SwiftData local record만 만들고 끝났다.
- 오늘 저장한 샘플은 일부 fetch 경로에서 제외되거나 오래된 값이 우선되어, write가 있더라도 최신 카드가 보장되지 않았다.

### Root Cause

원인은 두 겹이었다.

1. `WellnessView`의 body record 저장 경로가 `modelContext.insert(record)`만 수행하고 HealthKit에는 아무 sample도 쓰지 않았다.
2. `WellnessViewModel`의 body metric fetch는 오늘 sample을 우선 조회하지 않았다.
   - weight / lean body mass는 `fetchLatest…(withinDays:)` 경로가 사실상 과거 sample 중심이었다.
   - body fat은 최신값 대신 history의 오래된 끝값을 집는 경로가 있었다.

결과적으로 수동 저장 직후에도 Wellness 카드 데이터 소스와 저장 데이터가 분리되어 있었다.

## Solution

수동 body record 저장을 HealthKit write-first 흐름으로 바꿨다. `BodyCompositionWriteService`가 weight, body fat, lean body mass sample을 HealthKit에 저장하고, 성공 시에만 local `BodyCompositionRecord`를 insert한 뒤 `WellnessViewModel.loadData()`를 다시 호출한다. 동시에 Wellness body metric fetch가 오늘 sample을 먼저 조회하고, 없을 때만 older fallback을 사용하도록 정리했다.

### Changes Made

| File | Change | Reason |
|------|--------|--------|
| `DUNE/Data/HealthKit/BodyCompositionWriteService.swift` | Added body composition HealthKit writer | manual body record를 Wellness card 데이터 소스인 HealthKit으로 연결 |
| `DUNE/Data/HealthKit/HealthKitManager.swift` | Added body share types to authorization request | body mass/body fat/lean mass write 권한 확보 |
| `DUNE/Presentation/BodyComposition/BodyCompositionFormSheet.swift` | Save action made async | HealthKit sync 실패 시 sheet를 닫지 않고 에러 유지 |
| `DUNE/Presentation/BodyComposition/BodyCompositionViewModel.swift` | Added `didFinishSaving()` and kept `isSaving` active until completion | async save 동안 중복 탭/상태 꼬임 방지 |
| `DUNE/Presentation/Wellness/WellnessView.swift` | Body save now writes HealthKit first, then inserts record and reloads Wellness | 저장 직후 Physical 카드 갱신 |
| `DUNE/Presentation/Wellness/WellnessViewModel.swift` | Today-first lookup for weight/body fat/lean mass | 오늘 입력한 sample이 카드에 바로 반영되도록 보장 |
| `DUNETests/BodyCompositionWriteServiceTests.swift` | Added sample conversion tests | kg/% → HealthKit sample mapping 회귀 방지 |
| `DUNETests/WellnessViewModelTests.swift` | Added today-preferred body card tests | 오래된 sample보다 오늘 sample을 우선하는 계약 고정 |

### Key Code

```swift
try await BodyCompositionWriteService().save(input)
modelContext.insert(record)
bodyViewModel.didFinishSaving()
bodyViewModel.resetForm()
bodyViewModel.isShowingAddSheet = false
viewModel.loadData()
```

```swift
if let todayWeight = try await bodyService.fetchWeight(start: todayStart, end: now).first {
    return (.weight, .vitalSample(VitalSample(value: todayWeight.value, date: todayWeight.date)))
}
```

## Prevention

Wellness처럼 HealthKit read 모델이 명확한 화면에서 수동 입력 기능을 추가할 때는, local persistence만 만들지 말고 실제 read source까지 같은 트랜잭션으로 연결해야 한다. 또한 "latest" helper가 오늘 sample을 제외하는지, history 배열이 newest-first인지 oldest-first인지 테스트로 고정해야 한다.

### Checklist Addition

- [ ] 수동 입력 기능이 존재하면, 저장 직후 해당 화면의 실제 read source가 갱신되는지 확인한다.
- [ ] body metric/card fetch는 오늘 sample 우선 여부를 unit test로 고정한다.
- [ ] UI test runner에서 HealthKit entitlement가 빠진 환경이면 HK-dependent assertion을 억지로 추가하지 않고 unit coverage로 보완한다.

### Rule Addition (if applicable)

같은 유형이 반복되면 HealthKit read/write consistency 규칙으로 `.claude/rules/` 승격을 검토한다.

## Lessons Learned

수동 입력 폼을 추가했다고 해서 화면이 자동으로 풍부해지지 않는다. 그 화면이 어떤 source-of-truth를 읽는지 먼저 고정하고, 저장 경로를 그 source에 맞춰야 한다. HealthKit 중심 화면에서는 local SwiftData insert만으로는 사용자 기대인 "저장 직후 카드 반영"이 충족되지 않는다.
