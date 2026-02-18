---
topic: phase2-exercise-detail-completion
date: 2026-02-18
status: draft
confidence: high
related_solutions: [chart-ux-layout-stability, healthkit-query-parallelization]
related_brainstorms: [2026-02-18-healthkit-swiftdata-unification]
---

# Implementation Plan: Phase 2 — 운동 상세 통합 표시 완성

## Context

HealthKit ↔ SwiftData 통합의 Phase 1 구현에서 **4가지 누락**이 발생했다:

1. **다운샘플링 미구현**: 30분 운동 = ~1800개 raw 샘플이 차트에 그대로 들어감. 렌더링 성능 저하
2. **HeartRateSummary 모델 미구현**: avg/max/min을 View에서 인라인 계산. Domain 모델 빈약
3. **fetchHeartRateSummary 메서드 미구현**: 프로토콜에 명시했으나 구현 안 됨
4. **recoverSession UUID 캡처 누락**: Watch 크래시 복구 시 UUID를 캡처하지 않음

ExerciseSessionDetailView 자체는 존재하고 네비게이션도 연결되어 있다. 핵심은 **데이터 품질 보완**이다.

## Requirements

### Functional

1. 심박수 샘플을 10초 구간 평균으로 다운샘플링 (max ~180 포인트/30분)
2. HeartRateSummary 모델로 avg/max/min + samples를 캡슐화
3. fetchHeartRateSummary 메서드 구현 (프로토콜 완성)
4. Watch 크래시 복구 세션에서도 HKWorkout UUID 캡처

### Non-functional

- 다운샘플링은 Data 레이어에서 수행 (Presentation은 결과만 받음)
- HeartRateSummary는 Domain 레이어에 위치 (HealthKit import 없음)
- 기존 ExerciseSessionDetailView의 인라인 계산을 HeartRateSummary로 교체

## Approach

**Bottom-up 수정**: Data 레이어 서비스 보완 → Domain 모델 추가 → Presentation 연결 순서.

기존 코드를 최소한으로 수정. 새 메서드/모델 추가 후 호출부만 교체.

### Alternative Approaches Considered

| Approach | Pros | Cons | Decision |
|----------|------|------|----------|
| Chart에서 다운샘플링 | Presentation 단독 변경 | Data 레이어 책임 위반, 재사용 불가 | ❌ |
| Data 레이어에서 다운샘플링 | 단일 책임, 테스트 용이 | 기존 메서드 수정 필요 | ✅ |
| LTTB 알고리즘 | 시각적 보존 우수 | 구현 복잡, MVP에 과잉 | ❌ Future |
| 10초 구간 평균 | 단순, 예측 가능, 충분한 품질 | 급변구간 약간 smoothed | ✅ |

## Affected Files

| File | Change Type | Description |
|------|-------------|-------------|
| `Dailve/Domain/Models/HealthMetric.swift` | Modify | HeartRateSummary 모델 추가 |
| `Dailve/Data/HealthKit/HeartRateQueryService.swift` | Modify | 다운샘플링 + fetchHeartRateSummary 구현 |
| `Dailve/Presentation/Exercise/ExerciseSessionDetailView.swift` | Modify | HeartRateSummary 사용으로 인라인 계산 제거 |
| `DailveWatch/Managers/WorkoutManager.swift` | Modify | recoverSession UUID 캡처 |
| `DailveTests/HeartRateQueryServiceTests.swift` | Modify | 다운샘플링 테스트 추가 |

## Implementation Steps

### Step 1: HeartRateSummary Domain 모델 추가

