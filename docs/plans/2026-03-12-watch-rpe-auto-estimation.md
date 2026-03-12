---
tags: [watch, rpe, auto-estimation, rest-timer, ux]
date: 2026-03-12
category: plan
status: draft
---

# Plan: Watch RPE Auto-Estimation & Rest Screen Integration

## Problem

Watch SetInputSheet에서 RPE 입력이 무게/횟수 아래에 위치하여 스크롤에 가려지고, 접힌 상태에서 기능 인지가 어렵다.
RPE를 자동 추정하고 세트 간 휴식 화면에서 확인/조정하도록 변경한다.

## Approach

- **Watch**: SetInputSheet에서 RPE 제거 → 세트 완료 후 자동 추정 → RestTimerView에 추정값 표시 + 탭으로 조정
- **iOS**: 인라인 RPE 유지, 자동 추정값으로 prefill
- **자동 추정**: in-session 데이터만 사용 (Watch에 SwiftData/1RM 이력 없음)

## Estimation Algorithm

### 1RM% 기반 RPE 매핑 (primary signal)

세션 내 완료된 세트에서 `OneRMFormula.epley.estimate(weight:reps:)` → in-session best 1RM 산출.
현재 세트의 weight / estimated1RM = %1RM → RPE 매핑:

| %1RM | Base RPE | Description |
|------|----------|-------------|
| 95-100% | 10.0 | Max Effort |
| 90-95% | 9.0-9.5 | Very Hard |
| 85-90% | 8.0-8.5 | Hard |
| 80-85% | 7.5 | Moderate-Hard |
| 75-80% | 7.0 | Moderate |
| 70-75% | 6.5 | Light-Moderate |
| <70% | 6.0 | Light |

### Reps Degradation Correction

같은 운동 내 세트가 진행될수록 피로 누적. 이전 세트 대비 reps가 줄면 RPE를 +0.5 보정.

### Silent Skip

추정 불가 시 (첫 세트, bodyweight 운동 등) RPE를 nil로 두고 UI에 표시하지 않음.

## Affected Files

| File | Change | Risk |
|------|--------|------|
| `DUNEWatch/Views/SetInputSheet.swift` | RPE 섹션 제거, rpe binding 제거 | Low |
| `DUNEWatch/Views/MetricsView.swift` | rpe state 관리 변경, 자동 추정 호출 | Medium |
| `DUNEWatch/Views/RestTimerView.swift` | RPE 추정값 오버레이 + 탭 조정 UI 추가 | Medium |
| `DUNEWatch/Views/Components/WatchSetRPEPickerView.swift` | 삭제 또는 RestTimerView용으로 간소화 | Low |
| `DUNEWatch/Helpers/WatchRPEEstimator.swift` | **NEW**: in-session RPE 자동 추정 로직 | Medium |
| `DUNEWatch/Managers/WorkoutManager.swift` | `completeSet` 호출부 rpe 파라미터 흐름 변경 | Low |

## Implementation Steps

### Step 1: WatchRPEEstimator 서비스 생성

**파일**: `DUNEWatch/Helpers/WatchRPEEstimator.swift` (신규)

- `struct WatchRPEEstimator` (Sendable)
- `func estimateRPE(weight: Double, reps: Int, completedSets: [CompletedSetData]) -> Double?`
  - completedSets에서 같은 운동의 valid 세트 필터 (weight > 0, reps > 0)
  - `OneRMFormula.epley.estimate()` 으로 각 세트의 estimated 1RM 산출
  - best 1RM 선택 → current weight / best1RM = %1RM
  - %1RM → RPE 매핑 (위 테이블)
  - reps degradation: 이전 세트 reps > current reps → +0.5 보정
  - 결과를 `RPELevel.validate()` 로 범위 검증 (6.0-10.0)
  - 추정 불가 시 nil 반환

**Verification**: Unit test — 알려진 weight/reps/1RM 조합에 대해 기대 RPE 확인

### Step 2: RestTimerView에 RPE 오버레이 추가

**파일**: `DUNEWatch/Views/RestTimerView.swift`

