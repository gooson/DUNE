---
tags: [wave, theme, animation, dark-mode, desert, ocean, forest]
date: 2026-03-01
category: plan
status: approved
---

# Plan: 테마별 웨이브 그래픽 및 애니메이션 고도화

## Summary

3개 테마의 웨이브 시각적 정체성 강화:
1. **Forest**: 다크모드 색상 밝기 상향으로 가시성 확보
2. **Desert**: 비대칭 sand dune Shape 신규 생성 + 2-layer parallax
3. **Ocean**: 기존 파라미터 튜닝으로 curl/foam/steepness 역동성 강화

## Affected Files

| 파일 | 변경 유형 | 설명 |
|------|----------|------|
| `Assets.xcassets/Colors/ForestDeep.colorset/Contents.json` | **수정** | 다크모드 색상 밝기 상향 |
| `Assets.xcassets/Colors/ForestMid.colorset/Contents.json` | **수정** | 다크모드 색상 밝기 상향 |
| `Assets.xcassets/Colors/ForestMist.colorset/Contents.json` | **수정** | 다크모드 색상 밝기 상향 |
| `Components/DesertDuneShape.swift` | **신규** | 비대칭 sand dune Shape |
| `Components/DesertWaveBackground.swift` | **신규** | Desert 전용 2-layer parallax 배경 (Tab/Detail/Sheet) |
| `Components/WaveShape.swift` | **수정** | Desert dispatch → DesertWaveBackground로 변경 |
| `Components/OceanWaveBackground.swift` | **수정** | Surface layer curl/foam/steepness 파라미터 상향 |
| `Components/ForestWaveBackground.swift` | **수정** | 다크모드 opacity 미세 조정 (필요시) |

## Implementation Steps

### Step 1: Forest 다크모드 가시성 (Asset catalog)

**ForestDeep dark**: RGB(0.059, 0.180, 0.122) → RGB(0.140, 0.320, 0.200)
- Light 모드의 ForestMid 수준까지 밝게 (명도 2.5x 상향)

**ForestMid dark**: RGB(0.137, 0.302, 0.196) → RGB(0.220, 0.420, 0.290)
- 중간 레이어 명확한 구분을 위해 상향

**ForestMist dark**: RGB(0.561, 0.725, 0.588) → RGB(0.500, 0.680, 0.540)
- Mist는 이미 밝으므로 약간 조정 (다크모드에서 살짝 차분하게)

### Step 2: Desert — DesertDuneShape 생성

비대칭 sand dune profile:
```
y = sin(angle + phase)
  + skewness * sin(2*angle + phase + skewOffset)
  + ripple * sin(highFreq*angle + phase*rippleDrift)
```

- `skewness`: 0.25 (바람맞이 완만, 바람등 급경사)
- `ripple`: 미세한 모래 물결 (Near layer only)
- WaveSamples 재사용 (120 sample points)
- pre-computed edgeNoise (Forest와 동일 패턴)

### Step 3: Desert — DesertWaveBackground 구현

**Tab Background (2-layer)**:
- Far: 큰 언덕 (freq 0.8, amp 0.03, slow drift 10s, skew 0.25)
- Near: 작은 모래물결 (freq 2.5, amp 0.05, fast drift 5s, skew 0.15, ripple)
- 열기 shimmer: pre-rendered grain 텍스처 (Forest UkiyoeGrain 패턴 재사용)
- intensityScale: train 1.2, today 1.0, wellness 0.8, life 0.6

**Detail Background (1-layer)**: amplitude 50%, opacity 70%
**Sheet Background (1-layer)**: amplitude 40%, opacity 60%

### Step 4: WaveShape.swift — Desert dispatch 변경

`DesertTabWaveContent` → `DesertTabWaveBackground`
`DesertDetailWaveContent` → `DesertDetailWaveBackground`
`DesertSheetWaveContent` → `DesertSheetWaveBackground`

기존 Desert Content views를 삭제하고 새 Background로 교체.

### Step 5: Ocean — 파라미터 역동성 강화

Surface layer (Tab):
- `curlHeight`: 1.8*scale → **2.2*scale**
- `curlWidth`: 0.12 → **0.15**
- `curlCount`: train/today/wellness=1 → train=**2**, today/wellness=**1**
- `steepness`: 0.35 → **0.40**
- `crestSharpness`: 0.1*scale → **0.12*scale**
- foam `opacity`: 0.25*scale → **0.30*scale**
- foam `depth`: 0.03 → **0.035**

### Step 6: 빌드 검증 + 테스트
