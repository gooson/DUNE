---
tags: [healthkit, swiftdata, watch, exercise, heart-rate, unification]
date: 2026-02-18
category: brainstorm
status: draft
---

# Brainstorm: HealthKit ↔ SwiftData 운동 데이터 통합

## Problem Statement

현재 Dailve 앱은 운동 데이터를 **두 경로로 분리 저장**하고 있으며 연결고리가 없다:

1. **HealthKit (HKWorkout)** — 세션 메타데이터 (시간, 심박수, 칼로리)
2. **SwiftData (ExerciseRecord + WorkoutSet)** — 상세 기록 (운동명, 세트, 무게, 횟수)

결과:
- 운동 상세 화면에서 HealthKit 심박수/칼로리를 볼 수 없음
- Dailve에서 삭제해도 Apple Health에 잔여 기록 남음
- Watch 운동과 iPhone 수동 기록 모두 `healthKitWorkoutID`가 채워지지 않아 dedup도 불완전

## Target Users

- Watch로 운동하고 iPhone에서 기록을 확인하는 사용자
- iPhone에서 수동 운동 기록을 하는 사용자
- 심박수 데이터로 운동 강도를 파악하고 싶은 사용자

## Success Criteria

1. **운동 상세 화면에서 통합 뷰**: SwiftData 세트 데이터 + HealthKit 심박수 차트 + 칼로리가 하나의 화면에 표시
2. **UUID 연결**: 모든 ExerciseRecord가 대응하는 HKWorkout UUID를 보유
3. **삭제 동기화**: Dailve에서 운동 삭제 시 연결된 HKWorkout도 함께 삭제
4. **Dedup 정확도**: Activity 탭에서 동일 운동이 중복 표시되지 않음

## Current State 분석

### 이미 있는 것
- `ExerciseRecord.healthKitWorkoutID: String?` 필드 — **존재하지만 Watch에서 채워지지 않음**
- `WorkoutWriteService` (iPhone) — `finishWorkout()` 후 UUID 반환 **구현됨**
- `WorkoutQueryService` — HealthKit에서 `WorkoutSummary` 조회, `id = workout.uuid.uuidString`
- `WorkoutSummary+Dedup` — `healthKitWorkoutID` 기반 dedup 로직 **구현됨**
- Watch `WorkoutManager` — `HKLiveWorkoutBuilder` 사용, `finishWorkout()` 호출하지만 **반환값(UUID) 버림**

### 빠져있는 것
- Watch: `finishWorkout()` 반환 HKWorkout UUID → `WorkoutManager`에 저장 → `SessionSummaryView`에서 `ExerciseRecord.healthKitWorkoutID`에 세팅
- iPhone 수동 기록: `WorkoutWriteService.save()` 반환 UUID → `ExerciseRecord.healthKitWorkoutID`에 세팅 (현재 ExerciseView에서 연결 누락 확인 필요)
- 삭제 시 `healthStore.delete()` 호출
- 운동 상세에서 HKWorkout UUID로 심박수 샘플 조회 → 타임라인 차트 표시

## Proposed Approach

### Phase 1: UUID 연결 파이프라인

**Watch 경로:**
```
WorkoutManager.finishWorkout()
  → HKWorkout UUID 캡처 → workoutManager.healthKitWorkoutUUID에 저장
  → SessionSummaryView.saveWorkoutRecords()에서 ExerciseRecord.healthKitWorkoutID = uuid
  → CloudKit sync → iPhone에 도착
```

**iPhone 수동 기록 경로:**
```
ExerciseView → 저장 시 WorkoutWriteService.save() 호출
  → 반환된 UUID → ExerciseRecord.healthKitWorkoutID에 세팅
```

### Phase 2: 통합 표시

**운동 상세 화면 (ExerciseHistoryView 또는 새 DetailView):**
```
ExerciseRecord (SwiftData)
  ├── 세트 정보: WorkoutSet[] (무게, 횟수, 세트번호)
  ├── 기본 정보: 날짜, 시간, 메모
  └── healthKitWorkoutID → HealthKit 쿼리
       ├── 심박수 타임라인 차트 (HKQuantityType.heartRate, 운동 시간 범위)
       ├── 평균/최대 심박수
       └── 활성 칼로리 (HealthKit 값 우선)
```

### Phase 3: 삭제 동기화

```
ExerciseRecord 삭제 시
  → healthKitWorkoutID가 있으면
  → HKObjectQuery(uuid) → healthStore.delete(workout)
  → ExerciseRecord 삭제 (SwiftData)
```

## Constraints

