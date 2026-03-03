---
topic: Solar Pop Theme
date: 2026-03-04
status: draft
confidence: medium
related_solutions:
  - docs/solutions/design/2026-03-01-multi-theme-architecture.md
  - docs/solutions/design/2026-03-02-sakura-calm-theme.md
  - docs/solutions/design/2026-03-03-arctic-dawn-theme.md
related_brainstorms:
  - docs/brainstorms/2026-03-04-new-theme-addition.md
---

# Implementation Plan: Solar Pop Theme

## Context

사용자 요청은 `Solar Pop` 테마를 iOS + watchOS에 동시 적용하고, 배경 애니메이션까지 포함해
전체 테마 경험을 확장하는 것이다. 기존 5개 테마와 겹치지 않게 따뜻하고 활기 있는 무드를 제공하되,
현재 prefix 기반 테마 아키텍처를 유지해 확장 안정성을 확보한다.

## Requirements

### Functional

- `AppTheme`에 `solarPop` 케이스를 추가한다.
- `assetPrefix`/`displayName`에 Solar 매핑을 추가한다.
- `Solar*` 색상 토큰(brand/score/metric/tab/weather/card + wave)을 추가한다.
- `Tab/Detail/Sheet` 배경에 Solar 전용 애니메이션 레이어를 추가한다.
- Watch 배경(`WatchWaveBackground`)에 Solar 전용 경량 표현을 추가한다.
- Settings ThemePicker에서 Solar Pop 선택이 가능해야 한다.

### Non-functional

- 기존 5개 테마 동작/표현 회귀가 없어야 한다.
- 다크 모드에서 가독성과 대비를 유지해야 한다.
- watchOS에서 과도한 모션/레이어로 성능 저하가 없어야 한다.
- AppTheme 및 신규 Shape 테스트로 회귀를 방지해야 한다.

## Approach

기존 `AppTheme + prefix resolver + shared xcassets` 구조를 그대로 사용한다.
Solar의 차별화는 테마 토큰 세트와 전용 배경 컴포넌트(Glow + Ember 레이어)로 만든다.
구조상 `WaveShape` dispatch 연결만 하면 iOS 주요 화면 전체에 자동 반영된다.
Watch는 동일 컨셉의 축소 버전(저비용 밴드/스파크)으로 맞춘다.

### Alternative Approaches Considered

| Approach | Pros | Cons | Decision |
|----------|------|------|----------|
| 기존 Desert 배경 재사용 + 색상만 교체 | 구현 속도 빠름 | 신규 테마 차별성 약함 | 미채택 |
| Solar를 Sakura/Arctic와 동일 수준의 대형 컴포넌트로 분리 파일 생성 | 구조 명확 | 파일/프로젝트 반영 비용 증가 | 미채택 |
| 기존 배경 파일 내 Solar shape/background 추가 + dispatch 확장 | 변경 집중, 적용 범위 명확 | 파일 길이 증가 | 채택 |

## Affected Files

| File | Change Type | Description |
|------|-------------|-------------|
| `DUNE/Domain/Models/AppTheme.swift` | 수정 | `solarPop` case 추가 |
| `DUNE/Presentation/Shared/Extensions/AppTheme+View.swift` | 수정 | `assetPrefix`, `displayName`, Solar wave color accessor 추가 |
| `DUNE/Presentation/Shared/Components/WaveShape.swift` | 수정 | Solar Tab/Detail/Sheet background dispatch 연결 |
| `DUNE/Presentation/Shared/Components/OceanWaveBackground.swift` | 수정 | Solar shape/overlay/background 구현 |
| `DUNE/Presentation/Shared/Components/GlassCard.swift` | 수정 | Solar 전용 border/surface gradient 추가 |
| `DUNE/Presentation/Shared/Components/SectionGroup.swift` | 수정 | Solar section surface/top bloom/border 분기 추가 |
| `DUNE/Presentation/Shared/Components/ProgressRingView.swift` | 수정 | Solar accent gradient 캐시 분기 추가 |
| `DUNEWatch/Views/WatchWaveBackground.swift` | 수정 | Solar watch 배경/애니메이션 분기 추가 |
| `Shared/Resources/Colors.xcassets/*` | 추가 | `Solar*` colorset 30종 추가 |
| `DUNETests/AppThemeTests.swift` | 수정 | case count/rawValue/prefix/themedAssetName 기대값 갱신 |
| `DUNETests/WaveShapeTests.swift` | 수정 | Solar shape geometry/animatableData 테스트 추가 |

