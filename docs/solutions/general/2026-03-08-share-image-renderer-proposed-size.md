---
tags: [swiftui, imagerenderer, iosurface, sharelink, rendering, workout-share]
date: 2026-03-08
category: solution
status: implemented
---

# Share ImageRenderer Zero-Height Fix

## Problem

운동 공유 이미지를 만들 때 콘솔에 `Failed to create 1320x0 image slot`가 출력될 수 있었다.

증상은 공유 이미지 생성 실패 또는 빈 이미지로 이어질 수 있었고, 특히 `ImageRenderer`가 SwiftUI view를 offscreen으로 캡처하는 경로에서 발생했다.

## Root Cause

`WorkoutShareService.renderShareImage()`가 `WorkoutShareCard`를 `ImageRenderer`에 바로 전달하고 있었다.

이 경로는 일반 화면 레이아웃과 달리 intrinsic size가 완전히 해석되지 않을 수 있는데, 폭은 환경에서 잡히더라도 높이가 `0`으로 계산되면 IOSurface가 `1320x0` 같은 invalid buffer를 만들려다 실패한다.

## Solution

공유 카드의 렌더 크기를 먼저 측정한 뒤, 그 값을 `frame`과 `ImageRenderer.proposedSize`에 같이 넣도록 바꿨다.

### Changes Made

| File | Change | Reason |
|------|--------|--------|
| `DUNE/Presentation/Exercise/Components/WorkoutShareService.swift` | 고정 폭 기준 `sizeThatFits` 측정, invalid size guard, explicit `frame` + `proposedSize` 적용 | offscreen 렌더링에서도 0 높이 방지 |
| `DUNETests/WorkoutShareServiceTests.swift` | 렌더된 이미지의 width/height 검증, empty/minimal content size 테스트 추가 | 재발 방지 |

### Key Code

```swift
let renderSize = measuredRenderSize(data: data, weightUnit: weightUnit)
guard renderSize.width > 0, renderSize.height > 0 else { return nil }

let renderer = ImageRenderer(content: card.frame(width: renderSize.width, height: renderSize.height))
renderer.proposedSize = .init(width: renderSize.width, height: renderSize.height)
```

## Prevention

- `ImageRenderer`로 export/share 이미지를 만들 때는 intrinsic size 추론에 맡기지 않는다.
- 먼저 `sizeThatFits` 또는 동등한 측정 경로로 non-zero width/height를 확보한다.
- 빈 상태 데이터도 포함해 "rendered image width/height > 0" 테스트를 둔다.

## Lessons Learned

SwiftUI view가 화면에 잘 보인다고 해서 offscreen renderer도 같은 크기 계산을 보장하지는 않는다. `ImageRenderer`는 별도 레이아웃 계약으로 다뤄야 하고, export 경로에서는 명시적인 크기 지정이 더 안전하다.
