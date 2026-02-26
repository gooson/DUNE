---
tags: [swiftui, charts, accessibility, contrast, design-token, animation, task-cancellation]
category: general
date: 2026-02-26
status: implemented
severity: important
related_files:
  - DUNE/Presentation/Shared/Detail/MetricDetailView.swift
  - DUNE/Resources/Assets.xcassets/Colors/SandMuted.colorset/Contents.json
  - DUNEWatch/Resources/Assets.xcassets/Colors/SandMuted.colorset/Contents.json
related_solutions: []
---

# Solution: Chart 축 가독성 회귀 및 Period 전환 Shimmer 안정화

## Problem

Desert aesthetic 확장 이후 리뷰에서 두 가지 UX 품질 이슈가 확인되었다.

### Symptoms

- 차트 축 라벨에 `SandMuted`를 광범위 적용하면서 라이트 모드 가독성이 저하됨
- Metric Detail의 period 변경 시 shimmer 오버레이가 간헐적으로 보이지 않음

### Root Cause

- 라이트 모드 `SandMuted` 색상이 너무 밝아 소형 정보 텍스트 대비가 부족했음
- `showShimmer = true` 직후 동일 변경 사이클에서 `false`로 되돌려 SwiftUI가 상태 변경을 합쳐버릴 수 있었음

## Solution

라이트 모드 색상 토큰을 조정하고, shimmer 상태 전환을 cancellation-safe 비동기 플로우로 분리했다.

### Changes Made

| File | Change | Reason |
|------|--------|--------|
| `DUNE/Presentation/Shared/Detail/MetricDetailView.swift` | `shimmerTask` 추가, period 변경 시 기존 task 취소 후 120ms 유지 뒤 fade-out, `onDisappear` 정리 | 즉시 true→false coalescing 방지 및 전환 피드백 안정화 |
| `DUNE/Resources/Assets.xcassets/Colors/SandMuted.colorset/Contents.json` | 라이트 모드 RGB를 `0.651/0.580/0.502` → `0.500/0.430/0.360`으로 조정 | 축 라벨 대비 개선 (화이트 배경 기준 약 4.91:1) |
| `DUNEWatch/Resources/Assets.xcassets/Colors/SandMuted.colorset/Contents.json` | iOS와 동일한 라이트 모드 값으로 동기화 | 플랫폼 간 디자인 토큰 일관성 유지 |

### Key Code

```swift
@State private var shimmerTask: Task<Void, Never>?

.onChange(of: viewModel.selectedPeriod) {
    shimmerTask?.cancel()
    guard !reduceMotion else {
        showShimmer = false
        shimmerTask = nil
        return
    }

    showShimmer = true
    shimmerTask = Task {
        try? await Task.sleep(for: .milliseconds(120))
        guard !Task.isCancelled else { return }
        await MainActor.run {
            withAnimation(DS.Animation.shimmer) {
                showShimmer = false
            }
        }
    }
}
.onDisappear {
    shimmerTask?.cancel()
    shimmerTask = nil
}
```

```json
{
  "components": { "red": "0.500", "green": "0.430", "blue": "0.360", "alpha": "1.000" }
}
```

## Prevention

### Checklist Addition

- [ ] 정보 전달용 텍스트 토큰 변경 시 라이트/다크 각각 대비를 확인한다 (소형 텍스트 기준 4.5:1 목표)
- [ ] SwiftUI 시각 피드백은 동일 사이클의 즉시 true→false 토글 대신 최소 표시 시간 또는 phase 기반 전환을 사용한다
- [ ] period/segment 전환 애니메이션에는 `Task.cancel` 경로와 `onDisappear` 정리를 함께 검토한다

### Rule Addition (if applicable)

이번 케이스는 신규 rule 파일 추가 대신, 리뷰 체크리스트 강화로 관리한다.

## Lessons Learned

디자인 토큰은 decorative 텍스트와 data-bearing 텍스트를 분리해 관리해야 접근성 회귀를 줄일 수 있다.  
또한 SwiftUI 상태 기반 애니메이션은 “보여야 하는 시간”을 명시적으로 설계하지 않으면 시각 피드백이 비결정적으로 사라질 수 있다.
