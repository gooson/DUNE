---
tags: [forest, wave, shape, parallax, silhouette, pine-tree]
date: 2026-03-01
category: plan
status: approved
---

# Plan: Forest 테마 웨이브 고도화

## 변경 요약

`ForestSilhouetteShape`를 전면 재설계하여 톱니바퀴 노이즈를 산 능선 + 소나무 실루엣으로 교체.
`ForestWaveBackground`의 Tab/Detail/Sheet 3가지 배경 파라미터를 모두 조정.

## Affected Files

| 파일 | 변경 유형 | 설명 |
|------|----------|------|
| `ForestSilhouetteShape.swift` | **Major rewrite** | Bezier 곡선 + 소나무 실루엣 + 개선된 하모닉 |
| `ForestWaveBackground.swift` | **Param update** | Amplitude 3-5배, frame height, verticalOffset 조정 |
| `DUNETests/ForestSilhouetteShapeTests.swift` | **New** | Shape 테스트 |

## Implementation Steps

### Step 1: ForestSilhouetteShape 재설계

**1a. edgeNoise 제거, 다중 주파수 산 능선**

현재 5개 하모닉(base + canopy swell + mid + canopy pulse + edgeNoise) → 4개로 정리:

```swift
// Primary ridge: 큰 산 봉우리 (frequency × 1.0)
let primary = sin(angle)

// Secondary hills: 중간 언덕 (frequency × 2.3)
let secondary = 0.35 * sin(2.3 * angle + 0.7)

// Tertiary undulation: 작은 굴곡 (frequency × 4.7)
let tertiary = 0.15 * sin(4.7 * angle + 1.4)

// Pine canopy: 나무 실루엣 (별도 함수)
let pines = treeDensity * pineCanopy(angle)
```

edgeNoise 제거 → 톱니바퀴 원인 제거.

**1b. Catmull-Rom → Bezier 곡선 변환**

120개 샘플 포인트를 직선이 아닌 부드러운 곡선으로 연결:

```swift
// Catmull-Rom to cubic Bezier conversion
// 인접 4개 포인트(P0,P1,P2,P3)에서 P1→P2 구간의 control points 계산
func controlPoints(p0: CGPoint, p1: CGPoint, p2: CGPoint, p3: CGPoint)
    -> (cp1: CGPoint, cp2: CGPoint) {
    let d1 = distance(p0, p1)
    let d2 = distance(p1, p2)
    let d3 = distance(p2, p3)
    // Centripetal parameterization for smooth curves
    ...
}
```

`path.addLine(to:)` → `path.addCurve(to:control1:control2:)` 전환.

**1c. 소나무 실루엣 (pineCanopy)**

```swift
// 삼각 펄스: 뾰족한 꼭대기 + 약간 비대칭 하강
private static func pineCanopy(angle: CGFloat, density: CGFloat) -> CGFloat {
    // 여러 주파수의 삼각파 합성
    let freq1 = triangleWave(angle * 3.1) * 0.5   // 큰 나무
    let freq2 = triangleWave(angle * 5.7) * 0.3   // 중간 나무
    let freq3 = triangleWave(angle * 8.3) * 0.2   // 작은 나무
    return density * (freq1 + freq2 + freq3)
}

// Triangle wave: -1 to 1, 뾰족한 꼭대기
private static func triangleWave(_ x: CGFloat) -> CGFloat {
    let t = x / (2 * .pi)
    let frac = t - floor(t)
    return frac < 0.4
        ? frac / 0.4           // 급경사 상승
        : (1 - frac) / 0.6    // 완만한 하강
}
```

### Step 2: ForestWaveBackground 파라미터 조정

**Tab 배경 (ForestTabWaveBackground)**

| 파라미터 | Far (현재→개선) | Mid (현재→개선) | Near (현재→개선) |
|---------|----------------|----------------|-----------------|
| amplitude | 0.045→0.14 | 0.075→0.22 | 0.115→0.32 |
| frequency | 0.62→0.55 | 0.95→0.75 | 1.25→0.95 |
| verticalOffset | 0.4→0.35 | 0.5→0.48 | 0.55→0.58 |
| frame height | 200→250 | 200→260 | 200→280 |
| ruggedness | 0.03→(제거) | 0.12→(제거) | 0.18→(제거) |
| treeDensity | 0.03→0.15 | 0.08→0.35 | 0.12→0.55 |

ruggedness 파라미터는 새 하모닉 구조에서 불필요 → secondary/tertiary가 대체.

**Detail 배경**: Tab의 55% amplitude, 70% opacity
**Sheet 배경**: Tab의 35% amplitude, 55% opacity

### Step 3: 테스트

- Path non-empty (valid rect)
- Path empty (zero rect)
- Path within bounds (높은 amplitude에서도)
- Phase changes path
- Zero amplitude → flat
- treeDensity 0 vs >0 차이
- animatableData reflects phase

### Step 4: 빌드 검증

`scripts/build-ios.sh` 로 빌드 + 테스트 통과 확인.

## 설계 결정

1. **WaveSamples 재사용**: Bezier control point 계산은 ForestSilhouetteShape 내부에서 수행. WaveSamples 구조체 수정 불필요.
2. **ruggedness 파라미터 제거**: 새 하모닉 구조에서 secondary/tertiary가 역할 대체. API breaking change이지만 ForestWaveBackground만 소비자이므로 영향 최소.
3. **edgeNoise static 배열 삭제**: 메모리 절약 + 톱니바퀴 원인 제거.
4. **Crest stroke 호환**: ForestSilhouetteShape를 fill과 stroke에 모두 사용하는 현재 패턴 유지. Bezier 곡선이 stroke에도 자연스럽게 적용됨.
