---
tags: [visionos, realitykit, volumetric-window, healthkit, fatigue-analysis]
category: architecture
date: 2026-03-07
severity: important
related_files:
  - DUNE/Domain/UseCases/SpatialTrainingAnalyzer.swift
  - DUNE/Domain/Models/ExerciseRecordSnapshot.swift
  - DUNE/DUNEVision/Presentation/Volumetric/VisionSpatialViewModel.swift
  - DUNE/DUNEVision/Presentation/Volumetric/VisionVolumetricExperienceView.swift
  - DUNE/DUNEVision/App/DUNEVisionApp.swift
  - DUNETests/SpatialTrainingAnalyzerTests.swift
related_solutions:
  - docs/solutions/architecture/visionos-multi-target-setup.md
---

# Solution: Vision Pro Phase 2 Volumetric Experience

## Problem

Vision Pro target에는 Shared Space 대시보드와 3D chart window까지만 있었고, Phase 2 roadmap의 volumetric 회복 경험은 비어 있었다. 동시에 visionOS에서 SwiftData `ExerciseRecord`를 직접 공유하지 않으면서도 최근 운동 데이터 기반의 muscle load/fatigue를 재사용 가능한 방식으로 계산해야 했다.

### Symptoms

- Vision Pro 앱에서 volumetric window를 열어도 표시할 RealityKit 기반 회복 경험이 없었다.
- iOS Domain의 fatigue/weekly volume 로직을 그대로 재사용하기 어려워 visionOS 전용 계산 코드가 생길 위험이 있었다.
- Swift 6 테스트 게이트에서 `URLProtocolStub`와 네트워크 테스트가 concurrency-safe shared state 경고로 막혔다.

### Root Cause

volumetric UI 계층과 shared analyzer 계층이 분리돼 있지 않았고, workout summary를 SwiftData 의존 없는 snapshot으로 변환하는 도메인 모델이 없었다. 테스트 쪽도 `@Sendable` 클로저 안에서 mutable captured state를 직접 수정하고 있었다.

## Solution

HealthKit `WorkoutSummary`를 shared domain analyzer에서 `ExerciseRecordSnapshot`으로 변환하고, Vision Pro에서는 그 결과만 이용해 RealityKit scene을 렌더링하도록 구조를 분리했다. Body Heatmap은 외부 USDZ 자산 의존 대신 procedural body rig로 구현해 target/asset 복잡도를 줄였고, volumetric window를 대시보드 액션으로 연결했다. 동시에 Swift 6 테스트 헬퍼를 `LockedValue` 기반으로 정리해 전체 테스트 게이트가 다시 돌 수 있게 만들었다.

### Changes Made

| File | Change | Reason |
|------|--------|--------|
| `DUNE/Domain/Models/ExerciseRecordSnapshot.swift` | Added snapshot model | SwiftData 없이 shared analyzer 입력을 만들기 위해 |
| `DUNE/Domain/UseCases/SpatialTrainingAnalyzer.swift` | Added analyzer and summary model | HealthKit workout를 muscle load/fatigue/heart-rate summary로 변환하기 위해 |
| `DUNE/DUNEVision/App/DUNEVisionApp.swift` | Added volumetric `WindowGroup` | Vision Pro에서 별도 spatial window를 열기 위해 |
| `DUNE/DUNEVision/Presentation/Volumetric/*` | Added 3 RealityKit scenes and view model | Heart orb, load blocks, body heatmap 경험을 제공하기 위해 |
| `DUNE/Resources/Localizable.xcstrings` | Added en/ko/ja strings | 새 Vision Pro copy의 localization leak를 막기 위해 |
| `DUNETests/Helpers/URLProtocolStub.swift` | Added `LockedValue`, marked shared handler as `nonisolated(unsafe)` | Swift 6 concurrency-safe test helper로 정리하기 위해 |
| `DUNETests/OpenMeteo*.swift` | Replaced captured mutable arrays with `LockedValue` | `@Sendable` handler inside tests를 안전하게 만들기 위해 |
| `DUNETests/SpatialTrainingAnalyzerTests.swift` | Added analyzer tests | pseudo load, fallback muscle mapping, summary ordering을 고정하기 위해 |

### Key Code

```swift
struct SpatialTrainingAnalyzer: SpatialTrainingAnalyzing, Sendable {
    func buildSummary(
        workouts: [WorkoutSummary],
        latestHeartRateBPM: Double?,
        baselineRHR: Double?,
        generatedAt: Date = Date()
    ) -> SpatialTrainingSummary {
        let snapshots = workouts.compactMap(Self.snapshot(from:))
        let fatigueStates = computeFatigueStates(from: snapshots, referenceDate: generatedAt)

        return SpatialTrainingSummary(
            heartRateOrb: .init(currentBPM: latestHeartRateBPM, baselineRHR: baselineRHR),
            muscleLoads: fatigueStates.map { state in
                .init(
                    muscle: state.muscle,
                    weeklyLoadUnits: state.weeklyVolume,
                    fatigueLevel: state.fatigueLevel,
                    recoveryPercent: state.recoveryPercent,
                    normalizedFatigue: normalizedFatigue(for: state),
                    lastTrainedDate: state.lastTrainedDate,
                    nextReadyDate: state.nextReadyDate
                )
            },
            generatedAt: generatedAt
        )
    }
}
```

## Prevention

Vision Pro나 다른 platform-specific surface를 확장할 때는 UI-specific orchestration과 shared calculation을 처음부터 분리한다. 테스트 헬퍼는 Swift 6 기준으로 `@Sendable` closure에서 mutable captured var를 직접 다루지 않도록 공용 locked wrapper 또는 actor를 사용한다.

### Checklist Addition

- [ ] 새 visionOS/SwiftUI 화면이 helper `String` leak 없이 `LocalizedStringKey` 또는 `String(localized:)` 경로를 따르는지 확인
- [ ] `@Sendable` 테스트 closure가 mutable captured var를 직접 수정하지 않는지 확인
- [ ] platform target 확장 시 계산 로직이 shared Domain에 남아 있는지 확인

### Rule Addition (if applicable)

새 규칙 파일 추가는 불필요했다. 기존 localization/testing/layer-boundary 규칙을 그대로 적용해 해결 가능했다.

## Lessons Learned

Vision Pro 기능은 asset-heavy 접근보다 shared domain analyzer + procedural RealityKit primitives 조합이 구현 속도와 target 안정성 측면에서 더 유리했다. 또 Swift 6 동시성 검사는 기존 테스트 헬퍼의 숨은 shared-state 문제를 빨리 드러내므로, feature 작업 중에도 테스트 인프라 정비를 함께 처리하는 편이 전체 파이프라인을 더 빠르게 끝낸다.
