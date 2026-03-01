---
tags: [forest, wave, shape, parallax, silhouette, pine-tree, ukiyo-e]
date: 2026-03-01
category: brainstorm
status: draft
---

# Brainstorm: Forest 테마 웨이브 고도화

## Problem Statement

현재 `ForestSilhouetteShape`가 숲/산 느낌이 아닌 **톱니바퀴 노이즈** 같은 느낌을 줌.

### 근본 원인

| 원인 | 코드 위치 | 영향 |
|------|----------|------|
| `addLine(to:)` 직선 연결 | ForestSilhouetteShape:89-93 | 꺾인 선분 = 톱니바퀴 외곽 |
| 고주파 edgeNoise (7.3 × 13.7) | ForestSilhouetteShape:38-41 | 매 포인트 급격한 높낮이 변화 |
| 낮은 amplitude (0.045~0.115) | ForestWaveBackground:209,226,245 | 높이 200pt 중 ~9~23pt 변동 → 평탄 |
| canopyPulse = pow(sin,1.8) | ForestSilhouetteShape:105-108 | 나무가 아닌 약간 둥근 범프 |
| 120 샘플 직선 연결 | WaveSamples.sampleCount=120 | 저해상도 + 직선 = 각진 외곽 |

### 참고 이미지 분석

첨부된 산림 이미지에서 추출한 핵심 시각 요소:
- **레이어드 산 실루엣**: 먼 산 → 중간 숲 → 가까운 숲 (3-5 레이어)
- **소나무 꼭대기**: 뾰족하면서도 부드러운 삼각형 윤곽
- **높낮이 차이**: 봉우리와 골짜기가 뚜렷
- **안개/미스트**: 먼 레이어일수록 옅고 부드러움
- **유기적 곡선**: 자연스러운 능선 → Bezier 곡선 필수

## Target Users

앱 사용자 (Forest Green 테마 선택자). 매일 보는 배경이므로 자연스러운 분위기가 중요.

## Success Criteria

1. 톱니바퀴 → 산 능선 + 소나무 실루엣으로 시각적 개선
2. 3개 레이어 parallax 유지 (Far / Mid / Near)
3. 기존 성능 유지 (pre-computed samples, static 캐시)
4. Tab / Detail / Sheet 3가지 배경 모두 개선
5. 기존 crest highlight, bokashi gradient, ukiyo-e grain 유지

## Proposed Approach

### A. ForestSilhouetteShape 재설계

#### A1. Bezier 곡선 전환

```
현재: addLine(to:) — 120개 직선
개선: addQuadCurve(to:controlPoint:) — 부드러운 곡선
```

Catmull-Rom → Bezier 변환으로 샘플 포인트 사이를 부드럽게 보간.
매 포인트 쌍마다 자동 control point 계산.

#### A2. 능선 프로필 개선

```swift
// 현재: 단순 sin + noise
y = sin(angle) + noise

// 개선: 다중 주파수 산 능선
y = primaryRidge(angle)      // 큰 봉우리 (1-2개)
  + secondaryHills(angle)    // 중간 언덕 (3-5개)
  + microVariation(angle)    // 미세한 자연 변동
```

| 하모닉 | 목적 | 주파수 비율 | 가중치 |
|--------|------|------------|--------|
| Primary | 큰 봉우리 | 1× | 0.5 |
| Secondary | 중간 언덕 | 2.3× | 0.3 |
| Tertiary | 작은 굴곡 | 4.7× | 0.12 |
| Micro | 자연 변동 | 8.1× | 0.05 |

edgeNoise 제거 또는 micro 하모닉으로 대체.

#### A3. 소나무 실루엣 클러스터

```
개별 나무 프로필:       클러스터:
    /\                  /\  /\    /\
   /  \               /  \/  \  /  \  /\
  /    \             /        \/    \/  \
 /      \           /                    \
```

소나무 = 삼각 펄스 (tri pulse). 현재 `canopyPulse`의 sin 기반 대신:

