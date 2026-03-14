---
tags: [mac, swiftdata, cloudkit, migration, 134504, sync, performance]
date: 2026-03-14
category: plan
status: draft
---

# Plan: macOS 동기화 성능 개선 + 134504 Store Recovery 강화

## Problem Statement

macOS에서 앱 실행 시 두 가지 문제가 발생:

1. **134504 Migration Error**: `default.store`가 staged migration에서 실패하고, store 삭제 후 재시도도 실패하여 in-memory fallback으로 강등
2. **"iCloud 동기화 중..." 무한 대기**: in-memory container는 CloudKit 동기화가 불가능하므로 데이터가 영원히 도착하지 않음

### Root Cause Analysis

**134504 retry 실패 원인**: store 파일은 삭제되지만 CloudKit metadata (`ckAssetFiles`, zone metadata 등)가 App Group container에 잔존. 새 container가 CloudKit sync를 시도할 때 stale metadata와 현재 schema 불일치로 동일 에러 재발.

**동기화 대기 원인**: in-memory fallback container는 `cloudKitDatabase: .automatic`이어도 CloudKit persistent history tracking이 불가능하여 remote change를 수신하지 못함. 결과적으로 `CloudMirroredSharedHealthDataService`가 빈 snapshot만 반환.

## Affected Files

| File | Change | Risk |
|------|--------|------|
| `DUNE/App/DUNEApp.swift` | store recovery에 CloudKit-disabled retry 추가, deletion 로깅 강화 | Medium - recovery path 변경 |
| `DUNEWatch/DUNEWatchApp.swift` | 동일 recovery 패턴 적용 | Low - watch는 해당 경로 안 탐 |
| `DUNE/Presentation/Shared/Components/CloudSyncWaitingView.swift` | timeout + 재시도 버튼 + 구체적 안내 메시지 | Low - UI만 변경 |
| `DUNE/Presentation/Dashboard/DashboardView.swift` | CloudSyncWaitingView에 timeout/retry 전달 | Low |
| `DUNE/Presentation/Wellness/WellnessView.swift` | 동일 | Low |
| `DUNETests/PersistentStoreRecoveryTests.swift` | 새 recovery 경로 테스트 | Low |

## Implementation Steps

### Step 1: Store Recovery 강화 — CloudKit-disabled retry

`recoverModelContainer`에서 store 삭제 후 첫 retry 실패 시, `cloudKitDatabase: .none`으로 두 번째 retry를 추가한다. CloudKit metadata 불일치가 원인인 경우 이 경로로 persistent store가 복구된다.

```
1차: 삭제 → retry(CloudKit 유지) → 성공이면 return
2차: 1차 실패 → retry(CloudKit 없음) → 성공이면 return
3차: 2차 실패 → in-memory fallback
```

**Verification**: 기존 PersistentStoreRecoveryTests에 CloudKit-disabled fallback 경로 테스트 추가

### Step 2: Store 삭제 로깅 강화

`deleteStoreFiles`에서 `try?` 대신 명시적 error logging 추가. 삭제 실패 시 원인을 진단할 수 있도록 한다.

**Verification**: 로그에 삭제 성공/실패가 명시적으로 기록됨

### Step 3: CloudSyncWaitingView 개선

현재 무한 spinner만 표시. 개선사항:
- 일정 시간(30초) 후 "데이터가 아직 도착하지 않았습니다" 안내 + "다시 시도" 버튼
- in-memory fallback 상태일 때 "iCloud 데이터를 불러올 수 없습니다" 구체적 메시지

**Verification**: Mac 시뮬레이터에서 UI 확인

## Warning Analysis (수정 불필요 항목)

| Warning | 원인 | 수정 필요 |
|---------|------|----------|
| `CLIENT: Failure to determine if this machine is in the process of shutting down` | macOS sandbox 제한. Apple 시스템 경고 | **No** |
| `LSPrefs: could not find untranslocated node` | macOS app translocation. Xcode debug build 한정 | **No** |
| `Failed to load item AXCodeItem RealityFoundation/ScreenTimeUI` | macOS Accessibility framework. 앱 무관 시스템 경고 | **No** |
| `HealthKit unavailable. Falling back to cloud mirrored snapshot service.` | 의도된 동작 (Mac에서 HealthKit 미지원) | **No** |

## Test Strategy

- `PersistentStoreRecoveryTests`: CloudKit-disabled fallback 경로 테스트
- 수동 검증: Mac에서 앱 실행 후 134504 에러 미발생 확인

## Risks & Edge Cases

- CloudKit-disabled container로 복구 시 이후 CloudKit sync 불가 → remote change notification에서 runtime rebuild로 CloudKit 재활성화 필요 (기존 `refreshAppRuntimeIfNeeded` 경로 활용)
- store 삭제 후 모든 로컬 데이터 유실 → 사용자에게 안내 필요하지만 현재도 동일 동작
