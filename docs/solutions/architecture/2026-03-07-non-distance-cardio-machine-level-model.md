---
tags: [swift, swiftui, watchos, swiftdata, cardio, machine-level, migration, localization]
category: architecture
date: 2026-03-07
severity: important
related_files:
  - DUNE/Domain/Models/CardioSecondaryUnit.swift
  - DUNE/Domain/Models/WorkoutActivityType.swift
  - DUNE/Presentation/Exercise/CardioSession/CardioSessionViewModel.swift
  - DUNEWatch/Managers/WorkoutManager.swift
  - DUNE/Data/Persistence/Migration/AppSchemaVersions.swift
related_solutions:
  - docs/solutions/architecture/2026-02-28-cardio-secondary-unit-pattern.md
  - docs/solutions/architecture/2026-03-02-ios-cardio-live-tracking.md
  - docs/solutions/general/2026-03-02-phone-watch-cardio-parity.md
---

# Solution: Non-Distance Cardio as Machine-Level Sessions

## Problem

비거리 유산소(스텝 클라이머, 엘립티컬 등)가 `durationDistance` 운동이더라도 실제 시작 흐름에서는 거리 기반 유산소로만 분기돼서, 세트/횟수 중심 기록 모델과 충돌하고 있었습니다.

### Symptoms

- 스텝 클라이머가 유산소가 아니라 세트 운동처럼 기록됐다.
- `floors`가 사실상 `reps` 대체 필드처럼 저장돼 의미가 뒤틀렸다.
- 워치와 iPhone 모두 시간은 자동 측정하면서도 강도 입력이 없어서 칼로리/강도 추정이 부정확했다.
- 워치 라이브러리 메타데이터가 늦게 동기화되면 거리 유산소까지 실내 전용처럼 보일 수 있었다.

### Root Cause

- 카디오 시작 분기가 `isDistanceBased` 중심이라 비거리 유산소를 공통 카디오 세션으로 태우지 못했다.
- `CardioSecondaryUnit`는 저장 필드 라우팅까지만 표현하고, 머신 강도 모델은 표현하지 못했다.
- 세션 레이어(iOS `CardioSessionViewModel`, watch `WorkoutManager`)에 레벨 기반 집계 상태가 없었다.
- SwiftData 스키마 변경 시 V10 스냅샷을 완전한 모델 쌍으로 고정하지 않으면 staged migration checksum 충돌이 발생했다.

## Solution

비거리 유산소를 "시간 자동 측정 + 레벨 입력" 머신 카디오 세션으로 재정의하고, iPhone/watch/persistence를 같은 모델로 맞췄습니다.

### Changes Made

| File | Change | Reason |
|------|--------|--------|
| `DUNE/Domain/Models/CardioSecondaryUnit.swift` | 머신 레벨 지원 여부, 레벨 범위, intensity score, MET multiplier 추가 | 도메인에서 비거리 머신 카디오 규칙을 공통 표현 |
| `DUNE/Domain/Models/WorkoutActivityType.swift` | `resolveCardioActivity` 추가 | 거리 기반 여부와 상관없이 단일 카디오 세션 진입 판단 |
| `DUNE/Presentation/Exercise/CardioSession/CardioSessionViewModel.swift` | 레벨 입력, 시간가중 평균/최대 레벨, MET 보정 로직 추가 | iPhone 라이브 세션을 머신 강도 기반으로 계산 |
| `DUNEWatch/Managers/WorkoutManager.swift` | 워치 세션에 `cardioSecondaryUnit`와 레벨 집계 상태 추가 | 워치 실시간 조작과 세션 요약을 동일 모델로 유지 |
| `DUNEWatch/Views/WorkoutPreviewView.swift` | cardio unit fallback 추가 | 메타데이터 미동기화 시에도 거리 유산소의 실외 옵션 유지 |
| `DUNE/Data/Persistence/Models/ExerciseRecord.swift` | 평균/최대 레벨 저장 필드 추가 | 기록/히스토리/요약에서 머신 강도 복원 |
| `DUNE/Data/Persistence/Migration/AppSchemaVersions.swift` | V11 추가, V10 snapshot self-contained화 | staged migration checksum 충돌 없이 저장소 진화 |
| `DUNE/Resources/Localizable.xcstrings` / `DUNEWatch/Resources/Localizable.xcstrings` | `Level`, `Avg Level`, `Max Level` 등 추가 | 새 머신 카디오 UI 문자열 로컬라이즈 |
| `DUNETests/*`, `DUNEWatchTests/WatchEffortInputPolicyTests.swift` | 머신 카디오 테스트와 로케일 민감 테스트 보강 | 회귀 방지 및 전체 테스트 그린 유지 |

### Key Code

```swift
static func resolveCardioActivity(
    from id: String,
    name: String,
    inputTypeRaw: String? = nil
) -> WorkoutActivityType? {
    if let inputTypeRaw,
       !inputTypeRaw.isEmpty,
       !cardioInputTypes.contains(inputTypeRaw) {
        return nil
    }

    if let type = WorkoutActivityType(rawValue: id), type.category == .cardio {
        return type
    }

    let stem = id.components(separatedBy: "-").first ?? ""
    if !stem.isEmpty, let type = WorkoutActivityType(rawValue: stem), type.category == .cardio {
        return type
    }

    if let type = infer(from: name), type.category == .cardio {
        return type
    }

    return .mixedCardio
}
```

```swift
private func captureMachineLevelSegment(until date: Date) {
    guard supportsMachineLevel else { return }
    guard let lastMachineLevelSampleDate else {
        self.lastMachineLevelSampleDate = date
        return
    }

    let delta = max(date.timeIntervalSince(lastMachineLevelSampleDate), 0)
    guard delta > 0 else { return }

    let segmentMET = exercise.metValue * cardioUnit.metMultiplier(forMachineLevel: currentMachineLevel)
    machineAdjustedMETSeconds += segmentMET * delta

    if let currentMachineLevel {
        machineLevelWeightedSeconds += delta
        machineLevelWeightedSum += Double(currentMachineLevel) * delta
        averageMachineLevel = machineLevelWeightedSum / machineLevelWeightedSeconds
    }

    self.lastMachineLevelSampleDate = date
}
```

## Prevention

### Checklist Addition

- [ ] 카디오 진입 분기를 만들 때 `distance-based`와 `cardio`를 같은 개념으로 취급하지 않는다.
- [ ] watch preview가 라이브러리 메타데이터 부재 시 안전한 fallback unit을 가지는지 확인한다.
- [ ] SwiftData schema snapshot을 도입할 때 관계 모델(`ExerciseRecord`/`WorkoutSet`)을 반쯤만 스냅샷하지 않는다.
- [ ] 새 사용자 문자열을 추가하면 iOS/watch `xcstrings` 둘 다 함께 갱신한다.

### Rule Addition (if applicable)

새 규칙 파일까지 추가할 정도는 아니지만, 향후 카디오 모델 변경은 `cardio unit`, `session UI`, `watch recovery`, `migration`, `localization`을 한 묶음으로 리뷰하는 게 안전합니다.

## Lessons Learned

- 유산소 분류에서 "거리 측정 가능"은 하위 속성이고, 시작/저장 모델의 1차 기준은 "cardio session인지"가 맞다.
- 워치 메타데이터는 동기화 지연이 있기 때문에, UI gating을 원격 필드에만 의존하면 정상 운동도 막힐 수 있다.
- SwiftData staged migration은 checksum 충돌과 unknown coordinator model version에 매우 민감해서, snapshot 모델을 부분적으로만 분리하면 런타임에서 바로 터진다.
