---
tags: [wave, animation, ui, shape, ocean-theme]
date: 2026-03-01
category: brainstorm
status: draft
---

# Brainstorm: OceanBigWaveShape 개선 - Wave Surface 통합 Curl

## Problem Statement

현재 `OceanBigWaveShape`는 바닥(`y: 1.0`)에서 시작하여 꼭대기까지 올라가는 독립 삼각형 형태의 Bezier 곡선이다. 이로 인해:

1. 기존 wave layer들과 시각적으로 분리되어 부자연스러움
2. "파도 위에 얹힌 큰 파도" 느낌이 아닌 바닥에서 솟은 기둥처럼 보임
3. 독립 phase를 사용하여 surface wave와 동기화되지 않음

**목표**: 참조 이미지(일본식 파도 일러스트)처럼 Surface wave 위에서 자연스럽게 솟아오르는 curl crest를 구현.

## Target Users

- 앱 사용자 전체 (배경 비주얼)
- Today/Train/Wellness 탭에서 노출

## Success Criteria

1. BigWave crest가 Surface wave의 crest 위치에서 자연스럽게 솟아오름
2. Surface wave phase와 동기화되어 함께 이동
3. 기존 OceanBigWaveShape 삭제 가능 (코드 DRY)
4. `.life` 탭에서는 여전히 비활성
5. 기존 테스트(`OceanBigWaveShapeTests`)가 새 구현에 맞게 갱신됨

## Proposed Approach

### OceanWaveShape에 Curl 통합

기존 `OceanWaveShape`의 sample point 기반 렌더링에 curl 기능을 추가한다.

```
기존: wave line → fill to bottom
개선: wave line → [crest 위치에서 curl bump 삽입] → fill to bottom
```

#### 핵심 아이디어

1. **Crest 감지**: 120개 sample point에서 local maxima(crest) 탐지
2. **Top-N 선택**: 가장 높은 1~2개 crest 선택
3. **Curl 삽입**: 해당 crest 위치에서 wave line 대신 Bezier curl 곡선으로 대체
4. **Phase 동기화**: 동일 `phase` 사용으로 wave와 curl이 함께 이동

#### Curl 곡선 형태

```
          ╭─╮  ← curl tip (rises above wave line)
         ╱   ╲
  ──────╱     ╲──── ← normal wave line continues
        ↑
   crest position
```

Crest 전후 N개 sample point 범위에서:
- 진입부: wave line에서 부드럽게 상승
- 정점: wave line 위로 `curlHeight` 만큼 돌출
- 하강부: 앞쪽으로 살짝 기울어지며 wave line으로 복귀 (컬링 효과)

### 새 파라미터 (OceanWaveShape 확장)

| 파라미터 | 타입 | 기본값 | 설명 |
|---------|------|-------|------|
| `curlCount` | Int | 0 | 표시할 curl 개수 (0=없음, 기존 동작) |
| `curlHeight` | CGFloat | 0.15 | Wave amplitude 대비 curl 높이 비율 |
| `curlWidth` | CGFloat | 0.08 | Curl이 차지하는 수평 비율 |
| `curlForwardLean` | CGFloat | 0.3 | 컬링의 앞쪽 기울기 (0=수직, 1=완전 수평) |

`curlCount == 0`이면 기존 동작과 100% 동일 → 하위 호환성 보장.

### Layer 구성 변경

```
현재:
  Layer 1: Deep wave (OceanWaveOverlayView)
  Layer 2: Mid wave (OceanWaveOverlayView)
  Layer 3: Surface wave (OceanWaveOverlayView)
  Layer 4: BigWave (OceanBigWaveOverlayView) ← 독립, 바닥부터 시작

개선:
  Layer 1: Deep wave (curlCount: 0)
  Layer 2: Mid wave (curlCount: 0)
  Layer 3: Surface wave (curlCount: 1~2, curlHeight: 0.15)
  (Layer 4 삭제)
```