- 새 파라미터: `estimatedRPE: Double?`, `onRPEAdjusted: ((Double) -> Void)?`
- RPE가 있을 때: 타이머 하단에 추정 RPE 배지 표시 (예: "RPE 7.5")
- 탭하면 간단한 ±0.5 조정 UI (RPE 수치 + 상하 버튼 또는 Digital Crown)
- RPE가 nil이면 오버레이 미표시 (silent skip)

**Verification**: Preview에서 estimatedRPE 유/무 양쪽 확인

### Step 3: SetInputSheet에서 RPE 섹션 제거

**파일**: `DUNEWatch/Views/SetInputSheet.swift`

- RPE 관련 `@Binding var rpe: Double?` 제거
- WatchSetRPEPickerView import/사용 제거
- RPE 섹션 View 코드 제거

**파일**: `DUNEWatch/Views/Components/WatchSetRPEPickerView.swift`
- 파일 삭제 (더 이상 사용처 없음, RestTimerView는 자체 UI 사용)

**Verification**: SetInputSheet preview — RPE 없이 weight/reps만 표시

### Step 4: MetricsView 통합

**파일**: `DUNEWatch/Views/MetricsView.swift`

4-1. `@State private var rpe: Double?` 유지 (자동 추정값 저장용)
4-2. `executeCompleteSet()` 에서:
  - 세트 완료 시 다음 세트의 RPE를 자동 추정: `WatchRPEEstimator.estimateRPE(weight:reps:completedSets:)`
  - 추정값을 `rpe` state에 저장
  - `workoutManager.completeSet(weight:reps:rpe:)` 에서 현재 세트의 RPE 전달 (이전 rest에서 확정된 값)
4-3. RestTimerView 호출부에 `estimatedRPE: rpe, onRPEAdjusted: { rpe = $0 }` 전달
4-4. `handleRestComplete()` 에서:
  - 확정된 rpe를 다음 세트의 `completeSet` 호출에 사용하도록 보존
  - `rpe = nil` 리셋은 `executeCompleteSet` 이후로 이동
4-5. SetInputSheet 호출에서 `rpe: $rpe` 바인딩 제거

**Flow**: 세트 완료 → 자동 RPE 추정 → RestTimer에 표시 → 사용자 조정 가능 → 다음 세트 시작 시 이전 세트 RPE로 확정 저장

**Verification**: 빌드 성공, 세트 완료→휴식→다음 세트 flow에서 RPE가 CompletedSetData에 기록되는지 확인

### Step 5: Unit Tests

**파일**: `DUNE/DUNETests/WatchRPEEstimatorTests.swift` (신규)

- 기본 1RM% → RPE 매핑 검증
- reps degradation 보정 검증
- 빈 completedSets → nil 반환
- bodyweight (weight=0) → nil 반환
- 범위 경계값 (6.0, 10.0) 검증

## Test Strategy

- WatchRPEEstimator: unit test (위 Step 5)
- RestTimerView RPE overlay: Preview 확인
- SetInputSheet RPE 제거: Preview 확인
- 전체 flow: Watch 시뮬레이터에서 수동 검증 (세트→휴식→RPE표시→조정→다음세트)

## Risks & Edge Cases

| Risk | Mitigation |
|------|------------|
| 첫 세트에 1RM 데이터 없음 | silent skip (nil) → 세트 2부터 추정 시작 |
| Bodyweight 운동 (weight=0) | silent skip |
| 극단적 무게/횟수로 왜곡된 1RM | `RPELevel.validate()` 로 6.0-10.0 범위 보장 |
| RestTimer 매우 짧아 조정 못함 | 기본 추정값으로 자동 확정, 조정은 optional |
| iOS inline RPE prefill | 이번 스코프 외. 추후 별도 작업 |

## Out of Scope

- iOS 인라인 RPE prefill (추후 작업)
- WatchConnectivity로 1RM 이력 동기화 (추후 정밀도 향상)
- 휴식 시간 기반 RPE 보정 (추후 추가 signal)
