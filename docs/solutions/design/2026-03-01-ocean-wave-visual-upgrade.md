---
tags: [ocean-cool, wave, animation, shape, performance, dry]
date: 2026-03-01
category: solution
status: implemented
---

# Ocean Wave 비주얼 개선: 가변 높이 + 포말 + 호 패턴

## Problem

Ocean Cool 테마의 파도 배경이 단순한 sine + 2차 하모닉으로 구성되어 있어
시각적 깊이감과 역동성이 부족했다.

구체적 문제:
1. 모든 파도가 동일한 높이 → 단조로움
2. 흰색 포말이 거의 보이지 않음 (opacity 0.06)
3. 파도 사이 장식 패턴 없음

## Solution

### 1. 가변 amplitude (OceanWaveShape)

기존 2-하모닉 공식에 저주파 envelope + 고주파 sharpness 추가:

```swift
// 기존: y = A × [sin(θ) + steepness × sin(2θ)]
// 개선: y = A × [sin(θ) + steepness × sin(2θ)
//              + crestHeight × sin(0.5θ + φ × 0.3)     // envelope
//              + crestSharpness × sin(3θ + φ × 1.5)]   // sharpness
```

- `crestHeight` (0…0.4): 저주파 envelope → 일부 파도만 높게
- `crestSharpness` (0…0.15): 고주파 → 파도 꼭대기 날카롭게

### 2. 흰색 포말 표현

**Stroke**: `OceanWaveStrokeShape` — 파도 윤곽선을 흰색으로 표현
**Foam gradient**: `OceanFoamGradientShape` — 파도 꼭대기에서 아래로 흰색→투명

`WaveStrokeStyle`과 `WaveFoamStyle` 값 타입으로 파라미터 그룹화.

### 3. 동심원 호 패턴 (OceanArcPattern)

일본 전통 청해파(seigaiha) 스타일의 반원 패턴:
- brick 배열 (짝수/홀수 행 오프셋)
- phase 애니메이션으로 느린 수평 drift (25초 주기)

### 적용 스케일

| 배경 | 높이감 | 포말 | 호 패턴 |
|------|--------|------|---------|
| Tab | 100% | stroke + foam | 2행 |
| Detail | 70% | stroke만 | 1행 |
| Sheet | 50% | stroke만 | 없음 |

## Key Patterns

### DRY: 공유 파형 계산

3개 Shape가 동일 공식을 사용 → `waveY()` file-scope 함수 + `WaveSamples` 구조체로 추출.

```swift
private struct WaveSamples { ... }

@inline(__always)
private func waveY(angle:phase:centerY:amp:steepness:harmonicOffset:
                   crestHeight:crestSharpness:) -> CGFloat { ... }
```

### 성능: 파라미터 클램핑

crestHeight/crestSharpness를 init에서 클램핑하여 합산 harmonics가
rect를 과도하게 벗어나지 않도록 방어.

### 매직 넘버 제거

```swift
private enum HarmonicPhase {
    static let envelopeDrift: CGFloat = 0.3
    static let sharpnessDrift: CGFloat = 1.5
}
```

## Prevention

- Shape에 새 하모닉 추가 시 `waveY()` 단일 소스만 수정
- `WaveStrokeStyle`/`WaveFoamStyle`로 call-site 파라미터 폭발 억제
- `.clipped()` 적용으로 harmonics 합산 overflow 시각적 방어
- `driftDuration > 0` guard로 0-duration 애니메이션 CPU 스핀 방지
