---
tags: [wave, animation, theme, dark-mode, desert, ocean, forest, performance]
date: 2026-03-01
category: solution
status: implemented
---

# Theme Wave Visual Upgrade

## Problem

각 테마의 웨이브 배경이 테마 정체성을 충분히 표현하지 못함:
1. **Forest 다크모드**: ForestDeep/Mid/Mist 색상이 어두운 배경에서 거의 보이지 않음 (effective alpha ~0.02)
2. **Desert**: 단순 sine wave로 사막/모래 언덕 느낌 없음
3. **Ocean**: Curl crest가 충분히 역동적이지 않음

## Solution

### 1. Forest Dark Mode — Asset Catalog 색상 보정

| Color | Before (Dark) | After (Dark) | Change |
|-------|--------------|--------------|--------|
| ForestDeep | (0.059, 0.180, 0.122) | (0.140, 0.320, 0.200) | ~2.5× |
| ForestMid | (0.137, 0.302, 0.196) | (0.220, 0.420, 0.290) | ~1.5× |
| ForestMist | (0.561, 0.725, 0.588) | (0.500, 0.680, 0.540) | 약간 차분하게 |

**핵심**: opacity 0.14 × RGB(0.059...) = effective alpha ~0.02 → 사실상 투명. 색상 자체를 밝혀야 함.

### 2. Desert — 비대칭 사구 Shape 신규 생성

`DesertDuneShape`: 바람에 의해 조각된 모래 언덕 프로파일
- **Base sine** + **2nd harmonic skew** (풍상/풍하 비대칭)
- **Sand ripple** (고주파 모래 결 텍스처)
- **Edge noise** (유기적 가장자리)
- **Heat shimmer** (아지랑이 텍스처, 사전 렌더링)

`DesertWaveBackground`: 2-layer parallax (Tab), 1-layer (Detail/Sheet)

### 3. Ocean — 파라미터 튜닝

| Parameter | Before | After |
|-----------|--------|-------|
| Surface steepness | 0.35 | 0.40 |
| Surface crestSharpness | 0.10 | 0.12 |
| Surface foam opacity | 0.25 | 0.30 |
| curlHeight | 1.8 | 2.2 |
| curlWidth | 0.12 | 0.15 |
| train curlCount | 1 | 2 |

### 4. Performance 최적화 (리뷰 반영)

- `WaveSamples` frequency 기반 static cache (body 재평가 시 재할당 방지)
- `rippleAngles` init-time 사전 계산 (프레임당 121회 곱셈 제거)
- `bottomFadeMask()` View extension 추출 (4개 overlay에서 DRY)
- 텍스처 크기를 `UIScreen.main.bounds.width`로 동적화

## Prevention

- **다크모드 색상 추가 시**: opacity와 곱한 effective alpha를 계산하여 최소 0.04 이상 확보
- **새 테마 Shape 추가 시**: `WaveSamples` 캐시 활용, `path(in:)` 내 frame-invariant 계산 사전 수행
- **Animation restart**: 모든 overlay view에 `.task` + `.onAppear` 쌍으로 구성 (탭 전환 시 freeze 방지)

## Files Changed

| File | Change |
|------|--------|
| `Colors/ForestDeep.colorset/Contents.json` | 다크모드 RGB 보정 |
| `Colors/ForestMid.colorset/Contents.json` | 다크모드 RGB 보정 |
| `Colors/ForestMist.colorset/Contents.json` | 다크모드 RGB 조정 |
| `Components/DesertDuneShape.swift` | 신규 — 비대칭 사구 Shape |
| `Components/DesertWaveBackground.swift` | 신규 — Desert Tab/Detail/Sheet |
| `Components/OceanWaveBackground.swift` | 파라미터 튜닝 |
| `Components/OceanWaveShape.swift` | WaveSamples 캐시 추가 |
| `Components/WaveShape.swift` | Desert dispatch 변경 |
| `Components/ForestWaveBackground.swift` | bottomFadeMask 적용 |
| `Extensions/View+BottomFadeMask.swift` | 신규 — 공유 mask extension |
