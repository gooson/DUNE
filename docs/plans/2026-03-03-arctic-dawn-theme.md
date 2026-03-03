---
topic: Arctic Dawn Theme
date: 2026-03-03
status: draft
confidence: medium
related_solutions:
  - docs/solutions/design/2026-03-01-multi-theme-architecture.md
  - docs/solutions/design/2026-03-02-sakura-calm-theme.md
  - docs/solutions/design/2026-03-03-sakura-dark-mode-readability-polish.md
  - docs/solutions/architecture/2026-03-03-theme-prefix-resolver-shared-extension.md
related_brainstorms:
  - docs/brainstorms/2026-03-03-arctic-dawn-theme.md
---

# Implementation Plan: Arctic Dawn Theme

## Context

기존 테마(Desert/Ocean/Forest/Sakura)와 감성적으로 명확히 구분되는 신규 테마가 필요하다.
이번 변경은 "빙하 + 오로라" 컨셉을 iOS/watchOS에 동시에 도입하고, 배경/카드/지표 색상까지
전면 반영하여 테마 일관성을 강화하는 것이 목표다.

## Requirements

### Functional

- `AppTheme`에 `arcticDawn` 케이스를 추가한다.
- 테마 토큰(accent/score/metric/tab/weather/card)을 Arctic 색상 세트로 확장한다.
- `TabWaveBackground`/`DetailWaveBackground`/`SheetWaveBackground`에 Arctic 전용 비주얼을 추가한다.
- Watch 배경(`WatchWaveBackground`)에도 Arctic 컨셉을 반영한다.
- 설정 화면 ThemePicker에서 Arctic 선택/표시가 가능해야 한다.

### Non-functional

- 기존 테마 동작/표현 회귀가 없어야 한다.
- 테마 전환 시 애니메이션 정지/깜빡임이 없어야 한다.
- watchOS에서 경량화된 표현으로 성능 저하를 피한다.
- 테스트(`AppThemeTests` + 신규 Shape 테스트)로 핵심 회귀를 방지한다.

## Approach

현재 구조는 `AppTheme+View`의 prefix 기반 resolver를 사용하므로, 신규 테마는
`AppTheme` 케이스 + `assetPrefix` + `Arctic*` colorset 추가만으로 다수 화면에 자동 전파된다.
배경은 기존 `WaveShape` dispatch 구조를 유지하고 Arctic 전용 컴포넌트를 추가해
컨셉 차별화와 구조 일관성을 동시에 확보한다.

### Alternative Approaches Considered

| Approach | Pros | Cons | Decision |
|----------|------|------|----------|
| Ocean 배경 재사용 + 색상만 변경 | 구현 빠름 | 테마 차별성이 약함 | 미채택 |
| Sakura처럼 기존 파일 확장 | 코드 집중 | 파일 복잡도 급증 | 미채택 |
| Arctic 전용 배경 파일 신설 + 기존 dispatch 연결 | 명확한 책임 분리, 테스트 용이 | 신규 파일/자산 추가 필요 | 채택 |

## Affected Files

| File | Change Type | Description |
|------|-------------|-------------|
| `DUNE/Domain/Models/AppTheme.swift` | 수정 | `arcticDawn` 케이스 추가 |
| `DUNE/Presentation/Shared/Extensions/AppTheme+View.swift` | 수정 | `assetPrefix`, `displayName`, Arctic 전용 색상 접근자 |
| `DUNE/Presentation/Shared/Components/WaveShape.swift` | 수정 | 배경 dispatch에 Arctic 케이스 추가 |
| `DUNE/Presentation/Shared/Components/ArcticWaveBackground.swift` | 추가 | Tab/Detail/Sheet Arctic 배경 구현 |
| `DUNEWatch/Views/WatchWaveBackground.swift` | 수정 | Arctic watch 배경 튜닝 |
| `DUNE/Presentation/Shared/Components/GlassCard.swift` | 수정 | Arctic 카드 surface/border 분기 |
| `DUNE/Presentation/Shared/Components/SectionGroup.swift` | 수정 | Arctic 섹션 surface/border 분기 |
| `DUNE/Presentation/Shared/Components/ProgressRingView.swift` | 수정 | Arctic ring gradient 캐시 분기 |
| `Shared/Resources/Colors.xcassets/*` | 추가 | `Arctic*` colorset 추가 |
| `DUNETests/AppThemeTests.swift` | 수정 | case count/rawValue/prefix 검증 업데이트 |
| `DUNETests/ArcticRibbonShapeTests.swift` | 추가 | Arctic 배경 shape geometry 테스트 |