### Foam/Stroke 자동 적용

- `OceanWaveStrokeShape`와 `OceanFoamGradientShape`도 동일한 curl 파라미터 적용
- Curl 부분의 stroke가 자연스럽게 foam line을 형성
- 별도의 `OceanBigWaveCrestShape` 불필요

### Animation

- Surface wave의 `phase`를 공유하므로 curl도 wave와 함께 이동
- Curl 자체는 wave crest 위치에 종속 → phase 변화 시 crest 위치가 바뀌면 curl도 따라감
- 추가 breathing 효과 고려: `curlHeight`를 미세하게 oscillate (future)

## Constraints

### 기술적 제약
- `path(in:)` 내 allocation 금지 (performance-patterns 규칙)
- Shape 내 문자열/JSON 파싱 금지
- `@inline(__always)` 유지하여 hot path 최적화
- `WaveSamples` 사전 계산 구조 유지
- Crest 탐지 로직이 매 frame 호출되므로 O(N) 이내 유지 (N=120)

### 호환성 제약
- `curlCount: 0`일 때 기존 path와 pixel-identical
- Watch에서는 사용하지 않으므로 Watch target 영향 없음
- `accessibilityReduceMotion` 존중 (기존 대로)

## Edge Cases

- **아주 작은 rect**: `guard rect.width > 0, rect.height > 0` 기존 방어
- **crest가 1개 미만**: 데이터가 flat하면 curl 미표시 (curlCount보다 crest가 적을 때)
- **crest가 화면 가장자리**: 잘려도 자연스러워야 함 → `.clipped()` 활용
- **amplitude 0**: curl도 0 높이 → 사실상 미표시

## Scope

### MVP (Must-have)
- [ ] OceanWaveShape에 curl 파라미터 추가
- [ ] Crest 감지 + Top-N 선택 로직
- [ ] Curl Bezier 곡선 삽입 (path 수정)
- [ ] OceanWaveStrokeShape/OceanFoamGradientShape에도 동일 적용
- [ ] OceanTabWaveBackground에서 Surface layer에 curl 적용
- [ ] OceanBigWaveShape/OceanBigWaveCrestShape/OceanBigWaveOverlayView 삭제
- [ ] 테스트 갱신

### Nice-to-have (Future)
- curlHeight breathing 애니메이션 (미세한 높이 변화)
- Detail/Sheet background에도 작은 curl 적용
- Curl에 내부 wave pattern (이미지의 동심원 패턴)
- 날씨 연동: 거친 날씨일 때 curlCount/curlHeight 증가

## Open Questions

1. **Curl 높이**: Surface wave amplitude의 몇 배가 적절한가? (1.5x? 2x? 프리뷰로 튜닝 필요)
2. **Curl 방향**: wave 진행 방향과 같은 방향으로 기울어야 하는가? (reverseDirection 고려)
3. **OceanBigWaveShapeTests 이관**: 기존 테스트를 OceanWaveShape curl 테스트로 전환할지, 새로 작성할지

## Architecture Impact

### 삭제 대상
- `OceanBigWaveShape` (struct)
- `OceanBigWaveCrestShape` (struct)
- `OceanBigWaveOverlayView` (struct)
- `bigWavePt()` (helper)
- `OceanBigWaveShapeTests.swift`

### 수정 대상
- `OceanWaveShape` — curl 파라미터 + path 로직 추가
- `OceanWaveStrokeShape` — 동일 curl 적용
- `OceanFoamGradientShape` — 동일 curl 적용
- `OceanWaveOverlayView` — curl 파라미터 전달
- `OceanTabWaveBackground` — Layer 4 제거, Layer 3에 curl 파라미터 추가
- `WaveShapeTests` / `OceanWaveShapeTests` — curl 관련 테스트 추가

## Next Steps

- [ ] `/plan` 으로 구체 구현 계획 생성
