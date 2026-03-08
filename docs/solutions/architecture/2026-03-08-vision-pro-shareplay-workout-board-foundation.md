---
tags: [visionos, shareplay, groupactivities, group-session-messenger, workout-board]
category: architecture
date: 2026-03-08
severity: important
related_files:
  - DUNE/Presentation/Vision/VisionSharePlayWorkoutViewModel.swift
  - DUNEVision/Presentation/Activity/VisionSharePlayWorkoutCard.swift
  - DUNEVision/Presentation/Activity/VisionTrainView.swift
  - DUNETests/VisionSharePlayWorkoutViewModelTests.swift
  - DUNE/project.yml
  - DUNEVision/Resources/DUNEVision.entitlements
  - Shared/Resources/Localizable.xcstrings
  - todos/020-in-progress-p3-vision-pro-phase4-social-advanced.md
  - todos/023-in-progress-p2-vision-phase4-remaining.md
related_solutions:
  - docs/solutions/architecture/2026-03-07-vision-pro-multi-window-dashboard.md
  - docs/solutions/architecture/2026-03-08-vision-pro-voice-workout-entry-foundation.md
---

# Solution: Vision Pro SharePlay Workout Board Foundation

## Problem

`todos/020-in-progress-p3-vision-pro-phase4-social-advanced.md`의 `G1 Shared Workout Space`는 남아 있었지만, 실제 visionOS `Train` 탭에는 여러 사용자가 같이 들어와 운동 진행 상태를 맞춰 볼 수 있는 social surface가 없었다. 동시에 brainstorm 원문 scope인 `SharedWorldAnchors` + full spatial alignment까지 한 번에 구현하려면 capability, signing, 실기기 검증 범위가 너무 커서 ship 가능한 단위를 만들기 어려웠다.

### Symptoms

- Vision Pro에서 SharePlay를 시작해도 운동 진행 상태를 공유할 UI가 없었다.
- 각 참여자의 현재 exercise / set / rep를 lightweight하게 동기화하는 state layer가 없었다.
- 늦게 들어온 참여자에게 현재 board 상태를 다시 보내는 replay 동작이 준비되지 않았다.

### Root Cause

`G1`을 full spatial experience로만 보고 있었기 때문에, 지금 당장 ship 가능한 `window-based SharePlay foundation`과 후속 `SharedWorldAnchors` 확장 단계를 분리하지 못했다. 결과적으로 GroupActivities 기반 최소 social workflow도 비어 있었다.

## Solution

이번 배치에서는 `G1`을 **SharePlay workout board foundation**으로 재정의했다. shared `VisionSharePlayWorkoutViewModel`이 GroupActivity session lifecycle, participant state merge, late-join replay를 담당하고, visionOS `Train` 탭에는 `VisionSharePlayWorkoutCard`를 추가해 current exercise / set / rep / phase를 실시간으로 공유하도록 연결했다.

### Changes Made

| File | Change | Reason |
|------|--------|--------|
| `DUNE/Presentation/Vision/VisionSharePlayWorkoutViewModel.swift` | Added GroupActivities-backed shared workout board state layer | session lifecycle과 participant sync를 testable shared layer에 두기 위해 |
| `DUNEVision/Presentation/Activity/VisionSharePlayWorkoutCard.swift` | Added SharePlay workout board card UI | Train 탭에서 social foundation을 실제로 노출하기 위해 |
| `DUNEVision/Presentation/Activity/VisionTrainView.swift` | Inserted SharePlay card before voice/form guide surfaces | social flow를 Train entry에 자연스럽게 배치하기 위해 |
| `DUNETests/VisionSharePlayWorkoutViewModelTests.swift` | Added replay / merge / invalidation coverage | SharePlay state regression을 unit test로 고정하기 위해 |
| `DUNE/project.yml` | Added `GroupActivities.framework` and group-session entitlement wiring | shared source compile + visionOS capability wiring을 맞추기 위해 |
| `DUNEVision/Resources/DUNEVision.entitlements` | Added `com.apple.developer.group-session` | SharePlay capability를 target entitlement와 일치시키기 위해 |
| `Shared/Resources/Localizable.xcstrings` | Added SharePlay copy for en/ko/ja | localization leak 없이 새 social UI를 ship하기 위해 |
| `todos/020-in-progress-p3-vision-pro-phase4-social-advanced.md` | Recorded G1 foundation completion | umbrella TODO 상태를 실제 ship 범위와 맞추기 위해 |
| `todos/023-in-progress-p2-vision-phase4-remaining.md` | Narrowed remaining scope to advanced spatial sync | 후속 phase가 foundation 재구현 없이 anchor/audio/persistence만 다루게 하기 위해 |

### Key Code

```swift
case .sessionJoined(let localParticipantID, let activeParticipantIDs):
    self.localParticipantID = localParticipantID
    self.sessionState = .sharing
    self.activeRemoteParticipantIDs = activeParticipantIDs
        .filter { $0 != localParticipantID }
        .sorted()
    await syncLocalStateIfNeeded()
```

```swift
participantsTask = Task { [weak self] in
    for await participants in session.$activeParticipants.values {
        self?.continuation.yield(
            .participantsChanged(
                localParticipantID: localParticipantID,
                activeParticipantIDs: participants.map(Self.participantID(for:))
            )
        )
    }
}
```

## Prevention

SharePlay처럼 capability-heavy한 feature는 `session + state sync + lightweight UI` foundation과 `anchor/alignment + richer 3D placement` 확장 단계를 처음부터 나눠야 한다. 또 async observer task는 `weak self`를 유지해 view model / controller lifetime leak가 생기지 않도록 설계하는 편이 안전하다.

### Checklist Addition

- [ ] GroupActivities feature는 first ship 범위를 `GroupSessionMessenger` 기반 sync까지로 자를 수 있는지 먼저 확인한다.
- [ ] long-lived observer task는 `guard let self`로 강한 참조를 잡아 순환 참조를 만들지 않는지 확인한다.
- [ ] SharePlay capability 추가 시 signing entitlement와 local verification command(`CODE_SIGNING_ALLOWED=NO`)를 같이 점검한다.

### Rule Addition (if applicable)

새 rule 파일 추가는 필요 없었다. 기존 `swift-layer-boundaries.md`, `localization.md`, `testing-required.md` 안에서 정리 가능했다.

## Lessons Learned

Vision Pro social feature도 full spatial sync가 준비될 때까지 기다릴 필요는 없다. system SharePlay window placement와 `GroupSessionMessenger`만으로도 실제 가치가 있는 workout board foundation을 먼저 ship할 수 있고, 그 위에 `SharedWorldAnchors`와 advanced placement를 후속 phase로 더하는 편이 훨씬 안전하다.
