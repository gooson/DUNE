---
tags: [wave, shape, animation, ocean-theme, refactor]
date: 2026-03-01
category: plan
status: approved
---

# Plan: OceanBigWaveShape Curl 통합

## Summary

OceanBigWaveShape를 삭제하고, OceanWaveShape에 curl 파라미터를 추가하여 Surface wave 위에서 자연스럽게 솟아오르는 curl crest를 구현한다.

## Affected Files

| File | Action | Description |
|------|--------|-------------|
| `OceanWaveShape.swift` | Modify | curl 파라미터 + 2-pass path building |
| `OceanWaveBackground.swift` | Modify | Layer 4 삭제, Layer 3에 curl 적용 |
| `OceanBigWaveShape.swift` | Delete | 전체 삭제 |
| `OceanBigWaveShapeTests.swift` | Delete | 전체 삭제 |
| `OceanWaveShapeTests.swift` | Modify | curl 관련 테스트 추가 |

## Implementation Steps

### Step 1: OceanWaveShape에 curl 파라미터 추가

- `curlCount: Int = 0` (0이면 기존 동작)
- `curlHeight: CGFloat = 0.15` (amplitude 대비 curl 높이)
- `curlWidth: CGFloat = 0.08` (수평 비율)

### Step 2: 2-pass path building

curlCount > 0일 때:
1. Pass 1: 모든 Y값 사전 계산 + crest 탐지
2. Pass 2: crest 위치에서 Bezier curl 삽입

curlCount == 0: 기존 1-pass 유지 (하위 호환)

### Step 3: Stroke/Foam Shape에도 동일 적용

OceanWaveStrokeShape, OceanFoamGradientShape에 같은 파라미터 추가.
공유 helper로 curl path 생성 로직 추출.

### Step 4: OceanWaveOverlayView 갱신

curl 파라미터를 View → Shape로 전달.

### Step 5: OceanTabWaveBackground 갱신

Layer 4 (OceanBigWaveOverlayView) 삭제.
Layer 3 (Surface)에 curlCount: 1 적용.

### Step 6: 삭제 + 테스트

OceanBigWaveShape.swift, OceanBigWaveShapeTests.swift 삭제.
OceanWaveShapeTests에 curl 테스트 추가.
