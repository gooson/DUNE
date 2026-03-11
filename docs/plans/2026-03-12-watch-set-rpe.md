---
tags: [watch, rpe, exercise, workout-set, crown-input, digital-crown]
date: 2026-03-12
category: plan
status: approved
---

# Watch Per-Set RPE Picker

## Overview

watchOS 운동 세션에서 세트 완료 시 RPE(자각적 운동 강도)를 입력할 수 있도록 한다.
iOS에서 이미 구현된 SetRPEPickerView 패턴을 watchOS에 맞게 적용한다.

## Background

- iOS: `SetRPEPickerView` 9-button horizontal picker (6.0-10.0, 0.5 step)
- Domain: `RPELevel` struct, `WorkoutIntensityService.averageSetRPE()` — Shared에 위치, Watch 접근 가능
- Data: `WorkoutSet.rpe: Double?` 필드 이미 존재 (V14 migration)
- DTO: `WatchSetData.rpe: Double?` 이미 추가됨
- `CompletedSetData`에 rpe 필드 미존재 → 추가 필요

## Affected Files

| File | Change |
|------|--------|
| `DUNEWatch/Managers/WorkoutManager.swift` | `CompletedSetData.rpe` 추가, `completeSet()` rpe 파라미터 추가 |
| `DUNEWatch/Views/MetricsView.swift` | RPE 상태 관리, completeSet에 rpe 전달 |
| `DUNEWatch/Views/SetInputSheet.swift` | RPE 선택 UI 추가 (Digital Crown) |
| `DUNEWatch/Views/SessionSummaryView.swift` | WorkoutSet 생성 시 rpe 전달, WatchSetData에 rpe 전달 |
| `DUNEWatch/Views/Components/WatchSetRPEPickerView.swift` | 신규 — watchOS용 RPE 선택 컴포넌트 |

## Implementation Steps

### Step 1: CompletedSetData에 rpe 필드 추가

**파일**: `DUNEWatch/Managers/WorkoutManager.swift`

1. `CompletedSetData`에 `var rpe: Double?` 필드 추가
2. `completeSet(weight:reps:)` → `completeSet(weight:reps:rpe:)` 시그니처 변경
3. CompletedSetData 생성 시 rpe 전달
4. `WorkoutRecoveryState`는 CompletedSetData를 포함하므로 자동 호환 (Codable, Optional 필드)

**Verification**: 빌드 성공, 기존 호출부 컴파일 에러 → Step 2에서 수정

### Step 2: WatchSetRPEPickerView 생성

**파일**: `DUNEWatch/Views/Components/WatchSetRPEPickerView.swift` (신규)

watchOS 화면 크기에 맞는 RPE 선택 컴포넌트:
- 3x3 그리드 레이아웃 (9개 RPE 값: 6.0-10.0)
- 선택/해제 토글
- RPELevel 색상 매핑 (DS.Color.positive → negative 그라데이션)
- 선택 시 haptic feedback (.click)
- 컴팩트 폰트 (caption2 or caption)

**Design Decision**: iOS의 horizontal HStack은 watchOS에서 너무 작음 → 3x3 LazyVGrid 사용

**Verification**: Preview 정상 렌더링

### Step 3: SetInputSheet에 RPE 선택 통합

**파일**: `DUNEWatch/Views/SetInputSheet.swift`

1. `@Binding var rpe: Double?` 추가
2. Weight/Reps 입력 아래에 `WatchSetRPEPickerView` 배치
3. "Done" 버튼 탭 시 rpe 값이 parent로 전달됨

**Verification**: SetInputSheet에서 RPE 선택 후 dismiss 시 값 유지

### Step 4: MetricsView에서 RPE 상태 관리

**파일**: `DUNEWatch/Views/MetricsView.swift`

1. `@State private var rpe: Double?` 추가
2. SetInputSheet에 `rpe: $rpe` binding 전달
3. `executeCompleteSet()`에서 `workoutManager.completeSet(weight:reps:rpe:)` 호출
4. completeSet 후 `rpe = nil`로 리셋 (다음 세트는 fresh start)
5. 현재 세트 표시에 RPE badge 추가 (선택된 경우)

**Verification**: 세트 완료 후 rpe가 CompletedSetData에 저장됨

### Step 5: SessionSummaryView에서 RPE 전달

**파일**: `DUNEWatch/Views/SessionSummaryView.swift`

1. `saveWorkoutRecords()`: WorkoutSet 생성 시 `setData.rpe` 전달
2. WatchConnectivity 전송: `WatchSetData` 생성 시 `rpe: set.rpe` 전달
3. `applySetBasedRPE()` 호출 추가 — iOS와 동일 패턴으로 세트 RPE에서 세션 effort 자동 계산

**Verification**: 저장된 WorkoutSet에 rpe 값 존재, WatchConnectivity DTO에 rpe 포함

### Step 6: Localization

1. WatchSetRPEPickerView에서 사용하는 문자열 확인
2. "RPE" 자체는 이미 xcstrings에 등록됨
3. 새 문자열 필요 시 Watch xcstrings에 en/ko/ja 추가

**Verification**: xcstrings 키 누락 없음

## Test Strategy

- `CompletedSetData` rpe 필드 인코딩/디코딩: 기존 데이터(rpe 없는) 복원 시 nil 호환 확인
- `RPELevel.validate()`: 이미 DUNETests에 존재, 추가 불필요
- `averageSetRPE()`: 이미 DUNETests에 존재, 추가 불필요
- Watch 전용 테스트: WatchSetInputPolicy 수준 — RPE는 Optional이므로 validation 불필요

## Risks & Edge Cases

1. **화면 크기**: 3x3 그리드가 38mm Watch에서 터치 가능한지 확인 필요
   - 대안: 2-column ScrollView
2. **Crash recovery**: CompletedSetData는 UserDefaults에 Codable로 저장 — Optional rpe 추가는 backward compatible
3. **기존 세션 데이터**: rpe 없는 기존 CompletedSetData는 nil로 디코딩됨 — 문제 없음
4. **effort 자동 계산**: 세트 RPE가 하나라도 있으면 averageSetRPE로 effort 덮어쓰기 — 수동 effort와 충돌 가능
   - 해결: iOS와 동일하게 세트 RPE 우선, 없으면 수동 effort 유지

## References

- iOS SetRPEPickerView: `DUNE/Presentation/Exercise/Components/SetRPEPickerView.swift`
- RPELevel model: `DUNE/Domain/Models/WorkoutIntensity.swift`
- Watch effort input pattern: `docs/solutions/design/2026-03-06-watch-effort-input-step.md`
- iOS RPE integration: `docs/solutions/architecture/2026-03-12-set-rpe-integration.md`
