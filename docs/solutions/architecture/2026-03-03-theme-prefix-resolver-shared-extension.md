---
tags: [theme, architecture, watchos, design-system, refactor, automation]
date: 2026-03-03
category: solution
status: implemented
---

# Theme Prefix Resolver + Shared Extension 통합

## Problem

새 테마를 추가할 때 iOS(`AppTheme+View`)와 watchOS(`AppTheme+WatchView`)에 동일한 `switch self` 매핑을 반복 추가해야 했다.
이 구조는 다음 문제를 만들었다.

### Symptoms

- 테마 색상 매핑 로직이 iOS/Watch에 중복되어 동시 반영 누락 위험이 큼
- 매핑 규칙이 분산되어 신규 테마 추가 속도가 느림
- 수정 포인트가 많아 회귀 가능성이 증가

### Root Cause

- 테마 자산 네이밍 규칙(`OceanScoreGood`, `ForestMetricHRV` 등)이 코드 레벨에서 공통화되지 않음
- watch 타깃이 iOS의 테마 확장 파일을 공유하지 않아 중복 구현이 누적됨

## Solution

테마 자산 이름 규칙을 prefix 기반으로 통합하고, iOS/Watch 모두 동일한 `AppTheme+View.swift`를 사용하도록 구조를 변경했다.

### Changes Made

| File | Change | Reason |
|------|--------|--------|
| `DUNE/Presentation/Shared/Extensions/AppTheme+View.swift` | 공용 resolver(`assetPrefix`, `themedAssetName`) 도입 및 반복 switch 제거 | 테마 확장 시 단일 규칙 적용 |
| `DUNEWatch/Views/Extensions/AppTheme+WatchView.swift` | 테마 색상 매핑 제거, Watch EnvironmentKey만 유지 | 중복 코드 제거 |
| `DUNE/project.yml` | Watch target에 `AppTheme+View.swift` 추가 | iOS/Watch 동시 반영 자동화 |
| `DUNE/Presentation/Settings/Components/ThemePickerSection.swift` | swatch를 `[accentColor, bronzeColor, duskColor]`로 통일 | 수동 테마별 분기 축소 |
| `DUNETests/AppThemeTests.swift` | prefix/asset-name 규칙 테스트 추가 | 규칙 회귀 방지 |

### Key Code

```swift
extension AppTheme {
    var assetPrefix: String? { ... }   // Desert=nil, Ocean/Forest/Sakura prefix
    func themedAssetName(defaultAsset: String, variantSuffix: String) -> String { ... }
}

private extension AppTheme {
    func themedColor(defaultAsset: String, variantSuffix: String) -> Color {
        Color(themedAssetName(defaultAsset: defaultAsset, variantSuffix: variantSuffix))
    }
}
```

## Verification

- `scripts/build-ios.sh --no-regen` 성공 (`BUILD SUCCEEDED`)
- `xcodebuild build -scheme DUNETests -destination 'generic/platform=iOS'` 성공
- `xcodebuild build -scheme DUNEWatchTests -destination 'generic/platform=watchOS Simulator'` 성공
- 시뮬레이터 서비스(CoreSimulatorService) 불안정으로 실제 `xcodebuild test` 실행은 환경 제약으로 실패

## Prevention

- 새 테마 추가 시 prefix 규칙 + asset 세트 추가만으로 iOS/Watch 공통 반영
- 테마 매핑은 `AppTheme+View.swift` 단일 파일에서 관리
- 테스트로 prefix/asset 네이밍 규칙을 고정하여 누락 회귀를 조기 검출

## Lessons Learned

- 테마 로직의 “플랫폼별 복제”보다 “타깃 공유 파일”이 유지보수성과 안정성에 더 유리하다.
- 코드 생성 없이도 prefix 규칙 통일만으로 신규 테마 추가 비용을 크게 줄일 수 있다.
