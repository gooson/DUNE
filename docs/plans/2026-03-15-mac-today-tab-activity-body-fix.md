---
tags: [macos, dashboard, cloud-sync, activity, body, snapshot, infinite-spinner]
date: 2026-03-15
category: plan
status: draft
---

# Plan: Mac 투데이탭 활동/신체 섹션 누락 + 무한 스피너 수정

## Problem Statement

Mac 투데이탭에서 두 가지 문제 발생:
1. **활동(Activity), 신체(Body) 섹션이 표시되지 않음** — SharedHealthSnapshot에 exercise/steps/weight/BMI 데이터가 포함되지 않아 Mac에서 해당 메트릭을 생성할 수 없음
2. **첫 로드 후 무한 스피너** — CloudKit remote change notification → 캐시 무효화 → 리로드 시 빈 결과가 반환되면 sortedMetrics가 []로 덮어씌워져 CloudSyncWaitingView가 다시 표시됨

## Root Cause Analysis

### 활동/신체 섹션 누락
- `SharedHealthSnapshot`은 HRV/RHR/Sleep 데이터만 포함
- `DashboardViewModel.safeExerciseFetch`, `safeStepsFetch`, `safeWeightFetch`, `safeBMIFetch`는 `canQueryHealthKit = false`일 때 빈 결과 반환
- Mac에서 HealthKit 사용 불가 → 이 4개 메트릭은 항상 빈 배열 → Activity/Body 섹션 렌더링 안됨

### 무한 스피너
- `.NSPersistentStoreRemoteChange` → 60초 throttle 후 `refreshSignal++` → `.task(id:)` 재트리거
- `loadData()` 재실행 → 캐시 무효화된 `fetchSnapshot()` → SwiftData 재쿼리
- 일시적 실패(CloudKit 동기화 중 오류) 시 `emptySnapshot` 반환 → `allMetrics` 빈 배열 → `sortedMetrics = []`
- View 조건: `sortedMetrics.isEmpty && !isLoading` → CloudSyncWaitingView (스피너)

## Implementation Steps

### Step 1: SharedHealthSnapshot에 활동/신체 필드 추가
**File**: `DUNE/Domain/Models/SharedHealthSnapshot.swift`
- `todaySteps: Double?` 추가
- `todayExerciseMinutes: Double?` 추가
- `latestWeight: WeightSample?` 추가 (struct WeightSample { value: Double, date: Date })
- `latestBMI: BMISample?` 추가 (struct BMISample { value: Double, date: Date })
- `Source` enum에 `.steps`, `.exercise`, `.weight`, `.bmi` 추가

### Step 2: SharedHealthDataServiceImpl에서 새 필드 수집
**File**: `DUNE/Data/Services/SharedHealthDataServiceImpl.swift`
- init에 `stepsService`, `workoutService`, `bodyService` 파라미터 추가
- `buildSnapshot()`에서 새 데이터 병렬 fetch 추가
- Steps: `stepsService.fetchSteps(for: referenceDate)`
- Exercise: `workoutService.fetchWorkouts(days: 1)` → 합산 분
- Weight: `bodyService.fetchLatestWeight(withinDays: 30)`
- BMI: `bodyService.fetchLatestBMI(withinDays: 30)`

### Step 3: HealthSnapshotMirrorMapper 인코딩/디코딩 확장
**File**: `DUNE/Data/Services/HealthSnapshotMirrorMapper.swift`
- `Payload`에 새 필드 추가: `todaySteps`, `todayExerciseMinutes`, `latestWeight`, `latestBMI`
- 모든 필드 Optional로 선언 (기존 페이로드 역호환)
- `makePayload()` 업데이트
- `makeSnapshot()` 업데이트

### Step 4: DashboardViewModel safe fetch에 snapshot fallback 추가
**File**: `DUNE/Presentation/Dashboard/DashboardViewModel.swift`
- `safeExerciseFetch`, `safeStepsFetch`, `safeWeightFetch`, `safeBMIFetch`에 `snapshot` 파라미터 추가
- `canQueryHealthKit = false`일 때 snapshot 데이터로 HealthMetric 생성
- `loadData()` 내 fetch 순서 조정: snapshot을 먼저 fetch → 나머지 fetch에 전달

### Step 5: 리로드 시 optimistic retention (무한 스피너 방지)
**File**: `DUNE/Presentation/Dashboard/DashboardViewModel.swift`
- `loadData()`에서 `allMetrics` 계산 후:
  - `hasLoadedOnce && isMirroredReadOnlyMode && allMetrics.isEmpty` → 기존 sortedMetrics 유지, 리턴
- 로그 추가: 기존 데이터 유지 시 로깅

## Affected Files

| File | Change | Risk |
|------|--------|------|
| `DUNE/Domain/Models/SharedHealthSnapshot.swift` | 새 필드 추가 | Low |
| `DUNE/Data/Services/SharedHealthDataServiceImpl.swift` | 새 서비스 주입 + fetch | Medium |
| `DUNE/Data/Services/HealthSnapshotMirrorMapper.swift` | Payload 확장 | Medium (역호환) |
| `DUNE/Presentation/Dashboard/DashboardViewModel.swift` | snapshot fallback + optimistic retention | Medium |
| `DUNE/App/DUNEApp.swift` | SharedHealthDataServiceImpl init 변경 | Low |
| `DUNETests/SharedHealthSnapshotTests.swift` | 테스트 업데이트 | Low |
| `DUNETests/HealthSnapshotMirrorMapperTests.swift` | 새 필드 roundtrip 테스트 | Low |

## Test Strategy

- HealthSnapshotMirrorMapper roundtrip 테스트: 새 필드 인코딩/디코딩 검증
- 기존 Payload 역호환: 새 필드 없는 JSON 디코딩 시 nil로 처리되는지 검증
- DashboardViewModel: isMirroredReadOnlyMode에서 snapshot 기반 메트릭 생성 검증
- Optimistic retention: hasLoadedOnce && empty → 기존 데이터 유지 검증

## Edge Cases / Risks

1. **Payload 역호환**: 기존 iPhone이 새 필드 없는 payload를 보내도 Mac이 디코딩 가능해야 함 → Optional 필드로 해결
2. **SharedHealthDataServiceImpl init 변경**: DUNEApp.swift에서 추가 서비스 주입 필요
3. **Steps/Exercise/Weight/BMI 서비스가 실패해도** 기존 HRV/Sleep 데이터는 정상 동작해야 함
