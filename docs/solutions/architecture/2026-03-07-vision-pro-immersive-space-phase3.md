---
tags: [visionos, immersive-space, realitykit, healthkit, localization, testing]
category: architecture
date: 2026-03-07
severity: important
related_files:
  - DUNE/Domain/Models/ImmersiveRecoverySummary.swift
  - DUNE/Domain/UseCases/ImmersiveRecoveryAnalyzer.swift
  - DUNE/Data/HealthKit/HealthKitManager.swift
  - DUNE/Presentation/Immersive/VisionImmersiveExperienceViewModel.swift
  - DUNEVision/App/DUNEVisionApp.swift
  - DUNEVision/App/VisionContentView.swift
  - DUNEVision/Presentation/Dashboard/VisionDashboardView.swift
  - DUNEVision/Presentation/Immersive/VisionImmersiveExperienceView.swift
  - DUNEVision/Presentation/Immersive/VisionImmersiveSceneView.swift
  - DUNETests/ImmersiveRecoveryAnalyzerTests.swift
  - DUNETests/ImmersiveRecoverySummaryTests.swift
  - DUNETests/VisionImmersiveExperienceViewModelTests.swift
related_solutions:
  - docs/solutions/architecture/2026-03-07-vision-pro-volumetric-phase2.md
  - docs/solutions/architecture/visionos-multi-target-setup.md
---

# Solution: Vision Pro Phase 3 Immersive Recovery Space

## Problem

`DUNEVision`에는 Shared Space와 volumetric window까지만 연결돼 있었고, 다음 roadmap 단계인 `ImmersiveSpace` 경험은 비어 있었다. 이번 단계는 컨디션 점수, 회복 가이드, 수면 단계 데이터를 Vision Pro에서 몰입형으로 보여주되, shared snapshot 구조와 테스트 가능한 domain 경계를 유지하는 것이 핵심이었다.

### Symptoms

- Vision Pro 대시보드에서 immersive scene으로 진입할 수 있는 경로가 없었다.
- condition/sleep 데이터를 immersive-friendly summary로 변환하는 shared analyzer가 없어 UI 계층에 계산 로직이 섞일 위험이 있었다.
- mindful recovery session 완료 후 HealthKit `mindfulSession` 저장 경로가 없어 Phase 3 요구사항을 충족하지 못했다.
- 초기 scene 구현은 `Sleep Journey` column을 8개로 고정해, 일반적인 수면 stage 전환 수에서 뒤 timeline이 잘릴 수 있었다.

### Root Cause

`SharedHealthSnapshot`을 visionOS immersive UI에 직접 연결할 중간 summary/use case 계층이 없었고, HealthKit 권한/저장 경로도 workout 중심으로만 열려 있었다. 또한 view model이 visionOS target 안쪽에 머물면 단위 테스트가 어려워지고, RealityKit scene이 고정 개수 geometry에 의존하면 실제 데이터 길이를 제대로 반영하지 못한다.

## Solution

shared domain에 `ImmersiveRecoverySummary`와 `ImmersiveRecoveryAnalyzer`를 추가해 snapshot을 atmosphere, guided recovery session, sleep journey 3개 experience로 정규화했다. `HealthKitManager`에는 `mindfulSession` share 권한과 저장 helper를 추가했고, immersive view model은 shared `DUNE` source로 옮겨 unit test 가능하게 만들었다. Vision Pro target에는 `ImmersiveSpace` 진입점, dashboard action, SwiftUI control panel, RealityKit scene을 연결했다. 리뷰 중 드러난 sleep timeline truncation은 고정 8-column 구조를 버리고 segment 수에 맞춰 entity를 동적으로 맞추는 방식으로 수정했다.

### Changes Made

