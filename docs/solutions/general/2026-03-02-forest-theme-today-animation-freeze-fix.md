---
tags: [swiftui, tabview, theme, forest, animation, onappear, repeatforever]
category: general
date: 2026-03-02
severity: important
related_files:
  - DUNE/Presentation/Shared/Components/ForestWaveBackground.swift
related_solutions:
  - docs/solutions/design/theme-wave-visual-upgrade.md
  - docs/solutions/design/2026-03-01-forest-green-theme.md
---

# Solution: Forest Theme 선택 후 Today 탭 복귀 시 배경 애니메이션 정지

## Problem

Forest Green 테마를 Settings에서 선택한 뒤 Today 탭으로 복귀하면 `ForestTabWaveBackground` 애니메이션이 멈춘 것처럼 보였다.

### Symptoms

- Settings에서 Forest 테마 적용 직후 Today 탭 복귀 시 숲 실루엣 드리프트가 정지
- 동일 구조의 Desert/Ocean 배경에서는 재현되지 않음

### Root Cause

`ForestWaveOverlayView`는 `.task`에서만 `phase` 애니메이션을 시작하고, 탭 재진입 시 재시작을 담당하는 `.onAppear` 블록이 없었다. 그 결과 탭 전환/복귀 lifecycle에서 애니메이션이 살아나지 않는 경로가 발생했다.

## Solution

`ForestWaveOverlayView`에 `.onAppear` 재시작 로직을 추가해 뷰가 다시 나타날 때 `phase`를 0으로 리셋 후 `repeatForever` 애니메이션을 재시작하도록 수정했다.

### Changes Made

| File | Change | Reason |
|------|--------|--------|
| `DUNE/Presentation/Shared/Components/ForestWaveBackground.swift` | `.onAppear` 추가 (`phase = 0` 후 선형 반복 애니메이션 재시작) | 탭/화면 재진입 시 정지된 모션 상태 복구 |

### Key Code

```swift
.onAppear {
    guard !reduceMotion, driftDuration > 0 else { return }
    Task { @MainActor in
        phase = 0
        withAnimation(.linear(duration: phaseDuration).repeatForever(autoreverses: false)) {
            phase = phaseTarget
        }
    }
}
```

## Prevention

### Checklist Addition

- [ ] 테마별 overlay view(`Desert/Ocean/Forest`)의 animation lifecycle(`.task` + `.onAppear`)가 동일한지 리뷰에서 비교 확인
- [ ] 탭 전환/복귀 기반 수동 회귀 시나리오(설정 변경 → Today 복귀)를 QA 항목에 포함

### Rule Addition (if applicable)

신규 rule 파일 추가는 불필요. 기존 wave 관련 리뷰 체크리스트에 lifecycle parity 항목을 포함해 관리 가능.

## Lessons Learned

테마 파생 구현에서 시각 파라미터(색/shape)만 맞추면 충분하지 않다. 라이프사이클 modifier parity(`.task`, `.onAppear`, reduce motion guard)까지 동일하게 맞춰야 탭 기반 UI에서 모션 회귀를 예방할 수 있다.
