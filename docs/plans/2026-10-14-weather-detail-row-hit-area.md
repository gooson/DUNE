---
topic: weather-detail-row-hit-area
date: 2026-10-14
status: approved
confidence: high
related_solutions:
  - docs/solutions/performance/2026-10-14-today-scroll-top-bounce.md
related_brainstorms: []
---

# Implementation Plan: Weather 상세 화면 행 탭 복구

## Context

`main`(05e6c794)에서 `TodaySettingsRegressionTests/testWeatherCardOpensWeatherDetail`을 iPhone 18 Pro, iOS 27.0으로 단독 실행해 1건 실패를 재현했다. XCTest는 `dashboard-weather-card` 버튼을 찾아 탭했으나 `weather-detail-screen`이 나타나지 않았다. 실패 시점의 스크린샷과 접근성 계층은 Today 화면에 그대로 남아 있다.

버튼의 접근성 프레임은 x=31.3…373.3이고 가운데 x≈202는 Weather 텍스트(x≈64…178)와 우측 배지(x≈254…354) 사이의 빈 `Spacer`이다. `.buttonStyle(.plain)` 라벨에 이 공간의 `contentShape`가 없어 가운데 탭이 action에 도달하지 않는 것이 가장 유력하다. visual audit 전용 테스트 fallback은 페인트된 텍스트를 다시 탭하므로 이 결함을 가릴 수 있다.

## Requirements

### Functional

- Weather 행의 중앙 빈 공간을 탭해도 Weather 상세 화면이 열린다.
- 행의 기존 접근성 식별자와 다른 Today Brief 버튼 동작을 유지한다.

### Non-functional

- Weather 데이터·라우팅 상태 계약을 바꾸지 않는다.
- 원래 실패한 단독 테스트와 관련 Today UI 범위를 실제 실행한다.

## Approach

Weather `Button` 라벨인 `HStack`에 직사각형 `contentShape`를 부여한다. 기존 테스트가 버튼 중심을 탭하도록 두고, visual audit에서만 동작하는 재탭 fallback을 제거해 실패를 숨기지 않게 한다. Apple의 [SwiftUI NavigationStack 문서](https://developer.apple.com/documentation/swiftui/understanding-the-navigation-stack)에 따른 기존 destination 구성은 이번 실패의 원인이 아니므로 유지한다.

### Alternative Approaches Considered

| Approach | Pros | Cons | Decision |
|----------|------|------|----------|
| 텍스트나 배지에만 좌표 탭 | 테스트 통과 가능 | 행 중앙의 실제 터치 결함을 숨김 | 제외 |
| Weather를 `NavigationLink(value:)`로 교체 | 라우팅 코드 단순화 가능 | 터치 영역 문제를 직접 해결하지 않음 | 제외 |
| 버튼 라벨에 `contentShape(Rectangle())` | 투명한 `Spacer`도 행의 터치 영역에 포함 | 인접 버튼과 프레임 겹침 확인 필요 | 적용 |

## Affected Files

| File | Change Type | Description |
|------|-------------|-------------|
| `DUNE/Presentation/Dashboard/Components/TodayBriefCard.swift` | 수정 | Weather 행 전체를 탭 가능하게 함 |
| `DUNEUITests/Full/TodaySettingsRegressionTests.swift` | 수정 | visual audit 재탭 fallback 제거, 중심 탭 결과를 그대로 검증 |
| `docs/solutions/testing/2026-10-14-weather-detail-row-hit-area.md` | 추가 | 원인·검증·예방 기록 |

## Implementation Steps

### Step 1: Weather 행 터치 영역 수정

- **Files**: `TodayBriefCard.swift`
- **Changes**: Weather `Button` 라벨의 `HStack`에 `.contentShape(Rectangle())` 추가.
- **Verification**: 원래 실패한 UI 테스트가 상세 화면 식별자를 찾는지 확인.

### Step 2: 회귀 테스트가 우회 경로를 사용하지 않게 정리

- **Files**: `TodaySettingsRegressionTests.swift`
- **Changes**: visual audit 모드의 텍스트 재탭 fallback 제거. 기존 AXID·중앙 탭·상세 화면 assertion 유지.
- **Verification**: 관련 Today 테스트와 공통 smoke를 실행하고 결과 로그의 실행 건수 확인.

### Step 3: 빌드·리뷰·해결책 문서화

- **Files**: solution 문서와 최종 diff.
- **Changes**: 검증된 원인과 최종 구현만 기록.
- **Verification**: `scripts/build-ios.sh`, 리뷰, `git diff --check`.

## Edge Cases

| Case | Handling |
|------|----------|
| 빈 공간을 탭 | 중심 탭 UI 테스트로 검증 |
| 텍스트·배지 탭 | 기존 Button label 안의 요소로 유지 |
| Weather 데이터가 없음 | 기존 위치 권한 요청 버튼은 변경하지 않음 |
| 인접 coaching·briefing 버튼 | `contentShape`를 Weather 행의 HStack에만 적용 |
| iPad 폭 | 행 폭이 넓어져도 Spacer의 hit area가 포함되도록 동일 modifier 사용 |

## Testing Strategy

- Unit tests: SwiftUI View hit testing 변경이므로 별도 단위 테스트는 추가하지 않는다.
- UI tests: 기존 Weather 단독 테스트를 수정 전 실패 증거로 남기고 수정 후 재실행한다. `scripts/plan-ui-tests.py --base main`의 최종 판정과 소비자 검색으로 Today 관련 테스트·공통 smoke 범위를 정한다.
- Manual verification: Today → Weather 행의 텍스트와 배지 사이 빈 공간 탭 → Weather 화면 표시를 확인한다.

## Risks

| Risk | Probability | Impact | Mitigation |
|------|-------------|--------|------------|
| hit area가 하단 briefing 버튼과 겹침 | 낮음 | 중간 | label HStack에만 shape 지정, AX 프레임 비교 |
| navigation state가 별도 원인 | 낮음 | 중간 | 수정 후 동일 테스트 실패 시 탭 이벤트·state를 추가 조사 |
| visual audit fallback 제거로 새로운 실패 노출 | 중간 | 낮음 | 중심 탭이 실제 사용자 흐름을 대표하므로 실패를 수정 대상으로 취급 |

## Confidence Assessment

- **Overall**: High
- **Reasoning**: 실패 스크린샷의 빈 중앙 공간과 XCTest가 탭한 버튼 프레임이 일치하고, 실패 후에도 Today 화면이 유지됐다.