| File | Change | Reason |
|------|--------|--------|
| `DUNE/Domain/Models/ImmersiveRecoverySummary.swift` | Added immersive summary model and shared enums | UI와 분리된 domain 결과 형식을 만들기 위해 |
| `DUNE/Domain/UseCases/ImmersiveRecoveryAnalyzer.swift` | Added snapshot -> immersive summary analyzer | condition/sleep fallback을 shared layer에서 계산하기 위해 |
| `DUNE/Data/HealthKit/HealthKitManager.swift` | Added `HealthKitManaging`, mindful-session authorization/save path | immersive recovery completion을 HealthKit에 기록하기 위해 |
| `DUNE/Presentation/Immersive/VisionImmersiveExperienceViewModel.swift` | Moved view model into shared source | visionOS orchestration을 테스트 가능한 shared layer로 두기 위해 |
| `DUNE/project.yml` | Added shared immersive view model to `DUNEVision` target | shared source를 visionOS target에 포함하기 위해 |
| `DUNEVision/App/DUNEVisionApp.swift` | Added `ImmersiveSpace` scene | immersive experience entry point를 등록하기 위해 |
| `DUNEVision/App/VisionContentView.swift` | Wired `openImmersiveSpace` action | Today surface에서 immersive space를 열기 위해 |
| `DUNEVision/Presentation/Dashboard/VisionDashboardView.swift` | Added immersive toolbar/quick action | dashboard에서 접근성을 높이기 위해 |
| `DUNEVision/Presentation/Immersive/VisionImmersiveExperienceView.swift` | Added immersive control surface and state rendering | 3개 experience 전환과 fallback/status copy를 제공하기 위해 |
| `DUNEVision/Presentation/Immersive/VisionImmersiveSceneView.swift` | Added RealityKit scene and dynamic sleep columns | 분위기/회복/수면 timeline을 primitive scene으로 표현하고 data truncation을 막기 위해 |
| `DUNE/Resources/Localizable.xcstrings` | Added en/ko/ja immersive copy | 새 Vision Pro 문자열의 localization leak를 막기 위해 |
| `DUNETests/ImmersiveRecoveryAnalyzerTests.swift` | Added analyzer coverage | threshold, fallback, stage compression을 고정하기 위해 |
| `DUNETests/ImmersiveRecoverySummaryTests.swift` | Added summary model coverage | derived property regression을 막기 위해 |
| `DUNETests/VisionImmersiveExperienceViewModelTests.swift` | Added orchestration/save-path coverage | authorization, mindful save success/failure, one-shot load를 검증하기 위해 |

### Key Code

```swift
private func ensureSleepColumns(count: Int) {
    guard sleepColumns.count != count else { return }

    if sleepColumns.count < count {
        let newColumns = (sleepColumns.count..<count).map(makeSleepColumn(index:))
        for column in newColumns {
            sleepRoot.addChild(column)
        }
        sleepColumns.append(contentsOf: newColumns)
        return
    }

    for column in sleepColumns[count...] {
        column.removeFromParent()
    }
    sleepColumns.removeSubrange(count...)
}
```

## Prevention

Vision Pro feature를 추가할 때는 platform-specific view와 shared analyzer/view-model 경계를 먼저 정하고, HealthKit write path는 권한 세트와 저장 helper를 함께 설계한다. RealityKit scene geometry는 실제 data cardinality를 가정하지 말고, timeline/segment 기반 뷰는 동적 entity reconciliation을 기본 패턴으로 삼는 편이 안전하다.

### Checklist Addition

- [ ] 새 immersive/spatial scene이 실제 data cardinality를 임의 상수로 자르지 않는지 확인
- [ ] visionOS 전용 orchestration이 unit-test 가능한 shared source 또는 protocol boundary를 갖는지 확인
- [ ] 새 Vision Pro copy가 `Localizable.xcstrings`에 en/ko/ja로 모두 등록됐는지 확인
- [ ] locale-sensitive 테스트가 영어 문구 하드코딩에 의존하지 않는지 확인

### Rule Addition (if applicable)

새 규칙 파일 추가는 불필요했다. 기존 localization, testing-required, swift-layer-boundaries 규칙으로 충분히 커버됐다.

## Lessons Learned

`ImmersiveSpace` 기능도 volumetric phase와 마찬가지로 shared analyzer + lightweight RealityKit primitives 조합이 가장 안정적이었다. 또 visionOS UI를 shared view model로 끌어올리면 테스트가 쉬워질 뿐 아니라, 리뷰 단계에서 발견된 data-shape 문제도 더 빨리 고칠 수 있었다.
