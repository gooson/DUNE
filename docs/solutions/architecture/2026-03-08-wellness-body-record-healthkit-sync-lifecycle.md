---
tags: [swiftui, healthkit, wellness, body-composition, body-record, sync-identifier, source-of-truth]
category: architecture
date: 2026-03-08
status: implemented
severity: important
related_files:
  - DUNE/Data/HealthKit/BodyCompositionQueryService.swift
  - DUNE/Data/HealthKit/BodyCompositionWriteService.swift
  - DUNE/Data/HealthKit/HealthKitManager.swift
  - DUNE/Presentation/BodyComposition/BodyCompositionViewModel.swift
  - DUNE/Presentation/Wellness/BodyHistoryDetailView.swift
  - DUNE/Presentation/Wellness/WellnessView.swift
  - DUNE/Presentation/Wellness/WellnessViewModel.swift
  - DUNETests/BodyCompositionViewModelTests.swift
  - DUNETests/BodyCompositionWriteServiceTests.swift
  - DUNETests/WellnessViewModelTests.swift
related_solutions:
  - docs/solutions/performance/2026-02-28-wellness-scrollview-infinite-bounce.md
---

# Solution: Wellness body record HealthKit sync lifecycle

## Problem

웰니스 탭의 `+ > Body Record` 수동 입력이 HealthKit 기반 카드, body history, 수정/삭제 흐름과 일관되게 연결되지 않았다.

### Symptoms

- body record를 추가해도 weight/body fat/lean body mass 카드가 새로 나타나지 않았다.
- Wellness는 HealthKit body metrics를 읽는데, form 저장은 SwiftData local record만 만들고 끝났다.
- 오늘 저장한 샘플은 일부 fetch 경로에서 제외되거나 오래된 값이 우선되어, write가 있더라도 최신 카드가 보장되지 않았다.
- create 경로만 HealthKit sync로 바꾸면 body history에 manual + HealthKit row가 같이 보여 duplicate가 생겼다.
- edit/delete가 local record만 바꾸면 Wellness 카드 값과 “Delete from all devices” 문구가 실제 동작과 어긋났다.

### Root Cause

원인은 세 겹이었다.

1. `WellnessView`의 body record 저장 경로가 `modelContext.insert(record)`만 수행하고 HealthKit에는 아무 sample도 쓰지 않았다.
2. `WellnessViewModel`의 body metric fetch는 오늘 sample을 우선 조회하지 않았다.
   - weight / lean body mass는 `fetchLatest…(withinDays:)` 경로가 사실상 과거 sample 중심이었다.
   - body fat은 최신값 대신 history의 오래된 끝값을 집는 경로가 있었다.
3. body record를 local SwiftData와 HealthKit 두 군데에 유지하면서도 stable linkage가 없었다.
   - create/edit/delete가 같은 HealthKit sample set를 다시 찾을 수 없었다.
   - history는 DUNE이 직접 쓴 HealthKit sample과 local record를 구분하지 못해 duplicate를 노출했다.
   - launch authorization과 body write authorization이 같은 API에 묶여 permission scope가 과도하게 넓어졌다.

결과적으로 수동 저장 직후에도 Wellness 카드 데이터 소스와 저장 데이터가 분리되어 있었다.

## Solution

수동 body record를 HealthKit card source와 local edit source가 분리되지 않도록 다시 설계했다.

- create/edit/delete 모두 `BodyCompositionWriteService`를 통과하도록 바꿨다.
- 각 HealthKit sample에는 `record.id` 기반 `HKMetadataKeySyncIdentifier`와 `HKMetadataKeySyncVersion`을 심어서, edit는 replace-upsert, delete는 metadata predicate로 같은 샘플 묶음을 정확히 제거한다.
- 여러 body metrics 저장은 `saveObjects`로 한 번에 처리해 partial write를 피한다.
- Body History는 DUNE이 쓴 sync-managed HealthKit sample을 숨기고 local record만 보여주도록 바꿔 duplicate row를 없앴다.
- 권한은 launch read authorization과 on-demand body write authorization으로 분리했다.
- Wellness body metric fetch는 오늘 sample을 먼저 조회하고, 없을 때만 older fallback을 사용하도록 유지했다.

