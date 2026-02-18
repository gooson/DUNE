---
topic: healthkit-swiftdata-unification
date: 2026-02-18
status: draft
confidence: high
related_solutions: [healthkit-deduplication-best-practices, healthkit-dedup-implementation]
related_brainstorms: [2026-02-18-healthkit-swiftdata-unification]
---

# Implementation Plan: HealthKit ↔ SwiftData 운동 데이터 통합

## Context

현재 Watch/iPhone에서 운동을 기록하면 HealthKit(HKWorkout)과 SwiftData(ExerciseRecord)에 각각 저장되지만 연결고리가 없다. `ExerciseRecord.healthKitWorkoutID` 필드는 존재하지만 Watch에서는 전혀 채워지지 않고, iPhone에서는 fire-and-forget으로 비동기 세팅된다.

결과:
- 운동 상세에서 HealthKit 심박수/칼로리를 볼 수 없음
- 삭제 시 Apple Health에 잔여 기록 남음
- Activity 탭 dedup이 불완전 (UUID 매칭 실패 → fallback 의존)

## Requirements

### Functional

1. Watch 운동 완료 시 HKWorkout UUID를 ExerciseRecord.healthKitWorkoutID에 저장
2. 운동 상세 화면에서 심박수 타임라인 차트 표시 (HealthKit 쿼리)
3. 운동 상세 화면에서 HealthKit 칼로리 표시 (있으면 우선)
4. 운동 삭제 시 연결된 HKWorkout도 함께 삭제
5. HealthKit heartRate 읽기 권한 추가

### Non-functional

- 심박수 쿼리는 운동 상세 진입 시 lazy 로드 (리스트 스크롤 성능 보호)
- 심박수 샘플 다운샘플링 (30분 운동 = 최대 180포인트, 10초 평균)
- HealthKit 쿼리 실패 시 graceful degradation (차트 미표시, SwiftData 데이터만 표시)

## Approach

**Bottom-up 구현**: Data 레이어 서비스 → Domain 연결 → Presentation 표시 순서로 구현.

### Alternative Approaches Considered

| Approach | Pros | Cons | Decision |
|----------|------|------|----------|
| HealthKit Observer로 자동 sync | 실시간, 양방향 | 복잡도 높음, 백그라운드 권한 필요 | ❌ Future |
| UUID 직접 연결 (현재 선택) | 단순, 확실, 기존 필드 활용 | 수동 연결 필요 | ✅ MVP |
| 날짜+시간 fuzzy matching | 기존 레코드도 커버 | 오매칭 위험, 복잡 | ❌ Future |

## Affected Files

| File | Change Type | Description |
|------|-------------|-------------|
| **Data Layer** | | |
| `DailveWatch/Managers/WorkoutManager.swift` | Modify | `finishWorkout()` UUID 캡처, 프로퍼티 추가 |
| `DailveWatch/Views/SessionSummaryView.swift` | Modify | `healthKitWorkoutID` 세팅 |
| `Dailve/Data/HealthKit/HeartRateQueryService.swift` | **New** | 심박수 샘플 쿼리 서비스 |
| `Dailve/Data/HealthKit/HealthKitManager.swift` | Modify | heartRate 읽기 권한 추가 |
| `Dailve/Data/HealthKit/WorkoutDeleteService.swift` | **New** | HKWorkout 삭제 서비스 |
| **Presentation Layer** | | |
| `Dailve/Presentation/Shared/ViewModifiers/ConfirmDeleteRecordModifier.swift` | Modify | 삭제 시 HealthKit 연동 |
| `Dailve/Presentation/Exercise/ExerciseHistoryView.swift` | Modify | 세션 상세에 심박수 차트 추가 |
| `Dailve/Presentation/Shared/Charts/HeartRateChartView.swift` | **New** | 심박수 타임라인 차트 컴포넌트 |
| **Tests** | | |
| `DailveTests/HeartRateQueryServiceTests.swift` | **New** | 심박수 서비스 테스트 |

## Implementation Steps

### Step 1: Watch — HKWorkout UUID 캡처

