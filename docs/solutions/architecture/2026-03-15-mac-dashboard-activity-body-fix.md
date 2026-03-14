---
tags: [macos, dashboard, cloud-sync, activity, body, snapshot, infinite-spinner, mirrored-mode]
date: 2026-03-15
category: solution
status: implemented
---

# Mac 투데이탭 활동/신체 섹션 누락 + 무한 스피너 수정

## Problem

Mac 투데이탭에서 두 가지 문제:
1. **활동(Activity), 신체(Body) 섹션이 표시되지 않음** — SharedHealthSnapshot에 exercise/steps/weight/BMI 데이터가 포함되지 않아 Mac에서 해당 메트릭을 생성할 수 없음
2. **첫 로드 후 무한 스피너** — CloudKit remote change notification → 캐시 무효화 → 리로드 시 빈 결과가 반환되면 sortedMetrics가 []로 덮어씌워져 CloudSyncWaitingView가 다시 표시됨

## Root Cause

### 활동/신체 섹션 누락
- `SharedHealthSnapshot`은 HRV/RHR/Sleep 데이터만 포함
- `DashboardViewModel.safeExerciseFetch`, `safeStepsFetch`, `safeWeightFetch`, `safeBMIFetch`는 `canQueryHealthKit = false`일 때 빈 결과 반환
- Mac에서 HealthKit 사용 불가 → 이 4개 메트릭은 항상 빈 배열 → Activity/Body 섹션 렌더링 안됨

### 무한 스피너
- `.NSPersistentStoreRemoteChange` → 60초 throttle → `refreshSignal++` → `.task(id:)` 재트리거
- `loadData()` 재실행 → 캐시 무효화된 `fetchSnapshot()` → SwiftData 재쿼리
- 일시적 실패 시 `emptySnapshot` 반환 → `allMetrics` 빈 배열 → `sortedMetrics = []`
- View 조건: `sortedMetrics.isEmpty && !isLoading` → CloudSyncWaitingView (스피너)

## Solution

### 1. SharedHealthSnapshot에 활동/신체 필드 추가
- `todaySteps: Double?`, `todayExerciseMinutes: Double?` 추가
- `latestWeight: WeightSample?`, `latestBMI: BMISample?` 추가
- `var` + `nil` default로 기존 init 호환 유지

### 2. SharedHealthDataServiceImpl에서 새 데이터 수집
- `stepsService`, `workoutService`, `bodyService` 의존성 추가
- `buildSnapshot()`에서 기존 HRV/Sleep과 병렬로 4개 추가 fetch
- 각 fetch 실패는 독립적 — 기존 데이터에 영향 없음

### 3. HealthSnapshotMirrorMapper 확장
- `Payload`에 `todaySteps`, `todayExerciseMinutes`, `latestWeight`, `latestBMI` 추가
- 모든 신규 필드는 Optional → 기존 payload 역호환

### 4. DashboardViewModel safe*Fetch에 snapshot fallback
- HRV/Sleep과 동일 패턴: snapshot이 있으면 snapshot에서 HealthMetric 생성
- `canQueryHealthKit = false` (Mac)에서도 데이터 표시 가능
- 모든 fetch를 snapshot 획득 이후로 재배치

### 5. Optimistic retention (무한 스피너 방지)
- `hasLoadedOnce && isMirroredReadOnlyMode && allMetrics.isEmpty && !sortedMetrics.isEmpty` → 기존 sortedMetrics 유지
- 로그 추가로 디버깅 지원

## Prevention

- 새 HealthKit 메트릭을 대시보드에 추가할 때는 반드시 SharedHealthSnapshot 경로도 함께 구현
- Mac mirrored mode 테스트: 데이터가 있는 상태에서 CloudKit 알림 후 UI가 유지되는지 확인
- 리로드 시 기존 데이터를 덮어쓰기 전에 새 데이터가 유효한지 확인하는 패턴 적용

## Affected Files

| File | Change |
|------|--------|
| `DUNE/Domain/Models/SharedHealthSnapshot.swift` | 새 필드 + 구조체 추가 |
| `DUNE/Data/Services/SharedHealthDataServiceImpl.swift` | 새 서비스 주입 + 병렬 fetch |
| `DUNE/Data/Services/HealthSnapshotMirrorMapper.swift` | Payload 확장 (역호환) |
| `DUNE/Presentation/Dashboard/DashboardViewModel.swift` | snapshot fallback + optimistic retention |
| `DUNETests/HealthSnapshotMirrorMapperTests.swift` | 4개 roundtrip 테스트 추가 |
