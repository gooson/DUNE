---
tags: [rpe, set-level, workout, intensity, ui-integration]
date: 2026-03-12
category: plan
status: approved
---

# Set-Level RPE Integration Plan

## Summary

기존 4개 커밋(스키마, 모델, DTO, UI picker)을 기반으로 RPE picker를 iOS 운동 세션 UI에 통합하고, 세트별 RPE를 저장·표시·집계하는 작업.

## Already Done (4 commits)

| Commit | Content |
|--------|---------|
| V13 schema migration | `WorkoutSet.rpe: Double?` 필드 추가 |
| RPELevel model | validate, displayLabel, rir, levels array |
| averageSetRPE | `WorkoutIntensityService.averageSetRPE(sets:)` — working/failure/drop sets에서 평균 RPE → 1-10 effort 매핑 |
| WatchSetData.rpe | DTO `rpe: Double?` + isValid에 RPELevel.range 검증 |
| SetRPEPickerView | 6.0-10.0 수평 버튼 picker (미연결 상태) |

## Remaining Integration

### Step 1: EditableSet.rpe 필드 추가
- **File**: `DUNE/Presentation/Exercise/WorkoutSessionViewModel.swift`
- **Change**: `EditableSet`에 `var rpe: Double? = nil` 추가
- **Verification**: 컴파일 확인

### Step 2: SetRowView에 RPE 표시 통합
- **File**: `DUNE/Presentation/Exercise/Components/SetRowView.swift`
- **Change**: 완료된 세트 행에 RPE 배지 표시 (rpe != nil인 경우). 세트 행에 RPE 값 캡슐 표시
- **Design**: 체크마크 옆에 작은 RPE 캡슐 (e.g. "8.0") — 행 내부, compact
- **Verification**: Preview에서 RPE 있는/없는 세트 확인

### Step 3: 운동 세션에 RPE picker 연결
- **File**: `DUNE/Presentation/Exercise/WorkoutSessionView.swift`
- **Change**: 세트 목록 아래에 현재 세트의 RPE picker 표시. `SetRPEPickerView(rpe: $currentSetRPE)` 추가
- **Note**: RPE 입력은 선택사항 — 세트 완료 시 현재 RPE 값을 EditableSet에 저장
- **Verification**: 세션 화면에서 RPE 선택 가능

### Step 4: WorkoutSessionViewModel — RPE 저장 경로
- **File**: `DUNE/Presentation/Exercise/WorkoutSessionViewModel.swift`
- **Change**: `createValidatedRecord()` 내 WorkoutSet 생성 시 `rpe: editableSet.rpe` 전달
- **Verification**: 세트 저장 후 WorkoutSet.rpe 값 존재 확인

### Step 5: TemplateWorkoutView/CompoundWorkoutView 동일 통합
- **Files**: `TemplateWorkoutView.swift`, `CompoundWorkoutView.swift` (및 해당 ViewModel)
- **Change**: Step 3-4와 동일한 패턴으로 RPE picker + 저장 경로 추가
- **Note**: 이 뷰들은 WorkoutSessionView와 유사한 세트 입력 구조를 공유
- **Verification**: 템플릿/컴파운드 운동에서도 RPE 저장 가능

### Step 6: ExerciseSessionDetailView — 세트별 RPE 표시
- **File**: `DUNE/Presentation/Exercise/ExerciseSessionDetailView.swift`
- **Change**: `setRow(_:)` 함수에서 `workoutSet.rpe != nil`인 경우 RPE 배지 표시
- **Verification**: 운동 히스토리에서 RPE 확인 가능

### Step 7: averageSetRPE → session effort 자동 계산
- **File**: `DUNE/Presentation/Exercise/WorkoutSessionView.swift` (effort computation path)
- **Change**: 세션 완료 시 세트별 RPE가 있으면 `averageSetRPE` 호출하여 session-level effort 자동 제안
- **Note**: 기존 effort slider의 초기값으로 사용. 사용자가 override 가능
- **Verification**: 세트 RPE 입력 후 세션 완료 시 effort 자동 제안 확인

### Step 8: Tests
- **File**: `DUNETests/RPELevelTests.swift` (new)
- **Coverage**:
  - RPELevel.validate: 범위 내/외, NaN, Infinity, snap 동작
  - RPELevel.rir: 각 RPE 값별 RIR 매핑
  - RPELevel.displayLabel: 각 범위별 라벨
  - averageSetRPE: warmup 제외, 빈 입력, 단일/복수, 무효 값
- **Verification**: `xcodebuild test` 통과

### Step 9: Localization
- **Files**: `Shared/Resources/Localizable.xcstrings`, `DUNEWatch/Resources/Localizable.xcstrings`
- **Change**: 새 UI 문자열 en/ko/ja 번역 추가
  - "RPE" (번역 면제 — 국제 표준 약어)
  - "%d reps left" (RIR 표시)
  - RPELevel.displayLabel 문자열 ("Max Effort", "Very Hard", "Hard", "Moderate", "Light")
- **Note**: displayLabel 문자열은 이미 `String(localized:)` 사용 중
- **Verification**: xcstrings 파일에 en/ko/ja 키 존재

## Affected Files

| File | Change Type |
|------|------------|
| `WorkoutSessionViewModel.swift` | EditableSet.rpe 추가, 저장 경로 |
| `SetRowView.swift` | RPE 배지 표시 |
| `WorkoutSessionView.swift` | RPE picker 연결, effort 자동 계산 |
| `TemplateWorkoutView.swift` | RPE picker + 저장 |
| `CompoundWorkoutView.swift` | RPE picker + 저장 |
| `TemplateWorkoutViewModel.swift` | RPE 저장 경로 |
| `CompoundWorkoutViewModel.swift` | RPE 저장 경로 |
| `ExerciseSessionDetailView.swift` | 세트별 RPE 표시 |
| `RPELevelTests.swift` (new) | 유닛 테스트 |
| `Localizable.xcstrings` (shared) | 번역 추가 |

## Test Strategy

- **Unit Tests**: RPELevel validation, rir mapping, displayLabel, averageSetRPE 로직
- **Manual Verification**: 운동 세션에서 RPE 선택 → 저장 → 히스토리 표시 확인

## Risks & Edge Cases

1. **RPE optional**: RPE 미입력 시 nil — 모든 경로에서 nil 안전성 확인
2. **CloudKit sync**: WorkoutSet.rpe가 V13 migration에서 이미 추가됨 — 추가 migration 불필요
3. **Watch RPE**: WatchSetData.rpe DTO 이미 존재 — Watch에서 RPE 입력 UI는 이번 범위 제외 (향후)
4. **TemplateWorkout/CompoundWorkout**: WorkoutSessionView와 동일한 패턴이지만 독립적인 save 경로 — 누락 주의