## Implementation Steps

### Step 1: Theme 모델/토큰 확장

- **Files**: `AppTheme.swift`, `AppTheme+View.swift`, `Colors.xcassets`
- **Changes**:
- `solarPop` rawValue 추가
- `assetPrefix == "Solar"` 추가
- `displayName == "Solar Pop"` 추가
- Solar colorset(brand/score/metric/tab/weather/card/wave) 추가
- **Verification**:
- `AppTheme(rawValue: "solarPop")` 정상 동작
- `themedAssetName(defaultAsset: "AccentColor", variantSuffix: "Accent") == "SolarAccent"`

### Step 2: iOS 배경/컴포넌트 반영

- **Files**: `WaveShape.swift`, `OceanWaveBackground.swift`, `GlassCard.swift`, `SectionGroup.swift`, `ProgressRingView.swift`
- **Changes**:
- Solar Tab/Detail/Sheet 배경 추가 및 dispatch 연결
- 카드/섹션/링에서 Solar 전용 gradient 분기 추가
- **Verification**:
- Solar 선택 시 Today/Activity/Wellness/Life + detail/sheet에서 Solar 시각 언어 확인
- Desert/Ocean/Forest/Sakura/Arctic 회귀 없음

### Step 3: watchOS 동시 반영

- **Files**: `WatchWaveBackground.swift`
- **Changes**:
- Solar 전용 glint/spark 경량 오버레이 추가
- reduce motion 케이스 보존
- **Verification**:
- watch에서 Solar 동기화 및 배경 표현 확인
- 모션 과다/프레임 저하 없음

### Step 4: 테스트/검증

- **Files**: `AppThemeTests.swift`, `WaveShapeTests.swift`
- **Changes**:
- AppTheme 관련 케이스/prefix/themed name 기대값 업데이트
- 신규 Solar shape 테스트 추가
- **Verification**:
- 대상 테스트 통과
- DUNE build + DUNETests 대상 테스트 통과

## Edge Cases

| Case | Handling |
|------|----------|
| Solar asset 일부 누락 | 컴파일/런타임 시 색상 fallback 확인 + 누락 asset 추가 |
| 다크 모드에서 과포화 | opacity와 contrast 계수를 다크 모드에서 낮춰 적용 |
| 테마 전환 직후 애니메이션 정지 | 기존 `.id(theme)` + `onAppear/task` 시작 패턴 유지 |
| watch에서 과한 점멸 | spark 개수/opacity/속도 제한 |

## Testing Strategy

- Unit tests:
- `DUNETests/AppThemeTests.swift`
- `DUNETests/WaveShapeTests.swift` (Solar shape 추가)
- Build/Test:
- `xcodebuild build -project DUNE/DUNE.xcodeproj -scheme DUNE -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.2'`
- `xcodebuild test -project DUNE/DUNE.xcodeproj -scheme DUNETests -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.2' -only-testing DUNETests/AppThemeTests -only-testing DUNETests/WaveShapeTests`
- Manual verification:
- iOS: ThemePicker에서 Solar 선택 후 각 탭 + detail/sheet 확인
- watchOS: iPhone 테마 변경 후 watch 반영 및 배경 동작 확인

## Risks

| Risk | Probability | Impact | Mitigation |
|------|-------------|--------|------------|
| colorset 대량 추가 시 오타 | Medium | Medium | 네이밍 규칙 통일 + `rg "Solar"` 검증 |
| switch 분기 누락 | Medium | High | exhaustive switch 컴파일 에러 기반 보정 |
| 시각 톤 과도/부족 | Medium | Medium | 다크/라이트에서 opacity 튜닝 |
| 테스트 환경 이슈로 런타임 테스트 실패 | Low | Medium | build + 대상 test 우선, 실패 시 로그 첨부 |

## Confidence Assessment

- **Overall**: Medium
- **Reasoning**: 기존 테마 확장 패턴이 명확해 구조 리스크는 낮다. 다만 신규 색상셋 대량 추가와 시각 튜닝에서 수동 실수 가능성이 있어 테스트/검증이 중요하다.
