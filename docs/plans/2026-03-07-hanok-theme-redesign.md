---
tags: [theme, hanok, wave, design-system, redesign, color]
date: 2026-03-07
category: plan
status: draft
---

# Plan: 한옥 테마 전면 재설계 — 모던 한국 미니멀

## Summary

한옥 테마의 figurative 요소(경회루, 와당, 산, 한지 텍스처)를 전부 삭제하고,
달항아리 비대칭 곡선 + 수묵 색상 팔레트로 교체하여 시그니처 테마 수준으로 격상한다.

## Affected Files

| File | Change Type | Description |
|------|-------------|-------------|
| `DUNE/Presentation/Shared/Components/HanokEaveShape.swift` | **Rewrite** | DalhangariWaveShape로 교체 |
| `DUNE/Presentation/Shared/Components/HanokWaveBackground.swift` | **Rewrite** | 장식 6개 삭제, 달항아리 곡선으로 교체 |
| `Shared/Resources/Colors.xcassets/Hanok*.colorset/` (27개) | **Update** | hex값 전체 교체 (수묵/백자/비색 팔레트) |
| `DUNE/Presentation/Shared/Components/GlassCard.swift` | **Update** | Hanok static gradient 정의 업데이트 |
| `DUNE/Presentation/Shared/Components/SectionGroup.swift` | **Update** | Hanok gradient 정의 업데이트 |
| `DUNETests/HanokEaveShapeTests.swift` | **Rewrite** | DalhangariWaveShape 테스트로 교체 |

**변경 불필요 (아키텍처 분리 덕분):**
- `AppTheme.swift` — enum case 유지
- `AppTheme+View.swift` — property 이름 유지, Color("HanokXxx") 참조 유지
- `WaveShape.swift` — dispatch routing 유지
- `ProgressRingView.swift` — theme.accentColor 참조만 (색상 asset 변경으로 자동 반영)
- `ThemePickerSection.swift` — swatch가 accentColor/bronzeColor/duskColor 참조 (자동 반영)

## Implementation Steps

### Step 1: DalhangariWaveShape 구현

**File**: `HanokEaveShape.swift` (파일명 유지 → 내용 교체)

기존 HanokEaveShape를 삭제하고 DalhangariWaveShape로 교체한다.

```
알고리즘:
1. 기본 sine wave (base contour)
2. 비대칭 변조: sin(x) * (1 + asymmetry * sin(x / 3))
   → 좌반부/우반부 amplitude 차이
3. 유기적 3차 harmonic: + organicBlend * sin(3x + phase)
   → 완벽하지 않은 곡선
4. 넓은 swell: + swell * sin(x / 2 + phase/3)
   → 달항아리의 넓은 몸통감

파라미터:
- amplitude: CGFloat (기존과 동일)
- frequency: CGFloat (기존과 동일)
- phase: CGFloat (animatable, 기존과 동일)
- verticalOffset: CGFloat (기존과 동일)
- asymmetry: CGFloat = 0.3 (신규: 비대칭 정도)
- organicBlend: CGFloat = 0.15 (신규: 유기적 변형)

삭제할 파라미터:
- uplift (처마 끝 올림)
- tileRipple, tileFrequency (기와 텍스처)
- edgeNoise (점토 변형)
```

**Verification**: Shape이 asymmetric sine wave를 그리는지 Preview에서 확인

### Step 2: HanokWaveBackground 재작성

**File**: `HanokWaveBackground.swift`

#### 삭제 대상 (6개 shape/overlay):
1. `HanokRoofTileSealShape` — 와당 막새
2. `HanokMountainBackdropShape` — 산 배경
3. `HanokPavilionSilhouetteShape` — 경회루 실루엣
4. `HanokRoofSealOverlay` — 와당 overlay view
5. `HanokPavilionLandscapeOverlay` — 경회루+산 overlay view
6. `HanjiTextureView` — 한지 텍스처

#### HanokWaveOverlayView 수정:
- `showHanji`, `hanjiOpacity` 파라미터 삭제
- `uplift`, `tileRipple`, `tileFrequency` 파라미터 삭제
- `breathIntensity` 유지 (유기적 움직임)
- 신규 `asymmetry`, `organicBlend` 파라미터 추가
- `eaveShape` → `dalhangariShape` 참조 변경
- crest highlight 유지 (수묵 번짐 효과로 재해석)

#### HanokTabWaveBackground 재작성:
```
Layer 1 (Far):
  color: hanokMistColor, opacity: 0.08
  amplitude: 0.04, frequency: 0.7
  asymmetry: 0.2, organicBlend: 0.10
  drift: 28초 (매우 느림)
  breathIntensity: 0.04
  → 수묵화 원경

Layer 2 (Mid):
  color: hanokMidColor, opacity: 0.18
  amplitude: 0.055, frequency: 1.2
  asymmetry: 0.35, organicBlend: 0.18
  drift: 22초
  breathIntensity: 0.07
  → 달항아리 시그니처 곡선

Layer 3 (Near):
  color: hanokDeepColor, opacity: 0.45
  amplitude: 0.048, frequency: 1.8
  asymmetry: 0.25, organicBlend: 0.12
  drift: 18초
  breathIntensity: 0.10
  crestColor: sandColor (수묵 번짐)
  → 전경 깊이감
```

장식 overlay: **없음** (여백의 미)

