---
tags: [visionos, localization, exercise-name, string-catalog, review-fix, locale-aware]
category: general
date: 2026-03-07
severity: important
related_files:
  - DUNE/Presentation/Vision/VisionExerciseFormGuideViewModel.swift
  - DUNEVision/Presentation/Activity/VisionExerciseFormGuideView.swift
  - DUNEVision/Presentation/Activity/VisionExerciseMuscleMapView.swift
  - DUNETests/VisionExerciseFormGuideViewModelTests.swift
  - Shared/Resources/Localizable.xcstrings
related_solutions:
  - docs/solutions/architecture/2026-03-07-vision-pro-exercise-form-guide.md
  - docs/solutions/architecture/full-localization-xcstrings.md
  - docs/solutions/general/2026-03-01-localization-leak-pattern-fixes.md
---

# Solution: Vision Guide Localization Review Fixes

## Problem

Vision Pro Exercise Form Guide를 머지한 뒤 `/review`에서 locale 관련 두 가지 문제가 드러났다. 새 guide surface가 `exercise.localizedName`을 그대로 제목에 사용해 English/Japanese locale에서도 Korean 운동명이 노출됐고, 근육맵의 rear silhouette 라벨은 기존 `"Back"` 키를 재사용해 body orientation이 아니라 muscle group 번역으로 표시됐다.

### Symptoms

- visionOS guide rail과 detail header에서 `Barbell Bench Press` 대신 `바벨 벤치프레스`처럼 Korean 이름이 고정으로 보였다.
- Korean이 아닌 locale에서는 subtitle에 의미 있는 보조 이름이 없어 title 계층이 locale 정책과 어긋났다.
- front/back body map의 rear 라벨이 `후면/背面`이 아니라 muscle 의미의 `등/背中`로 표시됐다.

### Root Cause

문제의 근본 원인은 두 데이터 소스를 같은 종류의 localization으로 취급한 데 있다.

- `ExerciseDefinition.localizedName`은 runtime locale에 따라 바뀌는 localized string이 아니라, exercise library에 저장된 Korean-friendly display field다.
- String Catalog의 `"Back"` 키는 이미 muscle group 의미로 쓰이고 있었는데, 새 뷰가 이를 body orientation 라벨로 재사용했다.

## Solution

guide title 표시를 `VisionExerciseGuide` helper로 추출해 locale별 표시 규칙을 한곳에 고정하고, rear silhouette에는 orientation 전용 `"Rear"` 키를 새로 추가했다. 동시에 Swift Testing으로 locale 선택 로직을 고정해 같은 실수가 다시 들어오지 않도록 했다.

### Changes Made

| File | Change | Reason |
|------|--------|--------|
| `DUNE/Presentation/Vision/VisionExerciseFormGuideViewModel.swift` | `primaryDisplayName(locale:)`, `secondaryDisplayName(locale:)`, `Locale.prefersKoreanExerciseNames` 추가 | guide title 정책을 shared helper로 고정하기 위해 |
| `DUNEVision/Presentation/Activity/VisionExerciseFormGuideView.swift` | title/header가 helper를 사용하도록 변경 | non-Korean locale에서 English exercise name을 기본으로 노출하기 위해 |
| `DUNEVision/Presentation/Activity/VisionExerciseMuscleMapView.swift` | rear 라벨을 `"Back"`에서 `"Rear"`로 변경 | muscle group 번역 키와 body orientation 키를 분리하기 위해 |
| `Shared/Resources/Localizable.xcstrings` | `"Rear"`의 ko/ja 번역 추가 | orientation 의미를 정확히 번역하기 위해 |
| `DUNETests/VisionExerciseFormGuideViewModelTests.swift` | locale별 title selection 테스트 2건 추가 | Korean-only field 오용이 다시 들어오는 것을 막기 위해 |

### Key Code

```swift
func primaryDisplayName(locale: Locale = .autoupdatingCurrent) -> String {
    let localized = exercise.localizedName.trimmingCharacters(in: .whitespacesAndNewlines)
    let english = exercise.name.trimmingCharacters(in: .whitespacesAndNewlines)

    if locale.prefersKoreanExerciseNames, !localized.isEmpty {
        return localized
    }

    return english.isEmpty ? localized : english
}
```

```swift
bodyView(isFront: false, label: "Rear")
```

## Prevention

새 visionOS/iOS surface에서 exercise title을 노출할 때는 `localizedName`을 곧바로 `Text()`에 넣지 말고, locale-aware display helper를 먼저 거치는 편이 안전하다. String Catalog key는 같은 영어 단어라도 의미 영역이 다르면 재사용하지 말고, UI 개념별로 별도 key를 둬야 한다.

### Checklist Addition

- [ ] `ExerciseDefinition.localizedName`을 runtime locale-aware 문자열로 가정하지 않았는지 확인한다.
- [ ] exercise title을 새 surface에 노출할 때 English/Korean/Japanese에서 어떤 이름이 primary인지 helper 수준에서 고정했는지 확인한다.
- [ ] `"Back"`, `"Body"`, `"Core"`처럼 의미가 겹칠 수 있는 일반 단어는 muscle/방향/상태 용도로 같은 key를 재사용하지 않는지 확인한다.
- [ ] review finding으로 locale policy가 바뀌면 Swift Testing으로 locale별 표시 결과를 함께 고정한다.

### Rule Addition (if applicable)

새 rule 파일 추가는 보류했다. 기존 `localization.md`가 문자열 처리 원칙은 이미 커버하고 있으므로, 이번 문서는 `ExerciseDefinition.localizedName`을 generic localized string으로 오해하지 말아야 한다는 구체적 사례 문서로 둔다.

## Lessons Learned

locale bug는 string literal 누락만으로 생기지 않는다. 이미 존재하는 data field나 catalog key도 의미 영역을 잘못 해석하면 같은 leak가 생긴다. 특히 exercise title처럼 도메인 데이터와 UI localization이 만나는 지점은 display policy를 helper로 추출하고 테스트로 고정하는 편이 가장 안전하다.