### Changes Made

| File | Change | Reason |
|------|--------|--------|
| `DUNE/Data/HealthKit/BodyCompositionWriteService.swift` | Added sync-identifier based save/update/delete for body composition | create/edit/delete가 모두 같은 HealthKit sample set를 조작하도록 통일 |
| `DUNE/Data/HealthKit/HealthKitManager.swift` | Split general authorization from body write authorization | launch 시 과도한 body write prompt를 막고 save 시점에만 요청 |
| `DUNE/Presentation/BodyComposition/BodyCompositionViewModel.swift` | Added validated draft model and filtered sync-managed HK history | local apply/sync input 재사용과 history duplicate 제거 |
| `DUNE/Presentation/Wellness/WellnessView.swift` | Create/edit now sync HealthKit and reload Wellness | 저장/수정 직후 Physical 카드 일관성 보장 |
| `DUNE/Presentation/Wellness/BodyHistoryDetailView.swift` | Delete/edit now sync HealthKit and refresh history/cards | “Delete from all devices” 동작을 실제로 맞춤 |
| `DUNE/Presentation/Wellness/WellnessViewModel.swift` | Today-first lookup for weight/body fat/lean mass | 오늘 입력한 sample이 카드에 바로 반영되도록 보장 |
| `DUNETests/BodyCompositionWriteServiceTests.swift` | Added sync metadata tests | sample mapping과 metadata contract 회귀 방지 |
| `DUNETests/BodyCompositionViewModelTests.swift` | Added DUNE-managed HK history filtering tests | sync 후 body history duplicate가 다시 생기지 않도록 고정 |
| `DUNETests/WellnessViewModelTests.swift` | Added today-preferred body card tests | 오래된 sample보다 오늘 sample을 우선하는 계약 고정 |

### Key Code

```swift
try await BodyCompositionWriteService().save(
    recordID: record.id,
    input: draft.writeInput
)
modelContext.insert(record)
viewModel.loadData()
```

```swift
metadata: [
    HKMetadataKeySyncIdentifier: "com.dune.body-composition.<record-id>.<metric>",
    HKMetadataKeySyncVersion: NSNumber(value: syncVersion)
]
```

## Prevention

Wellness처럼 HealthKit read 모델이 명확한 화면에서 수동 입력 기능을 추가할 때는, create만 sync하고 edit/delete는 local-only로 두면 바로 source-of-truth가 갈라진다. local record가 계속 필요하다면, HealthKit object를 다시 찾을 수 있는 stable sync identifier를 처음부터 같이 설계해야 한다. 또한 "latest" helper가 오늘 sample을 제외하는지, history 배열이 newest-first인지 oldest-first인지 테스트로 고정해야 한다.

### Checklist Addition

- [ ] 수동 입력 기능이 존재하면, 저장 직후 해당 화면의 실제 read source가 갱신되는지 확인한다.
- [ ] write-first로 연결한 수동 입력은 edit/delete도 같은 external source를 갱신하는지 확인한다.
- [ ] HealthKit sample을 local model과 함께 유지해야 하면 stable sync identifier를 metadata에 남긴다.
- [ ] body metric/card fetch는 오늘 sample 우선 여부를 unit test로 고정한다.
- [ ] UI test runner에서 HealthKit entitlement가 빠진 환경이면 HK-dependent assertion을 억지로 추가하지 않고 unit coverage로 보완한다.

### Rule Addition (if applicable)

같은 유형이 반복되면 HealthKit read/write consistency 규칙으로 `.claude/rules/` 승격을 검토한다.

## Lessons Learned

수동 입력 폼을 추가했다고 해서 화면이 자동으로 풍부해지지 않는다. 그 화면이 어떤 source-of-truth를 읽는지 먼저 고정하고, create/edit/delete 전체를 그 source에 맞춰야 한다. HealthKit 중심 화면에서는 local SwiftData insert만으로는 사용자 기대인 "저장 직후 카드 반영"이 충족되지 않고, create만 sync하면 edit/delete 시점에 더 큰 정합성 문제가 생긴다.
