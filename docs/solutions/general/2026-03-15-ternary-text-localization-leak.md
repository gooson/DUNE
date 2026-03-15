---
tags: [localization, swiftui, text, ternary, LocalizedStringKey]
date: 2026-03-15
category: general
status: implemented
related_files:
  - DUNE/Presentation/Posture/PostureResultView.swift
  - DUNE/Presentation/Exercise/Components/CompoundWorkoutSetupView.swift
  - DUNE/Presentation/Shared/Charts/DotLineChartView.swift
related_solutions:
  - docs/solutions/general/2026-03-01-localization-leak-pattern-fixes.md
---

# Solution: ternary 조건식 내 Text()의 LocalizedStringKey 누출

## Problem

### 증상

`Text(condition ? "A" : "B")` 패턴이 xcstrings에 번역이 등록되어 있음에도 런타임에 영어로 표시됨.

### Root Cause

Swift의 타입 추론에서 ternary 조건식 `condition ? "A" : "B"`는 `String`으로 추론됨.
이에 따라 `Text.init(_ content: some StringProtocol)` init이 호출되어 `LocalizedStringKey` 변환이 우회됨.

```swift
// BAD: String init 사용 → 번역 미적용
Text(captureType == .front
    ? "Capture front view for analysis"
    : "Capture side view for analysis")

// GOOD: 각 Text가 독립적으로 LocalizedStringKey init 사용
Group {
    if captureType == .front {
        Text("Capture front view for analysis")
    } else {
        Text("Capture side view for analysis")
    }
}
.font(.caption2)
.foregroundStyle(.tertiary)
```

### 영향 범위

오늘 감사에서 2건 발견:
1. `PostureResultView.swift:145-147` — 자세 캡처 안내 문구
2. `CompoundWorkoutSetupView.swift:64-66` — 복합 운동 모드 설명

## Solution

ternary를 `if-else` 분기로 대체. 공유 modifier가 있으면 `Group { }` 으로 래핑.

### 추가 수정

`DotLineChartView.yDomain` computed property가 body 렌더마다 2×O(N) min/max를 수행하는 문제를
`@State` + `.onAppear` + `.onChange(of: data.count)` 캐싱으로 해결.

## Prevention

- `Text()` 안에서 ternary 사용 금지 → `if-else` 분기 사용
- 코드 리뷰 시 `Text(.*\?.*:` regex로 ternary 패턴 검출
- 이 패턴은 `localization.md` Leak Pattern에 추가 고려

## Lessons Learned

1. xcstrings에 번역이 있어도 코드에서 `String` init이 호출되면 번역이 적용되지 않음
2. ternary는 ViewBuilder 컨텍스트에서도 `String`으로 추론됨 — `if-else`만 `@ViewBuilder`가 각 분기를 독립 처리
3. 공유 modifier는 `Group { }` 래핑으로 중복 없이 적용 가능
