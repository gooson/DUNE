---
tags: [swiftui, whats-new, sheet, launch, state, ui-test]
category: general
date: 2026-03-12
severity: important
related_files:
  - DUNE/App/DUNEApp.swift
  - DUNEUITests/Smoke/LaunchExperienceSmokeTests.swift
  - DUNEUITests/Manual/HealthKitPermissionUITests.swift
related_solutions:
  - docs/solutions/general/2026-03-08-whatsnew-sheet-list-blank-simulator.md
  - docs/solutions/architecture/2026-03-07-launch-permission-whatsnew-sequencing.md
---

# Solution: Stabilize Automatic What's New Sheet Payload

## Problem

launch 시점에 자동으로 뜨는 `What's New` sheet가 navigation title과 `Done` 버튼만 보이고 본문 feature row는 비어 보일 수 있었다.

### Symptoms

- 앱 첫 실행 또는 업데이트 직후 automatic `What's New` sheet가 빈 흰 화면처럼 보임
- manual 진입 경로(Settings, Today toolbar)의 `What's New`는 정상인데 launch automatic 경로만 불안정함
- 기존 manual permission UI test는 automatic sheet가 떴는지만 확인하고 본문 row 존재는 검증하지 못함

### Root Cause

`DUNEApp`가 automatic `What's New`를 `showWhatsNewSheet`, `automaticWhatsNewReleases`, `automaticWhatsNewBuild`의 분리된 state로 관리하고 있었다.

이 구조에서는 sheet visibility와 payload가 다른 source of truth를 가지므로, launch 시점처럼 상태 전이가 빠른 경로에서 본문 payload가 안정적으로 전달되지 않는 blank-state race를 만들기 쉽다.

또한 automatic 경로는 CI에서 재현되는 smoke coverage가 없어 regressions가 다시 들어와도 놓치기 쉬웠다.

## Solution

automatic `What's New` presentation을 single item state로 통합하고, UI test 전용 launch hook + smoke test로 automatic 경로를 직접 검증하도록 바꿨다.

### Changes Made

| File | Change | Reason |
|------|--------|--------|
| `DUNE/App/DUNEApp.swift` | `sheet(isPresented:)`를 `sheet(item:)`로 변경하고 automatic payload를 `AutomaticWhatsNewPresentation`으로 통합 | visibility/payload race 제거 |
| `DUNE/App/DUNEApp.swift` | `--force-automatic-whatsnew` UI test hook 추가 | automatic sheet를 deterministic하게 재현 |
| `DUNEUITests/Smoke/LaunchExperienceSmokeTests.swift` | automatic `What's New` smoke test 추가 | CI에서 blank sheet regression 고정 |
| `DUNEUITests/Manual/HealthKitPermissionUITests.swift` | automatic sheet row 존재 확인 추가 | manual permission flow에서도 blank surface 감지 |

### Key Code

```swift
.sheet(item: $automaticWhatsNewPresentation, onDismiss: handleAutomaticWhatsNewDismissed) { presentation in
    NavigationStack {
        WhatsNewView(
            releases: presentation.releases,
            mode: .automatic
        )
    }
}

automaticWhatsNewPresentation = AutomaticWhatsNewPresentation(
    id: build,
    build: build,
    releases: releases
)
```

```swift
override var additionalLaunchArguments: [String] { ["--force-automatic-whatsnew"] }

func testAutomaticWhatsNewRendersFeatureRows() throws {
    let screen = app.descendants(matching: .any)[AXID.whatsNewScreen].firstMatch
    XCTAssertTrue(screen.waitForExistence(timeout: 5))
    XCTAssertTrue(app.descendants(matching: .any)[AXID.whatsNewRow("healthDataQA")].firstMatch.waitForExistence(timeout: 1))
}
```

## Prevention

### Checklist Addition

- [ ] launch automatic sheet/surface는 visibility boolean과 payload model을 분리하지 않았는가?
- [ ] automatic 진입 경로는 manual path와 별도로 smoke UI test가 있는가?
- [ ] UI test용 강제 진입 hook은 launch argument로만 제한되어 production flow와 분리되는가?

### Rule Addition (if applicable)

없음. 현재는 solution 문서와 smoke test로 충분하다.

## Lessons Learned

- launch 시점 surface는 “데이터가 있으면 보여준다”보다 “보여줄 데이터 자체를 sheet item으로 만든다”가 더 안전하다.
- manual 경로 테스트가 있어도 automatic 경로 regression을 막아주지는 않는다. 진입 트리거가 다르면 별도 smoke coverage가 필요하다.
- blank screen 유형 버그는 UI layout보다 state handoff 불일치에서 먼저 찾는 편이 빠르다.