#### HanokDetailWaveBackground: 2 layers (위 패턴의 opacity 60%)
#### HanokSheetWaveBackground: 1 layer (opacity 40%)

**Verification**: Preview에서 3가지 배경 모두 렌더링 확인

### Step 3: 색상 Asset 전체 교체

**Path**: `Shared/Resources/Colors.xcassets/`

27개 colorset의 Contents.json에서 hex값을 교체한다.

#### Core Layer Colors:
| Asset | Light | Dark |
|-------|-------|------|
| HanokDeep | #1A1A2E | #0F0F1A |
| HanokMid | #4A4A5A | #3A3A4E |
| HanokMist | #F7F3EE | #2A2A36 |

#### Accent & Typography:
| Asset | Light | Dark |
|-------|-------|------|
| HanokAccent | #5BA4A4 | #7BC4C0 |
| HanokBronze | #5C4A3A | #D4C4B0 |
| HanokDusk | #3A4A6A | #5A6A8A |
| HanokSand | #F5EFE6 | #C8C0B4 |

#### Score Colors:
| Asset | Light | Dark |
|-------|-------|------|
| HanokScoreExcellent | #2E9E8E | #4CC4B4 |
| HanokScoreGood | #C4945A | #DEB87A |
| HanokScoreFair | #7A8A7A | #9AAA98 |
| HanokScoreTired | #8A8A9A | #7A7A8C |
| HanokScoreWarning | #5A5A7A | #6A6A88 |

#### Metric Colors:
| Asset | Light | Dark |
|-------|-------|------|
| HanokMetricHRV | #4A9A8E | #6CC0B4 |
| HanokMetricRHR | #C4645A | #E8847A |
| HanokMetricHeartRate | #D45A5A | #F07A7A |
| HanokMetricSleep | #4A5A7A | #6A7A9A |
| HanokMetricActivity | #C49A4A | #E0BA6A |
| HanokMetricSteps | #5A9A6A | #7ABA8A |
| HanokMetricBody | #8A8A7A | #AAA898 |

#### Tab & Card:
| Asset | Light | Dark |
|-------|-------|------|
| HanokTabTrain | #5BA4A4 | #7BC4C0 |
| HanokTabWellness | #4A9A8E | #6CC0B4 |
| HanokTabLife | #C49A4A | #E0BA6A |
| HanokCardBackground | #F5EFE6 @ 0.12 | #2A2A36 @ 0.18 |

#### Weather Colors:
| Asset | Light | Dark |
|-------|-------|------|
| HanokWeatherRain | #4A5A7A | #6A7A9A |
| HanokWeatherSnow | #E8E4DE | #AAA898 |
| HanokWeatherCloudy | #8A8A9A | #7A7A8C |
| HanokWeatherNight | #1A1A2E | #0F0F1A |

**Verification**: Xcode preview에서 Light/Dark 모드 색상 확인

### Step 4: GlassCard & SectionGroup 업데이트

**GlassCard.swift**: Hanok static gradient definitions — 색상 asset이 바뀌므로 opacity/blend 값만 조정 필요할 수 있음. 기존 `HanokAccent`, `HanokDusk` 등의 참조는 유지.

**SectionGroup.swift**: 동일 — opacity 값 조정만.

이 파일들은 `Color("HanokXxx")`를 직접 참조하므로 hex 변경 시 자동 반영된다.
다만 기존 jade/slate 기준의 opacity 튜닝이 수묵 팔레트에서 어울리는지 확인이 필요.

**Verification**: GlassCard, SectionGroup가 새 색상에서 자연스럽게 보이는지 확인

### Step 5: 테스트 업데이트

**File**: `DUNETests/HanokEaveShapeTests.swift`

- Shape 이름을 DalhangariWaveShape로 변경
- 테스트 케이스:
  1. `path(in:)` 결과가 비어있지 않은지
  2. asymmetry=0일 때 대칭인지
  3. asymmetry>0일 때 비대칭인지
  4. animatableData (phase)가 동작하는지
  5. 0 크기 rect에서 빈 Path 반환하는지

### Step 6: 빌드 & 검증

```bash
scripts/build-ios.sh
```

## Test Strategy

| 테스트 유형 | 대상 | 방법 |
|-------------|------|------|
| Unit | DalhangariWaveShape | 기존 Shape 테스트 패턴 따름 |
| Visual | Wave backgrounds | Preview에서 Tab/Detail/Sheet 확인 |
| Integration | 색상 반영 | ThemePicker에서 Hanok 선택 후 전체 화면 색상 |
| L/D Mode | 색상 대비 | Light/Dark 모드 전환 확인 |

## Risks & Mitigations

| Risk | Impact | Mitigation |
|------|--------|------------|
| 색상 hex값 오타 | 시각적 결함 | colorset JSON 포맷 자동 검증 |
| 수묵 번짐 blur 성능 | 프레임 드롭 | blur radius 2px 이내 제한 |
| 비대칭 곡선 iPad 어색 | UX 저하 | asymmetry 값을 conservative하게 시작 |
| GlassCard opacity 부조화 | 시각적 결함 | Step 4에서 수동 확인 |

## Edge Cases

- Dark mode에서 HanokDeep(#0F0F1A)과 시스템 배경 구분
- Score 5단계 색상의 접근성 대비 (최소 3:1)
- Weather 전환 시 atmosphereTransition 자연스러움