- **Files**: `DailveWatch/Managers/WorkoutManager.swift`
- **Changes**:
  - `private(set) var healthKitWorkoutUUID: String?` 프로퍼티 추가
  - `.ended` 핸들러에서 `let workout = try await builder?.finishWorkout()` → `healthKitWorkoutUUID = workout?.uuid.uuidString`
  - `reset()`에서 `healthKitWorkoutUUID = nil`
  - 복구 세션(`recoverSession`)에서도 builder 있으면 UUID 캡처 가능하도록 처리
- **Verification**: Watch 시뮬레이터에서 운동 종료 후 `healthKitWorkoutUUID` 값 print 확인

### Step 2: Watch — ExerciseRecord에 UUID 세팅

- **Files**: `DailveWatch/Views/SessionSummaryView.swift`
- **Changes**:
  - `saveWorkoutRecords()`에서 `ExerciseRecord` 생성 시 `healthKitWorkoutID: workoutManager.healthKitWorkoutUUID` 파라미터 추가
  - 단일 HKWorkout 세션이므로 모든 ExerciseRecord가 같은 UUID를 공유
- **Verification**: Watch 운동 완료 → iPhone CloudKit sync → `ExerciseRecord.healthKitWorkoutID` 값 확인

### Step 3: HeartRateQueryService 신규 생성

- **Files**: `Dailve/Data/HealthKit/HeartRateQueryService.swift` (new)
- **Changes**:
  ```swift
  protocol HeartRateQuerying: Sendable {
      func fetchHeartRateSamples(workoutUUID: String) async throws -> [HeartRateSample]
      func fetchHeartRateSummary(workoutUUID: String) async throws -> HeartRateSummary?
  }
  ```
  - `HKQuantityType(.heartRate)` 샘플을 workout 시간 범위로 쿼리
  - `HKWorkout` UUID로 먼저 workout 조회 → `startDate`/`endDate` 추출 → 해당 범위의 심박수 쿼리
  - 다운샘플링: 10초 구간 평균으로 축소 (max 180 포인트/30분)
  - Domain 모델: `HeartRateSample(timestamp: Date, bpm: Double)`, `HeartRateSummary(average: Double, max: Double, min: Double, samples: [HeartRateSample])`
- **Verification**: `HeartRateQueryServiceTests` — mock 데이터로 다운샘플링 로직, 빈 결과 처리 테스트

### Step 4: HealthKit 권한에 heartRate 추가

- **Files**: `Dailve/Data/HealthKit/HealthKitManager.swift`
- **Changes**:
  - `readTypes`에 `HKQuantityType(.heartRate)` 추가
  - 기존 권한 요청 흐름에 자연스럽게 포함됨
- **Verification**: 앱 실행 시 건강 권한 화면에 "심박수" 항목 추가 확인

### Step 5: 심박수 차트 뷰 생성

- **Files**: `Dailve/Presentation/Shared/Charts/HeartRateChartView.swift` (new)
- **Changes**:
  - Swift Charts 기반 타임라인 차트
  - X축: 운동 시작부터의 경과 시간 (분)
  - Y축: BPM
  - `AreaMark` + `LineMark` 조합
  - 평균/최대 심박수 수평선 표시
  - 로딩 상태, 빈 상태, 에러 상태 처리
- **Verification**: Preview에서 mock 데이터로 차트 렌더링 확인

### Step 6: 운동 상세에 심박수 차트 연동

- **Files**: `Dailve/Presentation/Exercise/ExerciseHistoryView.swift`
- **Changes**:
  - 세션 상세 화면에 `HeartRateChartView` 추가
  - `healthKitWorkoutID`가 있는 ExerciseRecord만 차트 표시
  - `task` modifier로 lazy 로드: 상세 진입 시 `HeartRateQueryService.fetchHeartRateSummary()` 호출
  - 결과를 `@State` 에 저장, 로딩/에러 상태 관리
- **Verification**: Watch 운동 완료 → iPhone에서 해당 운동 상세 진입 → 심박수 차트 표시 확인

### Step 7: WorkoutDeleteService 생성 + 삭제 연동

- **Files**: `Dailve/Data/HealthKit/WorkoutDeleteService.swift` (new), `ConfirmDeleteRecordModifier.swift`
- **Changes**:
  - `WorkoutDeleteService`:
    ```swift
    func deleteWorkout(uuid: String) async throws
    // HKObjectQuery로 UUID 매칭 workout 조회 → healthStore.delete()
    ```
  - `ConfirmDeleteRecordModifier`: 삭제 버튼에서 `record.healthKitWorkoutID`가 있으면 `WorkoutDeleteService.deleteWorkout()` 호출 (fire-and-forget, 실패 시 무시 — SwiftData 삭제는 항상 진행)