## Implementation Steps

### Step 1: Theme 모델/토큰 확장

- **Files**: `AppTheme.swift`, `AppTheme+View.swift`, `Colors.xcassets`
- **Changes**:
- `arcticDawn` case 추가
- `assetPrefix == "Arctic"` 매핑 추가
- `displayName` 추가
- 필요한 `Arctic*` 색상 세트 추가
- **Verification**:
- `AppTheme(rawValue: "arcticDawn")` 정상 동작
- `themedAssetName(..., variantSuffix: "ScoreGood") == "ArcticScoreGood"`

### Step 2: iOS 배경/컴포넌트 반영

- **Files**: `ArcticWaveBackground.swift`, `WaveShape.swift`, `GlassCard.swift`, `SectionGroup.swift`, `ProgressRingView.swift`
- **Changes**:
- Arctic Tab/Detail/Sheet 배경 구현 및 dispatch 연결
- 카드/섹션/링에 Arctic 분기 추가
- **Verification**:
- Arctic 테마 선택 시 배경/카드/링이 테마 톤으로 표시
- 기존 4개 테마 시각 회귀 없음

### Step 3: watchOS 동시 적용

- **Files**: `WatchWaveBackground.swift`
- **Changes**:
- Arctic 테마에서 glacier/aurora 경량 표현 추가
- **Verification**:
- watch 화면에서 Arctic 선택 시 동일 무드 노출
- 과한 애니메이션/성능 이슈 없음

### Step 4: 테스트 및 검증

- **Files**: `AppThemeTests.swift`, `ArcticRibbonShapeTests.swift`
- **Changes**:
- AppTheme 관련 기대값 업데이트
- 신규 shape 테스트 추가
- **Verification**:
- 대상 테스트 전부 통과
- 필요 시 전체 DUNETests smoke 통과

## Edge Cases

| Case | Handling |
|------|----------|
| 다크 모드에서 배경 레이어가 과도해 가독성 저하 | opacity 상한을 낮추고 카드 border 대비 강화 |
| 테마 전환 직후 애니메이션 미시작 | 기존 `.id(theme)` 패턴 + onAppear/task 재시작 패턴 유지 |
| Arctic asset 누락 시 런타임 시각 불일치 | `AppThemeTests` + 빌드에서 asset 참조 확인 |
| watch에서 과한 모션 | 레이어 수 축소 + 낮은 drift amplitude 유지 |

## Testing Strategy

- Unit tests:
- `DUNETests/AppThemeTests.swift` 업데이트
- `DUNETests/ArcticRibbonShapeTests.swift` 추가
- Build/Test:
- `xcodebuild build -project DUNE/DUNE.xcodeproj -scheme DUNE -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.2'`
- `xcodebuild test -project DUNE/DUNE.xcodeproj -scheme DUNETests -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.2' -only-testing DUNETests/AppThemeTests -only-testing DUNETests/ArcticRibbonShapeTests`
- Manual verification:
- iOS: ThemePicker에서 Arctic 선택 후 Today/Activity/Wellness/Life/Detail/Sheet 확인
- watchOS: 홈/카드 화면 배경 무드 및 성능 확인

## Risks

| Risk | Probability | Impact | Mitigation |
|------|-------------|--------|------------|
| 신규 colorset 대량 추가 중 오타 | Medium | Medium | 규칙적 네이밍 + `rg "Arctic"`로 일괄 검증 |
| 기존 테마 분기 누락으로 컴파일 에러 | Medium | High | switch exhaustive 컴파일 확인 |
| 테마 표현 과도/미약으로 UX 품질 저하 | Medium | Medium | opacity 튜닝 + 다크모드 수동 검증 |
| watch 성능 저하 | Low | Medium | 경량 레이어/저진폭 모션 유지 |

## Confidence Assessment

- **Overall**: Medium
- **Reasoning**: prefix 기반 구조 덕분에 토큰 확장은 안정적이지만, 배경/카드 시각 튜닝과 자산 일괄 추가에서
  수동 실수 가능성이 있어 검증을 강화해야 한다.
