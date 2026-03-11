---
tags: [watchos, watchconnectivity, reinstall, rehydrate, templates, recent-order, quick-start]
category: general
date: 2026-03-12
severity: important
related_files:
  - DUNE/Data/WatchConnectivity/WatchExerciseLibraryPayloadBuilder.swift
  - DUNE/Data/WatchConnectivity/WatchSessionManager.swift
  - DUNE/Domain/Models/WatchConnectivityModels.swift
  - DUNEWatch/Helpers/WatchExerciseHelpers.swift
  - DUNEWatch/Views/CarouselHomeView.swift
  - DUNEWatch/Views/QuickStartAllExercisesView.swift
  - DUNE/Presentation/Settings/Components/ExerciseDefaultEditView.swift
  - DUNE/Presentation/Settings/Components/PreferredExercisesListView.swift
related_solutions:
  - docs/solutions/general/2026-03-03-watch-template-sync-watchconnectivity-fallback.md
  - docs/solutions/general/2026-03-08-watch-template-sync-background-request.md
---

# Solution: Watch Reinstall Rehydrate for Templates and Recent Ordering

## Problem

Apple Watch 앱을 재설치하면 watch 로컬 SwiftData/UserDefaults가 초기화된다.
이 상태에서 iPhone에 남아 있는 template와 recent 운동 순서가 watch quick start/home에 충분히 복구되지 않았다.

### Symptoms

- watch 재설치 직후 routine/template 카드가 비어 있거나 오래된 상태로 남는다.
- quick start의 `Recent`/`Popular` ordering이 iPhone 사용 이력과 무관하게 초기 상태로 돌아간다.
- settings에서 preferred/default를 바꿀 때 watch re-sync가 전체 기록 fetch를 메인 액터에서 수행한다.

### Root Cause

원인은 두 가지였다.

1. watch pull-request가 오면 iPhone이 persistent store를 다시 읽지 않고 in-memory cache(`cachedWorkoutTemplates`)만 재전송했다.
2. watch recent ordering은 로컬 `RecentExerciseTracker`에만 의존했고, iPhone의 `ExerciseRecord` history는 payload에 포함되지 않았다.

## Solution

iPhone persistent source를 watch rehydrate용 payload builder로 분리하고,
watch request/activation 시 cache-only 응답 대신 fresh payload를 다시 생성하도록 바꿨다.
동시에 watch exercise payload에 recent metadata를 추가해 재설치 후에도 recent/popular ordering이 iPhone history를 fallback으로 사용할 수 있게 했다.

### Changes Made

| File | Change | Reason |
|------|--------|--------|
| `WatchExerciseLibraryPayloadBuilder.swift` | `ExerciseRecord` + `ExerciseDefaultRecord`를 watch payload로 집계하는 순수 builder 추가 | iPhone history를 recent/default/preferred metadata로 재사용하기 위해 |
| `WatchSessionManager.swift` | registered `ModelContainer` 보관, activation/request 시 fresh payload fetch 사용 | watch 재설치 후 empty cache 응답 방지 |
| `WatchConnectivityModels.swift` | `WatchExerciseInfo.lastUsedAt`, `usageCount` 추가 | watch recent/popular fallback metadata 전달 |
| `WatchExerciseHelpers.swift` | local tracker 우선 + synced metadata fallback ordering 구현 | watch reinstall 후 recent/popular 복구 |
| `CarouselHomeView.swift` | `daysAgo`와 invalidation key에 synced metadata 반영 | recent card 표시/갱신 일관성 확보 |
| `QuickStartAllExercisesView.swift` | exercise snapshot key에 synced metadata 반영 | quick start list 갱신 누락 방지 |
| `ExerciseDefaultEditView.swift`, `PreferredExercisesListView.swift` | settings-triggered sync를 registered container 기반 async path로 전환 | main-actor full-history fetch 회피 |
| `WatchExerciseLibraryPayloadBuilderTests.swift`, `WatchExerciseHelpersTests.swift` | recent/default payload 및 fallback ordering 회귀 테스트 추가 | 재설치 회귀를 자동 검증하기 위해 |

### Key Code

```swift
if let registeredModelContainer {
    syncExerciseLibraryToWatch(using: registeredModelContainer)
    syncWorkoutTemplatesToWatch(using: registeredModelContainer)
} else {
    syncExerciseLibraryToWatch()
    transferWorkoutTemplates(cachedWorkoutTemplates)
}
```

```swift
private func resolvedLastUsedTimestamp(
    for exercise: WatchExerciseInfo,
    lastUsedTimestamps: [String: Double]
) -> Double? {
    if let localTimestamp = lastUsedTimestamps[exercise.id] {
        return localTimestamp
    }
    return exercise.lastUsedAt?.timeIntervalSince1970
}
```

## Prevention

### Checklist Addition

- [ ] watch reinstall/re-pair scenario가 있는 sync 경로는 cache-only reply가 아니라 persistent source re-fetch 경로를 갖는지 확인한다.
- [ ] watch local tracker 기반 정렬/프리필은 재설치 시 사라지므로 iPhone durable snapshot fallback을 함께 설계한다.
- [ ] settings/change hook에서 watch sync를 트리거할 때 전체 기록 fetch가 메인 액터를 막지 않는지 확인한다.

### Rule Addition (if applicable)

새 전역 rule 파일 추가는 보류했다.
다만 watch reinstall 성격의 버그를 건드릴 때는 `cache-only 응답 금지 + durable fallback payload`를 기본 점검 항목으로 삼는 편이 안전하다.

## Lessons Learned

- watch reinstall 버그는 “전송 자체가 되는가”보다 “누가 최신 source of truth를 다시 읽는가”가 더 중요하다.
- fallback payload를 모델로 명시해두면 template뿐 아니라 recent ordering 같은 UX 상태도 같은 transport에서 회복시킬 수 있다.
- sync correctness를 고친 뒤에는, 그 sync를 누가 어떤 actor에서 호출하는지도 같이 점검해야 성능 회귀를 막을 수 있다.