- **Verification**: 운동 삭제 → Apple Health에서 해당 워크아웃 사라졌는지 확인

## Edge Cases

| Case | Handling |
|------|----------|
| HKWorkout이 Apple Health에서 먼저 삭제됨 | UUID 쿼리 nil → 심박수 차트 미표시, 삭제 시 skip |
| HealthKit heartRate 권한 거부 | 차트 영역에 "권한 필요" 메시지, SwiftData 데이터는 정상 표시 |
| Watch 운동 중 크래시 → 복구 | 복구 세션은 `finishWorkout()` 반환값 없을 수 있음 → UUID nil 허용 |
| `finishWorkout()` 실패 | `healthKitWorkoutUUID = nil`, ExerciseRecord는 정상 저장 |
| iPhone 수동 기록 HK write 실패 | 기존 동작 유지 — `healthKitWorkoutID = nil`, 차트 미표시 |
| 심박수 데이터 없는 운동 (수동 기록) | 차트 미표시, 빈 상태 뷰 |
| 30분+ 장시간 운동 심박수 | 10초 평균 다운샘플 → 최대 ~180 포인트 |
| 같은 시간 여러 운동 (Quick Start 연속) | 각각 별도 HKWorkout UUID → 1:1 매핑 유지 |
| Watch 앱 쓴 HKWorkout을 iPhone에서 삭제 | 같은 iCloud 계정이면 삭제 가능 (App Group 소속) — 실패 시 graceful skip |

## Testing Strategy

- **Unit tests**:
  - `HeartRateQueryServiceTests`: 다운샘플링, 빈 배열, 범위 검증(20-300 bpm)
  - 기존 `ExerciseViewModelTests`에 UUID 연결 확인 케이스 추가
- **Manual verification**:
  - Watch 운동 → iPhone 상세에서 심박수 차트 표시
  - Watch 운동 → iPhone에서 삭제 → Apple Health에서도 삭제 확인
  - iPhone 수동 기록 → 삭제 → Apple Health 연동 확인
  - HealthKit 권한 거부 시 graceful degradation
- **빌드 검증**: Watch + iPhone 양쪽 빌드 통과

## Risks

| Risk | Probability | Impact | Mitigation |
|------|-------------|--------|------------|
| Watch 앱 HKWorkout을 iPhone에서 삭제 불가 | Low | Medium | 삭제 실패 시 SwiftData만 삭제, 사용자에게 "Apple Health에서 수동 삭제" 안내 |
| CloudKit sync 지연으로 UUID 도착 전 사용자가 상세 화면 접근 | Medium | Low | UUID nil → 차트 미표시, 다음 접근 시 표시 |
| 심박수 쿼리 성능 (대량 샘플) | Low | Medium | 다운샘플링 + 쿼리 날짜 범위 제한 |
| `finishWorkout()` 반환값 타이밍 — delegate callback 내 async | Low | High | `@MainActor` 보장 + 에러 처리로 UUID nil 허용 |

## Confidence Assessment

- **Overall**: High
- **Reasoning**:
  - `healthKitWorkoutID` 필드가 이미 존재하여 스키마 변경 불필요
  - iPhone 수동 기록은 이미 UUID 세팅 구현됨 (WorkoutSessionView)
  - Watch 수정은 `finishWorkout()` 반환값 캡처 1줄 추가가 핵심
  - HeartRateQueryService는 기존 HRVQueryService 패턴 따르면 됨
  - 삭제 연동은 fire-and-forget으로 실패 시 SwiftData 삭제는 항상 진행
  - 리스크가 모두 graceful degradation으로 처리 가능

## 구현 순서 요약

```
Step 1-2: Watch UUID 캡처 + ExerciseRecord 세팅 (핵심, 30분)
Step 3-4: HeartRateQueryService + 권한 (Data 레이어, 1시간)
Step 5-6: 심박수 차트 + 운동 상세 연동 (Presentation, 1시간)
Step 7:   삭제 동기화 (30분)
---
Total: ~3시간
```
