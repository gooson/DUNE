---
tags: [swiftui, combine, notificationcenter, threading, visionos]
category: architecture
date: 2026-03-14
severity: important
related_files:
  - DUNE/Data/Services/NotificationCenter+MainThread.swift
  - DUNE/App/ContentView.swift
  - DUNE/App/DUNEApp.swift
  - DUNE/Presentation/Dashboard/DashboardView.swift
  - DUNE/Presentation/Dashboard/NotificationHubView.swift
  - DUNE/Presentation/Shared/Components/OceanWaveBackground.swift
  - DUNEVision/App/VisionContentView.swift
  - DUNEVision/Presentation/Activity/VisionMuscleMapExperienceView.swift
  - DUNEVision/Presentation/Chart3D/Chart3DContainerView.swift
  - DUNEVision/Presentation/Dashboard/VisionDashboardWindowScene.swift
  - DUNEVision/Presentation/Immersive/VisionImmersiveExperienceView.swift
  - DUNEVision/Presentation/Volumetric/VisionVolumetricExperienceView.swift
  - DUNETests/NotificationCenterMainThreadPublisherTests.swift
related_solutions:
  - docs/solutions/architecture/2026-03-12-notification-ingress-mainactor-hardening.md
  - docs/solutions/architecture/2026-03-12-cloudkit-remote-change-mainactor-ingress.md
---

# Solution: Notification Main-Thread Publisher Hardening

## Problem

`Publishing changes from background threads is not allowed` 경고가 notification-driven UI 갱신 뒤 계속 남았다.

### Symptoms

- `NotificationCenter` 기반 `.onReceive` 이후 `@State`나 `@MainActor` model 갱신에서 background publish warning이 재발했다.
- 일부 경로는 `Task { @MainActor in ... }`를 추가했지만 경고가 완전히 사라지지 않았다.
- visionOS target은 공통 3D scene API 변경을 따라가지 못해 build가 끊겼다.

### Root Cause

문제의 핵심은 state mutation 위치가 아니라 `NotificationCenter.Publisher`의 delivery thread였다.
`.onReceive` 내부에서 main actor hop만 추가해도 publisher output 자체는 여전히 background queue에서 들어올 수 있다.
또한 verification을 막는 별도 compile blocker들이 남아 있어 수정 후 전체 파이프라인이 끝까지 닫히지 않았다.

## Solution

notification ingress contract를 publisher 단계에서 main run loop로 고정하는 공용 helper를 추가하고,
남아 있던 SwiftUI `.onReceive` 진입점들을 전부 그 helper로 통일했다.
동시에 verification을 막던 테스트 계약과 visionOS target/source mismatch도 함께 정리했다.

### Changes Made

| File | Change | Reason |
|------|--------|--------|
| `DUNE/Data/Services/NotificationCenter+MainThread.swift` | `mainThreadPublisher(for:)` helper 추가 | publisher delivery thread를 main run loop로 고정 |
| `DUNE/App/ContentView.swift` 외 notification ingress view files | `.publisher(for:)`를 `mainThreadPublisher(for:)`로 교체 | SwiftUI state mutation 진입점을 background delivery에서 분리 |
| `DUNE/Domain/UseCases/CalculateTrainingReadinessUseCase.swift` | `Input` explicit initializer 추가 | tests가 요구하는 `evaluationDate` 주입 계약 복원 |
| `DUNE/Domain/UseCases/CalculateWellnessScoreUseCase.swift` | `Input` explicit initializer 추가 | tests가 요구하는 `evaluationDate` 주입 계약 복원 |
| `DUNE/project.yml` | DUNEVision source set 조정 | iOS-only AI generator 의존성 제거 및 누락된 shared files 포함 |
| `DUNEVision/Presentation/Activity/VisionMuscleMapExperienceView.swift` | `anatomyLayer: .skin` 전달 | 공통 scene API와 vision view call site를 정합 |
| `DUNETests/NotificationCenterMainThreadPublisherTests.swift` | background post -> main-thread delivery 회귀 테스트 추가 | helper contract를 테스트로 고정 |

### Key Code

```swift
extension NotificationCenter {
    func mainThreadPublisher(
        for name: Notification.Name,
        object: AnyObject? = nil
    ) -> AnyPublisher<Notification, Never> {
        publisher(for: name, object: object)
            .receive(on: RunLoop.main)
            .eraseToAnyPublisher()
    }
}
```

```swift
.onReceive(NotificationCenter.default.mainThreadPublisher(for: .simulatorAdvancedMockDataDidChange)) { _ in
    refreshToken += 1
}
```

## Prevention

### Checklist Addition

- [ ] `NotificationCenter.default.publisher(...).onReceive`가 UI state나 `@MainActor` model을 건드리면 먼저 `receive(on: RunLoop.main)` 또는 공용 helper 적용 여부를 본다.
- [ ] `.onReceive` 내부 `Task { @MainActor in ... }`가 있더라도 publisher delivery thread가 여전히 background일 수 있음을 전제로 리뷰한다.
- [ ] fix verification을 막는 compile/test blocker가 남아 있으면 원인 범위를 분리해 같은 run 안에서 함께 정리한다.
- [ ] multi-target shared scene API를 바꿨다면 iOS와 visionOS call site를 함께 검색해 build break를 바로 잡는다.

### Rule Addition (if applicable)

새 rule 파일까지는 필요 없고, notification ingress review checklist에 publisher-level main-thread 고정을 명시적으로 포함하면 충분하다.

## Lessons Learned

- SwiftUI background publish warning은 state mutation line만 보정해서는 안 되고 publisher ingress contract까지 닫아야 한다.
- 작은 threading fix라도 verification blocker를 같이 치우지 않으면 실제로는 "해결 완료" 상태가 되지 않는다.
- shared RealityKit scene API는 multi-target call site를 같이 검색하지 않으면 visionOS build가 뒤늦게 깨질 수 있다.