### 기술적 제약
- **HealthKit 삭제 권한**: 앱이 작성한 데이터만 삭제 가능. Watch 앱이 쓴 HKWorkout을 iPhone 앱에서 삭제하려면 같은 App Group의 bundle이어야 함 → 확인 필요
- **심박수 쿼리 비용**: `HKQuantityType(.heartRate)` 샘플은 1초 간격일 수 있어 30분 운동 = 1800개 샘플. 차트 렌더링 최적화 필요 (다운샘플링)
- **CloudKit sync 지연**: Watch → iPhone UUID 전달이 CloudKit 경유이므로 수초~수분 지연 가능. UI에서 "syncing..." 상태 표시 필요할 수 있음
- **HKWorkout UUID 접근 타이밍**: `finishWorkout()`은 async이고, 세션 delegate의 `.ended` 콜백 내에서 호출됨. UUID를 안전하게 저장하는 타이밍 설계 필요

### 기존 아키텍처 제약
- Domain 레이어에 HealthKit import 금지 (교정 #62)
- ViewModel에 SwiftData import 금지
- 심박수 차트는 Presentation 레이어에서 처리

## Edge Cases

1. **HKWorkout이 사용자에 의해 Apple Health에서 먼저 삭제된 경우**: UUID로 쿼리 시 nil 반환 → graceful fallback (심박수 차트 미표시)
2. **HealthKit 권한 거부**: 심박수 읽기 권한 없으면 차트 미표시, 칼로리도 SwiftData 값 fallback
3. **Watch 운동 중 크래시 복구**: 복구된 세션은 `finishWorkout()` 시점이 달라 UUID가 다를 수 있음 → 복구 세션도 UUID 캡처 필요
4. **iPhone 수동 기록에서 HealthKit 쓰기 실패**: UUID가 nil → 심박수 연결 불가, SwiftData 기록만 존재
5. **같은 시간대에 여러 운동**: Quick Start 3회 연속 시 각각 별도 HKWorkout → 1:1 매핑 유지
6. **오래된 기록**: healthKitWorkoutID가 없는 기존 ExerciseRecord → 날짜+시간 기반 fuzzy matching으로 후속 연결 가능 (Future)

## Scope

### MVP (Must-have)
- [ ] Watch: `finishWorkout()` UUID 캡처 → ExerciseRecord.healthKitWorkoutID 저장
- [ ] iPhone 수동 기록: WorkoutWriteService UUID → ExerciseRecord.healthKitWorkoutID 연결
- [ ] 운동 상세 화면: healthKitWorkoutID로 심박수 조회 → 타임라인 차트 표시
- [ ] 운동 상세 화면: HealthKit 칼로리 우선 표시 (있으면)
- [ ] 삭제 시 연결된 HKWorkout도 삭제
- [ ] Dedup 정확도 향상 (UUID 기반 매칭)

### Nice-to-have (Future)
- [ ] 기존 레코드 후속 매칭 (날짜+시간 fuzzy match)
- [ ] 심박수 존 분석 (유산소/무산소/최대 존 비율)
- [ ] 운동 중 실시간 심박수 (Watch → iPhone 스트리밍)
- [ ] HealthKit workout route (GPS) 연동 (유산소 운동용)
- [ ] Apple Health에서 삭제 시 Dailve에도 반영 (HKObserverQuery)

## Open Questions

1. Watch 앱이 쓴 HKWorkout을 iPhone 앱에서 `healthStore.delete()` 할 수 있는가? (같은 App Group이면 가능한지 확인 필요)
2. 심박수 차트 다운샘플링 전략 — 10초 평균? 30초 평균? 포인트 수 제한?
3. iPhone 수동 기록 시 현재 `WorkoutWriteService.save()` 반환 UUID가 `ExerciseRecord`에 연결되는 코드가 있는지? (리서치 결과 누락 의심)

## Data Flow 요약

```
[Watch Quick Start]                    [iPhone 수동 기록]
       │                                      │
  HKWorkoutSession                    WorkoutWriteService
       │                                      │
  finishWorkout()                      finishWorkout()
       │                                      │
  HKWorkout.uuid ──────┐          ┌── HKWorkout.uuid
       │                │          │          │
  ExerciseRecord ←── healthKitWorkoutID ──→ ExerciseRecord
  (SwiftData/CloudKit)                  (SwiftData)
       │                                      │
       └──────────── iPhone UI ───────────────┘
                        │
              운동 상세 화면
              ├── 세트 데이터 (SwiftData)
              ├── 심박수 차트 (HealthKit query by UUID)
              ├── 칼로리 (HealthKit 우선)
              └── 삭제 → SwiftData + HealthKit 동시 삭제
```

## Next Steps

- [ ] `/plan healthkit-swiftdata-unification` 으로 구현 계획 생성
- [ ] Open Question #1 (Watch→iPhone 삭제 권한) 사전 검증
- [ ] Open Question #3 (iPhone 수동 기록 UUID 연결 현황) 코드 확인
