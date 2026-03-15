---
tags: [swiftdata, migration, recovery, cloudkit, modelcontainer, testing]
category: architecture
date: 2026-03-14
severity: important
related_files:
  - DUNE/Data/Persistence/Migration/PersistentStoreRecovery.swift
  - DUNE/App/DUNEApp.swift
  - DUNEWatch/DUNEWatchApp.swift
  - DUNETests/PersistentStoreRecoveryTests.swift
  - DUNETests/AppMigrationPlanTests.swift
related_solutions:
  - docs/solutions/architecture/2026-03-01-swiftdata-schema-model-mismatch.md
  - docs/solutions/architecture/2026-03-12-mac-swiftdata-migration-refresh-stability.md
  - docs/solutions/architecture/2026-03-12-swiftdata-reopen-snapshot-pairing.md
---

# Solution: SwiftData 134504 Recovery Must Recognize Wrapped Load Failures

## Problem

App Group SQLite store를 여는 시점에 `NSCocoaErrorDomain 134504`와
`Cannot use staged migration with an unknown model version`가 발생했고,
앱은 persistent store를 복구하지 못한 채 in-memory `ModelContainer`로 강등됐다.

### Symptoms

- `default.store`가 staged migration 단계에서 열리지 않음
- top-level 로그에는 `SwiftData.SwiftDataError._Error.loadIssueModelContainer`만 남는 경우가 있었음
- recovery 코드가 `Skipping store deletion for non-migration container error`로 분기해 purge/retry를 건너뜀
- 기존 migration guard test는 최신 schema가 `V15`로 올라간 상태를 충분히 검증하지 못했음

### Root Cause

원인은 두 갈래였다.

1. 실제 store failure는 recoverable한 staged migration error(`NSCocoaErrorDomain 134504`)였지만,
   SwiftData가 이 에러를 `SwiftData.SwiftDataError.loadIssueModelContainer`로 감싸 올리는 경로가 있었다.
   기존 `PersistentStoreRecovery.shouldDeleteStore(after:)`는 주로 `NSError` 체인만 보고 recoverability를 판정했기 때문에,
   wrapper만 남은 경우를 non-migration failure로 잘못 분류했다.
2. `AppMigrationPlanTests`는 아직 최신 schema 기대값과 reopen coverage가 `V15` 경계를 충분히 반영하지 못했다.
   그래서 최신 shipped snapshot drift나 newest-store reopen regression을 사전에 막는 guard가 느슨했다.

## Solution

recovery 판정을 `NSError` 체인뿐 아니라 reflected SwiftData wrapper까지 보도록 확장하고,
실패 진단 로그에는 reflected error를 private으로 남기도록 조정했다.
동시에 migration guard test를 `V15` 기준으로 갱신해 최신 schema drift와 reopen regression을 함께 막았다.

### Changes Made

| File | Change | Reason |
|------|--------|--------|
| `DUNE/Data/Persistence/Migration/PersistentStoreRecovery.swift` | reflected error text와 known SwiftData wrapper signature를 recoverable migration 판정에 포함 | `loadIssueModelContainer` wrapper만 남아도 purge/retry가 동작하도록 보강 |
| `DUNE/App/DUNEApp.swift` | reflected persistence error를 private 로그로 기록 | 현장 진단 정보는 늘리되 민감한 store context 노출은 피함 |
| `DUNEWatch/DUNEWatchApp.swift` | 동일 수정 적용 | watch recovery 경로도 앱과 동일하게 유지 |
| `DUNETests/PersistentStoreRecoveryTests.swift` | wrapped load issue / non-migration wrapper 분기 테스트 추가 | recovery heuristic이 과확장되지 않도록 회귀 방지 |
| `DUNETests/AppMigrationPlanTests.swift` | latest schema를 `V15`로 갱신하고 `V14` reopen guard 추가 | 최신 shipped schema 경계에서 migration drift를 조기 검출 |

### Key Code

```swift
static func shouldDeleteStore(after error: Error) -> Bool {
    let nsError = expandedNSErrorChain(from: error)
    if nsError.contains(where: isRecoverableMigrationError(_:)) {
        return true
    }

    let normalizedText = normalizedErrorText(from: error)
    return wrappedSwiftDataMigrationSignatures.allSatisfy { signature in
        normalizedText.contains(signature)
    }
}
```

```swift
let reflectedError = String(reflecting: error)
logger.error("ModelContainer failed: \(reflectedError, privacy: .private)")
```

## Follow-up: CloudKit-disabled Retry + Sync UX (same date)

store 삭제 후 retry가 CloudKit metadata 불일치로 재실패하는 경우를 위해
3단계 recovery chain을 추가했다.

```
1차: 삭제 → retry(CloudKit 유지) → 성공이면 return
2차: 1차 실패 → retry(CloudKit 없음) → 성공이면 return
3차: 2차 실패 → in-memory fallback
```

### 추가 변경

| File | Change | Reason |
|------|--------|--------|
| `DUNEApp.swift` | `recoverModelContainer`에 `cloudKitDatabase: .none` 2차 retry 추가 | stale CloudKit metadata가 원인인 경우 persistent store 복구 |
| `DUNEWatchApp.swift` | 동일 패턴 적용 | watch recovery 경로 일관성 |
| `DUNEApp.swift` | `deleteStoreFiles` do/catch 명시적 로깅 | 삭제 실패 원인 진단 |
| `CloudSyncWaitingView.swift` | 30초 timeout + 확장 안내 + Retry 버튼 | in-memory fallback 시 무한 대기 UX 개선 |
| `DashboardView.swift`, `WellnessView.swift` | `onRetry` 클로저 전달 | Retry 액션 연결 |

### Key Code

```swift
// Retry 2: disable CloudKit
let noCloudConfig = ModelConfiguration(
    url: configuration.url,
    cloudKitDatabase: .none
)
let container = try makeModelContainer(configuration: noCloudConfig)
```

## Prevention

### Checklist Addition

- [ ] SwiftData store load failure를 복구 분류할 때 `NSError` chain만 보지 말고 `String(reflecting: error)`까지 확인한다.
- [ ] newest `VersionedSchema`를 올렸다면 latest-version assertion과 newest shipped-store reopen test를 함께 갱신한다.
- [ ] reflected persistence error를 로그에 남길 때는 반드시 `privacy: .private`를 유지한다.

### Rule Addition (if applicable)

기존 `.claude/rules/swiftdata-cloudkit.md`와 migration solution 문서들이 schema/versioning 원칙은 이미 다루고 있어
새 rule 파일은 추가하지 않았다.

## Lessons Learned

- SwiftData migration 장애는 실제 root error보다 top-level wrapper 때문에 recovery가 무력화되는 경우가 있다.
- `ModelContainer failed` 로그만으로는 recoverability를 판단하기 어렵고, reflected error text를 함께 봐야 wrapper 손실을 확인할 수 있다.
- migration guard는 schema 배열 검증만으로 부족하고, 최신 shipped store reopen 경계까지 포함해야 drift를 실질적으로 막을 수 있다.
