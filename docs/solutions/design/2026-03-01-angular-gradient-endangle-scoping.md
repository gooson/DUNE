---
tags: [swiftui, angular-gradient, progress-ring, animation, desert-warm]
category: design
date: 2026-03-01
severity: important
related_files:
  - DUNE/Presentation/Shared/Components/ProgressRingView.swift
  - DUNE/Presentation/Shared/Extensions/ConditionScore+View.swift
related_solutions:
  - design/2026-03-01-multi-theme-architecture.md
  - performance/2026-02-19-swiftui-color-static-caching.md
---

# Solution: AngularGradient endAngle Scoping for Progress Ring

## Problem

ProgressRingView의 gradient가 높은 progress 값(>75%)에서 시작점으로 색상이 "번지는" 현상(bleed-through)과, Desert Warm 테마에서 gradient tip 색상이 arc 시작점에 나타나는 문제.

### Symptoms

- progress 75%+ 에서 gradient tip 색상이 arc 시작 캡에 bleed-through
- progress 100%에서 warmGlow/tipColor가 12시 위치에 가시적으로 노출
- Desert Warm 테마에서 다른 hue의 색상(DesertRingDark 등)을 시작점에 사용하면 round lineCap이 해당 색상을 샘플링하여 "이상한" 캡 색상 발생

### Root Cause

`AngularGradient(startAngle: .degrees(-90), endAngle: .degrees(270))`는 gradient의 location 0~1 범위를 전체 360도에 매핑한다. `Circle().trim(from: 0, to: progress)`은 시각적으로 arc를 클립하지만, gradient 자체는 전체 원에 걸쳐 분포한다.

progress가 0.75(270도)를 초과하면, arc의 끝부분이 gradient의 location 1.0 (270도 = 3시 방향) 이후 영역을 지나가면서 wrap-around가 발생한다. location 1.0 색상이 location 0.0 (12시 = -90도) 근처와 혼합되어 시작 캡에 tip 색상이 노출된다.

## Solution

### Key Insight

`AngularGradient`의 `endAngle`을 arc 크기(progress × 360)에 정확히 매치시키면, gradient의 location 0~1이 가시 arc에만 매핑된다. 가시 arc 바깥 영역은 존재하지 않으므로 bleed-through 자체가 불가능해진다.

### Changes Made

| File | Change | Reason |
|------|--------|--------|
| ProgressRingView.swift | `startAngle: 0, endAngle: animatedProgress × 360` | Gradient를 가시 arc에 정확히 스코핑 |
| ProgressRingView.swift | `gradientStops`(Stop 배열 + location) 사용 | 위치 기반 세밀한 gradient 제어 |
| ProgressRingView.swift | `arcDegrees`에 `min(1.0, ...)` 클램프 | progress > 1 방어 |
| ProgressRingView.swift | `arcDegrees`가 `animatedProgress` 사용 | 애니메이션 중 gradient-arc 동기화 |
| ConditionScore+View.swift | `nextTierColor` computed property | 다음 tier 색상 hint |

### Key Code

```swift
// endAngle을 animatedProgress에 스코핑
private var arcDegrees: Double {
    max(0.01, min(1.0, animatedProgress)) * 360
}

// AngularGradient — locations 0~1 = 가시 arc에만 매핑
AngularGradient(
    stops: gradientStops,
    center: .center,
    startAngle: .degrees(0),
    endAngle: .degrees(arcDegrees)
)
```

### Animation 동기화

`arcDegrees`가 `animatedProgress`를 사용하므로:
- SwiftUI가 매 애니메이션 프레임에서 body를 재평가할 때 `arcDegrees`도 보간된 값을 사용
- Gradient의 전체 stop 범위가 항상 가시 arc에 매핑됨
- Tip color가 arc 끝에 항상 보임 (final state에서만 보이는 것이 아님)

## Prevention

### Checklist Addition

- [ ] `AngularGradient` + `Circle().trim()` 조합 시 endAngle이 trim extent에 매치되는지 확인
- [ ] Gradient의 animated 속성과 shape의 animated 속성이 같은 @State를 참조하는지 확인
- [ ] Round lineCap 사용 시 location 0과 1의 색상이 캡에서 어떻게 보이는지 확인

### Rule Addition (if applicable)

performance-patterns.md에 이미 "static let > static func for body-called gradients" 규칙이 있음. 본 케이스는 base/tipColor가 caller마다 다르므로 static 캐싱이 불가하여 accepted trade-off로 문서화.

## Lessons Learned

1. **AngularGradient와 Circle.trim()은 독립적**: trim은 시각적 클리핑만 수행하고, gradient는 startAngle~endAngle 전체에 분포한다. 두 범위를 일치시키지 않으면 gradient가 보이지 않는 영역으로 "확산"된다.
2. **Round lineCap은 gradient의 양 끝점 색상을 샘플링**: location 0의 색상이 시작 캡에, location 1의 색상이 끝 캡에 직접 표시된다. 이 점을 gradient 디자인 시 고려해야 한다.
3. **Animated 속성 동기화**: 같은 시각 요소의 서로 다른 속성이 각각 다른 값(하나는 animated, 하나는 static)을 참조하면 애니메이션 중 불일치가 발생한다.
