---
tags: [healthkit, heart-rate, recovery, hrr1, parity, feature-gap, shared-component]
date: 2026-03-30
category: solution
status: implemented
---

# Exercise Session Detail — HRR₁ Recovery Display Parity Fix

## Problem

`ExerciseSessionDetailView` (앱 내 생성 운동의 상세 화면)에 Heart Rate Recovery(HRR₁) 표시가 누락되어 있었다. 동일한 기능이 `HealthKitWorkoutDetailView` (HealthKit 전용 운동 상세)에는 2026-03-12부터 구현되어 있었다.

### Root Cause

1. **기능 추가 시점 단일 화면 대상**: HRR₁는 `HealthKitWorkoutDetailView`에만 구현됨
2. **구조적 분리**: 두 detail view가 별도 파일/ViewModel로 존재하여 한쪽 변경이 다른 쪽에 전파되지 않음
3. **공유 컴포넌트 부재**: recovery row UI가 각 View에 인라인 private 함수로 구현됨

## Solution

### 1. HeartRateRecoveryRow 공유 컴포넌트 추출

`HeartRateRecovery+View.swift`에 `HeartRateRecoveryRow` struct 추가. 양쪽 View에서 `HeartRateRecoveryRow(recovery:)` 호출로 통일.

### 2. ExerciseSessionDetailView에 recovery fetch 추가

- `@State private var heartRateRecovery: HeartRateRecovery?` 추가
- `loadHeartRate()`에서 `async let` 병렬 fetch
- `Task.isCancelled` 가드 추가 (review P2 해결)

### Files

| File | Change |
|------|--------|
| `Presentation/Shared/Extensions/HeartRateRecovery+View.swift` | `HeartRateRecoveryRow` struct 추가 |
| `Presentation/Exercise/ExerciseSessionDetailView.swift` | recovery fetch + 공유 컴포넌트 사용 |
| `Presentation/Exercise/HealthKitWorkoutDetailView.swift` | 인라인 `recoveryRow` → 공유 컴포넌트로 교체 |

## Prevention

1. **기능 추가 시 영향 화면 명시**: solution 문서에 "적용 대상 화면" 섹션을 포함하여 누락 방지
2. **공통 UI 즉시 추출**: 동일 UI가 2곳에서 사용되면 즉시 `Shared/` 컴포넌트로 추출
3. **Parity 체크리스트**: HealthKit 데이터 표시 기능 추가 시, `ExerciseSessionDetailView`와 `HealthKitWorkoutDetailView` 양쪽 적용 여부 확인

## Lessons Learned

- HealthKit 데이터 표시 관련 기능은 항상 두 화면(앱 내 운동 / HealthKit 전용 운동)에 적용해야 함
- 코드 복제로 시작하더라도 review 단계에서 공유 컴포넌트로 추출하는 것이 효과적
- solution 문서의 "Files" 테이블이 영향 범위 누락을 사후에 발견하는 데 유용 — 기존 solution 문서에 ExerciseSessionDetailView가 없었음이 단서
