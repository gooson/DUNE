---
tags: [workout, effort, rpe, watch, ios, recommendation, localization]
category: general
date: 2026-03-03
severity: important
related_files:
  - DUNE/Domain/UseCases/WorkoutIntensityService.swift
  - DUNE/Presentation/Exercise/Components/EffortSliderView.swift
  - DUNE/Presentation/Exercise/CompoundWorkoutView.swift
  - DUNEWatch/Views/SessionSummaryView.swift
  - DUNE/Domain/Models/WatchConnectivityModels.swift
  - DUNE/Data/WatchConnectivity/WatchSessionManager.swift
  - DUNE/Resources/Localizable.xcstrings
  - DUNEWatch/Resources/Localizable.xcstrings
related_solutions: []
---

# Solution: iOS/Watch 운동 종료 강도 추천·이력·입력 통합

## Problem

운동 강도 입력이 특정 경로에만 노출되거나(예: 일부 운동 타입), 종료 화면에서 히스토리 기반 추천이 누락되어 Apple Fitness 스타일의 일관된 UX를 제공하지 못했다.

### Symptoms

- iOS 일부 종료 플로우(특히 Compound)에서 추천 강도 UI가 비활성 또는 미노출
- Watch 종료 시점에서 추천/이력 기반 입력이 없거나 저장/동기화가 불완전
- 강도 입력 관련 신규 문자열이 String Catalog에 등록되지 않아 번역 누출 위험 존재

### Root Cause

- 추천 모델(`EffortSuggestion`)이 최근 이력 컨텍스트를 충분히 제공하지 못함
- Watch 타깃에서 공용 타입 직접 의존 시 컴파일 경계 문제가 발생함
- WatchConnectivity DTO에 강도(`rpe`) 필드가 없어 iOS 수신 검증 경로와의 연결이 약함
- UI 문자열 추가 시 iOS/Watch 각각의 xcstrings 동기화가 누락됨

## Solution

도메인 추천 모델, iOS/Watch 종료 UI, DTO 동기화, localization을 한 번에 정렬했다.

### Changes Made

| File | Change | Reason |
|------|--------|--------|
| `DUNE/Domain/Models/WorkoutIntensity.swift` | `EffortSuggestion.recentEfforts` 추가 | 추천 근거 이력 컨텍스트 제공 |
| `DUNE/Domain/UseCases/WorkoutIntensityService.swift` | `suggestEffort`에서 최근 5개 유효 강도 필터/반환 | 추천 품질 및 표시 데이터 일관성 확보 |
| `DUNE/Presentation/Exercise/Components/EffortSliderView.swift` | 추천 배지 + 최근 이력 UI 추가 | iOS 종료 UX를 Apple Fitness 스타일에 맞춤 |
| `DUNE/Presentation/Exercise/CompoundWorkoutView.swift` | Compound 종료에도 추천 계산/전달 | "모든 운동에서 강도 입력" 요구 충족 |
| `DUNE/Domain/Models/WatchConnectivityModels.swift` | `WatchWorkoutUpdate.rpe` 추가 | Watch→iOS 강도 동기화 경로 확보 |
| `DUNE/Data/WatchConnectivity/WatchSessionManager.swift` | 수신 `rpe` 범위 검증(1...10) | 데이터 무결성 강화 |
| `DUNEWatch/Views/SessionSummaryView.swift` | 종료 강도 UI/추천/저장 + cardio 타입 기반 히스토리 필터 | Watch 종료 경험 완성 및 추천 정합성 개선 |
| `DUNE/Resources/Localizable.xcstrings` | iOS 추천 문구 키 추가 | 번역 누락 방지 |
| `DUNEWatch/Resources/Localizable.xcstrings` | Watch 추천/레이블 키 추가 | 번역 누락 방지 |

### Key Code

```swift
// Watch cardio는 템플릿 ID가 없으므로 activityType 기준으로 이력을 우선 필터링
if ids.isEmpty {
    guard case .cardio(let activityType, _) = workoutManager.workoutMode else { return true }
    let cardioID = activityType.rawValue
    let cardioName = activityType.typeName
    if let definitionID = record.exerciseDefinitionID {
        return definitionID == cardioID
    }
    return record.exerciseType == cardioID || record.exerciseType == cardioName
}
```

## Prevention

### Checklist Addition

- [ ] Watch 종료 UX 변경 시 `ExerciseRecord.rpe` 저장/추천 표시/DTO 전송이 모두 연결되었는지 확인
- [ ] WatchConnectivity DTO 필드 추가 시 iOS/Watch 양측 decode + validation 동기화 확인
- [ ] 종료 화면 신규 문구 추가 시 iOS/Watch xcstrings 동시 반영 확인

### Rule Addition (if applicable)

기존 교정 규칙 #69/#138/#190(Watch DTO 양측 동기화)와 localization 규칙으로 커버 가능해 신규 rule 추가는 보류.

## Lessons Learned

- Watch 타깃 컴파일 경계가 있을 때는 공용 모델 직접 의존보다 로컬 adapter/suggestion 모델이 실전적으로 안전하다.
- "종료 UI 노출"만 맞추면 충분하지 않고, 추천 계산 근거(히스토리 스코프)와 저장/동기화(DTO, validation)까지 묶어야 회귀가 줄어든다.
