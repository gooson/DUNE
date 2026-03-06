---
tags: [theme, hanok, materiality, roof-tile, dancheong, hanji, watch]
date: 2026-03-06
category: solution
status: implemented
---

# 한옥 테마 소재감 강화

## Problem

기존 Hanok 테마는 옥색 계열 리뉴얼과 sway animation까지는 들어가 있었지만, 실제 사용감은 여전히 "색만 바뀐 테마"에 가까웠다.

주요 부족점:

- 기와 청회색과 먹빛 중심의 roof identity가 약함
- 궁전 기와 끝 문양 같은 상징적 모티프가 없음
- 한지 texture가 재료감보다 옥색 tint로 읽힘
- watch 배경은 Hanok 전용 처리가 없어 iOS 대비 parity가 낮음

## Solution

### 1. Hanok palette를 `jade 중심`에서 `기와 + 한지 + 단청 포인트`로 재정렬

기존 asset 이름은 유지하고 `Shared/Resources/Colors.xcassets/Hanok*.colorset` 값만 교체했다.

핵심 방향:

- Base: slate/ink roof tones (`HanokDeep`, `HanokMid`, `HanokDusk`)
- Surface: warm paper ivory (`HanokSand`, `HanokCardBackground`)
- Accent: muted celadon + restrained cinnabar (`HanokAccent`, `HanokScoreExcellent`)

이 접근으로 기존 theme architecture와 prefix resolver를 그대로 유지하면서 인상만 바꿨다.

### 2. Hanok background에 roof-end motif overlay 추가

`HanokRoofTileSealShape`를 추가해 궁전 기와 끝 문양을 단순화한 medallion motif를 만들고,
`HanokRoofSealOverlay`로 Tab/Detail/Sheet에 강도만 다르게 공통 적용했다.

적용 포인트:

- top trailing ornament
- 얇은 roofline capsule
- sand + cinnabar + deep ink gradient stroke

결과적으로 background만 봐도 Hanok identity가 더 직접적으로 읽히게 했다.

### 3. Hanji texture를 종이 재질로 다시 조정

`HanjiTextureView`는 기존 jade fiber 단일 톤에서,
warm ivory fiber + cool slate fiber 혼합으로 바꿨다.

추가 조정:

- `softLight` blend 적용
- Detail/Sheet에도 약한 hanji overlay 허용
- Dark mode에서는 opacity를 더 낮게 유지

### 4. ThemePicker와 Watch parity 보강

- `ThemePickerSection`에 Hanok 전용 seal badge 추가
- 기존 Shanks badge도 row theme 색을 직접 사용하도록 정리
- `WatchWaveBackground`에 Hanok 전용 분기와 seal overlay를 추가해 iOS와 정체성을 맞췄다

### 5. 회귀 테스트 추가

`DUNETests/HanokEaveShapeTests.swift`에 `HanokRoofTileSealShape` smoke test 3개를 추가했다.

- square rect path 생성
- wide rect path 생성
- zero-size rect empty path

## Prevention

### Theme enhancement checklist

- [ ] 색상 교체만으로 끝내지 않고 theme-specific motif를 함께 넣었는가?
- [ ] Tab / Detail / Sheet에서 motif 강도를 단계적으로 조절했는가?
- [ ] iOS와 Watch에서 theme parity가 유지되는가?
- [ ] texture는 색감이 아니라 materiality로 읽히는가?

### Verification notes

- iOS build: `scripts/build-ios.sh --no-regen --log-file .xcodebuild/hanok-theme-build.log`
- targeted tests:
  - `xcodebuild test ... -only-testing DUNETests/AppThemeTests -only-testing DUNETests/HanokEaveShapeTests`
- watch build:
  - `xcodebuild build -project DUNE/DUNE.xcodeproj -scheme DUNEWatch -destination 'generic/platform=watchOS' ...`

### Remaining baseline issue

전체 `scripts/test-unit.sh --no-regen` 는 이번 변경과 무관한 기존 실패들로 여전히 red 상태였다.
확인된 선행 실패 예:

- `NotificationExerciseDataTests`
- `TemplateWorkoutViewModelTests`
- `WidgetScoreDataTests`

이번 작업 검증은 변경 관련 타깃 테스트와 watch build로 분리해 확인했다.
