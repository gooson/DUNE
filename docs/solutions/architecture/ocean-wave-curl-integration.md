---
tags: [wave, shape, animation, bezier, ocean-theme, refactor, dry]
date: 2026-03-01
category: solution
status: implemented
---

# Solution: OceanBigWaveShape Curl Integration

## Problem

`OceanBigWaveShape`는 바닥(`y: 1.0`)에서 시작하는 독립 삼각형 Bezier 곡선으로, 기존 wave layer와 시각적으로 분리되어 부자연스러웠다. Surface wave 위에서 자연스럽게 솟아오르는 curl crest가 필요했다.

## Solution

OceanBigWaveShape를 삭제하고, OceanWaveShape에 curl 기능을 통합했다.

### 핵심 접근: Additional Bezier Subpaths

Wave contour를 수정하는 대신, curl을 별도 closed/open Bezier subpath로 wave fill 위에 추가한다. Non-zero winding fill rule로 겹치는 영역이 자연스럽게 merge된다.

### 새 파라미터

| 파라미터 | 타입 | 기본값 | 범위 | 설명 |
|---------|------|-------|------|------|
| `curlCount` | Int | 0 | 0-5 | 표시할 curl 개수 (0=기존 동작) |
| `curlHeight` | CGFloat | 1.5 | >=0 | Wave amplitude 대비 curl 높이 |
| `curlWidth` | CGFloat | 0.1 | 0.03-1.0 | Curl 수평 범위 (전체 폭 비율) |

`curlCount == 0`이면 기존 동작과 100% 동일 (하위 호환).

### Curl 생성 알고리즘

1. **Y값 사전 계산**: `computeWaveYValues()` — 120개 sample point의 Y좌표 배열
2. **Crest 탐지**: strict `<` 비교로 local minima 탐지 (2-neighbor check)
3. **Top-N 선택**: Y값 정렬 → 가장 높은 N개 선택
4. **Bezier 앵커 계산**: start/peak/lip/end 좌표 + control point 계산
5. **Subpath 삽입**: `addCurlTopEdge()` 공유 helper로 rise→lip→descent 곡선 생성

### DRY: 공유 Helper 구조

```
addCurlTopEdge()  ← 핵심 Bezier 곡선 (1곳)
    ├── addCurlFillSubpaths()   → move + topEdge + close
    ├── addCurlStrokeSubpaths() → move + topEdge (open)
    └── addCurlFoamSubpaths()   → move + topEdge + reverse pass + close
```

### Performance 최적화

- `curlCount == 0`: 기존 inline Y 계산 유지 (배열 할당 없음)
- `curlCount > 0`: Y 배열 1회 계산 → contour + curl 양쪽에 사용 (double computation 제거)
- 모든 curl helper에 `@inline(__always)` 적용

### 삭제된 코드

- `OceanBigWaveShape` (struct)
- `OceanBigWaveCrestShape` (struct)
- `OceanBigWaveOverlayView` (struct + View)
- `bigWavePt()` (helper)
- `OceanBigWaveShapeTests.swift`

### Layer 구성 변경

```
Before:
  Layer 1: Deep (OceanWaveOverlayView)
  Layer 2: Mid (OceanWaveOverlayView, reverse)
  Layer 3: Surface (OceanWaveOverlayView)
  Layer 4: BigWave (OceanBigWaveOverlayView) ← 독립

After:
  Layer 1: Deep (curlCount: 0)
  Layer 2: Mid (curlCount: 0)
  Layer 3: Surface (curlCount: 1, curlHeight: 1.8*scale)
  (Layer 4 삭제)
```

## Prevention

- Wave Shape에 새 파라미터 추가 시 3개 Shape(Fill/Stroke/Foam) 모두에 동일 적용
- 새 curl 파라미터는 init에서 반드시 범위 clamp (`Swift.max/min`)
- `path(in:)` 내 배열 할당은 curl 활성 시에만 (`curlCount > 0` 분기)
- Bezier 곡선 로직은 `addCurlTopEdge()`에 집중 — 변경 시 1곳만 수정

## Related

- Brainstorm: `docs/brainstorms/2026-03-01-ocean-bigwave-improvement.md`
- Plan: `docs/plans/2026-03-01-ocean-bigwave-curl-integration.md`
