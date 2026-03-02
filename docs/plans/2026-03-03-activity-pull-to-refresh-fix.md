---
tags: [activity-tab, pull-to-refresh, swiftui, regression-fix]
date: 2026-03-03
category: plan
status: implemented
---

# Activity Tab Pull-to-Refresh 미노출 수정 계획

## 문제 정의

Activity 탭에서 pull-to-refresh 제스처를 수행해도 refresh indicator가 보이지 않고 refresh 동작이 트리거되지 않는 회귀가 발생했다.

## 원인 가설

- `waveRefreshable` modifier가 실제 스크롤 컨테이너(`ScrollView`)가 아닌 상위 래퍼(`ScrollViewReader`)에 적용되어, UIKit 레벨 `UIRefreshControl` 연결이 불안정/무효화되는 경로가 존재한다.

## 구현 전략

1. `ActivityView`에서 `waveRefreshable`를 `ScrollView` 레벨로 이동한다.
2. 회귀 방지를 위해 refresh indicator에 접근 가능한 AX 식별자를 부여한다.
3. `ActivitySmokeTests`에 pull-to-refresh indicator 노출 검증 케이스를 추가한다.
4. 변경 파일 기준 최소 테스트(관련 unit/UI) 실행으로 동작 검증을 완료한다.

## Affected Files

| File | Change | Purpose |
|------|--------|---------|
| `DUNE/Presentation/Activity/ActivityView.swift` | modify | refresh modifier 적용 위치를 실제 ScrollView로 이동 |
| `DUNE/Presentation/Shared/Components/WaveRefreshIndicator.swift` | modify | refresh indicator 접근성 식별자 추가 |
| `DUNEUITests/Helpers/UITestHelpers.swift` | modify | refresh indicator AXID 상수 추가 |
| `DUNEUITests/Smoke/ActivitySmokeTests.swift` | modify | pull-to-refresh indicator 표시 회귀 테스트 추가 |

## 검증 계획

1. `xcodebuild test -project DUNE/DUNE.xcodeproj -scheme DUNETests -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.2' -only-testing:DUNETests/ActivityViewModelTests -quiet`
2. `xcodebuild test -project DUNE/DUNE.xcodeproj -scheme DUNEUITests -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.2' -only-testing:DUNEUITests/Smoke/ActivitySmokeTests/testPullToRefreshShowsWaveIndicator -quiet`

## 리스크/완화

- UI 테스트 flaky 가능성: refresh indicator 표시 시간(1.8초 minimum)을 이용해 `waitForExistence` 타임아웃을 충분히 확보한다.
- modifier 이동으로 다른 탭과 동작 불일치 가능성: 동일 패턴이 필요한 탭은 별도 이슈로 분리하고 이번 범위는 Activity에 한정한다.
