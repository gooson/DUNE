---
tags: [watchos, cardio, machine-level, stair-climber, digital-crown, ui, preview]
category: design
date: 2026-03-15
severity: minor
related_files:
  - DUNEWatch/Views/WorkoutPreviewView.swift
  - DUNEWatch/Managers/WorkoutManager.swift
  - DUNEWatch/Views/Cardio/CardioSecondaryPage.swift
related_solutions:
  - docs/solutions/architecture/2026-03-07-non-distance-cardio-machine-level-model.md
---

# Solution: Watch 카디오 프리뷰에서 머신 레벨 선택 UI

## Problem

Watch에서 스텝 클라이머(천국의계단), 엘립티컬 등 머신 레벨을 지원하는 카디오 운동을 선택하면 시작 전에 레벨을 설정할 수 없었다. 사용자가 운동을 시작한 후 4번째 탭(CardioSecondaryPage)까지 스와이프해야 레벨을 조절할 수 있었고, 초기 레벨은 nil로 시작되어 레벨 기반 MET 보정이 세션 초반에 적용되지 않았다.

### Symptoms

- 스텝 클라이머 프리뷰 화면에 Indoor 버튼만 표시
- 세션 시작 시 `currentMachineLevel = nil`
- 사용자가 세션 시작 직후 4번째 탭으로 이동해야 레벨 설정 가능

## Solution

### Changes Made

| File | Change |
|------|--------|
| `WorkoutPreviewView.swift` | `machineLevelPicker` +/- 버튼 + Digital Crown 회전 추가 |
| `WorkoutManager.swift` | `startCardioSession`에 `initialLevel: Int?` 파라미터 추가 |

### Key Design Decisions

1. **Digital Crown 우선**: watchOS HIG에 따라 수치 조정은 Digital Crown이 1차 입력. `.digitalCrownRotation(detent:from:through:by:)` 사용
2. **+/- 버튼 병행**: Crown 외에도 시각적 피드백을 위한 명시적 버튼 제공
3. **secondaryMetric 폰트**: `primaryMetric`(42pt)은 Watch 화면에서 HStack을 overflow. `secondaryMetric` 사용
4. **기본값 5**: 1-20 범위에서 5는 합리적 시작점. `setMachineLevel`이 clamping하므로 범위 변경에도 안전

## Prevention

- Watch 프리뷰 화면에 수치 입력을 추가할 때는 항상 Digital Crown 지원을 포함할 것
- Watch UI에서 `primaryMetric` 폰트는 단독 표시 영역에서만 사용. HStack 내 다른 요소와 함께 쓸 때는 `secondaryMetric` 이하

## Lessons Learned

- 세션 중 조절 가능하다고 해서 시작 전 설정이 불필요한 것은 아니다. Watch는 탭 전환이 iOS보다 번거로우므로 시작 시점에서 핵심 설정을 완료하는 것이 중요하다.
- watchOS에서 수치 입력 UI는 Digital Crown을 먼저 고려해야 한다 — 작은 화면에서 반복 탭은 좋지 않은 UX.
