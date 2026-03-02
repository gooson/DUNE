---
tags: [localization, watchos, navigation-title, tab-title, xcstrings, swiftui]
category: general
date: 2026-03-02
severity: important
related_files:
  - DUNE/App/AppSection.swift
  - DUNE/App/ContentView.swift
  - DUNE/Presentation/Shared/Extensions/View+NavigationTitlePolicy.swift
  - DUNE/Presentation/Shared/Extensions/Date+Validation.swift
  - DUNEWatch/Views/CarouselHomeView.swift
  - DUNEWatch/Views/QuickStartAllExercisesView.swift
  - DUNEWatch/Views/WorkoutPreviewView.swift
  - DUNE/Resources/Localizable.xcstrings
related_solutions:
  - docs/solutions/general/localization-gap-audit.md
  - docs/solutions/general/2026-03-01-localization-leak-pattern-fixes.md
  - docs/solutions/general/2026-03-02-training-readiness-localization-leak-fix.md
---

# Solution: Tab/Navigation 영어 고정 + Watch 로컬라이즈 누락 일괄 수정

## Problem

사용자 제보 화면에서 다음 문제가 반복 노출되었습니다.

- iOS 탭/네비게이션 타이틀 정책 불일치(영어 고정 규칙 필요)
- Watch 홈/운동 시작 흐름에서 `Popular`, `Outdoor`, `Indoor`, `Strength` 등 영어 누락 노출
- 상대 날짜 라벨(`Today`, `2d ago`, `N days ago`)의 locale 적용 불안정

## Root Cause

1. iOS에서 타이틀 렌더링이 파일별로 분산되어 정책 강제가 어려웠음
2. Watch View에 하드코딩 `String` 리터럴이 남아 있어 `String Catalog` lookup이 우회됨
3. 날짜 라벨이 문자열 조합 방식(`"\(days)d ago"`)으로 생성되어 카탈로그 키(`%@ days ago`)와 불일치
4. `Localizable.xcstrings`에 일부 키 자체가 누락

## Solution

### 1) iOS 정책 고정

- `AppSection.title`을 영어 고정 `String`으로 단일 소스화
- 탭 라벨을 `Text(verbatim:)`로 고정 렌더링
- `englishNavigationTitle(_:)` 공통 API를 추가하고 iOS 전 화면에 적용
- Correction Log에 정책 항목 추가

### 2) 날짜 라벨 로컬라이즈 경로 정리

- `Date+Validation`에서 `Today/Yesterday`를 `String(localized:)`로 통일
- `N days ago`는 `String(format: String(localized: "%@ days ago"), locale: .current, ...)`로 포맷 안전화

### 3) Watch 주요 화면 누락 정리

- `CarouselHomeView`: `Routine/Popular/Recent/Browse`, `Browse All`, empty-state 문구, `days ago` 라벨 localize
- `QuickStartAllExercisesView`: `Strength/Bodyweight/Cardio/HIIT/Flexibility/Other`, `All Exercises`, `Search`, `No Exercises` localize
- `WorkoutPreviewView`: `Outdoor/Indoor`, alert(`Error`/`OK`), `Start`, 운동 수 헤더 localize

### 4) String Catalog 보강

- 추가 키: `Active Indicators`, `Physical`, `Routine`, `Browse`, `Browse All`, `Search`, `Open the DUNE app\non your iPhone to sync`
- `Today` 키의 `shouldTranslate: false` 제거

## Verification

- `scripts/build-ios.sh --log-file .xcodebuild/run-localization-build.log` → **BUILD SUCCEEDED**
- `scripts/test-unit.sh` 2회 시도 → 실패(시뮬레이터 런타임 미탑재/서비스 다운, 코드 실패 아님)
- `jq empty DUNE/Resources/Localizable.xcstrings` → JSON 유효
- 제보 문자열 경로(`Popular`, `Outdoor/Indoor`, `Strength`, `Today/days`) 코드상 localize 경로 확인

## Prevention

- View 문자열 리터럴을 UI 출력에 직접 전달하지 않고 `String(localized:)` 또는 `LocalizedStringKey`를 사용
- 동적 날짜/수량 문구는 interpolation 대신 catalog format key(`%@`, `%lld`) + `String(format:locale:)` 사용
- iOS 네비게이션 타이틀은 `englishNavigationTitle(_:)`만 사용
