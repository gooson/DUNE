---
tags: [visionos, swiftui, exercise-library, localization, muscle-map, spatial-guide]
category: architecture
date: 2026-03-07
severity: important
related_files:
  - DUNE/Presentation/Vision/VisionExerciseFormGuideViewModel.swift
  - DUNEVision/Presentation/Activity/VisionExerciseFormGuideView.swift
  - DUNEVision/Presentation/Activity/VisionExerciseMuscleMapView.swift
  - DUNE/Data/ExerciseDescriptions.swift
  - DUNE/Domain/Protocols/ExerciseLibraryQuerying.swift
  - DUNE/project.yml
  - DUNETests/VisionExerciseFormGuideViewModelTests.swift
  - Shared/Resources/Localizable.xcstrings
related_solutions:
  - docs/solutions/architecture/2026-03-07-svg-extruded-muscle-map-shared-scene.md
---

# Solution: Vision Pro Exercise Form Guide Foundation

## Problem

Vision Pro roadmap의 C5 Exercise Form Guide는 TODO에만 남아 있었고, 실제 `Train` 탭에서는 spatial muscle map experience로 바로 진입할 뿐 운동별 셋업 설명이나 form cue를 미리 확인할 수 없었다. 결과적으로 사용자는 공간 씬에 들어가기 전에 어떤 lift를 기준으로 봐야 하는지, 어떤 근육을 의식해야 하는지 확인할 수 있는 준비 단계가 비어 있었다.

### Symptoms

- visionOS `Train` 탭에 운동별 가이드 검색/선택 UI가 없었다.
- `ExerciseLibraryService`, `ExerciseDescriptions`, `exercises.json` 같은 shared exercise metadata가 `DUNEVision` target에 연결되지 않아 guide UI를 바로 재사용할 수 없었다.
- `conventional-deadlift`처럼 실제 라이브러리 ID와 설명 메타데이터 키가 어긋나는 항목은 cue/description fallback이 없으면 빈 상태가 됐다.

### Root Cause

문제의 근본 원인은 C5를 full-avatar/body-tracking 문제로만 보고 있었기 때문이다. 그 결과 "지금 바로 ship 가능한 foundation"과 "후속 capability가 필요한 advanced scope"가 분리되지 않았고, shared exercise library를 visionOS surface에 연결하는 최소 wiring도 준비되지 않았다.

## Solution

이번 배치에서는 C5를 spatial guide foundation으로 재정의했다. `VisionExerciseFormGuideViewModel`이 지원 lift를 정해진 순서로 로드하고, visionOS 전용 guide panel이 검색, form cue, equipment, target muscle visualization을 제공하도록 구성했다. 동시에 `DUNEVision` target에 exercise library/resource를 포함해 iOS의 shared metadata를 그대로 재사용하게 만들었다.

### Changes Made

| File | Change | Reason |
|------|--------|--------|
| `DUNE/Presentation/Vision/VisionExerciseFormGuideViewModel.swift` | Added shared guide loader, search/filter logic, selection normalization, metadata fallback | visionOS UI가 domain data를 직접 만지지 않고 테스트 가능한 shared state를 사용하도록 분리 |
| `DUNEVision/Presentation/Activity/VisionExerciseFormGuideView.swift` | Added guide header, search field, rail cards, detail panel | `Train` 탭에서 supported lift guide를 바로 탐색할 surface 제공 |
| `DUNEVision/Presentation/Activity/VisionExerciseMuscleMapView.swift` | Added lightweight front/back muscle highlight view | guide detail 안에서 타깃 근육을 2D로 즉시 확인 가능하게 함 |
| `DUNEVision/Presentation/Activity/VisionTrainView.swift` | Inserted form guide ahead of spatial muscle map experience | C5 foundation을 기존 visionOS activity flow 안에 실제 노출 |
| `DUNE/Data/ExerciseDescriptions.swift` | Added `conventional-deadlift` description and cues | 실제 exercise ID와 metadata key mismatch를 보정 |
| `DUNE/Domain/Protocols/ExerciseLibraryQuerying.swift` | Guarded `TemplateEntry` helper from visionOS compilation | `DUNEVision`이 shared protocol을 가져오되 visionOS에 없는 template model 참조는 차단 |
| `DUNE/project.yml` | Added exercise library sources/resources and shared display extensions to `DUNEVision` | visionOS target이 shared exercise metadata와 display helpers를 빌드에 포함하도록 보장 |
| `DUNETests/VisionExerciseFormGuideViewModelTests.swift` | Added search, selection, fallback coverage | guide foundation의 핵심 상태 전이를 회귀 테스트로 고정 |
| `Shared/Resources/Localizable.xcstrings` | Added guide copy, cues, and labels in ko/ja | visionOS UI 문자열 누락 없이 string catalog에 등록 |

### Key Code

```swift
guides = guideExerciseIDs.compactMap { id in
    guard let exercise = library.exercise(byID: id) ?? library.representativeExercise(byID: id) else {
        return nil
    }
    return Self.makeGuide(for: exercise)
}
```

```swift
VisionExerciseMuscleMapView(
    primaryMuscles: guide.exercise.primaryMuscles,
    secondaryMuscles: guide.exercise.secondaryMuscles
)
```

## Prevention

C5처럼 capability-heavy roadmap item은 처음부터 full implementation만 목표로 잡지 말고, "shared data wiring + shippable foundation UI"를 먼저 분리하는 편이 안전하다. visionOS 전용 surface가 shared model/resource를 필요로 할 때는 `project.yml`에 소스와 리소스를 명시적으로 추가하고, 바로 `scripts/lib/regen-project.sh`와 `xcodebuild build -destination 'generic/platform=visionOS'`까지 묶어서 검증해야 한다.

### Checklist Addition

- [ ] visionOS feature가 iOS shared metadata를 재사용할 때 `project.yml` source/resource wiring과 platform build를 같은 배치에서 함께 검증한다.
- [ ] exercise metadata ID와 UI lookup key가 다를 수 있으므로 fallback mapping이 필요한지 먼저 확인한다.
- [ ] 새 guide/cue copy를 `String Catalog`에 추가할 때 helper 함수 인자 타입이 `LocalizedStringKey` 또는 `String(localized:)` 패턴을 유지하는지 확인한다.

### Rule Addition (if applicable)

새 rule 추가는 필요 없었다. 기존 `localization.md`, `swift-layer-boundaries.md`, `testing-required.md`로 이번 변경을 충분히 검증할 수 있었다.

## Lessons Learned

Vision Pro roadmap에서 body tracking이 필요한 고난도 기능도, 그 전에 ship 가능한 guide foundation이 있다. shared exercise library와 muscle map 자산을 먼저 visionOS에 연결해 두면, 이후 avatar demo, body comparison, voice entry 같은 확장도 같은 data surface 위에서 단계적으로 붙일 수 있다.
