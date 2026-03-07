---
tags: [quick-start, preferred-exercises, settings, apple-watch, watchconnectivity, swiftdata, migration]
category: architecture
date: 2026-03-07
severity: important
related_files:
  - DUNE/Data/Persistence/Migration/AppSchemaVersions.swift
  - DUNE/Data/Persistence/Models/ExerciseDefaultRecord.swift
  - DUNE/Data/WatchConnectivity/WatchSessionManager.swift
  - DUNE/Domain/Models/WatchConnectivityModels.swift
  - DUNE/Domain/UseCases/QuickStartSectionOrderingService.swift
  - DUNE/Presentation/Exercise/Components/ExercisePickerView.swift
  - DUNE/Presentation/Settings/Components/ExerciseDefaultEditView.swift
  - DUNE/Presentation/Settings/Components/PreferredExercisesListView.swift
  - DUNEWatch/Helpers/WatchExerciseHelpers.swift
  - DUNEWatch/Views/CarouselHomeView.swift
  - DUNEWatch/Views/QuickStartAllExercisesView.swift
related_solutions:
  - architecture/watch-settings-sync-pattern.md
  - architecture/2026-02-28-settings-hub-patterns.md
  - general/2026-03-04-watch-workout-discovery-search-usability.md
---

# Solution: Preferred Exercise Quick Start Parity

## Problem

사용자가 선호 운동을 지정해도 iPhone Quick Start와 Apple Watch 홈/전체 운동 화면에 공통 우선순위로 반영할 수 있는 저장소와 동기화 경로가 없었다.

### Symptoms

- Settings에는 선호 운동만 빠르게 관리하는 진입점이 없었다
- iPhone Quick Start는 `Popular`/`Recent` 중심이어서 사용자가 고정하고 싶은 운동을 위로 올릴 수 없었다
- Watch 홈 캐러셀과 `All Exercises`도 iPhone과 같은 우선순위를 공유하지 못했다
- 기존 `ExerciseDefaultRecord` 스키마에는 선호 여부가 없어 CloudKit/SwiftData 마이그레이션이 필요했다

### Root Cause

- 운동별 설정이 `defaultWeight/defaultReps/isManualOverride`에만 묶여 있어 "기본값은 없지만 상단 고정만 원하는" 상태를 표현하지 못했다
- Quick Start 섹션 정렬이 화면별로 흩어져 있어 `Recent -> Preferred -> Popular` 규칙을 공유할 공통 로직이 없었다
- Watch 동기화 payload에 선호 여부가 없어서 Watch UI가 iPhone 설정을 재사용할 수 없었다

## Solution

### Changes Made

| File | Change | Reason |
|------|--------|--------|
| `AppSchemaVersions.swift` | `AppSchemaV12` 추가 및 `ExerciseDefaultRecord` 구버전 snapshot 복원 | `isPreferred` 추가를 안전하게 마이그레이션 |
| `ExerciseDefaultRecord.swift` | `isPreferred` 저장 필드 추가 | 기본값 저장과 선호 고정을 같은 레코드로 관리 |
| `SettingsView.swift` / `PreferredExercisesListView.swift` | 전용 `Preferred Exercises` 화면 추가 | 토글만 있는 hidden affordance 대신 찾기 쉬운 진입점 제공 |
| `ExerciseDefaultEditView.swift` | 상세 편집 화면에 `Preferred Exercise` 토글 추가 | 개별 운동 설정 화면에서도 바로 선호 상태 변경 가능 |
| `QuickStartSectionOrderingService.swift` | 공통 dedupe + `Recent -> Preferred -> Popular` 정렬 서비스 추가 | iPhone Quick Start 섹션 순서 일관화 |
| `WatchSessionManager.swift` / `WatchConnectivityModels.swift` | 선호 운동 snapshot을 Watch payload에 포함 | iPhone 설정을 Watch에서 그대로 재사용 |
| `WatchExerciseHelpers.swift` / Watch views | Watch 홈 캐러셀과 전체 목록에 `Preferred` 섹션 추가 | Watch에서도 같은 우선순위 적용 |
| Tests | 정렬/디코딩/Watch helper/UI smoke 보강 | 회귀 방지 |

### Key Patterns

1. **Single record, dual intent**
   `ExerciseDefaultRecord` 하나에 기본값과 선호 상태를 함께 저장해 "무게/횟수 없음 + 선호만 true" 케이스를 허용했다.

2. **Representative ID normalization**
   선호 운동은 저장/표시/동기화 시 모두 `representativeExercise(byID:)` 기준으로 정규화해 alias 중복 노출을 막았다.

3. **Shared section ordering service**
   iPhone Quick Start는 `QuickStartSectionOrderingService`로 섹션 dedupe를 공통화했고, Watch는 동일 규칙을 helper 함수 조합으로 재현했다.

4. **Watch payload backward compatibility**
   `WatchExerciseInfo`에 `isPreferred`를 추가하되, `init(from:)`에서 키가 없으면 `false`로 복원해 구버전 payload도 decode 가능하게 유지했다.

5. **Settings-first sync**
   선호 상태가 바뀌면 `WatchSessionManager.shared.syncExerciseLibraryToWatch(using:)`를 즉시 호출해 앱 재실행 없이 Watch 정렬이 따라오도록 했다.

### Key Code

```swift
let ordering = QuickStartSectionOrderingService.make(
    recentIDs: recentExerciseIDs,
    preferredIDs: preferredExerciseIDs,
    popularIDs: popularExerciseIDs,
    canonicalize: QuickStartCanonicalService.canonicalExerciseID(for:)
)
```

```swift
WatchExerciseInfo(
    id: def.id,
    name: def.localizedName,
    inputType: def.inputType.rawValue,
    defaultSets: WorkoutDefaults.setCount,
    defaultReps: ...,
    defaultWeightKg: nil,
    isPreferred: preferredExerciseIDs.contains(def.id),
    equipment: ...,
    cardioSecondaryUnit: ...,
    aliases: def.aliases
)
```

## Prevention

### Checklist Addition

- [ ] Settings에 새 per-exercise 상태를 추가할 때 "전용 화면"과 "상세 편집 토글" 둘 다 필요한지 검토한다
- [ ] iPhone/Watch가 같은 큐레이션 규칙을 써야 하면 화면별 정렬 구현을 복제하지 말고 공통 ordering helper를 둔다
- [ ] WatchConnectivity payload 확장 시 decode fallback을 넣어 구버전 context도 안전하게 읽히는지 확인한다
- [ ] Quick Start UI를 바꿀 때 검색 진입이 숨겨지지 않는지 iPhone UI smoke로 확인한다

### Rule Addition (if applicable)

새 규칙 추가는 불필요. 다만 Quick Start/Watch parity 작업은 앞으로도 "대표 ID 정규화 + payload fallback + 검색 회귀 확인"을 기본 리뷰 체크리스트로 삼는다.

## Lessons Learned

- 사용자가 자주 쓰는 운동을 상단에 고정하는 기능은 "기본값 편집"과 별개 affordance가 있어야 발견 가능성이 높다.
- iPhone과 Watch의 정렬 규칙이 조금만 갈라도 체감 불일치가 크므로, 섹션 우선순위는 공통 서비스나 helper로 먼저 고정하는 편이 안전하다.
- WatchConnectivity 모델을 확장할 때는 신규 키 추가 자체보다 "기존 payload를 여전히 decode 가능한가"가 더 중요하다.
- Quick Start 허브를 정리하면서 검색창을 숨기면 즉시 탐색성 회귀가 생긴다. UI smoke 하나로도 이런 회귀를 빨리 잡을 수 있다.
