---
tags: [visionos, chart3d, swift-charts, rectanglemark, runtime-crash]
category: general
date: 2026-03-09
severity: important
related_files:
  - DUNEVision/Presentation/Chart3D/TrainingVolume3DView.swift
related_solutions:
  - docs/solutions/architecture/2026-03-08-visionos-real-data-pipeline.md
---

# Solution: visionOS Chart3D RectangleMark Extents Crash

## Problem

`DUNEVision`의 Chart3D 화면을 Vision Pro simulator에서 열면 Swift Charts runtime이 `A rectangle mark needs to have exactly two extents.` fatal error로 중단됐다.

### Symptoms

- Vision Pro simulator에서 Chart3D 진입 직후 앱이 크래시
- console에 `Charts/RectangleMarkResolvable3DContent.swift:67` fatal error 출력
- crash 지점은 `TrainingVolume3DView`의 `RectangleMark(x:y:z:)` 사용과 일치

### Root Cause

`RectangleMark`의 3D initializer는 scalar 축 1개와 range 축 2개를 요구한다. 기존 구현은 `x`, `y`, `z` 모두 단일 numeric value를 전달해 Swift Charts의 3D mark contract를 위반했다.

## Solution

`TrainingVolume3DView`를 3D `RectangleMark` 규약에 맞게 수정했다. `x`는 근육 그룹 중심 주변 range, `y`는 `0..<volume` 높이 range, `z`는 주차 scalar로 바꿔 runtime assert를 제거했다. 이후 review에서 발견된 first/last category clipping까지 막기 위해 x-scale domain에 좌우 padding을 추가했다.

### Changes Made

| File | Change | Reason |
|------|--------|--------|
| `DUNEVision/Presentation/Chart3D/TrainingVolume3DView.swift` | `RectangleMark`를 `x range + y range + z scalar`로 변경 | Swift Charts 3D contract 만족 |
| `DUNEVision/Presentation/Chart3D/TrainingVolume3DView.swift` | `muscleRange`, `volumeRange`, `muscleDomain` helper 추가 | plotting intent를 명시하고 edge clipping 방지 |
| `DUNEVision/Presentation/Chart3D/TrainingVolume3DView.swift` | `isPlottable`에 `volume > 0` 조건 추가 | zero-height range mark 생성 방지 |

### Key Code

```swift
RectangleMark(
    x: .value("Muscle", point.muscleRange),
    y: .value("Volume", point.volumeRange),
    z: .value("Week", point.week)
)
.chartXScale(domain: muscleDomain)
```

## Prevention

Chart3D mark를 사용할 때는 "어떤 축이 scalar이고 어떤 축이 extent인지"를 코드 리뷰에서 먼저 확인해야 한다. 3D mark는 2D mark와 달리 runtime precondition이 강해, 잘못된 parameter shape가 compile-time이 아니라 launch-time crash로 드러날 수 있다.

### Checklist Addition

- [ ] `Chart3D`의 `RectangleMark`/`RuleMark`/유사 mark 사용 시 scalar 1개 + extent 2개 규약을 리뷰에서 확인한다
- [ ] range-based mark를 도입하면 axis domain이 first/last mark를 자르지 않는지 함께 확인한다

### Rule Addition (if applicable)

즉시 새 rule 파일로 분리할 정도의 반복 패턴은 아니므로 이번에는 추가하지 않는다. Chart3D mark 사용 사례가 더 늘어나면 visionOS chart rule로 승격을 검토한다.

## Lessons Learned

Chart3D API는 surface/plane 기반 mark가 많아서, 2D chart 감각으로 scalar 세 축을 모두 채우면 런타임에서 바로 실패한다. crash fix만으로 끝내지 말고 axis domain까지 같이 봐야 first/last element clipping 같은 후속 회귀를 줄일 수 있다.
