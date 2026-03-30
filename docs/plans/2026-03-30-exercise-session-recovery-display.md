---
tags: [healthkit, heart-rate, recovery, hrr1, exercise-session, parity]
date: 2026-03-30
category: plan
status: approved
---

# Exercise Session Detail — Heart Rate Recovery 표시 추가

## Problem Statement

`ExerciseSessionDetailView` (앱 내에서 생성한 운동 세션의 상세 화면)에 Heart Rate Recovery(HRR₁) 정보가 표시되지 않는다. 동일한 데이터가 `HealthKitWorkoutDetailView` (HealthKit 전용 운동 상세)에는 이미 표시되고 있어 기능 불균형이 존재한다.

## Root Cause Analysis

### 왜 누락되었는가?

1. **기능 추가 시점 단일 화면 대상**: HRR₁ 기능은 2026-03-12에 `HealthKitWorkoutDetailView`에만 구현됨 (docs/solutions/healthkit/2026-03-12-heart-rate-recovery-hrr1.md 참조)
2. **두 화면의 구조적 분리**: 앱 내 운동과 HealthKit 운동이 별도 View/ViewModel 트리로 존재하여 한쪽 변경이 다른 쪽에 자동 전파되지 않음
3. **공유 컴포넌트 부재**: 심박수 관련 UI가 각 View에 인라인으로 구현되어 있어 재사용 구조가 없음

### 재발 방지

1. 심박수 관련 UI 컴포넌트(차트 + 회복 행)를 `recoveryRow` 패턴으로 추출하여 양쪽에서 재사용
2. solution 문서에 영향 화면 목록을 명시하여 누락 방지

## Affected Files

| File | Change |
|------|--------|
| `DUNE/Presentation/Exercise/ExerciseSessionDetailView.swift` | HRR₁ fetch + recoveryRow 표시 추가 |

## Implementation Steps

### Step 1: ExerciseSessionDetailView에 recovery 상태 추가

- `@State private var heartRateRecovery: HeartRateRecovery?` 추가
- 기존 `loadHeartRate()` 함수에서 `heartRateService.fetchHeartRateRecovery(forWorkoutID:)` 병렬 호출 추가

### Step 2: recoveryRow UI 추가

- `heartRateSection` 내 심박수 차트 아래에 recovery row 표시
- `HealthKitWorkoutDetailView.recoveryRow()` 패턴 재사용 (동일 UI)
- `if let recovery = heartRateRecovery` 조건부 표시

## Test Strategy

- 기존 `HeartRateRecoveryTests`가 모델/알고리즘을 커버
- 새 View 변경은 UI 레벨 검증 (시뮬레이터 확인)
- `ExerciseSessionDetailView`는 HealthKit 실제 데이터에 의존하므로 유닛 테스트 면제 대상

## Risks & Edge Cases

- **HealthKit 링크 없는 세션**: `hasHealthKitLink`가 false일 때 recovery fetch 스킵 (기존 가드 활용)
- **Recovery 데이터 없음**: nil일 때 UI 미표시 (기존 `@ViewBuilder` 패턴)
- **로딩 타이밍**: recovery fetch는 HR summary와 병렬로 수행 (`async let`)
