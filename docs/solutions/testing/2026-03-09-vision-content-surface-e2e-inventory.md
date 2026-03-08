---
tags: [visionos, e2e, accessibility, ui-test, placeholder]
category: testing
date: 2026-03-09
severity: important
related_files:
  - DUNE/Presentation/Vision/VisionSurfaceAccessibility.swift
  - DUNETests/VisionSurfaceAccessibilityTests.swift
  - DUNEVision/App/VisionContentView.swift
  - DUNEVision/Presentation/Wellness/VisionWellnessView.swift
  - DUNEVision/Presentation/Life/VisionLifeView.swift
  - todos/084-done-p3-e2e-dunevision-content-view.md
  - todos/091-done-p3-e2e-dunevision-placeholder-surfaces.md
related_solutions:
  - docs/solutions/testing/2026-03-08-e2e-phase0-page-backlog-split.md
---

# Solution: visionOS Content Surface E2E Inventory

## Problem

`DUNEVision`의 root/placeholder surface TODO는 backlog에만 존재했고, 실제 코드에는 stable selector inventory가 충분히 고정돼 있지 않았다. 이 상태에서는 Vision Pro deferred lane을 나중에 자동화하려고 해도 root lane, placeholder lane, empty-state assertion 기준이 흔들릴 수 있었다.

### Symptoms

- `VisionContentView`의 Today/Activity/Wellness/Life lane을 코드 기반 selector로 구분하기 어려웠다.
- Wellness/Life placeholder surface의 최소 회귀 기준이 TODO 문서에만 있고 View에 고정된 assertion anchor가 없었다.
- TODO를 `done`으로 닫더라도 코드/테스트/문서가 같은 inventory를 바라보지 못했다.

### Root Cause

surface inventory가 planning artifact로만 남아 있었고, 실제 selector naming policy를 표현하는 shared helper가 없었다. 그 결과 TODO 문서와 View 구현 사이에 drift가 생겨도 unit test로 감지할 방법이 없었다.

## Solution

visionOS surface selector를 `VisionSurfaceAccessibility` helper로 분리하고, `VisionContentView`와 placeholder surface에 accessibility identifier를 연결했다. 동시에 `VisionSurfaceAccessibilityTests`로 identifier mapping/uniqueness를 고정하고, 관련 TODO 문서를 `done` 상태로 갱신했다.

### Changes Made

| File | Change | Reason |
|------|--------|--------|
| `DUNE/Presentation/Vision/VisionSurfaceAccessibility.swift` | Added shared selector helper | root/placeholder inventory drift를 줄이기 위해 |
| `DUNEVision/App/VisionContentView.swift` | Added root + section screen identifiers | tab lane assertion을 코드로 고정하기 위해 |
| `DUNEVision/Presentation/Wellness/VisionWellnessView.swift` | Added section/empty-state identifiers | placeholder regression anchor를 만들기 위해 |
| `DUNEVision/Presentation/Life/VisionLifeView.swift` | Added placeholder identifier | Life placeholder 회귀 기준을 고정하기 위해 |
| `DUNETests/VisionSurfaceAccessibilityTests.swift` | Added selector stability tests | helper가 바뀌어도 즉시 감지하기 위해 |
| `todos/084-done-p3-e2e-dunevision-content-view.md` | Filled entry/state/deferred inventory | root surface TODO를 실제로 닫기 위해 |
| `todos/091-done-p3-e2e-dunevision-placeholder-surfaces.md` | Filled placeholder inventory | placeholder surface TODO를 실제로 닫기 위해 |

### Key Code

```swift
enum VisionSurfaceAccessibility {
    static let contentRoot = "vision-content-root"

    static func sectionScreenID(for section: AppSection) -> String {
        "vision-content-screen-\(section.rawValue)"
    }
}
```

```swift
TabView(selection: $selectedSection) {
    ...
}
.accessibilityIdentifier(VisionSurfaceAccessibility.contentRoot)
```

## Prevention

Vision Pro deferred surface를 계속 닫아갈 때는 TODO 문서만 채우지 말고, selector policy를 code + test + TODO 세 군데에 동시에 반영해야 한다.

### Checklist Addition

- [ ] visionOS surface TODO를 닫을 때 root lane과 assertion anchor를 shared helper로 먼저 고정할 것
- [ ] tab/window selector가 label 기반이면 assertion anchor는 별도 AXID로 분리할 것
- [ ] placeholder/empty-state surface는 copy assert 이전에 stable container AXID를 만들 것
- [ ] TODO를 `done`으로 바꿀 때 관련 selector mapping test를 함께 추가할 것

### Rule Addition (if applicable)

새 rule 파일 추가는 하지 않았다. 다만 후속 visionOS deferred surface도 같은 `helper + view wiring + selector test + TODO update` 패턴을 기본값으로 삼는 편이 안전하다.

## Lessons Learned

Deferred target이라고 해서 문서만 쌓아두면 나중에 자동화 진입 비용이 다시 커진다. 오히려 Phase 0 TODO를 닫는 시점에 최소 selector inventory를 코드와 테스트로 고정해 두면, 나중에 harness가 생겼을 때 바로 UI test lane으로 승격할 수 있다.