```swift
// Pine tree: steep rise, pointed tip, gradual fall
func pineProfile(t: CGFloat) -> CGFloat {
    let frac = t - floor(t) // 0~1 주기 내 위치
    // 뾰족한 삼각형 (약간 비대칭)
    return frac < 0.45
        ? frac / 0.45          // 상승
        : (1.0 - frac) / 0.55  // 하강 (약간 완만)
}
```

- Near 레이어: 큰 나무 (높이 20-40pt), 밀집
- Mid 레이어: 중간 나무 (높이 10-20pt), 중간 밀도
- Far 레이어: 작은 나무 (높이 5-10pt), 희미

#### A4. Amplitude 증가

| 레이어 | 현재 amplitude | 개선 amplitude | 실제 높이 (200pt frame) |
|--------|---------------|---------------|----------------------|
| Far | 0.045 | 0.15 | ~30pt |
| Mid | 0.075 | 0.25 | ~50pt |
| Near | 0.115 | 0.35 | ~70pt |

### B. ForestWaveBackground 파라미터 조정

#### B1. Tab 배경

```
현재:
  3레이어 × height:200 × low amplitude = 평탄한 파도

개선:
  3레이어 × height:250-300 × high amplitude = 뚜렷한 산세
  Far: verticalOffset 0.35 (높게) → 먼 산 능선
  Mid: verticalOffset 0.5 (중간) → 중간 숲
  Near: verticalOffset 0.6 (낮게) → 가까운 숲
```

#### B2. Detail 배경

Tab의 50-60% 스케일. 2레이어 유지하되 같은 Shape 사용.

#### B3. Sheet 배경

Tab의 30-40% 스케일. 1레이어. 약한 소나무 실루엣.

### C. Crest Highlight 유지

현재 stroke 기반 crest는 능선 꼭대기를 강조.
Shape가 개선되면 crest도 자연스럽게 개선됨 (같은 Shape 사용).

### D. 성능 고려

| 항목 | 전략 |
|------|------|
| Bezier control points | WaveSamples에서 pre-compute |
| 소나무 프로필 | 주기 함수로 구현 (lookup table 불필요) |
| edgeNoise 제거 | 정적 배열 삭제 → 메모리 절약 |
| 샘플 수 유지 | 120개 (Bezier로 충분히 부드러움) |

## Constraints

- **기존 파라미터 호환**: `WavePreset` 기반 `intensityScale` 시스템 유지
- **Animation 호환**: `animatableData = phase` 유지, 20-turn loop 보존
- **Dark mode**: `visibilityBoost` 메커니즘 유지
- **Weather integration**: `weatherAtmosphere` overlay 호환

## Edge Cases

- Reduce motion 시 정적 산 실루엣 (현재와 동일)
- 매우 좁은 화면 (iPhone SE): frequency 자동 조정 필요할 수 있음
- iPad 가로모드: frame height 동일하므로 문제 없음

## Scope

### MVP (Must-have)

1. `ForestSilhouetteShape` Bezier 곡선 전환
2. edgeNoise 제거, 다중 주파수 하모닉으로 대체
3. 소나무 실루엣 클러스터 (pineProfile)
4. Amplitude 3-5배 증가
5. Tab / Detail / Sheet 3가지 배경 모두 적용

### Nice-to-have (Future)

- 시간대별 미스트 밀도 변화 (새벽 > 낮)
- 계절별 나무 형태 변화
- 4-5 레이어 확장 (성능 검증 후)
- 나무 사이로 빛이 새어나오는 효과

## Open Questions

1. 소나무 밀도/크기를 `treeDensity` 파라미터 하나로 계속 제어할지, `treeSize`를 분리할지
2. Near 레이어의 나무가 너무 크면 컨디션 카드와 겹칠 수 있음 → verticalOffset으로 해결?

## Affected Files

| 파일 | 변경 | 영향도 |
|------|------|--------|
| `ForestSilhouetteShape.swift` | Shape 로직 전면 재설계 | High |
| `ForestWaveBackground.swift` | 파라미터 조정 (amplitude, offset, frequency) | Medium |
| `OceanWaveShape.swift` (WaveSamples) | Bezier control point 추가 가능 | Low |

## Next Steps

- [ ] `/plan` 으로 구현 계획 생성
