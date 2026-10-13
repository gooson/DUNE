---
tags: [swiftui, weather, today, ui-testing, hit-testing, content-shape, accessibility]
category: solution
solution_category: testing
date: 2026-10-14
status: implemented
severity: important
related_files:
  - DUNE/Presentation/Dashboard/Components/TodayBriefCard.swift
  - DUNEUITests/Full/TodaySettingsRegressionTests.swift
related_solutions:
  - docs/solutions/testing/2026-09-27-life-menu-watch-offscreen-ui-tests.md
  - docs/solutions/general/2026-03-08-watch-summary-effort-button-hit-area.md
---

# Weather 상세 화면 행의 중앙 탭 복구

## Problem

### Symptoms

- `main`(05e6c794)에서 `TodaySettingsRegressionTests/testWeatherCardOpensWeatherDetail`을 단독 실행하면 1/1 실패했다. 테스트는 `dashboard-weather-card` 버튼을 찾아 탭했지만 `weather-detail-screen`이 나타나지 않았고 Today 화면에 머물렀다.
- 실패 시 접근성 프레임은 가로 x=31.3…373.3, 높이 약 21pt였다. 프레임 중심 x≈202는 Weather 텍스트(x≈64…178)와 우측 배지(x≈254…354) 사이의 빈 공간이었다.

### Root Cause

Weather 행은 `Spacer`가 들어간 `HStack`을 라벨로 쓰는 `.buttonStyle(.plain)` 버튼이었다. 접근성 프레임은 행 너비를 포함했지만, 투명한 `Spacer` 영역에 `contentShape`가 없어 XCTest의 버튼 중심 탭이 action에 전달되지 않았다. VisualAudit 모드에서 페인트된 텍스트를 다시 탭하는 테스트 fallback은 이 결함을 가릴 수 있었다. 행 높이도 [Apple의 최소 44pt 터치 대상 권장](https://developer.apple.com/design/tips/)보다 작았다.

## Solution

### Changes Made

| File | Change | Reason |
|------|--------|--------|
| `TodayBriefCard.swift` | Weather 버튼 라벨에 최소 높이 44pt와 직사각형 `contentShape` 추가 | 중앙의 빈 공간까지 터치 영역에 포함하고 높이 확보 |
| `TodaySettingsRegressionTests.swift` | VisualAudit 전용 텍스트 재탭 제거, 버튼 높이 44pt 이상 assertion 추가 | 원래 중심 탭 실패를 숨기지 않고 터치 크기 회귀 검출 |

### Key Code

```swift
HStack {
    // Existing weather label, spacer, and badge
}
.frame(minHeight: 44)
.contentShape(Rectangle())
```

수정한 modifier는 Weather 버튼 라벨에만 적용했다. 접근성 식별자와 상세 화면 라우팅은 유지했다.

### Validation

- 수정 전 같은 시뮬레이터의 원래 단독 테스트: 1/1 실패. 실패 화면과 접근성 계층에서 빈 중앙 탭 위치를 확인했다.
- 수정 후 원래 단독 테스트: 1/1 통과.
- iPhone 18 Pro, iOS 27.0에서 Weather 테스트와 공통 UI smoke: 27/27 통과, 실패·건너뜀 0. 전체 iOS UI suite는 실행하지 않았다.
- `scripts/build-ios.sh` 성공. 최종 코드 리뷰와 품질 검토 후 열린 P1/P2/P3 지적 0건.

## Prevention

### Checklist Addition

- [ ] `.buttonStyle(.plain)` 행의 라벨에 투명한 `Spacer`가 있으면 행 전체의 `contentShape`를 확인한다.
- [ ] 접근성 프레임의 중심과 실제 그려진 요소의 위치를 비교하고, 중심 탭으로 상세 화면 전환을 검증한다.
- [ ] 버튼의 높이와 인접 버튼의 경계를 확인한다.
- [ ] 실패한 중심 탭을 텍스트 좌표 재탭이나 대체 경로로 우회하지 않는다.

### Rule Addition

별도 규칙은 추가하지 않았다. 같은 plain Button 패턴은 기존 iPad·Watch 해결책에 이미 기록돼 있으며, 이번 사례를 검색 가능한 Weather 회귀 문서로 연결했다.

## Lessons Learned

접근성 계층에서 버튼이 보이고 `tap()`이 실행돼도 버튼 프레임의 중심이 실제 hit area라는 뜻은 아니다. 화면과 접근성 프레임을 함께 확인해야 테스트 실패와 사용자 터치 결함을 구분할 수 있다.