- **Files**: `Dailve/Domain/Models/HealthMetric.swift`
- **Changes**:
  - `HeartRateSample` 아래에 `HeartRateSummary` 추가:
    ```swift
    struct HeartRateSummary: Sendable {
        let average: Double
        let max: Double
        let min: Double
        let samples: [HeartRateSample]

        var isEmpty: Bool { samples.isEmpty }
    }
    ```
  - Foundation만 import — HealthKit 의존 없음 (교정 #62)
- **Verification**: 빌드 통과

### Step 2: 다운샘플링 + fetchHeartRateSummary 구현

- **Files**: `Dailve/Data/HealthKit/HeartRateQueryService.swift`
- **Changes**:
  - 프로토콜에 `fetchHeartRateSummary(forWorkoutID:)` 추가
  - 기존 `fetchHeartRateSamples`에서 raw 샘플 반환 후, 다운샘플링은 summary 메서드에서 수행
  - 다운샘플링 로직을 `static func downsample(_:intervalSeconds:)` 으로 추출 (테스트 용이):
    ```swift
    static func downsample(_ samples: [HeartRateSample], intervalSeconds: TimeInterval = 10) -> [HeartRateSample]
    ```
  - 10초 구간별 평균 BPM 계산, 구간 중앙 시각 사용
  - `fetchHeartRateSummary`는 raw fetch → downsample → avg/max/min 계산 → HeartRateSummary 반환
- **Verification**: 유닛 테스트 (Step 4)

### Step 3: ExerciseSessionDetailView에서 HeartRateSummary 사용

- **Files**: `Dailve/Presentation/Exercise/ExerciseSessionDetailView.swift`
- **Changes**:
  - `@State private var heartRateSamples: [HeartRateSample]` → `@State private var heartRateSummary: HeartRateSummary?`
  - `loadHeartRate()`에서 `fetchHeartRateSummary` 호출
  - `heartRateSection`에서 인라인 avg/max 계산 제거 → `summary.average`, `summary.max` 사용
  - `HeartRateChartView`에 `summary.samples`, `summary.average`, `summary.max` 전달
- **Verification**: 시뮬레이터에서 운동 상세 진입 → 심박수 차트 + 통계 정상 표시

### Step 4: Watch recoverSession UUID 캡처

- **Files**: `DailveWatch/Managers/WorkoutManager.swift`
- **Changes**:
  - `recoverSession()`에서 복구된 `session`의 현재 상태가 `.running`이면 아직 진행 중 → UUID는 나중에 `.ended`에서 캡처됨 (기존 로직)
  - 하지만 복구 시점에서 `builder`가 이미 있으므로, `.ended` delegate에서 `finishWorkout()` 호출 시 UUID 캡처는 **기존 코드에서 이미 동작함**
  - 확인만 필요: `workoutSession(_:didChangeTo:.ended)` 에서 `builder?.finishWorkout()` → `healthKitWorkoutUUID = workout?.uuid.uuidString` — 이 경로가 복구된 세션에서도 동일하게 탈
  - 추가 안전장치: `recoverSession()` 끝에서 `isActive = true` 세팅 확인 (delegate 수신 전제조건)
- **Verification**: Watch 앱 강제 종료 → 재실행 → 운동 종료 → UUID 출력 확인 (manual)

### Step 5: 다운샘플링 + Summary 테스트

- **Files**: `DailveTests/HeartRateQueryServiceTests.swift`
- **Changes**:
  - `downsample` static 메서드 테스트:
    - 빈 배열 → 빈 배열
    - 1개 샘플 → 1개 유지
    - 10초 내 3개 샘플 → 1개 평균
    - 30초 데이터, interval=10 → 3개 구간
    - 구간 경계 정확성 (시각이 구간 중앙인지)
  - `HeartRateSummary` 계산 정확성:
    - avg, max, min 값 검증
    - 빈 samples → isEmpty == true
- **Verification**: `xcodebuild test` 통과

### Step 6: 빌드 검증

- **Files**: 전체
- **Changes**: 없음
- **Verification**: iPhone + Watch 빌드 통과, 테스트 통과

## Edge Cases

| Case | Handling |
|------|----------|
| 운동 시간 < 10초 | 다운샘플링 결과 1개 구간 → 차트에 단일 포인트 표시 |
| 심박수 샘플 0개 | HeartRateSummary(avg: 0, max: 0, min: 0, samples: []) → isEmpty == true → "No data" 뷰 |
| 구간 내 샘플이 모두 범위 밖 | validatedSample 필터 후 빈 구간 → 해당 구간 스킵 |
| 매우 긴 운동 (2시간+) | 10초 평균 → ~720 포인트. Swift Charts 성능 충분 |
| 복구 세션에서 builder nil | finishWorkout() nil 반환 → healthKitWorkoutUUID = nil → 기존 방어 로직 |

## Testing Strategy

- **Unit tests**:
  - `downsample()`: 경계값, 빈 배열, 단일 샘플, 다중 구간
  - `HeartRateSummary` 계산: avg/max/min 정확성
  - 기존 `validatedSample()` 테스트 유지
- **Manual verification**:
  - Watch 운동 → iPhone 상세 진입 → 심박수 차트 포인트 수 확인 (~180개 이하)
  - 차트 스크롤/선택 성능 확인
  - 빈 심박수 데이터 상태 확인
- **빌드 검증**: Watch + iPhone 양쪽 빌드 통과

## Risks

| Risk | Probability | Impact | Mitigation |
|------|-------------|--------|------------|
| 10초 평균이 급변구간 (스프린트 시작) 표현 부족 | Low | Low | MVP에서는 충분. Future에서 LTTB 알고리즘 검토 |
| recoverSession 경로에서 delegate 미호출 | Very Low | Medium | 기존 `.ended` delegate가 복구 세션에도 동작 확인 |
| HeartRateSummary → HeartRateChartView 타입 변경 | Low | Low | ChartView는 여전히 [HeartRateSample] + avg + max 받음. 변경 최소 |

## Confidence Assessment

- **Overall**: High
- **Reasoning**:
  - 기존 코드가 이미 동작하는 상태에서 데이터 품질 보완만 수행
  - 다운샘플링은 static 메서드로 추출하여 완전히 테스트 가능
  - HeartRateSummary는 단순 데이터 컨테이너
  - recoverSession은 기존 delegate 경로가 복구 세션에서도 동작하므로 추가 코드 최소
  - 영향 범위가 5개 파일로 제한적

## 구현 순서 요약

```
Step 1: HeartRateSummary 모델 (5분)
Step 2: 다운샘플링 + fetchHeartRateSummary (20분)
Step 3: ExerciseSessionDetailView 교체 (10분)
Step 4: recoverSession 확인 (5분)
Step 5: 테스트 (15분)
Step 6: 빌드 검증 (5분)
---
Total: ~1시간
```
